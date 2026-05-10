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

RATE_LIMIT_MAX = 5          # max items per hour per user
RATE_LIMIT_WINDOW = 3600    # 1 hour in seconds
LONG_POLL_TIMEOUT = 30      # seconds for Telegram long-poll

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

def send_message(chat_id, text):
    if MOCK_DIR:
        _mock_send_message(chat_id, text)
        return
    url = f"{TELEGRAM_API_BASE}/sendMessage"
    payload = json.dumps({"chat_id": chat_id, "text": text}).encode()
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
    if not text.startswith("/btw"):
        # Other commands
        return chat_id, "Only /btw <text> supported"

    # Parse /btw [token] <text>
    # Strip "/btw" prefix
    rest = text[len("/btw"):].strip()

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
