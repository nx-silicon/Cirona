---
chapter: basic
parent: example-cell
summary: |
  Example-cell 拓扑骨架 + sizing 起点 + 仿真验证 quick path。Iron Law:
  写 example-cell 时**必须**先按本章节起手 sizing 表起手，不要凭直觉乱试。
tokens: ~600
prerequisite_chapters: []
related_skills:
  - device_sizing
---

# Example-Cell Basic Reference

> 这是 chapter 示例，演示 V4_KNOWLEDGE_FORMAT 推荐的章节结构：
> Iron Law → 拓扑骨架 → 因果链 → 起点表 → trade-off。
> 详细写作规范 + 反例见 V4_KNOWLEDGE_FORMAT.md。

## Iron Law

- Reference design 优先：写 example-cell 必须先 `read_file` 本章 § Topology 的 inline `.subckt`，复制为起点
- NEVER 凭直觉调 sizing：必先按 § Sizing Starting Points 表 + 跑 dc_op 验证 saturation

## Topology

```
              VDD
               │
            [ M_top ]      ← role / gate-bias source
               │
              vout
               │
            [ M_bot ]      ← role / gate-bias source
               │
              VSS
```

**端口约定**：vdd / vss / vin / vout / ibias / vbias

**device 角色 + 偏置来源**：
- `M_top` — PMOS / load / gate ← `vbp`（mirror from Mbias）
- `M_bot` — NMOS / driver / gate ← `vin`

**关键拓扑陷阱**：
- ❌ M_top 和 M_bot 同时 diode-connected → DC OP 锁死
- ❌ vbias 接错 mirror（W 不一致）→ Itail 不准 ±50%

## Sizing Starting Points (@vpdk180nm, VDD=1.8V, ibias=10µA)

| Device | role | W | L | m | gm/Id | Vov | 关键约束 |
|---|---|---|---|---|---|---|---|
| M_top | PMOS load | 10 µm | 1.0 µm | 1 | ~8 | 0.30 V | L > driver L（gain + 噪声）|
| M_bot | NMOS driver | 10 µm | 0.5 µm | 1 | ~12 | 0.15 V | gm 主导 |
| Mbias | NMOS bias diode | 10 µm | 0.5 µm | 1 | — | — | mirror reference |

⚠️ **数值标 @vpdk180nm**：换工艺时 µ·Cox 不同要重算 W；公式跨工艺通用。

## 因果链（spec → device 约束）

```
GBW target   → gm_M_bot       → W_bot 与 Id_bot 由 √(2·µ·Cox·W/L·Id) 反算
DC gain target → ro_M_top ‖ ro_M_bot → L_top ↑ + L_bot ↑ 提 gain
PM target    → mirror node cap << CL → W_top ↓（trade-off Vov_top ↑）
Output swing → Vov_M_top + Vov_M_bot 占用 → 反算可用范围
```

## When to load this chapter

- 用户首次问 example-cell 设计起点
- DC OP 不满足时回查 sizing 起点

## Related

- `blocks/base-cells/current-mirror` — Mbias mirror 细节
- `skills/device_sizing` — 通用 sizing 流程
