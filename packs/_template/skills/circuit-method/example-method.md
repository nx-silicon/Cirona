---
name: example-method
description: |
  示例方法论 Skill — 跨电路通用的"思维范式"。**don't summarize what to do**;
  description 只描述"何时召唤这个 skill"，让 agent 必须读完整文才能执行。
trigger:
  keywords:
    - example method
    - 示例方法
    - 何时使用本方法的关键词
related_knowledge:
  - blocks/example-cell
applicable_circuits: []
authors: ["Your Name"]
---

# Example Method Skill

> 这是 V4 Skill 模板。改写时遵循 V4_SKILL_FORMAT §2:
> Iron Law（NO X WITHOUT Y 绝对化）+ Mental Model（思维骨架）+
> Red Flags（心理陷阱）+ Why this works（因果解释）。
> 详细规范见 V4_SKILL_FORMAT.md。

## Iron Law

- NO claim of X WITHOUT verification by Y
  （把"X"换成你方法论关心的命题：sizing 调整 / 拓扑选型 / 仿真结论；
   把"Y"换成不可妥协的验证手段：dc_op 跑通 / inspect_device / 跨工艺一致性）

## Mental Model

State expectation → Observe → Hypothesize → Verify → Iterate

1. **State expectation**：在动手之前**用一句话写出"我期望什么数值变化、用什么验证"**
2. **Observe**：拿到事实（仿真数字 / 节点电压 / op_point）
3. **Hypothesize**：构造一条因果链（A 变化 → B 变化 → C 变化）
4. **Verify**：跑 verifying tool 看 hypothesize 对不对
5. **Iterate**：错了就回 Step 1（不是回 Step 2 跳 verify）

## Red Flags（识别心理陷阱）

| 你心里想 | 现实是 |
| "这电路标准不需要建模" | 标准拓扑也需要 expectation + verification |
| "和上次类似就行" | 工艺 / 偏置 / 负载差一点就 spec miss |
| "再调一次应该过" | 3 次同方向失败 = 拓扑或方法问题 |
| "MC 仿过 1 次就完事" | corner / 温度 / 老化下会更差 |

## Why this works

写下"为什么这套思维是对的"（agent 内化的因果解释）：
- 为什么 expectation-first：因为没有 expectation 时无法判断观测结果"够不够好"
- 为什么 verify before claim：因为 LLM 在 sizing 推理上有 ~20% 错误率（Phase 0 实测）
- 为什么 3 次失败要换思路：避免局部最优陷阱

## When to load this skill

- 用户做电路 sizing 调试
- 用户在 verify spec 是否达标
- agent 在做拓扑选型决策

## When NOT to load

- 用户在写文档 / chat / 知识管理（与电路推理无关）

## Related

- `blocks/example-cell` — 本方法在 example-cell 上的应用样例
