# agent-discuss

> Discuss a task with another agent using distilled context, selected assets, and resumable thread state.

`agent-discuss` is a Claude/Codex skill repo for a different workflow than `a2a`.

- `a2a` ends with a review verdict.
- `agent-discuss` ends with a sharper direction and a reusable thread.

## What It Does

`agent-discuss` lets the orchestrating agent:

1. Distill the current task into a compact packet
2. Attach a few high-value assets
3. Dispatch the packet to another agent
4. Save the remote reply in a structured format
5. Update a thread state so the next round does not need the full history again

This is useful when you want to "talk it through" with another agent, not ask for a formal review.

## Commands

### Start

```bash
scripts/discuss.sh start "state ownership refactor" \
  --understanding "The feature works, but responsibilities are smeared across page and child components." \
  --direction "Centralize the write path and keep read-only sections dumb." \
  --constraints "No new dependencies. Preserve route API." \
  --ask "Push back on this direction and suggest a simpler ownership split." \
  --asset src/pages/editor.tsx \
  --asset src/components/FormPanel.tsx
```

### Continue

```bash
scripts/discuss.sh continue 20260313-state-ownership-refactor \
  --direction "I am considering moving validation to the page level." \
  --asset src/lib/validation.ts
```

### Status

```bash
scripts/discuss.sh status 20260313-state-ownership-refactor
```

### Validate-only extraction

```bash
scripts/discuss.sh validate /path/to/raw-reply.txt \
  --thread-id 20260313-debug-normalizer
```

## Thread Layout

Each discussion thread lives under:

```text
.ai/discuss/<thread-id>/
```

Important files:

- `packet.md` — the exact prompt sent to the other agent
- `raw-reply.txt` — raw adapter output
- `debug.log` — adapter stderr and parser diagnostics
- `reply.json` — normalized reply contract
- `reply.md` — human-readable rendering
- `brief.md` — shortest current-state summary for the next round
- `state.json` — thread state for resume and automation
- `timeline.md` — appended round summaries

## Adapter Contract

`agent-discuss` writes and reads the same project-local adapter cache shape used by sibling tools:

```text
.ai/cache/preflight/adapters.json
```

Supported adapters in v1:

- `codex`
- `claude`

Selection order:

- explicit `--adapter`
- cache recommendation
- fallback: `codex`, then `claude`

## Local Coordination Files

This repo ignores local coordination files on purpose:

- `task_plan.md`
- `findings.md`
- `progress.md`
- `todo.md`
- `.ai/`

They are for cross-agent collaboration in a working tree, not for published releases.

## Release Surface

v1 ships:

- `SKILL.md`
- `README.md`
- `CLAUDE.md`
- `CHANGELOG.md`
- `scripts/preflight.sh`
- `scripts/invoke_adapter.sh`
- `scripts/discuss.sh`
- `references/thread-contract.md`
- `references/preflight-contract.md`
- `templates/discussion_packet.md`

## Validation

```bash
python3 /Users/xin/.codex/skills/.system/skill-creator/scripts/quick_validate.py agent-discuss
scripts/preflight.sh --json
scripts/discuss.sh start "smoke test" --understanding "dry run" --direction "verify packet generation" --ask "give pushback" --dry-run
scripts/discuss.sh validate /path/to/raw-reply.txt --thread-id validate-demo
```
