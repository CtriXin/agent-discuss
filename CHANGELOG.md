# Changelog

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
