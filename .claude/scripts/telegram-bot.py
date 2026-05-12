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

# Onboarding state dir (T23b)
INTAKE_ONBOARDING_STATE_DIR = pathlib.Path(
    os.environ.get("INTAKE_ONBOARDING_STATE_DIR",
                   str(pathlib.Path.home() / ".claude" / "state"))
)

# Intake (Council-gated) paths
PENDING_PROPOSAL_DIR = REPO_ROOT / ".claude" / "stakeholder" / "pending-proposal"
PENDING_APPROVAL_DIR = REPO_ROOT / ".claude" / "stakeholder" / "pending-approval"
REJECTED_DIR = REPO_ROOT / ".claude" / "stakeholder" / "rejected"
OVERSEER_INBOX_DIR = REPO_ROOT / ".claude" / "overseer" / "inbox"

YOTA_PROPOSE_SH = REPO_ROOT / ".claude" / "scripts" / "yota-propose.sh"
INTAKE_COUNCIL_SH = REPO_ROOT / ".claude" / "scripts" / "intake-council.sh"
COST_CAP_LIB = REPO_ROOT / ".claude" / "scripts" / "lib" / "cost-cap.sh"
INTAKE_TOKENS_LIB = REPO_ROOT / ".claude" / "scripts" / "lib" / "intake-tokens.sh"

MAX_INTAKE_ROUNDS = 3
INTAKE_REJECT_STREAK_THRESHOLD = int(os.environ.get("INTAKE_REJECT_STREAK_THRESHOLD", "5"))
INTAKE_REJECT_STREAK_WINDOW = 48 * 3600  # 48h
INTAKE_REJECT_STREAK_DEBOUNCE = 24 * 3600  # max 1 streak-notify per 24h
REJECT_STREAK_STATE_FILE = REPO_ROOT / ".claude" / "intake-council" / "state" / "reject-streak.json"

# Mocks for tests
MOCK_INTAKE_COUNCIL_CMD = os.environ.get("MOCK_INTAKE_COUNCIL_CMD", "")
MOCK_INTAKE_VALIDATOR_CMD = os.environ.get("MOCK_INTAKE_VALIDATOR_CMD", "")
MOCK_COST_TODAY_USD = os.environ.get("MOCK_COST_TODAY_USD", "")
MOCK_HOUR = os.environ.get("MOCK_HOUR", "")  # for quiet-hours testing

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

    Returns ``{"ok": True}`` when every chunk reached Telegram's API,
    ``{"ok": False, "error": "..."}`` otherwise. Pre-existing callers that
    ignore the return value remain unaffected (truthy on success).
    """
    if not text:
        return {"ok": True, "skipped": "empty"}
    chunks = _split_for_telegram(text, TELEGRAM_MAX_MSG_LEN)
    last_err = None
    for chunk in chunks:
        if not _send_single(chat_id, chunk, parse_mode):
            last_err = "send_failed"
    if last_err:
        return {"ok": False, "error": last_err}
    return {"ok": True}


def _send_single(chat_id, text, parse_mode) -> bool:
    """Send one chunk. Returns True iff Telegram accepted it (HTTP 200 + ok)."""
    if MOCK_DIR:
        _mock_send_message(chat_id, text)
        return True
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
            raw = resp.read().decode()
            try:
                resp_json = json.loads(raw)
            except Exception:
                resp_json = {}
            if not resp_json.get("ok", True):
                # Telegram returned ok=false; treat as failure so caller retries.
                return False
            return True
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
                    return True
            except urllib.error.URLError:
                return False
        return False


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
# T23b — Onboarding: first /btw after intake roll-out
# ---------------------------------------------------------------------------

INTAKE_ONBOARDING_HINT = (
    "\n\nℹ️ <b>Neu seit Mai 2026:</b> <code>/yota propose &lt;idee&gt;</code> "
    "lässt ein kleines Council deine Idee beraten bevor sie ins Backlog "
    "geht (~$1, ~90s). <code>/btw</code> bleibt der Direkt-Pfad ohne Gate. "
    "Mehr: <code>/help</code>"
)


def _intake_onboarding_marker(user_id: int) -> pathlib.Path:
    return INTAKE_ONBOARDING_STATE_DIR / f"yota-intake-introduced-{user_id}"


def _should_show_intake_onboarding(user_id: int) -> bool:
    """True if this is the first /btw for this user since intake roll-out."""
    return not _intake_onboarding_marker(user_id).exists()


def _mark_intake_onboarding_shown(user_id: int):
    """Create state-marker so onboarding is not shown again."""
    INTAKE_ONBOARDING_STATE_DIR.mkdir(parents=True, exist_ok=True)
    _intake_onboarding_marker(user_id).touch()


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
# Intake (Council-gated) helpers — T09..T13
# ---------------------------------------------------------------------------

INTAKE_ID_RE = _re.compile(r"^[0-9]{8}-[0-9]{6}-[a-z0-9-]{1,40}$")

# Reply-parser regex tables (DE/EN aliases). Order: go-anyway BEFORE go.
GO_ANYWAY_RE = _re.compile(
    r"^go-anyway\s+(?P<id>[a-z0-9-]+|\d+)\s+(?P<token>[a-f0-9]{16})\s+(?P<reason>.+)$",
    _re.IGNORECASE,
)
GO_RE = _re.compile(
    r"^(?:go|👍|okay|ok|ja|approve)\s+(?P<id>[a-z0-9-]+|\d+)\s*(?P<token>[a-f0-9]{16})?\s*$",
    _re.IGNORECASE,
)
REJECT_RE = _re.compile(
    r"^(?:reject|nope|nein|nö|stop)\s+(?P<id>[a-z0-9-]+|\d+)(?:\s+(?P<reason>.+))?$",
    _re.IGNORECASE,
)
CHANGE_RE = _re.compile(
    r"^(?:change|ändere|aber)\s+(?P<id>[a-z0-9-]+|\d+)\s+(?P<text>.+)$",
    _re.IGNORECASE | _re.DOTALL,
)


def _parse_frontmatter(path: pathlib.Path):
    """Parse simple YAML frontmatter — flat key: value pairs only."""
    try:
        content = path.read_text(encoding="utf-8")
    except OSError:
        return {}
    if not content.startswith("---"):
        return {}
    end = content.find("\n---", 3)
    if end < 0:
        return {}
    block = content[3:end].strip("\n")
    fm = {}
    for line in block.splitlines():
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        fm[k.strip()] = v.strip().strip('"').strip("'")
    return fm


def _write_frontmatter_field(path: pathlib.Path, field: str, value: str):
    """Update a single frontmatter field in-place (atomic via tmp+rename)."""
    try:
        content = path.read_text(encoding="utf-8")
    except OSError:
        return False
    pat = _re.compile(rf"^({_re.escape(field)}):.*$", _re.MULTILINE)
    new_line = f"{field}: {value}"
    if pat.search(content):
        new_content = pat.sub(new_line, content, count=1)
    else:
        # Inject before closing ---
        if content.startswith("---"):
            end = content.find("\n---", 3)
            if end >= 0:
                new_content = content[:end] + "\n" + new_line + content[end:]
            else:
                return False
        else:
            return False
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(new_content, encoding="utf-8")
    os.replace(str(tmp), str(path))
    return True


def _list_pending_approvals(user_id=None):
    """Return list of (path, frontmatter) for live pending-approval files."""
    out = []
    if not PENDING_APPROVAL_DIR.exists():
        return out
    for p in sorted(PENDING_APPROVAL_DIR.glob("*.md")):
        name = p.name
        if name.endswith(".superseded.md"):
            continue
        # ignore subdirs (stale/, etc handled by glob non-recursion)
        fm = _parse_frontmatter(p)
        if user_id is not None and fm.get("user_id"):
            # user_id may be "12345" or "local-xxx"
            if str(fm["user_id"]) != str(user_id):
                continue
        out.append((p, fm))
    return out


def _resolve_intake_id(id_or_slug: str, user_id):
    """
    Resolve user-typed ID (full ID, slug-prefix, or numeric index) to a
    pending-approval path. Returns (path, frontmatter, ambiguous_list).
    On exact match: (path, fm, []).
    On slug-prefix unique match: (path, fm, []).
    On multiple matches: (None, None, list).
    On no match: (None, None, []).
    """
    pendings = _list_pending_approvals(user_id=user_id)
    if not pendings:
        return None, None, []

    # Numeric index — within current user's pending list
    if id_or_slug.isdigit():
        idx = int(id_or_slug) - 1
        if 0 <= idx < len(pendings):
            p, fm = pendings[idx]
            return p, fm, []
        return None, None, []

    # Exact full intake ID
    if INTAKE_ID_RE.match(id_or_slug):
        for p, fm in pendings:
            if fm.get("id") == id_or_slug:
                return p, fm, []
        return None, None, []

    # Slug-prefix fuzzy match (e.g. "csv" matches "20260512-101010-csv-export")
    matches = []
    for p, fm in pendings:
        full_id = fm.get("id", p.stem)
        # The slug portion after YYYYMMDD-HHMMSS-
        parts = full_id.split("-", 2)
        slug = parts[2] if len(parts) >= 3 else full_id
        if slug.startswith(id_or_slug.lower()):
            matches.append((p, fm))
    if len(matches) == 1:
        return matches[0][0], matches[0][1], []
    if len(matches) > 1:
        return None, None, matches
    return None, None, []


def _intake_rate_limit_check(user_id: int) -> bool:
    """Use the same 5/h limit as /btw, dedicated state key."""
    return check_rate_limit(user_id)


def _spawn_intake_council(proposal_path: str):
    """Spawn intake-council.sh as a detached subprocess."""
    if MOCK_INTAKE_COUNCIL_CMD:
        env = {**os.environ, "INTAKE_PROPOSAL_PATH": proposal_path}
        try:
            subprocess.Popen(
                ["bash", "-c", MOCK_INTAKE_COUNCIL_CMD],
                env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except Exception as e:
            print(f"WARNING: mock intake-council spawn failed: {e}", file=sys.stderr)
        return
    env = dict(os.environ)
    # Pre-flight: unset ANTHROPIC_API_KEY (T08a)
    env.pop("ANTHROPIC_API_KEY", None)
    env["REPO_ROOT"] = str(REPO_ROOT)
    env["CLAUDE_PROJECT_DIR"] = str(REPO_ROOT)
    try:
        subprocess.Popen(
            ["nohup", "bash", str(INTAKE_COUNCIL_SH), proposal_path],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except FileNotFoundError:
        # No nohup — still detach via start_new_session
        subprocess.Popen(
            ["bash", str(INTAKE_COUNCIL_SH), proposal_path],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception as e:
        print(f"WARNING: intake-council spawn failed: {e}", file=sys.stderr)


def _cost_today_usd_str() -> str:
    """Get day-cost via lib/cost-cap.sh `cost_today_usd`. Mock-friendly."""
    if MOCK_COST_TODAY_USD:
        return MOCK_COST_TODAY_USD
    if not COST_CAP_LIB.exists():
        return "0.00"
    try:
        r = subprocess.run(
            ["bash", "-c",
             f'source "{COST_CAP_LIB}" && cost_today_usd'],
            env={**os.environ, "REPO_ROOT": str(REPO_ROOT),
                 "CLAUDE_PROJECT_DIR": str(REPO_ROOT)},
            capture_output=True, text=True, timeout=5,
        )
        out = (r.stdout or "").strip()
        return out or "0.00"
    except Exception:
        return "0.00"


VERDICT_EMOJI = {
    "propose": "✅",
    "propose-with-changes": "✏️",
    "reject": "❌",
    "needs-full-council": "⚠️",
}


def _short_summary(path: pathlib.Path) -> str:
    """Extract first non-empty line under '## Verdict-Summary' (1 sentence)."""
    try:
        content = path.read_text(encoding="utf-8")
    except OSError:
        return ""
    m = _re.search(r"^##\s*Verdict-Summary\s*$\n+([^\n#].+?)(?:\n\n|\n##|\Z)",
                   content, _re.MULTILINE | _re.DOTALL)
    if not m:
        return ""
    line = m.group(1).strip().split("\n")[0].strip()
    if len(line) > 160:
        line = line[:157] + "..."
    return line


def _render_verdict_mini(path: pathlib.Path, fm: dict) -> str:
    """3-line mini-format (Plan §5 / T13b)."""
    verdict = fm.get("verdict", "unknown")
    emoji = VERDICT_EMOJI.get(verdict, "•")
    full_id = fm.get("id", path.stem)
    parts = full_id.split("-", 2)
    slug = parts[2] if len(parts) >= 3 else full_id
    summary = _short_summary(path) or f"verdict={verdict}"
    token = fm.get("hmac_token", "")
    day_cost = _cost_today_usd_str()
    if verdict == "reject":
        action = f"→ go-anyway {slug} {token} <reason>  ·  reject {slug}"
    elif verdict == "needs-full-council":
        action = f"→ /council {slug} (Self-Mod-Pfad)"
    else:
        action = f"→ go {slug} {token}  ·  reject {slug}  ·  change {slug} <text>"
    return f"{emoji} {slug} — {verdict}\n└ {summary}\n└ {action}\n💰 ${day_cost} heute"


# --- Quiet-hours-aware push (uses notify.sh info → respects DND) ---
def _push_verdict(path: pathlib.Path, fm: dict) -> bool:
    """Push verdict via notify.sh + direct Telegram. Returns True only when the
    Telegram send to the creator actually succeeded (so the watcher can retry
    on transient network errors instead of falsely marking pushed_at)."""
    body = _render_verdict_mini(path, fm)
    title = f"Intake-Verdict: {fm.get('id', path.stem)}"
    # notify.sh — best-effort (ntfy-side; failure doesn't block retry)
    if NOTIFY_SH.exists():
        env = dict(os.environ)
        env["REPO_ROOT"] = str(REPO_ROOT)
        if MOCK_HOUR:
            env["NOTIFY_FORCE_HOUR"] = MOCK_HOUR
        subprocess.run(
            [str(NOTIFY_SH), "info", "intake-verdict", title, body],
            env=env, capture_output=True,
        )
    # Direct Telegram send to creator — authoritative success-signal
    user_id = fm.get("user_id", "")
    if not (user_id and user_id.isdigit()):
        # No Telegram creator (e.g. local-CLI proposal) → ntfy-only.
        # Consider that successful so we don't retry forever.
        return True
    try:
        result = send_message(int(user_id), body)
    except Exception as exc:
        sys.stderr.write(f"_push_verdict: telegram send failed: {exc}\n")
        return False
    # send_message returns the parsed Telegram response; check ok-flag.
    if isinstance(result, dict):
        return bool(result.get("ok"))
    # Unknown shape — treat as not-confirmed so we retry.
    return False


def watch_pending_verdicts():
    """Scan pending-approval/*.md, push any without pushed_at, set marker.

    pushed_at is set ONLY when the push to the creator's Telegram chat
    succeeded. On transient failure (network, Telegram-API down), the watcher
    retries on the next tick instead of silently dropping the verdict.
    """
    if not PENDING_APPROVAL_DIR.exists():
        return 0
    pushed = 0
    for p in sorted(PENDING_APPROVAL_DIR.glob("*.md")):
        if p.name.endswith(".superseded.md"):
            continue
        fm = _parse_frontmatter(p)
        pushed_at = fm.get("pushed_at", "")
        if pushed_at:
            continue
        ok = _push_verdict(p, fm)
        if not ok:
            audit_record("telegram-bot", "intake_verdict_push_retry", fm.get("id", p.stem), "deferred")
            continue
        iso = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        _write_frontmatter_field(p, "pushed_at", iso)
        audit_record("telegram-bot", "intake_verdict_pushed", fm.get("id", p.stem), "auto")
        pushed += 1
    return pushed


# --- Anti-loop / reject-streak (Mitigation #20, T17) ---

def _load_streak_state() -> dict:
    """Load reject-streak.json; return empty dict on missing/corrupt."""
    try:
        if REJECT_STREAK_STATE_FILE.exists():
            return json.loads(REJECT_STREAK_STATE_FILE.read_text(encoding="utf-8"))
    except Exception:
        pass
    return {}


def _save_streak_state(state: dict) -> None:
    """Persist reject-streak.json atomically."""
    try:
        REJECT_STREAK_STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        tmp = REJECT_STREAK_STATE_FILE.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
        tmp.replace(REJECT_STREAK_STATE_FILE)
    except Exception:
        pass


def _update_reject_streak(user_id: str) -> int:
    """
    Record a reject event for user_id in reject-streak.json.
    Prunes history entries older than 48h (sliding window).
    Returns updated count_48h.
    """
    state = _load_streak_state()
    now = time.time()
    cutoff = now - INTAKE_REJECT_STREAK_WINDOW
    uid = str(user_id)

    entry = state.get(uid, {"count_48h": 0, "first_in_window_ts": None, "history": []})
    # Prune old entries
    history = [ts for ts in entry.get("history", []) if ts > cutoff]
    # Append current event
    history.append(now)
    first_ts = history[0] if history else now
    entry = {
        "count_48h": len(history),
        "first_in_window_ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(first_ts)),
        "history": history,
    }
    state[uid] = entry
    _save_streak_state(state)
    return entry["count_48h"]


def _reset_reject_streak(user_id: str) -> None:
    """Reset the reject-streak counter for user_id (called on 'go')."""
    state = _load_streak_state()
    uid = str(user_id)
    if uid in state:
        state[uid] = {"count_48h": 0, "first_in_window_ts": None, "history": []}
        _save_streak_state(state)


def _streak_debounce_check(user_id: str) -> bool:
    """
    Returns True if a streak-alarm notify may be sent (not debounced).
    Debounce key stored in reject-streak.json as '<uid>_last_alarm_ts'.
    """
    state = _load_streak_state()
    uid = str(user_id)
    last_alarm = state.get(f"{uid}_last_alarm_ts", 0)
    return (time.time() - last_alarm) >= INTAKE_REJECT_STREAK_DEBOUNCE


def _record_streak_alarm(user_id: str) -> None:
    """Record the timestamp of the last streak-alarm for debounce."""
    state = _load_streak_state()
    state[f"{str(user_id)}_last_alarm_ts"] = time.time()
    _save_streak_state(state)


def _check_reject_streak(user_id) -> int:
    """
    Backward-compatible helper: update persistent state and return count_48h.
    Use _update_reject_streak() for the authoritative path in _handle_reject.
    """
    return _update_reject_streak(str(user_id))


# --- Validator invocation (T11) ---
def _run_intake_validator(approval_path: pathlib.Path) -> tuple:
    """
    Invoke intake-validator agent. Returns (verdict, reason).
    verdict in {pass, needs-full-council, quarantine, error}.
    """
    if MOCK_INTAKE_VALIDATOR_CMD:
        env = {**os.environ, "INTAKE_APPROVAL_PATH": str(approval_path),
               "REPO_ROOT": str(REPO_ROOT)}
        try:
            r = subprocess.run(
                ["bash", "-c", MOCK_INTAKE_VALIDATOR_CMD],
                env=env, capture_output=True, text=True, timeout=10,
            )
            out = (r.stdout or "").strip().lower()
            err = (r.stderr or "").strip()
            for tag in ("pass", "needs-full-council", "quarantine"):
                if tag in out:
                    return tag, err or out
            return ("error", out or err or "no verdict")
        except Exception as e:
            return ("error", str(e))
    # Real run
    env = dict(os.environ)
    env.pop("ANTHROPIC_API_KEY", None)
    env["REPO_ROOT"] = str(REPO_ROOT)
    env["CLAUDE_PROJECT_DIR"] = str(REPO_ROOT)
    cmd = [CLAUDE_BIN, "--print", "--agent", "intake-validator",
           "-p", f"Validate file: {approval_path}"]
    try:
        r = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=90)
        out = (r.stdout or "").strip().lower()
        for tag in ("pass", "needs-full-council", "quarantine"):
            if tag in out:
                return tag, ""
        return ("error", r.stderr.strip()[:200] if r.stderr else "no verdict")
    except Exception as e:
        return ("error", str(e))


# ---------------------------------------------------------------------------
# Intake command handlers
# ---------------------------------------------------------------------------

def _handle_yota_propose(chat_id, user_id, text):
    text = (text or "").strip()
    if not text:
        return chat_id, "Usage: /yota propose <text>"

    if not _intake_rate_limit_check(user_id):
        audit_record("telegram-bot", "intake_rate_limited", "", f"user={user_id}")
        return chat_id, f"Rate-Limit ({RATE_LIMIT_MAX}/h) — bitte später."

    env = dict(os.environ)
    env["YOTA_PROPOSE_TIER"] = "tier-2"
    env["TELEGRAM_USER_ID"] = str(user_id)
    env["REPO_ROOT"] = str(REPO_ROOT)
    env["CLAUDE_PROJECT_DIR"] = str(REPO_ROOT)
    env.pop("ANTHROPIC_API_KEY", None)

    try:
        r = subprocess.run(
            ["bash", str(YOTA_PROPOSE_SH), text],
            env=env, capture_output=True, text=True, timeout=15,
        )
    except subprocess.TimeoutExpired:
        return chat_id, "❌ yota-propose Timeout"

    rc = r.returncode
    stdout = (r.stdout or "").strip()
    stderr = (r.stderr or "").strip()

    if rc == 2:
        audit_record("telegram-bot", "intake_sentinel_rejected", "", f"user={user_id}")
        return chat_id, "❌ Prompt-Injection erkannt, ignoriert."
    if rc == 3:
        return chat_id, f"⚠️ Identischer Vorschlag in den letzten Stunden — {stderr[:200]}"
    if rc != 0 or not stdout:
        return chat_id, f"❌ yota-propose Fehler: {stderr[:200] or 'unknown'}"

    proposal_path = stdout.splitlines()[-1].strip()
    _spawn_intake_council(proposal_path)
    audit_record("telegram-bot", "intake_proposal_queued",
                 pathlib.Path(proposal_path).stem, f"user={user_id}")

    slug = pathlib.Path(proposal_path).stem
    day_cost = _cost_today_usd_str()
    msg = (
        f"📥 Proposal queued: `{slug}`\n"
        f"Council deliberiert (~90s, ~$0.50-2).\n"
        f"💰 Cost heute: ${day_cost}"
    )
    return chat_id, ("HTML", md_to_html(msg))


def _handle_yota_pending(chat_id, user_id):
    pendings = _list_pending_approvals(user_id=user_id)
    if not pendings:
        return chat_id, "Nichts offen."
    lines = [f"📋 Pending Approvals ({len(pendings)}):"]
    for i, (p, fm) in enumerate(pendings, start=1):
        full_id = fm.get("id", p.stem)
        parts = full_id.split("-", 2)
        slug = parts[2] if len(parts) >= 3 else full_id
        verdict = fm.get("verdict", "?")
        token = fm.get("hmac_token", "")[:8]
        # age
        try:
            age_s = int(time.time() - p.stat().st_mtime)
            if age_s < 3600:
                age = f"{age_s // 60}min"
            elif age_s < 86400:
                age = f"{age_s // 3600}h"
            else:
                age = f"{age_s // 86400}d"
        except OSError:
            age = "?"
        lines.append(f"{i}. `{slug}` ({verdict}, vor {age}) — go {slug} {token}")
    lines.append("")
    lines.append("Reply: `go <slug-or-id> <token>` / `reject <id>` / `change <id> <text>`")
    return chat_id, ("HTML", md_to_html("\n".join(lines)))


def _move_to_rejected(path: pathlib.Path, reason: str, fm: dict):
    REJECTED_DIR.mkdir(parents=True, exist_ok=True)
    iso = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    try:
        content = path.read_text(encoding="utf-8")
    except OSError:
        content = ""
    # Build new file with rejected frontmatter prepended
    new_fm = (
        "---\n"
        f"id: {fm.get('id', path.stem)}\n"
        "state: rejected\n"
        "rejected_by: user\n"
        f"rejected_at: {iso}\n"
        f"user_reason: {reason}\n"
        f"council_verdict_was: {fm.get('verdict', 'unknown')}\n"
        "---\n\n"
        "## Original (snapshot)\n\n"
    )
    target = REJECTED_DIR / path.name
    target.write_text(new_fm + content, encoding="utf-8")
    try:
        path.unlink()
    except OSError:
        pass
    return target


def _handle_go(chat_id, user_id, m, override=False):
    """Shared handler for go and go-anyway."""
    id_or_slug = m.group("id")
    token = m.group("token") if "token" in m.groupdict() else None
    reason = m.group("reason") if override else None

    if id_or_slug and not (id_or_slug.isdigit() or _re.match(r"^[a-z0-9-]+$", id_or_slug)):
        audit_record("telegram-bot", "intake_id_invalid", id_or_slug, f"user={user_id}")
        return chat_id, "Ungültige ID-Form."

    # Resolve WITHOUT user-id filter so we can detect wrong-user attempts
    path, fm, ambiguous = _resolve_intake_id(id_or_slug, None)
    if ambiguous:
        lines = ["Mehrere offen, welches?"]
        for i, (p, f) in enumerate(ambiguous, start=1):
            lines.append(f"{i}. {f.get('id', p.stem)}")
        return chat_id, "\n".join(lines)
    if not path:
        return chat_id, "Keine offene Approval mit dieser ID."

    # Creator-binding (silent ignore on mismatch)
    fm_user = fm.get("user_id", "")
    if str(fm_user) != str(user_id) and not (fm_user.startswith("local-")):
        audit_record("telegram-bot", "intake_go_wrong_user",
                     fm.get("id", path.stem), f"actual={user_id} expected={fm_user}")
        return chat_id, None  # silent ignore

    # HMAC token check (if token provided)
    if token:
        # Verify via intake-tokens lib
        try:
            r = subprocess.run(
                ["bash", "-c",
                 f'source "{INTAKE_TOKENS_LIB}" && verify_hmac_token "{fm.get("id", "")}" "{token}"'],
                env={**os.environ, "REPO_ROOT": str(REPO_ROOT)},
                capture_output=True, timeout=5,
            )
            if r.returncode != 0:
                # Cross-check frontmatter hmac_token directly (constant-time)
                expected = fm.get("hmac_token", "")
                if not hmac.compare_digest(expected, token):
                    audit_record("telegram-bot", "intake_token_mismatch",
                                 fm.get("id", path.stem), f"user={user_id}")
                    return chat_id, "Token ungültig."
        except Exception:
            expected = fm.get("hmac_token", "")
            if not hmac.compare_digest(expected, token):
                audit_record("telegram-bot", "intake_token_mismatch",
                             fm.get("id", path.stem), f"user={user_id}")
                return chat_id, "Token ungültig."

    # go-anyway: only for reject-verdicts, mandatory reason >10 chars
    verdict_was = fm.get("verdict", "")
    if override:
        if verdict_was != "reject":
            return chat_id, "go-anyway nur für reject-Verdicts."
        if not reason or len(reason.strip()) <= 10:
            return chat_id, "go-anyway braucht <reason> (>10 Zeichen Begründung)."
        audit_record("telegram-bot", "intake_user_go_anyway",
                     fm.get("id", path.stem), f"user={user_id} reason={reason[:80]}")

    # Run validator
    val_verdict, val_reason = _run_intake_validator(path)
    audit_record("telegram-bot", "intake_user_go",
                 fm.get("id", path.stem),
                 f"user={user_id} validator={val_verdict} override={override}")

    slug_parts = fm.get("id", path.stem).split("-", 2)
    slug = slug_parts[2] if len(slug_parts) >= 3 else fm.get("id", path.stem)

    if val_verdict == "pass":
        # Validator already wrote overseer/inbox/01-stakeholder-<slug>.md.
        # Move approval file out of live path (atomic).
        try:
            done_dir = PENDING_APPROVAL_DIR / "approved"
            done_dir.mkdir(parents=True, exist_ok=True)
            path.rename(done_dir / path.name)
        except OSError:
            pass
        # Reset reject-streak counter on go (T17)
        _reset_reject_streak(str(user_id))
        return chat_id, f"✅ approved + queued als `{slug}`."
    if val_verdict == "needs-full-council":
        return chat_id, f"⚠️ Self-Mod-Pfad erkannt. Reply `/council {slug}` zum starten."
    if val_verdict == "quarantine":
        return chat_id, f"❌ Quarantined (Regel-Verstoß): {val_reason[:200]}"
    return chat_id, f"❌ Validator-Fehler: {val_reason[:200]}"


def _handle_reject(chat_id, user_id, m):
    id_or_slug = m.group("id")
    reason = (m.group("reason") or "").strip()
    path, fm, ambiguous = _resolve_intake_id(id_or_slug, None)
    if ambiguous:
        return chat_id, f"Mehrere offen ({len(ambiguous)}) — nutze /yota pending für IDs."
    if not path:
        return chat_id, "Keine offene Approval mit dieser ID."
    if str(fm.get("user_id", "")) != str(user_id) and not fm.get("user_id", "").startswith("local-"):
        audit_record("telegram-bot", "intake_go_wrong_user",
                     fm.get("id", path.stem), f"actual={user_id}")
        return chat_id, None

    _move_to_rejected(path, reason, fm)
    audit_record("telegram-bot", "intake_user_reject",
                 fm.get("id", path.stem), f"user={user_id} reason={reason[:80]}")

    streak = _update_reject_streak(str(user_id))
    if streak >= INTAKE_REJECT_STREAK_THRESHOLD:
        if _streak_debounce_check(user_id):
            audit_record("telegram-bot", "intake_rejected_streak_alarm",
                         str(user_id),
                         f"streak={streak} window=48h threshold={INTAKE_REJECT_STREAK_THRESHOLD}")
            env = dict(os.environ)
            env["REPO_ROOT"] = str(REPO_ROOT)
            try:
                subprocess.run(
                    [str(NOTIFY_SH), "critical", "intake-streak",
                     "Reject-Streak", f"{streak} rejects in 48h — Brainstorm-Modus oder Council off?"],
                    env=env, capture_output=True,
                )
            except Exception:
                pass
            _record_streak_alarm(user_id)
    return chat_id, f"❌ Rejected. Anti-Loop-Counter: {streak}/{INTAKE_REJECT_STREAK_THRESHOLD}."


def _handle_change(chat_id, user_id, m):
    id_or_slug = m.group("id")
    new_text = (m.group("text") or "").strip()
    path, fm, ambiguous = _resolve_intake_id(id_or_slug, None)
    if ambiguous:
        return chat_id, f"Mehrere offen ({len(ambiguous)})."
    if not path:
        return chat_id, "Keine offene Approval mit dieser ID."
    if str(fm.get("user_id", "")) != str(user_id) and not fm.get("user_id", "").startswith("local-"):
        return chat_id, None

    # Round-counter enforcement
    try:
        cur_round = int(fm.get("round", "1"))
    except ValueError:
        cur_round = 1
    if cur_round >= MAX_INTAKE_ROUNDS:
        return chat_id, "Max 3 Runden erreicht. Schliess mit `go`/`reject`."

    # Atomic-mv to superseded
    full_id = fm.get("id", path.stem)
    superseded = path.with_name(path.stem + ".superseded.md")
    try:
        path.rename(superseded)
    except OSError as e:
        return chat_id, f"❌ Konnte nicht versionieren: {e}"

    # Write new pending-proposal with round+1
    PENDING_PROPOSAL_DIR.mkdir(parents=True, exist_ok=True)
    new_proposal = PENDING_PROPOSAL_DIR / f"{full_id}.md"
    iso = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    try:
        orig_content = superseded.read_text(encoding="utf-8")
    except OSError:
        orig_content = ""
    body = (
        "---\n"
        f"id: {full_id}\n"
        f"source: {fm.get('source', 'tier-2')}\n"
        f"trust_tier: {fm.get('trust_tier', '2')}\n"
        f"user_id: {user_id}\n"
        f"created_at: {iso}\n"
        "state: pending-proposal\n"
        f"round: {cur_round + 1}\n"
        f"content_hash: {fm.get('content_hash', '')}\n"
        "---\n\n"
        f"<<<UNTRUSTED_PROPOSAL tier={fm.get('trust_tier', '2')}>>>\n"
        f"{orig_content}\n\n"
        f"## User-Change (Round {cur_round + 1})\n"
        f"{new_text}\n"
        "<<<END_UNTRUSTED_PROPOSAL>>>\n"
    )
    new_proposal.write_text(body, encoding="utf-8")

    _spawn_intake_council(str(new_proposal))
    audit_record("telegram-bot", "intake_user_change",
                 full_id, f"user={user_id} round={cur_round + 1}")
    audit_record("telegram-bot", "intake_round_advanced",
                 full_id, f"round={cur_round + 1}")

    return chat_id, f"🔄 Round {cur_round + 1} läuft mit deiner Korrektur. Verdict in ~90s."


def _try_intake_reply(chat_id, user_id, stripped):
    """Try parsing the user reply as a council intake command.
    Returns (chat_id, reply) tuple if matched, else None."""
    m = GO_ANYWAY_RE.match(stripped)
    if m:
        return _handle_go(chat_id, user_id, m, override=True)
    m = GO_RE.match(stripped)
    if m:
        return _handle_go(chat_id, user_id, m, override=False)
    m = REJECT_RE.match(stripped)
    if m:
        return _handle_reject(chat_id, user_id, m)
    m = CHANGE_RE.match(stripped)
    if m:
        return _handle_change(chat_id, user_id, m)
    return None


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
            "/yota propose <i>idee</i> — Council-gated intake (default, ~$0.50-2).\n"
            "/yota pending — offene Council-Verdicts auflisten.\n"
            "/yota — Snapshot in 5 Zeilen (free, sofort).\n"
            "/yota <i>frage</i> — Yota-LLM-Antwort (~$0.05).\n"
            "/btw <i>text</i> — Power-User Fast-Lane (skip Council).\n"
            "go &lt;id&gt; &lt;token&gt; / reject &lt;id&gt; / change &lt;id&gt; &lt;text&gt; / go-anyway &lt;id&gt; &lt;token&gt; &lt;reason&gt;\n"
            "/status — Alias zu /yota.\n"
            "/help — diese Liste."
        )
        return chat_id, ("HTML", msg)

    # /yota propose <text>  — Council-gated intake (T09)
    # Also aliases: /yotapropose, /propose
    if cmd in ("/yota", "/yotapropose", "/propose"):
        # /yota propose <text>
        if cmd == "/yota" and rest_after_cmd.lower().startswith("propose"):
            sub = rest_after_cmd[len("propose"):].strip()
            return _handle_yota_propose(chat_id, user_id, sub)
        if cmd == "/yota" and rest_after_cmd.lower().strip() == "pending":
            return _handle_yota_pending(chat_id, user_id)
        if cmd in ("/yotapropose", "/propose"):
            return _handle_yota_propose(chat_id, user_id, rest_after_cmd)
        # Plain /yota → snapshot/LLM (existing behaviour)
        return _handle_yota(chat_id, user_id, rest_after_cmd)

    if cmd == "/status":
        return _handle_yota(chat_id, user_id, rest_after_cmd)

    # Intake reply parsing (go/reject/change/go-anyway) — T11/T12
    intake_reply = _try_intake_reply(chat_id, user_id, stripped)
    if intake_reply is not None:
        return intake_reply

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

    # T23b — show onboarding hint exactly once per user after intake roll-out
    reply_text = f"queued: {slug}"
    if _should_show_intake_onboarding(user_id):
        reply_text += INTAKE_ONBOARDING_HINT
        _mark_intake_onboarding_shown(user_id)
        audit_record("telegram-bot", "intake_onboarding_shown", slug,
                     f"user={user_id}")
        return chat_id, ("HTML", reply_text)

    return chat_id, reply_text

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
    """Long-poll loop — runs until interrupted. Watcher every 5 iterations."""
    last_update_id = 0
    iteration = 0
    print(f"telegram-bot: starting long-poll loop (allowed users: {sorted(allowed_ids)})", flush=True)
    while True:
        try:
            last_update_id = run_once(allowed_ids, last_update_id)
            iteration += 1
            if iteration % 5 == 0:
                try:
                    watch_pending_verdicts()
                except Exception as e:
                    print(f"WARNING: verdict-watcher: {e}", file=sys.stderr)
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

    if "--watch-once" in args:
        # Run only the verdict-watcher pass (no getUpdates). Useful for tests.
        pushed = watch_pending_verdicts()
        print(json.dumps({"pushed": pushed}))
        return

    validate_config()
    allowed_ids = parse_allowed_ids()

    if "--once" in args:
        run_once(allowed_ids, last_update_id=0)
        return

    run_loop(allowed_ids)

if __name__ == "__main__":
    main()
