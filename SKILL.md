---
name: agent-discuss
description: Discuss a task with another agent using distilled context, selected assets, and a resumable thread state. Use when Codex needs to bring another agent into the loop for brainstorming, design pressure-testing, implementation direction, or follow-up discussion without resending the full chat history or full plan every time. Triggers include "discuss this with another agent", "聊一聊", "继续上次讨论", "carry context to another agent", and tasks that need thread-based cross-agent coordination rather than review verdicts.
---

# Agent Discuss

Use this skill to turn a messy local task into a compact discussion packet, send it to another agent, and keep a resumable thread under `.ai/discuss/<thread-id>/`.

## Workflow

1. Decide whether this is `start`, `continue`, `validate`, or `status`.
2. Distill the request before dispatching. Always prepare:
   - `goal`
   - `current understanding`
   - `current direction`
   - `constraints`
   - `what I need from the other agent`
3. Select only high-value assets. Prefer a few files that explain the problem or direction. Do not forward the full repo by default.
4. Run `scripts/discuss.sh` from the target project root or pass `--project-root`.
5. Read the generated `brief.md`, `reply.md`, and `state.json`.
6. Present a concise synthesis to the user and keep future rounds anchored on the thread state instead of full history.

## Command Shapes

### Start a new thread

```bash
scripts/discuss.sh start "landing page architecture" \
  --understanding "We already have a working page, but the section composition is getting brittle." \
  --direction "Keep the current visual language, but split by content block and add a typed data contract." \
  --constraints "Do not add dependencies. Keep current route structure." \
  --ask "Pressure-test this direction and suggest a simpler component boundary." \
  --asset src/pages/home.tsx \
  --asset src/components/Hero.tsx
```

### Continue an existing thread

```bash
scripts/discuss.sh continue 20260313-landing-page-architecture \
  --direction "I now want to move state ownership one level up." \
  --asset src/components/sections/Pricing.tsx
```

### Show current state

```bash
scripts/discuss.sh status 20260313-landing-page-architecture
```

### Re-run normalization on an existing raw reply

```bash
scripts/discuss.sh validate /path/to/raw-reply.txt \
  --thread-id 20260313-normalizer-debug
```

## Packet Discipline

- Keep packets intent-heavy and history-light.
- Include a small number of assets with direct relevance.
- Prefer current direction over abstract brainstorming.
- Preserve pushback. This skill is collaborative, but the other agent must still challenge weak assumptions.
- Do not ask the remote agent to modify project files directly in v1.

## Thread Files

Read [references/thread-contract.md](references/thread-contract.md) when you need the exact file layout or response contract.

Key files per thread:

- `.ai/discuss/<thread-id>/packet.md`
- `.ai/discuss/<thread-id>/debug.log`
- `.ai/discuss/<thread-id>/reply.json`
- `.ai/discuss/<thread-id>/reply.md`
- `.ai/discuss/<thread-id>/brief.md`
- `.ai/discuss/<thread-id>/state.json`
- `.ai/discuss/<thread-id>/timeline.md`

## Workspace Coordination

This repo intentionally ignores local coordination files so multiple agents can collaborate without polluting release commits:

- `task_plan.md`
- `findings.md`
- `progress.md`
- `todo.md`
- `.ai/`

Use those files for local execution tracking and handoff notes. Do not rely on them as published documentation.
