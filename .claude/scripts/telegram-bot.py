#!/usr/bin/env python3
"""
telegram-bot.py — Long-poll Telegram-Bot-Adapter (Tier-2)

Listens for /btw <text> from allowed Telegram users, writes items to
.claude/stakeholder/inbox/ via btw.sh with BTW_SOURCE_TIER=tier-2.

Stdlib-only: urllib, json, os, hmac, hashlib, time, subprocess, pathlib.

Usage:
  telegram-bot.py           — long-poll loop (default)
  telegram-bot.py --once    — one getUpdates iteration then exit (for tests)
  telegram-bot.py --status  — print rate-limit state JSON and exit
"""

import json
import os
import sys
import hmac
import hashlib
import time
import subprocess
import pathlib
import urllib.request
import urllib.error

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")
ALLOWED_USER_IDS_RAW = os.environ.get("TELEGRAM_ALLOWED_USER_IDS", "")
HMAC_SECRET_FILE = os.path.expanduser(
    os.environ.get("TELEGRAM_HMAC_SECRET_FILE", "~/.claude/telegram-hmac-secret")
)

# Support MOCK_TELEGRAM_API_DIR for tests
MOCK_DIR = os.environ.get("MOCK_TELEGRAM_API_DIR", "")

# Resolve repo root: script lives in .claude/scripts/
SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
REPO_ROOT = pathlib.Path(os.environ.get("REPO_ROOT", str(SCRIPT_DIR.parent.parent)))

STATE_DIR = REPO_ROOT / ".claude" / "overseer" / "state"
RATELIMIT_FILE = STATE_DIR / "telegram-ratelimit.json"
INBOX_DIR = REPO_ROOT / ".claude" / "stakeholder" / "inbox"
DIGEST_DIR = REPO_ROOT / ".claude" / "stakeholder" / "digest"
BTW_SH = REPO_ROOT / ".claude" / "scripts" / "btw.sh"
AUDIT_SH = REPO_ROOT / ".claude" / "scripts" / "lib" / "audit.sh"
NOTIFY_SH = REPO_ROOT / ".claude" / "scripts" / "notify.sh"

RATE_LIMIT_MAX = 5          # max /btw items per hour per user
RATE_LIMIT_WINDOW = 3600    # 1 hour in seconds
LONG_POLL_TIMEOUT = 30      # seconds for Telegram long-poll

# Yota-specific limits
YOTA_RATE_LIMIT_MAX = 10        # max /yota <frage> LLM-calls per hour per user
YOTA_LLM_TIMEOUT = 60           # seconds for claude --print --agent yota
YOTA_LLM_BUDGET_USD = "0.30"    # max-budget-usd cap per LLM call
TELEGRAM_MAX_MSG_LEN = 4096     # Telegram sendMessage max characters

YOTA_RATELIMIT_FILE = None  # populated lazily (depends on STATE_DIR)
YOTA_INFLIGHT_FILE = None   # populated lazily

YOTA_SNAPSHOT_SH = None
CLAUDE_BIN = os.environ.get("CLAUDE_BIN", "claude")
# Allow tests to stub LLM-call
MOCK_YOTA_LLM_CMD = os.environ.get("MOCK_YOTA_LLM_CMD", "")
# Allow tests to stub snapshot
MOCK_YOTA_SNAPSHOT_CMD = os.environ.get("MOCK_YOTA_SNAPSHOT_CMD", "")

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

def validate_config():
    errors = []
    if not BOT_TOKEN:
        errors.append("TELEGRAM_BOT_TOKEN is not set")
    if not ALLOWED_USER_IDS_RAW:
        errors.append("TELEGRAM_ALLOWED_USER_IDS is not set (comma-separated numeric IDs)")
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

def parse_allowed_ids():
    ids = set()
    for part in ALLOWED_USER_IDS_RAW.split(","):
        part = part.strip()
        if part:
            try:
                ids.add(int(part))
            except ValueError:
                print(f"WARNING: invalid user ID '{part}' in TELEGRAM_ALLOWED_USER_IDS", file=sys.stderr)
    return ids

# ---------------------------------------------------------------------------
# Telegram API helpers
# ---------------------------------------------------------------------------

TELEGRAM_API_BASE = f"https://api.telegram.org/bot{BOT_TOKEN}"

def _mock_get_updates(offset):
    """Read mock updates from MOCK_TELEGRAM_API_DIR/updates.json."""
    updates_file = pathlib.Path(MOCK_DIR) / "updates.json"
    if not updates_file.exists():
        return []
    with open(updates_file) as f:
        data = json.load(f)
    # Filter by offset
    updates = [u for u in data if u.get("update_id", 0) >= offset]
    return updates

def _mock_send_message(chat_id, text):
    """Write sent messages to MOCK_TELEGRAM_API_DIR/sent.jsonl."""
    sent_file = pathlib.Path(MOCK_DIR) / "sent.jsonl"
    entry = {"chat_id": chat_id, "text": text, "ts": time.time()}
    with open(sent_file, "a") as f:
        f.write(json.dumps(entry) + "\n")

def get_updates(offset=0):
    if MOCK_DIR:
        return _mock_get_updates(offset)
    url = f"{TELEGRAM_API_BASE}/getUpdates"
    payload = json.dumps({"offset": offset, "timeout": LONG_POLL_TIMEOUT}).encode()
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=LONG_POLL_TIMEOUT + 5) as resp:
            result = json.loads(resp.read().decode())
            if result.get("ok"):
                return result.get("result", [])
    except (urllib.error.URLError, json.JSONDecodeError) as e:
        print(f"WARNING: getUpdates failed: {e}", file=sys.stderr)
    return []

def send_message(chat_id, text, parse_mode=None):
    """
    Send a message to Telegram. Auto-splits messages longer than
    TELEGRAM_MAX_MSG_LEN. parse_mode in {None, 'HTML', 'MarkdownV2'}.
    """
    if not text:
        return
    chunks = _split_for_telegram(text, TELEGRAM_MAX_MSG_LEN)
    for chunk in chunks:
        _send_single(chat_id, chunk, parse_mode)


def _send_single(chat_id, text, parse_mode):
    if MOCK_DIR:
        _mock_send_message(chat_id, text)
        return
    url = f"{TELEGRAM_API_BASE}/sendMessage"
    body = {"chat_id": chat_id, "text": text}
    if parse_mode:
        body["parse_mode"] = parse_mode
    payload = json.dumps(body).encode()
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            pass
    except urllib.error.URLError as e:
        print(f"WARNING: sendMessage failed: {e}", file=sys.stderr)
        # Fallback: retry without parse_mode (in case HTML was malformed)
        if parse_mode:
            try:
                body2 = {"chat_id": chat_id, "text": text}
                payload2 = json.dumps(body2).encode()
                req2 = urllib.request.Request(
                    url, data=payload2,
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                with urllib.request.urlopen(req2, timeout=10):
                    pass
            except urllib.error.URLError:
                pass


def send_chat_action(chat_id, action="typing"):
    """Show 'typing...' indicator while we generate an answer."""
    if MOCK_DIR:
        return  # no-op in tests
    url = f"{TELEGRAM_API_BASE}/sendChatAction"
    payload = json.dumps({"chat_id": chat_id, "action": action}).encode()
    req = urllib.request.Request(
        url, data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=5):
            pass
    except urllib.error.URLError:
        pass


def _split_for_telegram(text, limit):
    """Split text into chunks <= limit, preferring line boundaries."""
    if len(text) <= limit:
        return [text]
    chunks = []
    remaining = text
    while len(remaining) > limit:
        # Find last newline within limit
        cut = remaining.rfind("\n", 0, limit)
        if cut <= 0:
            cut = limit
        chunks.append(remaining[:cut].rstrip("\n"))
        remaining = remaining[cut:].lstrip("\n")
    if remaining:
        chunks.append(remaining)
    return chunks


# ---------------------------------------------------------------------------
# Markdown → HTML (Telegram parse_mode=HTML)
# ---------------------------------------------------------------------------

import re as _re

def md_to_html(text: str) -> str:
    """
    Convert a small Markdown subset to Telegram-HTML.
    Supports: **bold**, *italic*, `code`, ```block```, [text](url).
    Escapes raw <, >, & first; emitted tags are added afterwards.
    """
    if not text:
        return ""

    # 1) Extract fenced code blocks first so they're not touched by other rules
    placeholders = []

    def stash(match):
        idx = len(placeholders)
        placeholders.append(match.group(1))
        return f"\x00BLOCK{idx}\x00"

    text = _re.sub(r"```(.*?)```", stash, text, flags=_re.DOTALL)

    # 2) Extract inline code
    inline_codes = []

    def stash_inline(match):
        idx = len(inline_codes)
        inline_codes.append(match.group(1))
        return f"\x00ICODE{idx}\x00"

    text = _re.sub(r"`([^`\n]+)`", stash_inline, text)

    # 3) Escape HTML-special chars in remaining text
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    # 4) Links [text](url)
    def link_sub(m):
        label = m.group(1)
        url = m.group(2).replace('"', "%22")
        return f'<a href="{url}">{label}</a>'
    text = _re.sub(r"\[([^\]]+)\]\(([^)]+)\)", link_sub, text)

    # 5) Bold **x** (before italic so *x* doesn't eat one of the stars)
    text = _re.sub(r"\*\*([^*\n]+)\*\*", r"<b>\1</b>", text)
    # 6) Italic *x*  (single-star, non-greedy, no inner star)
    text = _re.sub(r"(?<![\w*])\*([^*\n]+)\*(?!\w)", r"<i>\1</i>", text)

    # 7) Restore inline code with escaping
    def restore_inline(m):
        idx = int(m.group(1))
        content = inline_codes[idx]
        content = content.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        return f"<code>{content}</code>"
    text = _re.sub(r"\x00ICODE(\d+)\x00", restore_inline, text)

    # 8) Restore block code
    def restore_block(m):
        idx = int(m.group(1))
        content = placeholders[idx]
        content = content.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        return f"<pre>{content}</pre>"
    text = _re.sub(r"\x00BLOCK(\d+)\x00", restore_block, text)

    return text

# ---------------------------------------------------------------------------
# Rate-limit (sliding window, state file)
# ---------------------------------------------------------------------------

def _load_ratelimit():
    if RATELIMIT_FILE.exists():
        try:
            with open(RATELIMIT_FILE) as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError):
            pass
    return {}

def _save_ratelimit(state):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with open(RATELIMIT_FILE, "w") as f:
        json.dump(state, f, indent=2)

def check_rate_limit(user_id: int) -> bool:
    """
    Returns True if user is within rate limit (item allowed).
    Updates state file. Uses sliding window: prune events older than 1h.
    """
    now = time.time()
    state = _load_ratelimit()
    key = str(user_id)
    entry = state.get(key, {"items": [], "items_last_hour": 0, "first_in_window_ts": 0})

    # Migrate old format (items_last_hour / first_in_window_ts) to items list
    if "items" not in entry:
        # Legacy: reconstruct from count + first_ts (best effort)
        first_ts = entry.get("first_in_window_ts", 0)
        count = entry.get("items_last_hour", 0)
        if now - first_ts < RATE_LIMIT_WINDOW and count > 0:
            entry["items"] = [first_ts + i for i in range(count)]
        else:
            entry["items"] = []

    # Prune old items
    entry["items"] = [ts for ts in entry["items"] if now - ts < RATE_LIMIT_WINDOW]

    if len(entry["items"]) >= RATE_LIMIT_MAX:
        state[key] = entry
        _save_ratelimit(state)
        return False

    entry["items"].append(now)
    # Keep legacy fields in sync for --status display
    entry["items_last_hour"] = len(entry["items"])
    entry["first_in_window_ts"] = entry["items"][0] if entry["items"] else 0
    state[key] = entry
    _save_ratelimit(state)
    return True

# ---------------------------------------------------------------------------
# Yota rate-limit (separate counter, 10/h) + in-flight lock
# ---------------------------------------------------------------------------

def _yota_ratelimit_file():
    return STATE_DIR / "telegram-yota-ratelimit.json"

def _yota_inflight_file():
    return STATE_DIR / "telegram-yota-inflight.json"

def check_yota_rate_limit(user_id: int) -> bool:
    """True if user is within Yota LLM-call rate limit (10/h)."""
    now = time.time()
    f = _yota_ratelimit_file()
    state = {}
    if f.exists():
        try:
            state = json.loads(f.read_text())
        except (json.JSONDecodeError, OSError):
            state = {}
    key = str(user_id)
    entry = state.get(key, {"items": []})
    entry["items"] = [ts for ts in entry.get("items", []) if now - ts < RATE_LIMIT_WINDOW]
    if len(entry["items"]) >= YOTA_RATE_LIMIT_MAX:
        state[key] = entry
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        f.write_text(json.dumps(state, indent=2))
        return False
    entry["items"].append(now)
    state[key] = entry
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    f.write_text(json.dumps(state, indent=2))
    return True

def yota_inflight_acquire(user_id: int) -> bool:
    """Return True if no other Yota-call is running for this user."""
    now = time.time()
    f = _yota_inflight_file()
    state = {}
    if f.exists():
        try:
            state = json.loads(f.read_text())
        except (json.JSONDecodeError, OSError):
            state = {}
    key = str(user_id)
    cur = state.get(key)
    # Expire stale lock (older than YOTA_LLM_TIMEOUT + buffer)
    if cur and now - cur.get("started", 0) < YOTA_LLM_TIMEOUT + 10:
        return False
    state[key] = {"started": now}
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    f.write_text(json.dumps(state, indent=2))
    return True

def yota_inflight_release(user_id: int):
    f = _yota_inflight_file()
    if not f.exists():
        return
    try:
        state = json.loads(f.read_text())
    except (json.JSONDecodeError, OSError):
        return
    state.pop(str(user_id), None)
    f.write_text(json.dumps(state, indent=2))

# ---------------------------------------------------------------------------
# Yota invocations
# ---------------------------------------------------------------------------

def invoke_yota_snapshot() -> str:
    """Run yota-snapshot.sh --human and return stdout (Markdown)."""
    if MOCK_YOTA_SNAPSHOT_CMD:
        cmd = ["bash", "-c", MOCK_YOTA_SNAPSHOT_CMD]
    else:
        snap = REPO_ROOT / ".claude" / "scripts" / "yota-snapshot.sh"
        cmd = ["bash", str(snap), "--human"]
    try:
        r = subprocess.run(
            cmd,
            capture_output=True, text=True, timeout=15,
            env={**os.environ, "REPO_ROOT": str(REPO_ROOT)},
        )
        out = (r.stdout or "").strip()
        if not out and r.returncode != 0:
            return f"snapshot failed (rc={r.returncode}): {(r.stderr or '').strip()[:300]}"
        return out or "(empty snapshot)"
    except subprocess.TimeoutExpired:
        return "snapshot timeout (>15s)"
    except Exception as e:
        return f"snapshot error: {e}"

def invoke_yota_llm(question: str) -> str:
    """
    Run `claude --print --agent yota -p "<question>"` with budget cap.
    Returns answer text or a human-readable error message.
    """
    if MOCK_YOTA_LLM_CMD:
        cmd = ["bash", "-c", MOCK_YOTA_LLM_CMD]
        env = {**os.environ, "YOTA_QUESTION": question}
    else:
        cmd = [
            CLAUDE_BIN, "--print",
            "--agent", "yota",
            "--max-budget-usd", YOTA_LLM_BUDGET_USD,
            "-p", question,
        ]
        env = {**os.environ, "CLAUDE_PROJECT_DIR": str(REPO_ROOT)}
    try:
        r = subprocess.run(
            cmd, capture_output=True, text=True,
            timeout=YOTA_LLM_TIMEOUT, cwd=str(REPO_ROOT), env=env,
        )
        out = (r.stdout or "").strip()
        if not out and r.returncode != 0:
            return f"Yota-Fehler (rc={r.returncode}): {(r.stderr or '').strip()[:300]}"
        return out or "(Yota lieferte keine Antwort)"
    except subprocess.TimeoutExpired:
        return "Yota braucht länger als erwartet, schau ins Briefing."
    except FileNotFoundError:
        return "Yota-CLI nicht gefunden (claude binary fehlt im PATH)."
    except Exception as e:
        return f"Yota-Fehler: {e}"

# ---------------------------------------------------------------------------
# HMAC Token (per-briefing rotation)
# ---------------------------------------------------------------------------

def _get_hmac_secret():
    if not pathlib.Path(HMAC_SECRET_FILE).exists():
        return None
    try:
        with open(HMAC_SECRET_FILE, "rb") as f:
            return f.read().strip()
    except OSError:
        return None

def _get_latest_briefing_id():
    """Return filename stem of latest digest/*.md or None."""
    if not DIGEST_DIR.exists():
        return None
    digests = sorted(DIGEST_DIR.glob("*.md"), reverse=True)
    if not digests:
        return None
    return digests[0].stem

def _compute_expected_token(secret: bytes, briefing_id: str) -> str:
    msg = (briefing_id).encode("utf-8")
    return hmac.new(secret, msg, hashlib.sha256).hexdigest()

def verify_hmac_token(token: str) -> bool:
    """
    Returns True if HMAC verification passes OR if not required
    (no briefing file or no secret file).
    """
    secret = _get_hmac_secret()
    if secret is None:
        return True  # HMAC not configured → skip check
    briefing_id = _get_latest_briefing_id()
    if briefing_id is None:
        return True  # no briefing yet → initial bootstrap, skip check
    expected = _compute_expected_token(secret, briefing_id)
    # Constant-time compare
    return hmac.compare_digest(token, expected)

# ---------------------------------------------------------------------------
# Audit helper (shell-based)
# ---------------------------------------------------------------------------

def audit_record(actor, action, subject, reason):
    if not AUDIT_SH.exists():
        return
    env = dict(os.environ)
    env["CLAUDE_PROJECT_DIR"] = str(REPO_ROOT)
    env["REPO_ROOT"] = str(REPO_ROOT)
    script = f'source "{AUDIT_SH}" && audit_record "{actor}" "{action}" "{subject}" "{reason}"'
    subprocess.run(
        ["bash", "-c", script],
        env=env,
        capture_output=True,
    )

def notify_info(topic, title, body):
    if not NOTIFY_SH.exists():
        return
    env = dict(os.environ)
    env["REPO_ROOT"] = str(REPO_ROOT)
    subprocess.run(
        [str(NOTIFY_SH), "info", topic, title, body],
        env=env,
        capture_output=True,
    )

# ---------------------------------------------------------------------------
# btw.sh invocation
# ---------------------------------------------------------------------------

def invoke_btw(text: str) -> str:
    """
    Calls btw.sh with BTW_SOURCE_TIER=tier-2.
    Returns the slug/filename from stdout or empty string on failure.
    """
    env = dict(os.environ)
    env["BTW_SOURCE_TIER"] = "tier-2"
    env["REPO_ROOT"] = str(REPO_ROOT)
    env["CLAUDE_PROJECT_DIR"] = str(REPO_ROOT)

    result = subprocess.run(
        ["bash", str(BTW_SH), text],
        env=env,
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        # btw.sh prints: "btw.sh: queued <filename>"
        out = result.stdout.strip()
        parts = out.split()
        if len(parts) >= 2:
            return parts[-1]
    else:
        print(f"WARNING: btw.sh failed (rc={result.returncode}): {result.stderr.strip()}", file=sys.stderr)
    return ""

# ---------------------------------------------------------------------------
# /yota and /status handler
# ---------------------------------------------------------------------------

def _handle_yota(chat_id, user_id, argtext):
    """
    /yota (no arg)  → snapshot (fast, free).
    /yota <frage>   → LLM-call via yota agent (rate-limited).
    Returns (chat_id, ('HTML', html_text)).
    """
    argtext = (argtext or "").strip()

    if not argtext:
        md = invoke_yota_snapshot()
        audit_record("telegram-bot", "yota_snapshot", "",
                     f"user={user_id}")
        return chat_id, ("HTML", md_to_html(md))

    # Rate-limit (LLM-cost guard)
    if not check_yota_rate_limit(user_id):
        audit_record("telegram-bot", "yota_rate_limited", "",
                     f"user={user_id}")
        return chat_id, (
            None,
            f"rate-limited: max {YOTA_RATE_LIMIT_MAX} Yota-Fragen pro Stunde erreicht. "
            "Schnell-Snapshot ohne Frage geht weiter (/yota)."
        )

    # Concurrency-lock
    if not yota_inflight_acquire(user_id):
        return chat_id, (None, "Moment, ich bin noch an deiner letzten Frage dran.")

    # Typing indicator (real API only; no-op in mock)
    send_chat_action(chat_id, "typing")

    try:
        answer = invoke_yota_llm(argtext)
    finally:
        yota_inflight_release(user_id)

    audit_record("telegram-bot", "yota_llm", "",
                 f"user={user_id} chars={len(argtext)}")
    return chat_id, ("HTML", md_to_html(answer))

# ---------------------------------------------------------------------------
# Update processing
# ---------------------------------------------------------------------------

def process_update(update, allowed_ids):
    """Process one Telegram update dict. Returns reply text or None."""
    message = update.get("message")
    if not message:
        return None, None

    chat_id = message.get("chat", {}).get("id")
    text = message.get("text", "")
    from_user = message.get("from", {})
    user_id = from_user.get("id")

    if not chat_id or not text or user_id is None:
        return None, None

    # --- Allowlist check ---
    if user_id not in allowed_ids:
        audit_record(
            "telegram-bot",
            "tier2_disallowed",
            "",
            f"user={user_id} reason=not-in-allowlist",
        )
        return chat_id, None  # ignore silently (no reply)

    # --- Command detection ---
    stripped = text.strip()
    # Allow command suffix `/foo@botname` from group-chats
    first_token = stripped.split(None, 1)[0] if stripped else ""
    cmd = first_token.split("@", 1)[0].lower()
    rest_after_cmd = stripped[len(first_token):].strip()

    # /help
    if cmd == "/help":
        msg = (
            "<b>Yota-Bot commands</b>\n"
            "/yota — Snapshot in 5 Zeilen (free, sofort).\n"
            "/yota <i>frage</i> — Yota-LLM-Antwort (~$0.05).\n"
            "/status — Alias zu /yota.\n"
            "/btw <i>text</i> — Stakeholder-Item ins Triage-Inbox.\n"
            "/help — diese Liste."
        )
        return chat_id, ("HTML", msg)

    # /yota or /status
    if cmd in ("/yota", "/status"):
        return _handle_yota(chat_id, user_id, rest_after_cmd)

    if cmd != "/btw":
        # Other commands
        return chat_id, "Only /btw <text> supported"

    # Parse /btw [token] <text>
    rest = rest_after_cmd

    if not rest:
        return chat_id, "Usage: /btw <text>"

    # --- Rate-limit check ---
    # (done after initial parsing so we don't count non-/btw messages)
    if not check_rate_limit(user_id):
        audit_record(
            "telegram-bot",
            "tier2_rate_limited",
            "",
            f"user={user_id}",
        )
        notify_info(
            "telegram-bot",
            "Telegram rate-limit hit",
            f"user={user_id} exceeded {RATE_LIMIT_MAX} items/hour",
        )
        return chat_id, "rate-limited: max 5 items/hour reached"

    # --- HMAC token check ---
    secret = _get_hmac_secret()
    briefing_id = _get_latest_briefing_id()
    hmac_required = secret is not None and briefing_id is not None

    actual_text = rest
    if hmac_required:
        # Expect: /btw <token> <text>
        parts = rest.split(None, 1)
        if len(parts) < 2:
            return chat_id, "Usage: /btw <token> <text>  (HMAC token required)"
        token_candidate = parts[0]
        actual_text = parts[1]
        if not verify_hmac_token(token_candidate):
            audit_record(
                "telegram-bot",
                "tier2_hmac_rejected",
                "",
                f"user={user_id} reason=invalid-token",
            )
            return chat_id, "rejected: invalid HMAC token"

    # --- Invoke btw.sh ---
    slug_or_file = invoke_btw(actual_text)
    if not slug_or_file:
        return chat_id, "error: failed to queue item"

    # Use slug part (strip timestamp prefix for display)
    slug = slug_or_file.replace(".md", "")
    if "-" in slug:
        # strip YYYYMMDD-HHMMSS- prefix
        parts = slug.split("-", 2)
        if len(parts) >= 3:
            slug = parts[2]

    audit_record(
        "telegram-bot",
        "tier2_received",
        slug,
        f"user={user_id} chars={len(actual_text)}",
    )

    return chat_id, f"queued: {slug}"

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def run_once(allowed_ids, last_update_id=0):
    """Run one getUpdates iteration. Returns new last_update_id."""
    updates = get_updates(offset=last_update_id + 1)
    for update in updates:
        update_id = update.get("update_id", 0)
        if update_id > last_update_id:
            last_update_id = update_id
        try:
            chat_id, reply = process_update(update, allowed_ids)
            if chat_id is not None and reply is not None:
                if isinstance(reply, tuple) and len(reply) == 2:
                    parse_mode, body = reply
                    send_message(chat_id, body, parse_mode=parse_mode)
                else:
                    send_message(chat_id, reply)
        except Exception as e:
            print(f"WARNING: error processing update {update.get('update_id')}: {e}", file=sys.stderr)
    return last_update_id

def run_loop(allowed_ids):
    """Long-poll loop — runs until interrupted."""
    last_update_id = 0
    print(f"telegram-bot: starting long-poll loop (allowed users: {sorted(allowed_ids)})", flush=True)
    while True:
        try:
            last_update_id = run_once(allowed_ids, last_update_id)
        except KeyboardInterrupt:
            print("\ntelegram-bot: stopped", flush=True)
            break
        except Exception as e:
            print(f"WARNING: loop error: {e}", file=sys.stderr)
            time.sleep(5)

def cmd_status():
    state = _load_ratelimit()
    print(json.dumps(state, indent=2))

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    args = sys.argv[1:]

    if "--status" in args:
        cmd_status()
        return

    validate_config()
    allowed_ids = parse_allowed_ids()

    if "--once" in args:
        run_once(allowed_ids, last_update_id=0)
        return

    run_loop(allowed_ids)

if __name__ == "__main__":
    main()
