# Agent Discuss Packet

## What this is

A compact discussion packet from one agent to another. The goal is to sharpen direction, not to produce a review verdict.

## Goal

What we are trying to achieve right now.

## My current understanding

What I believe is true about the task, background, and current state.

## My current direction

What I am leaning toward doing next.

## Constraints

What must not change, what is out of scope, and what tradeoffs already seem fixed.

## Selected assets

Only the most relevant files, excerpts, or notes.

## What I need from you

Push back, identify risks, offer better options, and recommend the best next step.

## Response contract

Return a JSON object only:

```json
{
  "agreement": ["..."],
  "pushback": ["..."],
  "risks": ["..."],
  "better_options": ["..."],
  "recommended_next_step": "...",
  "questions_back": ["..."],
  "one_paragraph_synthesis": "..."
}
```
