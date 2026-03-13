#!/usr/bin/env bash
set -euo pipefail

ADAPTER_NAME="${1:-}"
PACKET_FILE="${2:-}"
PROJECT_ROOT="${3:-}"

if [[ -z "$ADAPTER_NAME" || -z "$PACKET_FILE" || -z "$PROJECT_ROOT" ]]; then
  echo "ERROR: Usage: invoke_adapter.sh <adapter_name> <packet_file> <project_root>" >&2
  exit 1
fi

ADAPTERS_CACHE="$PROJECT_ROOT/.ai/cache/preflight/adapters.json"

if [[ ! -f "$ADAPTERS_CACHE" ]]; then
  echo "ERROR: adapters cache not found: $ADAPTERS_CACHE" >&2
  exit 1
fi

IS_AVAILABLE="$(python3 - "$ADAPTERS_CACHE" "$ADAPTER_NAME" <<'PYEOF'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())
adapter = data.get("adapters", {}).get(sys.argv[2], {})
print("true" if adapter.get("available") else "false")
PYEOF
)"

if [[ "$IS_AVAILABLE" != "true" ]]; then
  echo "ERROR: adapter '$ADAPTER_NAME' is not available" >&2
  exit 1
fi

PACKET_CONTENT="$(cat "$PACKET_FILE")"

case "$ADAPTER_NAME" in
  codex)
    codex exec --cd "$PROJECT_ROOT" --skip-git-repo-check --full-auto -- "$PACKET_CONTENT"
    ;;
  claude)
    claude -p --dangerously-skip-permissions "$PACKET_CONTENT"
    ;;
  *)
    echo "ERROR: unsupported adapter '$ADAPTER_NAME'" >&2
    exit 1
    ;;
esac
