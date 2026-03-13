#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: preflight.sh [--json] [--refresh] [--ttl-seconds N] [--project-root DIR]
EOF
  exit 64
}

JSON_MODE="false"
FORCE_REFRESH="false"
TTL_SECONDS="${AGENT_DISCUSS_PREFLIGHT_TTL_SECONDS:-900}"
PROJECT_ROOT=""

now_epoch() { date +%s; }
now_iso() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

run_cmd() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 5 "$@" 2>&1
    return
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout 5 "$@" 2>&1
    return
  fi
  "$@" 2>&1
}

probe_version() {
  local cli="$1"
  local raw=""
  raw="$(run_cmd "$cli" --version || true)"
  printf '%s' "$raw" | tr -d '\r' | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

probe_claude_auth() {
  local raw=""
  raw="$(run_cmd claude auth status || true)"
  [[ -z "$raw" ]] && { printf 'unknown'; return; }
  python3 - "$raw" <<'PYEOF'
import json
import sys

raw = sys.argv[1]
try:
    data = json.loads(raw)
except Exception:
    print("unknown")
    raise SystemExit(0)

logged_in = data.get("loggedIn")
if logged_in is True:
    print("true")
elif logged_in is False:
    print("false")
else:
    print("unknown")
PYEOF
}

probe_codex_auth() {
  local raw=""
  raw="$(run_cmd codex login status || true)"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  if [[ "$raw" == *"not logged in"* || "$raw" == *"logged out"* || "$raw" == *"not authenticated"* ]]; then
    printf 'false'
  elif [[ "$raw" == *"logged in"* ]]; then
    printf 'true'
  else
    printf 'unknown'
  fi
}

cache_fresh() {
  [[ "$TTL_SECONDS" == "0" ]] && return 1
  [[ "$FORCE_REFRESH" == "true" ]] && return 1
  [[ -f "$CACHE_FILE" ]] || return 1
  python3 - "$CACHE_FILE" "$TTL_SECONDS" "$(now_epoch)" <<'PYEOF'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
ttl = int(sys.argv[2])
now = int(sys.argv[3])

try:
    data = json.loads(path.read_text())
except Exception:
    raise SystemExit(1)

checked = int(data.get("checked_at_epoch", -1))
if checked < 0:
    raise SystemExit(1)

age = now - checked
raise SystemExit(0 if 0 <= age <= ttl else 1)
PYEOF
}

write_cache() {
  mkdir -p "$CACHE_DIR"
  python3 - "$CACHE_FILE" "$(now_epoch)" "$(now_iso)" \
    "$HAS_JQ" "$CAN_REVIEW" "$CROSS_MODEL" "$EXIT_CODE" "$RECOMMENDED" \
    "$CLAUDE_INSTALLED" "$CLAUDE_VERSION" "$CLAUDE_AUTH" "$CLAUDE_AVAILABLE" \
    "$CODEX_INSTALLED" "$CODEX_VERSION" "$CODEX_AUTH" "$CODEX_AVAILABLE" <<'PYEOF'
import json
import pathlib
import sys

(_, cache_file, checked_epoch, checked_at, has_jq, can_review, cross_model, exit_code, recommended,
 claude_installed, claude_version, claude_auth, claude_available,
 codex_installed, codex_version, codex_auth, codex_available) = sys.argv

def b(value):
    return value == "true"

def auth(value):
    if value == "unknown":
        return None
    return value == "true"

data = {
    "checked_at": checked_at,
    "checked_at_epoch": int(checked_epoch),
    "jq": b(has_jq),
    "can_review": b(can_review),
    "cross_model": b(cross_model),
    "exit_code": int(exit_code),
    "adapters": {
        "codex": {
            "available": b(codex_available),
            "installed": b(codex_installed),
            "version": codex_version,
            "authenticated": auth(codex_auth),
            "invoke": "codex exec --full-auto --",
        },
        "claude": {
            "available": b(claude_available),
            "installed": b(claude_installed),
            "version": claude_version,
            "authenticated": auth(claude_auth),
            "invoke": "claude -p --dangerously-skip-permissions",
        },
    },
    "recommended_reviewer": recommended,
}

path = pathlib.Path(cache_file)
path.write_text(json.dumps(data, indent=2) + "\n")
PYEOF
}

print_human() {
  python3 - "$CACHE_FILE" <<'PYEOF'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(f"project_root: {pathlib.Path(sys.argv[1]).parents[3]}")
print(f"recommended: {data.get('recommended_reviewer', 'none')}")
print(f"can_review: {data.get('can_review', False)}")
print(f"cross_model: {data.get('cross_model', False)}")
for name in ("codex", "claude"):
    adapter = data.get("adapters", {}).get(name, {})
    print(f"{name}: installed={adapter.get('installed')} auth={adapter.get('authenticated')} available={adapter.get('available')} version={adapter.get('version')}")
PYEOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_MODE="true"; shift ;;
    --refresh) FORCE_REFRESH="true"; shift ;;
    --ttl-seconds) [[ $# -lt 2 ]] && usage; TTL_SECONDS="$2"; shift 2 ;;
    --project-root) [[ $# -lt 2 ]] && usage; PROJECT_ROOT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ "$TTL_SECONDS" =~ ^[0-9]+$ ]] || usage

if [[ -z "$PROJECT_ROOT" ]]; then
  PROJECT_ROOT="$(pwd)"
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
CACHE_DIR="$PROJECT_ROOT/.ai/cache/preflight"
CACHE_FILE="$CACHE_DIR/adapters.json"

if cache_fresh; then
  if [[ "$JSON_MODE" == "true" ]]; then
    cat "$CACHE_FILE"
  else
    print_human
  fi
  python3 - "$CACHE_FILE" <<'PYEOF'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())
raise SystemExit(int(data.get("exit_code", 3)))
PYEOF
fi

HAS_JQ="false"
command -v jq >/dev/null 2>&1 && HAS_JQ="true"

CLAUDE_INSTALLED="false"
CLAUDE_VERSION=""
CLAUDE_AUTH="unknown"
CLAUDE_AVAILABLE="false"
if command -v claude >/dev/null 2>&1; then
  CLAUDE_INSTALLED="true"
  CLAUDE_VERSION="$(probe_version claude)"
  CLAUDE_AUTH="$(probe_claude_auth)"
  [[ "$CLAUDE_AUTH" != "false" ]] && CLAUDE_AVAILABLE="true"
fi

CODEX_INSTALLED="false"
CODEX_VERSION=""
CODEX_AUTH="unknown"
CODEX_AVAILABLE="false"
if command -v codex >/dev/null 2>&1; then
  CODEX_INSTALLED="true"
  CODEX_VERSION="$(probe_version codex)"
  CODEX_AUTH="$(probe_codex_auth)"
  [[ "$CODEX_AUTH" != "false" ]] && CODEX_AVAILABLE="true"
fi

CAN_REVIEW="false"
CROSS_MODEL="false"
EXIT_CODE=3
RECOMMENDED="none"

if [[ "$CODEX_AVAILABLE" == "true" ]]; then
  RECOMMENDED="codex"
elif [[ "$CLAUDE_AVAILABLE" == "true" ]]; then
  RECOMMENDED="claude"
fi

if [[ "$CODEX_AVAILABLE" == "true" || "$CLAUDE_AVAILABLE" == "true" ]]; then
  CAN_REVIEW="true"
  EXIT_CODE=2
fi

if [[ "$CODEX_AVAILABLE" == "true" && "$CLAUDE_AVAILABLE" == "true" ]]; then
  CROSS_MODEL="true"
  EXIT_CODE=0
fi

write_cache

if [[ "$JSON_MODE" == "true" ]]; then
  cat "$CACHE_FILE"
else
  print_human
fi

exit "$EXIT_CODE"
