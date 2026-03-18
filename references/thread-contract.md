# Thread Contract

## Directory layout

Each discussion thread lives under:

```text
.ai/discuss/<thread-id>/
```

Expected files:

- `packet.md`
- `raw-reply.txt`
- `debug.log`
- `reply.json`
- `reply.md`
- `brief.md`
- `state.json`
- `timeline.md`

## `state.json`

Stable fields in v1.2:

```json
{
  "thread_id": "20260313-example-topic",
  "round": 1,
  "goal": "what we are trying to achieve",
  "background_brief": "what I currently understand",
  "current_direction": "what I am planning to do",
  "constraints": "what must not change",
  "selected_assets": ["src/x.ts", "src/y.ts"],
  "latest_local_changes": "git diff --stat summary or fallback text",
  "last_remote_takeaways": "one paragraph synthesis",
  "open_questions": ["question 1", "question 2"],
  "next_action": "recommended next step",
  "initiator": "codex",
  "last_adapter": "codex",
  "updated_at": "2026-03-13T12:00:00Z",
  "latest_packet": ".ai/discuss/<thread-id>/packet.md",
  "latest_reply": ".ai/discuss/<thread-id>/reply.json"
}
```

- `initiator`: which adapter started the thread (round 1). Values: `"codex"`, `"claude"`, `"user"`, `"dry-run"`.
- `last_adapter`: which adapter was used in the most recent round. Used by `select_adapter()` for bidirectional routing.

## `reply.json`

Stable fields in v1.2:

```json
{
  "agreement": ["what the remote agent agrees with"],
  "pushback": ["required challenge or disagreement"],
  "risks": ["key risk"],
  "better_options": ["more promising option"],
  "recommended_next_step": "single next step",
  "questions_back": ["open question"],
  "one_paragraph_synthesis": "compact synthesis paragraph",
  "_normalized_confidence": "high|degraded|failed",
  "_validation_warnings": ["normalization or schema warnings"],
  "_quality_gate": "pass|warn|fail"
}
```

`pushback` is required semantically. If the remote reply is missing it, the normalizer inserts a fallback challenge.
`_normalized_confidence` and `_validation_warnings` are additive metadata fields for downstream debugging and retry decisions.
`_quality_gate` summarizes overall reply quality:
- `pass`: high confidence, >= 2 substantive pushback items, synthesis >= 50 chars
- `warn`: degraded extraction, insufficient pushback, or short synthesis
- `fail`: no valid JSON extraction

## `request.json`

Fields added in v1.2 for prior round context:

```json
{
  "prior_synthesis": "synthesis from the previous round (empty on round 1)",
  "prior_open_questions": ["open questions from previous round"],
  "prior_next_step": "recommended next step from previous round"
}
```

These fields are carried into the packet as `## Prior round context` (only rendered when non-empty).

## Resume policy

The next round should prefer:

- `goal`
- `background_brief`
- `current_direction`
- `constraints`
- `selected_assets`
- `last_remote_takeaways`
- `latest_local_changes`

Do not reuse the full transcript by default.

## Adapter routing

`select_adapter()` uses a three-level strategy:

1. **Explicit**: `--adapter` flag overrides everything
2. **Bidirectional**: on `continue`, if `cross_model=true` in adapters cache, pick the opposite of `last_adapter` (codex↔claude)
3. **Fallback**: `recommended_reviewer` from adapters cache
