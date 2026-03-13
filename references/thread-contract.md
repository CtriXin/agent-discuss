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

Stable fields in v1:

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
  "updated_at": "2026-03-13T12:00:00Z",
  "latest_packet": ".ai/discuss/<thread-id>/packet.md",
  "latest_reply": ".ai/discuss/<thread-id>/reply.json"
}
```

## `reply.json`

Stable fields in v1:

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
  "_validation_warnings": ["normalization or schema warnings"]
}
```

`pushback` is required semantically. If the remote reply is missing it, the normalizer inserts a fallback challenge.
`_normalized_confidence` and `_validation_warnings` are additive metadata fields for downstream debugging and retry decisions.

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
