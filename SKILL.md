---
name: agent-discuss
version: "1.2.0"
description: "a2a 的兄弟技能 — 跨模型协作式讨论。不是 review 打分，而是 distill context → 派发讨论 → 收集结构化 pushback → 保持可续接 thread。用于头脑风暴、方案压力测试、方向确认、跨 agent 接力。触发词：'discuss this with codex'、'聊一聊'、'帮我和 codex 讨论'、'继续上次讨论'、'carry context to another agent'。"
argument-hint: '讨论主题或已有 thread-id（如 "20260317-mobile-mvp"）'
allowed-tools: Read, Write, Bash, Grep, Glob, Agent, AskUserQuestion
---

# Agent Discuss — 跨模型协作讨论

> 不是 review verdict，是 working discussion。让两个模型互相磨方向，而不是互相打分。

## 与 a2a 的区别

| | a2a | agent-discuss |
|---|-----|---------------|
| 目的 | 代码审查打分 | 方向讨论磨合 |
| 输出 | verdict + severity | pushback + synthesis + next step |
| 交互 | 一次性 | 可续接 thread（多轮） |
| 适合场景 | PR review | 架构决策、方案验证、头脑风暴 |

## 核心流程

```
用户描述任务/方向
  → Claude 蒸馏 context（goal + understanding + direction + constraints）
  → 选取少量关键文件
  → 打包 packet 发送给 Codex/Claude
  → 收到结构化 reply（agreement/pushback/risks/better_options/synthesis）
  → 展示给用户，保存 thread state
  → 下次 continue 时只带 delta + prior round context（synthesis + open questions + next step）
  → adapter 自动切换（codex→claude→codex，双向路由）
```

## 使用方式

### 方式一：自然语言触发（推荐）

直接对 Claude 说：
- "帮我和 codex 讨论一下这个方案"
- "discuss the mobile MVP architecture with another agent"
- "继续上次讨论 20260317-mobile-mvp"

Claude 会自动：
1. 蒸馏当前 context 为 compact packet
2. 选取相关 asset 文件
3. 调用 `scripts/discuss.sh` 执行
4. 解读 reply 并呈现结果

### 方式二：命令行直接调用

#### Start — 发起新讨论

```bash
scripts/discuss.sh start "mobile MVP architecture" \
  --understanding "We have multi-model chat/discuss/advisors on web-v2, Capacitor iOS ready" \
  --direction "Add Daily Challenge + Cognitive Evolution Tracker as mobile-first features" \
  --constraints "No backend dependency. Pure frontend with IndexedDB." \
  --ask "Pressure-test this direction. Is Daily Challenge the right hook for mobile?" \
  --asset docs/MOBILE_MVP_TODO.md \
  --asset docs/MOBILE_ADVANCED_DIRECTIONS.md
```

#### Continue — 续接已有 thread

```bash
scripts/discuss.sh continue 20260317-mobile-mvp-architecture \
  --direction "Revised: start with Content Digester instead of Daily Challenge" \
  --asset src/stores/discuss.ts
```

#### Status — 查看 thread 状态

```bash
scripts/discuss.sh status 20260317-mobile-mvp-architecture
```

#### Validate — 重跑 normalizer（不调 adapter）

```bash
scripts/discuss.sh validate /path/to/raw-reply.txt \
  --thread-id 20260317-debug
```

## Claude 执行规范

当用户触发讨论时，Claude 应该：

1. **蒸馏而非转发**：把当前对话 context 压缩为 5 个字段：
   - `goal`：一句话目标
   - `understanding`：当前认知（事实，不是猜测）
   - `direction`：当前倾向的方向
   - `constraints`：不能动的约束
   - `ask`：需要对方做什么（默认：pushback + risks + better options）

2. **精选 asset**：只附带直接相关的 2-5 个文件。不要转发整个目录。

3. **展示结果时分层**：
   - 先说 **synthesis**（一段话总结）
   - 再列 **pushback**（对方的挑战）
   - 再列 **risks** 和 **better_options**
   - 最后给出 **recommended_next_step**
   - 如果有 **questions_back**，提示用户是否要回答并 continue

4. **续接时只带 delta**：不要重复已有 context，只更新 direction/assets/ask。

## Thread 文件结构

每个讨论 thread 存在 `.ai/discuss/<thread-id>/`：

| 文件 | 用途 |
|------|------|
| `packet.md` | 发送给对方的完整 prompt |
| `raw-reply.txt` | 原始返回 |
| `debug.log` | adapter stderr |
| `reply.json` | 结构化 reply（source of truth） |
| `reply.md` | 人类可读版 |
| `brief.md` | 当前状态摘要（下轮输入） |
| `state.json` | thread 持久状态 |
| `timeline.md` | 多轮时间线 |

## Adapter 选择

- 优先 Codex（`codex exec`），因为 Claude 自己发起讨论时用对立模型效果更好
- Codex 不可用时 fallback 到 Claude（`claude -p`）
- 可通过 `--adapter codex|claude` 显式指定
- **双向路由**：`continue` 时如果 `cross_model=true`，自动选上轮 adapter 的 opposite（codex↔claude），实现真正的交叉讨论

## Reply 契约

对方必须返回 JSON：

```json
{
  "agreement": ["同意的点"],
  "pushback": ["挑战/质疑（必填）"],
  "risks": ["风险"],
  "better_options": ["更好的方案"],
  "recommended_next_step": "建议下一步",
  "questions_back": ["反问"],
  "one_paragraph_synthesis": "一段话综合"
}
```

Normalizer 会容错处理：缺少 pushback 会自动插入 fallback challenge。

## Packet 纪律

- 保持 packet **intent-heavy, history-light**
- 只附带直接相关的 asset
- 偏向当前方向而非抽象讨论
- 保留 pushback — 这是协作讨论，但对方必须挑战弱假设
- v1 中对方不直接修改项目文件
