# agent-discuss — AI quick context

`agent-discuss` is a skill for cross-agent **discussion**, not review.

## 与 a2a 的关系

- `a2a`：对抗式 code review，输出 verdict
- `agent-discuss`：协作式方向讨论，输出 synthesis + pushback + next step

两者共享 preflight adapter 检测机制，但目的和输出契约不同。

## 核心设计

1. 蒸馏而非转发：发送 compact packet，不转发完整上下文
2. 结构化 pushback：对方必须挑战弱假设
3. 可续接 thread：每轮只带 delta，不重复历史
4. reply.json 是 source of truth；reply.md 和 brief.md 是渲染视图
5. Adapter 可用性缓存在 `.ai/cache/preflight/adapters.json`
6. v1 中对方不直接修改项目文件
7. 续接时 packet 携带上轮 synthesis + open questions + next step（`## Prior round context`）
8. 双向路由：continue 时自动选择上轮 adapter 的 opposite（codex↔claude），前提是 `cross_model=true`

## 文件职责

| 文件 | 用途 |
|------|------|
| `SKILL.md` | 技能行为定义 + 触发指引 |
| `scripts/discuss.sh` | thread 编排主脚本 |
| `scripts/invoke_adapter.sh` | adapter 调度层 |
| `scripts/preflight.sh` | 本地 adapter 检测 + 缓存 |
| `references/thread-contract.md` | 文件布局 + reply schema |
| `templates/discussion_packet.md` | packet 模板参考 |

## 执行规则

- 优先蒸馏 context，减少 packet 体积
- asset 只选直接相关文件（2-5 个）
- 展示结果时先 synthesis → pushback → risks → next step
- 续接 thread 时只更新 delta（direction/assets/ask）
- 不要重写不相关的文件
