# agent-discuss — AI quick context

`agent-discuss` is a skill repo for cross-agent discussion, not review.

## Core idea

- Distill local context before dispatching
- Send a small set of selected assets
- Receive structured pushback and alternatives
- Persist a resumable thread state

## Design choices

1. The remote agent does not directly modify project files in v1.
2. Thread state is local and compact. Full transcripts are not reused by default.
3. `reply.json` is the source of truth for the remote reply; `reply.md` and `brief.md` are rendered views.
4. Adapter availability is cached in `.ai/cache/preflight/adapters.json`.
5. Local coordination files are intentionally ignored by git.

## File responsibilities

- `SKILL.md` — skill behavior and trigger guidance
- `scripts/preflight.sh` — local adapter detection and cache writer
- `scripts/invoke_adapter.sh` — adapter dispatch layer
- `scripts/discuss.sh` — thread orchestration
- `references/thread-contract.md` — file layout and reply schema
- `templates/discussion_packet.md` — packet shape reference

## Maintenance notes

- Keep the adapter cache contract stable
- Prefer additive changes to `state.json`
- Keep packet context lean
- Update `CHANGELOG.md` when release behavior changes
