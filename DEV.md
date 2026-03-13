# DEV

## Release checklist

1. Update `CHANGELOG.md`
2. Validate the skill:

```bash
python3 /Users/xin/.codex/skills/.system/skill-creator/scripts/quick_validate.py .
```

3. Run smoke checks:

```bash
scripts/preflight.sh --json
scripts/discuss.sh start "smoke test" --understanding "dry run" --direction "verify packet generation" --ask "push back" --dry-run
```

## Versioning

- patch: docs fix, wording, non-breaking script fix
- minor: new command option, thread field, better rendering
- major: packet contract break, state contract break, dispatch model break
