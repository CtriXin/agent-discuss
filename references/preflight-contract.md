# Preflight Contract

`agent-discuss` writes adapter availability to:

```text
.ai/cache/preflight/adapters.json
```

This contract intentionally mirrors sibling agent-orchestration tools so other consumers can reuse the same cache.

## Current shape

```json
{
  "checked_at": "2026-03-13T02:00:00Z",
  "checked_at_epoch": 1773367200,
  "jq": true,
  "can_review": true,
  "cross_model": true,
  "exit_code": 0,
  "adapters": {
    "codex": {
      "available": true,
      "installed": true,
      "version": "0.114.0",
      "authenticated": true,
      "invoke": "codex exec --full-auto --"
    },
    "claude": {
      "available": true,
      "installed": true,
      "version": "2.1.74",
      "authenticated": true,
      "invoke": "claude -p --dangerously-skip-permissions"
    }
  },
  "recommended_reviewer": "codex"
}
```

## Stability rules

- Keep `.ai/cache/preflight/adapters.json` stable
- Keep `adapters.<name>.available` stable
- Keep `adapters.<name>.invoke` stable
- Prefer additive fields over renames
