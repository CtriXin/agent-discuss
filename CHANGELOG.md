# Changelog

## [1.2.0] - 2026-03-18

### Added

- **Prior round context in packet**: `continue` rounds now carry `## Prior round context` section with previous synthesis, open questions, and recommended next step — remote agent sees what was discussed before
- **Bidirectional adapter routing**: `state.json` records `initiator` and `last_adapter`; `select_adapter()` uses 3-level strategy (explicit → opposite adapter → recommended_reviewer) for true cross-model ping-pong
- **Quality gate**: `reply.json` now includes `_quality_gate` field (`pass`/`warn`/`fail`) based on pushback quality (≥2 items, ≥20 chars each) and synthesis length; `brief.md` highlights warn/fail states
- `request.json` now includes `prior_synthesis`, `prior_open_questions`, `prior_next_step` fields

### Changed

- `invoke_adapter.sh`: claude adapter now passes packet via stdin (`echo | claude -p`) instead of argv; codex keeps argv with ARG_MAX size warning
- `load_state()` now extracts `PREV_OPEN_QUESTIONS` and `PREV_LAST_ADAPTER` from state
- `render_brief()` shows quality gate warnings when warn/fail
- `render_reply_md()` includes quality_gate in normalization section

## [1.1.0] - 2026-03-17

### Changed

- Rewrote SKILL.md: added frontmatter (version, argument-hint, allowed-tools), bilingual description, structured workflow guide for Claude
- Rewrote CLAUDE.md: clearer file responsibilities, execution rules, relationship to a2a
- Added comments to invoke_adapter.sh for clarity
- Installed as global skill via symlink to `~/.claude/skills/agent-discuss`

### Added

- Natural language trigger examples (中文 + English)
- Claude execution norms: distill → select assets → dispatch → present results layered
- Comparison table with a2a skill

## [1.0.1] - 2026-03-13

### Changed

- Tightened reply extraction: primary JSON selection now requires 5 of 7 contract keys, with degraded fallback metadata for weaker matches
- Removed shallow regex-based JSON extraction in favor of scoring decoder-discovered candidates
- Added normalization metadata to `reply.json` and `reply.md`
- Split adapter stderr into thread-local `debug.log` instead of mixing it into `raw-reply.txt`
- Added `validate` command for re-running normalization on an existing raw reply without invoking an adapter

## [1.0.0] - 2026-03-13

### Added

- Initial `agent-discuss` release
- `start`, `continue`, and `status` discussion flow in `scripts/discuss.sh`
- Project-local adapter preflight cache in `.ai/cache/preflight/adapters.json`
- Adapter invocation layer for `codex` and `claude`
- Thread persistence under `.ai/discuss/<thread-id>/`
- Structured remote reply normalization to `reply.json`
- Human-readable `reply.md`, `brief.md`, and `timeline.md` rendering
- Stable thread and packet reference docs
- Ignored local coordination files for multi-agent collaboration
