#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage:
  discuss.sh start <topic> [options]
  discuss.sh continue <thread-id> [options]
  discuss.sh validate <raw-reply-file> [options]
  discuss.sh status <thread-id> [--project-root DIR]

Options:
  --project-root DIR
  --thread-id ID
  --adapter NAME
  --understanding TEXT
  --direction TEXT
  --constraints TEXT
  --ask TEXT
  --asset PATH            Repeatable
  --reply-file FILE       Skip adapter invocation and normalize FILE instead
  --validate-only         Normalize an existing raw reply without invoking an adapter
  --refresh-preflight
  --preflight-ttl-seconds N
  --dry-run
EOF
  exit 64
}

slugify() {
  python3 - "$1" <<'PYEOF'
import re
import sys

text = sys.argv[1].strip().lower()
text = re.sub(r"[^a-z0-9]+", "-", text)
text = re.sub(r"-{2,}", "-", text).strip("-")
print(text or "discussion")
PYEOF
}

now_iso() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

resolve_project_root() {
  if [[ -n "$PROJECT_ROOT" ]]; then
    PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
    return
  fi
  PROJECT_ROOT="$(pwd)"
}

auto_local_changes() {
  if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local diff_stat=""
    diff_stat="$(git -C "$PROJECT_ROOT" diff --stat -- . 2>/dev/null || true)"
    if [[ -n "$diff_stat" ]]; then
      printf '%s\n' "$diff_stat"
      return
    fi
    git -C "$PROJECT_ROOT" status --short -- . 2>/dev/null || echo "(git status empty)"
    return
  fi
  echo "(not a git repo)"
}

load_state() {
  local state_file="$1"
  eval "$(
    python3 - "$state_file" <<'PYEOF'
import json
import pathlib
import shlex
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())

def emit(name, value):
    if isinstance(value, list):
        value = "\n".join(value)
    print(f"{name}={shlex.quote(str(value))}")

emit("PREV_ROUND", data.get("round", 0))
emit("PREV_GOAL", data.get("goal", ""))
emit("PREV_UNDERSTANDING", data.get("background_brief", ""))
emit("PREV_DIRECTION", data.get("current_direction", ""))
emit("PREV_CONSTRAINTS", data.get("constraints", ""))
emit("PREV_ASK", data.get("next_action", ""))
emit("PREV_SYNTHESIS", data.get("last_remote_takeaways", ""))
emit("PREV_ASSETS", data.get("selected_assets", []))
PYEOF
  )"
}

write_request_json() {
  GOAL="$GOAL" \
  UNDERSTANDING="$UNDERSTANDING" \
  DIRECTION="$DIRECTION" \
  CONSTRAINTS="$CONSTRAINTS" \
  ASK="$ASK" \
  LOCAL_CHANGES="$LOCAL_CHANGES" \
  THREAD_ID="$THREAD_ID" \
  ROUND="$ROUND" \
  REQUEST_FILE="$REQUEST_FILE" \
  ASSET_LIST_FILE="$ASSET_LIST_FILE" \
  python3 - <<'PYEOF'
import json
import os
from pathlib import Path

assets = []
asset_list_file = os.environ["ASSET_LIST_FILE"]
if Path(asset_list_file).exists():
    assets = [line.strip() for line in Path(asset_list_file).read_text().splitlines() if line.strip()]

data = {
    "thread_id": os.environ["THREAD_ID"],
    "round": int(os.environ["ROUND"]),
    "goal": os.environ["GOAL"],
    "background_brief": os.environ["UNDERSTANDING"],
    "current_direction": os.environ["DIRECTION"],
    "constraints": os.environ["CONSTRAINTS"],
    "ask": os.environ["ASK"],
    "selected_assets": assets,
    "latest_local_changes": os.environ["LOCAL_CHANGES"],
}

Path(os.environ["REQUEST_FILE"]).write_text(json.dumps(data, indent=2) + "\n")
PYEOF
}

generate_packet() {
  REQUEST_FILE="$REQUEST_FILE" \
  PACKET_FILE="$PACKET_FILE" \
  PROJECT_ROOT="$PROJECT_ROOT" \
  python3 - <<'PYEOF'
import json
import os
from pathlib import Path

data = json.loads(Path(os.environ["REQUEST_FILE"]).read_text())
project_root = Path(os.environ["PROJECT_ROOT"])

def excerpt(path_str):
    path = project_root / path_str
    if not path.exists():
        return "(missing asset)"
    try:
        text = path.read_text()
    except Exception:
        return "(binary or unreadable asset)"
    lines = text.splitlines()[:120]
    snippet = "\n".join(lines)
    if len(snippet) > 4000:
        snippet = snippet[:4000] + "\n...(truncated)"
    return snippet or "(empty file)"

asset_sections = []
for asset in data.get("selected_assets", []):
    asset_sections.append(f"### {asset}\n```text\n{excerpt(asset)}\n```")

selected_assets = "\n\n".join(asset_sections) if asset_sections else "(no assets selected)"

packet = f"""# Agent Discuss Packet

## What this is

You are the other agent in a focused working discussion. This is not a review verdict request. Help sharpen the direction while keeping some healthy pushback.

## Goal

{data['goal']}

## My current understanding

{data['background_brief'] or '(not provided)'}

## My current direction

{data['current_direction'] or '(not provided)'}

## Constraints

{data['constraints'] or '(not provided)'}

## Latest local changes

```text
{data['latest_local_changes'] or '(no local changes summary)'}
```

## Selected assets

{selected_assets}

## What I need from you

{data['ask'] or 'Push back on weak assumptions, surface risks, suggest better options, and recommend the best next step.'}

## Response contract

Return JSON only. No markdown fences. Use this exact shape:

{{
  "agreement": ["..."],
  "pushback": ["..."],
  "risks": ["..."],
  "better_options": ["..."],
  "recommended_next_step": "...",
  "questions_back": ["..."],
  "one_paragraph_synthesis": "..."
}}
"""

Path(os.environ["PACKET_FILE"]).write_text(packet)
PYEOF
}

normalize_reply() {
  RAW_REPLY_FILE="$RAW_REPLY_FILE" \
  REPLY_JSON_FILE="$REPLY_JSON_FILE" \
  python3 - <<'PYEOF'
import json
import os
import re
from pathlib import Path

raw = Path(os.environ["RAW_REPLY_FILE"]).read_text() if Path(os.environ["RAW_REPLY_FILE"]).exists() else ""
clean = raw.strip()
if clean.startswith("```"):
    clean = re.sub(r"^```[a-zA-Z0-9_-]*\n", "", clean)
    clean = re.sub(r"\n```$", "", clean)

REQUIRED_KEYS = {"agreement", "pushback", "risks", "better_options",
                  "recommended_next_step", "questions_back", "one_paragraph_synthesis"}
PRIMARY_THRESHOLD = 5
DEGRADED_THRESHOLD = 3

def _is_placeholder_only(obj):
    for value in obj.values():
        if isinstance(value, list):
            if value and not all(item == "..." for item in value):
                return False
        elif isinstance(value, str) and value != "...":
            return False
    return True

def _as_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    text = str(value).strip()
    return [text] if text else []

def _meaningful(value):
    if isinstance(value, list):
        return any(item and item != "..." for item in value)
    if isinstance(value, str):
        stripped = value.strip()
        return bool(stripped and stripped != "...")
    return value is not None

def _candidate_stats(obj):
    matched_keys = REQUIRED_KEYS & set(obj.keys())
    non_empty_required = 0
    for key in matched_keys:
        if _meaningful(obj.get(key)):
            non_empty_required += 1
    return len(matched_keys), non_empty_required

decoder = json.JSONDecoder()
candidates = []
for idx, ch in enumerate(clean):
    if ch != "{":
        continue
    try:
        candidate, _ = decoder.raw_decode(clean[idx:])
    except Exception:
        continue
    if not isinstance(candidate, dict):
        continue
    matched_keys, non_empty_required = _candidate_stats(candidate)
    if matched_keys < DEGRADED_THRESHOLD:
        continue
    if _is_placeholder_only(candidate):
        continue
    candidates.append((matched_keys, non_empty_required, idx, candidate))

selected = None
confidence = "failed"
warnings = []

if candidates:
    primary = [item for item in candidates if item[0] >= PRIMARY_THRESHOLD]
    pool = primary if primary else candidates
    matched_keys, _, _, selected = max(pool, key=lambda item: (item[0], item[1], item[2]))
    if primary:
        confidence = "high"
    else:
        confidence = "degraded"
        warnings.append(
            f"Normalized reply used degraded extraction with only {matched_keys} matching contract keys."
        )

if not isinstance(selected, dict):
    obj = {
        "agreement": [],
        "pushback": ["Remote reply was not valid JSON. Inspect raw-reply.txt manually."],
        "risks": [],
        "better_options": [],
        "recommended_next_step": "Inspect the raw reply and rerun with a clearer packet if needed.",
        "questions_back": [],
        "one_paragraph_synthesis": clean[:600] or "Remote reply could not be normalized.",
    }
    warnings.append("No qualifying JSON object matched the discussion reply contract.")
else:
    obj = selected

result = {
    "agreement": _as_list(obj.get("agreement")),
    "pushback": _as_list(obj.get("pushback")),
    "risks": _as_list(obj.get("risks")),
    "better_options": _as_list(obj.get("better_options")),
    "recommended_next_step": str(obj.get("recommended_next_step", "")).strip() or "Review the synthesis and choose the next local action.",
    "questions_back": _as_list(obj.get("questions_back")),
    "one_paragraph_synthesis": str(obj.get("one_paragraph_synthesis", "")).strip(),
    "_normalized_confidence": confidence,
    "_validation_warnings": warnings,
}

if not result["pushback"]:
    result["pushback"] = ["The remote reply did not include explicit pushback. Re-check the current direction for weak assumptions."]
    result["_validation_warnings"].append("Reply did not include explicit pushback; inserted fallback pushback.")

if not result["one_paragraph_synthesis"]:
    result["one_paragraph_synthesis"] = "The remote reply was normalized, but no synthesis paragraph was provided."
    result["_validation_warnings"].append("Reply did not include a synthesis paragraph; inserted fallback synthesis.")

if len(result["one_paragraph_synthesis"]) < 20:
    result["_validation_warnings"].append("Synthesis paragraph is very short; inspect raw-reply.txt for truncation.")

if not (result["agreement"] or result["risks"] or result["better_options"]):
    result["_validation_warnings"].append(
        "Reply has no substantive agreement, risks, or better_options content."
    )

Path(os.environ["REPLY_JSON_FILE"]).write_text(json.dumps(result, indent=2) + "\n")
PYEOF
}

render_reply_md() {
  REPLY_JSON_FILE="$REPLY_JSON_FILE" \
  REPLY_MD_FILE="$REPLY_MD_FILE" \
  python3 - <<'PYEOF'
import json
import os
from pathlib import Path

data = json.loads(Path(os.environ["REPLY_JSON_FILE"]).read_text())

def section(title, items):
    if not items:
        return f"## {title}\n\n- (none)\n"
    body = "\n".join(f"- {item}" for item in items)
    return f"## {title}\n\n{body}\n"

content = "\n".join([
    "# Agent Discuss Reply",
    "",
    "## Normalization",
    "",
    f"- confidence: {data.get('_normalized_confidence', 'unknown')}",
    *([f"- warning: {item}" for item in data.get("_validation_warnings", [])] or ["- warning: (none)"]),
    "",
    section("Agreement", data["agreement"]),
    section("Pushback", data["pushback"]),
    section("Risks", data["risks"]),
    section("Better Options", data["better_options"]),
    "## Recommended Next Step",
    "",
    data["recommended_next_step"],
    "",
    section("Questions Back", data["questions_back"]),
    "## Synthesis",
    "",
    data["one_paragraph_synthesis"],
    "",
])

Path(os.environ["REPLY_MD_FILE"]).write_text(content)
PYEOF
}

write_state() {
  REQUEST_FILE="$REQUEST_FILE" \
  REPLY_JSON_FILE="$REPLY_JSON_FILE" \
  STATE_FILE="$STATE_FILE" \
  REL_PACKET_FILE="$REL_THREAD_DIR/packet.md" \
  REL_REPLY_JSON_FILE="$REL_THREAD_DIR/reply.json" \
  python3 - <<'PYEOF'
import json
import os
from pathlib import Path
from datetime import datetime, timezone

request = json.loads(Path(os.environ["REQUEST_FILE"]).read_text())
reply = json.loads(Path(os.environ["REPLY_JSON_FILE"]).read_text())

state = {
    "thread_id": request["thread_id"],
    "round": request["round"],
    "goal": request["goal"],
    "background_brief": request["background_brief"],
    "current_direction": request["current_direction"],
    "constraints": request["constraints"],
    "selected_assets": request["selected_assets"],
    "latest_local_changes": request["latest_local_changes"],
    "last_remote_takeaways": reply["one_paragraph_synthesis"],
    "open_questions": reply["questions_back"],
    "next_action": reply["recommended_next_step"],
    "updated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "latest_packet": os.environ["REL_PACKET_FILE"],
    "latest_reply": os.environ["REL_REPLY_JSON_FILE"],
}

Path(os.environ["STATE_FILE"]).write_text(json.dumps(state, indent=2) + "\n")
PYEOF
}

render_brief() {
  STATE_FILE="$STATE_FILE" \
  BRIEF_FILE="$BRIEF_FILE" \
  python3 - <<'PYEOF'
import json
import os
from pathlib import Path

state = json.loads(Path(os.environ["STATE_FILE"]).read_text())
questions = "\n".join(f"- {item}" for item in state.get("open_questions", [])) or "- (none)"
assets = "\n".join(f"- {item}" for item in state.get("selected_assets", [])) or "- (none)"

content = f"""# Thread Brief

## Goal

{state.get('goal', '')}

## Current Direction

{state.get('current_direction', '')}

## Selected Assets

{assets}

## Last Remote Takeaways

{state.get('last_remote_takeaways', '')}

## Open Questions

{questions}

## Next Action

{state.get('next_action', '')}
"""

Path(os.environ["BRIEF_FILE"]).write_text(content)
PYEOF
}

append_timeline() {
  STATE_FILE="$STATE_FILE" \
  TIMELINE_FILE="$TIMELINE_FILE" \
  python3 - <<'PYEOF'
import json
import os
from pathlib import Path

state = json.loads(Path(os.environ["STATE_FILE"]).read_text())
path = Path(os.environ["TIMELINE_FILE"])
if not path.exists():
    path.write_text("# Timeline\n\n")

entry = (
    f"## Round {state['round']} — {state['updated_at']}\n\n"
    f"- Goal: {state['goal']}\n"
    f"- Direction: {state['current_direction']}\n"
    f"- Takeaway: {state['last_remote_takeaways']}\n"
    f"- Next action: {state['next_action']}\n\n"
)
with path.open("a") as handle:
    handle.write(entry)
PYEOF
}

select_adapter() {
  python3 - "$ADAPTERS_CACHE" "$ADAPTER" <<'PYEOF'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())
requested = sys.argv[2]
if requested:
    print(requested)
    raise SystemExit(0)
print(data.get("recommended_reviewer", "none"))
PYEOF
}

SUBCOMMAND="${1:-}"
[[ -z "$SUBCOMMAND" ]] && usage
shift || true

PROJECT_ROOT=""
THREAD_ID=""
ADAPTER=""
UNDERSTANDING=""
DIRECTION=""
CONSTRAINTS=""
ASK=""
DRY_RUN="false"
REPLY_FILE=""
VALIDATE_ONLY="false"
REFRESH_PREFLIGHT="false"
PREFLIGHT_TTL_SECONDS="${AGENT_DISCUSS_PREFLIGHT_TTL_SECONDS:-900}"
ASSET_LIST=()

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --thread-id) THREAD_ID="$2"; shift 2 ;;
    --adapter) ADAPTER="$2"; shift 2 ;;
    --understanding) UNDERSTANDING="$2"; shift 2 ;;
    --direction) DIRECTION="$2"; shift 2 ;;
    --constraints) CONSTRAINTS="$2"; shift 2 ;;
    --ask) ASK="$2"; shift 2 ;;
    --asset) ASSET_LIST+=("$2"); shift 2 ;;
    --reply-file) REPLY_FILE="$2"; shift 2 ;;
    --validate-only) VALIDATE_ONLY="true"; shift ;;
    --refresh-preflight) REFRESH_PREFLIGHT="true"; shift ;;
    --preflight-ttl-seconds) PREFLIGHT_TTL_SECONDS="$2"; shift 2 ;;
    --dry-run) DRY_RUN="true"; shift ;;
    -h|--help) usage ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

resolve_project_root
DISCUSS_ROOT="$PROJECT_ROOT/.ai/discuss"
mkdir -p "$DISCUSS_ROOT"

case "$SUBCOMMAND" in
  start)
    GOAL="${POSITIONAL[*]:-}"
    [[ -n "$GOAL" ]] || { echo "ERROR: start requires a topic/goal" >&2; exit 1; }
    if [[ -z "$THREAD_ID" ]]; then
      THREAD_ID="$(date '+%Y%m%d')-$(slugify "$GOAL")"
    fi
    ROUND=1
    ;;
  continue)
    THREAD_ID="${POSITIONAL[0]:-${THREAD_ID}}"
    [[ -n "$THREAD_ID" ]] || { echo "ERROR: continue requires a thread id" >&2; exit 1; }
    STATE_FILE="$DISCUSS_ROOT/$THREAD_ID/state.json"
    [[ -f "$STATE_FILE" ]] || { echo "ERROR: thread state not found: $STATE_FILE" >&2; exit 1; }
    load_state "$STATE_FILE"
    ROUND=$((PREV_ROUND + 1))
    GOAL="${PREV_GOAL}"
    [[ -z "$UNDERSTANDING" ]] && UNDERSTANDING="${PREV_UNDERSTANDING}"
    [[ -z "$DIRECTION" ]] && DIRECTION="${PREV_DIRECTION}"
    [[ -z "$CONSTRAINTS" ]] && CONSTRAINTS="${PREV_CONSTRAINTS}"
    [[ -z "$ASK" ]] && ASK="Continue the discussion from the prior synthesis and pressure-test the updated direction."
    if (( ${#ASSET_LIST[@]} == 0 )) && [[ -n "${PREV_ASSETS:-}" ]]; then
      while IFS= read -r item; do
        [[ -n "$item" ]] && ASSET_LIST+=("$item")
      done <<< "$PREV_ASSETS"
    fi
    ;;
  validate)
    REPLY_FILE="${REPLY_FILE:-${POSITIONAL[0]:-}}"
    [[ -n "$REPLY_FILE" ]] || { echo "ERROR: validate requires a raw reply file or --reply-file" >&2; exit 1; }
    VALIDATE_ONLY="true"
    GOAL="validate-only"
    UNDERSTANDING="Normalize an existing raw reply without invoking an adapter."
    DIRECTION="Run the normalizer and render the structured reply artifacts."
    CONSTRAINTS="No adapter invocation. No source code mutation."
    ASK="Validate the parser output."
    if [[ -z "$THREAD_ID" ]]; then
      THREAD_ID="$(date '+%Y%m%d')-validate-$(slugify "$(basename "$REPLY_FILE")")"
    fi
    ROUND=1
    ;;
  status)
    THREAD_ID="${POSITIONAL[0]:-${THREAD_ID}}"
    [[ -n "$THREAD_ID" ]] || { echo "ERROR: status requires a thread id" >&2; exit 1; }
    BRIEF_FILE="$DISCUSS_ROOT/$THREAD_ID/brief.md"
    STATE_FILE="$DISCUSS_ROOT/$THREAD_ID/state.json"
    [[ -f "$STATE_FILE" ]] || { echo "ERROR: thread state not found: $STATE_FILE" >&2; exit 1; }
    if [[ -f "$BRIEF_FILE" ]]; then
      cat "$BRIEF_FILE"
    else
      cat "$STATE_FILE"
    fi
    exit 0
    ;;
  *)
    usage
    ;;
esac

THREAD_DIR="$DISCUSS_ROOT/$THREAD_ID"
mkdir -p "$THREAD_DIR"
REL_THREAD_DIR=".ai/discuss/$THREAD_ID"
REQUEST_FILE="$THREAD_DIR/request.json"
PACKET_FILE="$THREAD_DIR/packet.md"
RAW_REPLY_FILE="$THREAD_DIR/raw-reply.txt"
REPLY_JSON_FILE="$THREAD_DIR/reply.json"
REPLY_MD_FILE="$THREAD_DIR/reply.md"
STATE_FILE="$THREAD_DIR/state.json"
BRIEF_FILE="$THREAD_DIR/brief.md"
TIMELINE_FILE="$THREAD_DIR/timeline.md"
DEBUG_LOG_FILE="$THREAD_DIR/debug.log"
ASSET_LIST_FILE="$THREAD_DIR/assets.txt"

if [[ "$SUBCOMMAND" == "start" ]]; then
  [[ -n "$ASK" ]] || ASK="Push back on the current direction, name the key risks, and suggest the best next step."
fi

printf '%s\n' "${ASSET_LIST[@]:-}" | sed '/^$/d' > "$ASSET_LIST_FILE"
LOCAL_CHANGES="$(auto_local_changes)"
write_request_json
generate_packet

if [[ "$VALIDATE_ONLY" == "true" ]]; then
  [[ -n "$REPLY_FILE" ]] || { echo "ERROR: --validate-only requires --reply-file or validate <raw-reply-file>" >&2; exit 1; }
  : > "$DEBUG_LOG_FILE"
  cp "$REPLY_FILE" "$RAW_REPLY_FILE"
elif [[ -n "$REPLY_FILE" ]]; then
  : > "$DEBUG_LOG_FILE"
  cp "$REPLY_FILE" "$RAW_REPLY_FILE"
elif [[ "$DRY_RUN" == "true" ]]; then
  : > "$DEBUG_LOG_FILE"
  cat > "$RAW_REPLY_FILE" <<'EOF'
{
  "agreement": ["The direction is coherent enough for a first pass."],
  "pushback": ["The packet should prove why these selected assets are enough and what state still remains unknown."],
  "risks": ["Thread state may drift if local changes are not refreshed before each continue round."],
  "better_options": ["Add one small note in the brief about what changed since the previous round."],
  "recommended_next_step": "Review the generated packet and add or remove assets before sending it to a real agent.",
  "questions_back": ["Which assumption is most expensive if it turns out wrong?"],
  "one_paragraph_synthesis": "The current direction is viable, but the packet should make the unknowns and asset-selection rationale more explicit so future rounds stay compact without becoming vague."
}
EOF
else
  PREFLIGHT_ARGS=(--project-root "$PROJECT_ROOT" --ttl-seconds "$PREFLIGHT_TTL_SECONDS" --json)
  [[ "$REFRESH_PREFLIGHT" == "true" ]] && PREFLIGHT_ARGS+=(--refresh)
  "$SCRIPT_DIR/preflight.sh" "${PREFLIGHT_ARGS[@]}" >/dev/null
  ADAPTERS_CACHE="$PROJECT_ROOT/.ai/cache/preflight/adapters.json"
  SELECTED_ADAPTER="$(select_adapter)"
  [[ "$SELECTED_ADAPTER" != "none" ]] || { echo "ERROR: no available adapter" >&2; exit 1; }
  "$SCRIPT_DIR/invoke_adapter.sh" "$SELECTED_ADAPTER" "$PACKET_FILE" "$PROJECT_ROOT" > "$RAW_REPLY_FILE" 2> "$DEBUG_LOG_FILE"
fi

normalize_reply
render_reply_md
write_state
render_brief
append_timeline

echo "thread_id: $THREAD_ID"
echo "packet: $PACKET_FILE"
echo "reply: $REPLY_MD_FILE"
echo "brief: $BRIEF_FILE"
