---
chapter: ahuja-style
parent: miller-compensation
summary: |
  Ahuja-style cascode Miller —— 用 cascode device 阻断前馈 / 完全消除 RHP zero /
  GBW 提升 30-50% / 复杂度 + Vov 头压代价
tokens: ~600
prerequisite_chapters:
  - plain-miller
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/cascode
---

# Ahuja-Style Cascode Miller

## 拓扑

```
        V_int (第一级输出)
          │
          ●────────● V_cascode_internal
                   │
              ┌────┴────┐
       Vbias→│ M_cascode│ ← cascode device（阻断前馈）
              │         │
              └────┬────┘
                   ●─── 接到 Cc 一端
                   │
                   Cc
                   │
                   ●─── Vout (第二级输出)
```

**核心机制**：在 Cc 与 V_int 之间插入一个 cascode device → cascode source 跟随 Cc 一端的 V_int，cascode drain 接到 V_cascode_internal。

**关键效果**：信号从 V_int → V_cascode_internal 是反相+增益（cascode bottom）；从 Cc → Vout 是 normal Miller 反向反馈。

→ 前馈路径（导致 RHP zero 的源头）被 cascode 阻断 → **完全消除 RHP zero**。

## 与 plain / nulling Rz 对比

| 维度 | plain Miller | + nulling Rz | Ahuja-style |
|---|---|---|---|
| RHP zero | 存在 | 推到 LHP | **完全消除** |
| GBW | baseline | 略损（5-10%）| **提升 30-50%** |
| 复杂度 | 低 | 低 | 中（多 cascode device + bias）|
| Vov 头压代价 | 0 | 0 | 1×Vdsat（cascode device）|
| 速度优势 | — | — | 高频性能更好（cascode 高 ro 让主极点更纯）|
| 典型应用 | 简单 / 原型 | **二级 opamp 标配** | 高速 + 大 Cload + 严格 PM |

## sizing 关系

cascode device sizing：
| 量 | 推荐 |
|---|---|
| W_cascode | 与第二级 M_o 同型 + 同尺寸 / 或 1/2 - 1/4 |
| Vov_cascode | 0.15 - 0.25 V（占 1×Vdsat headroom）|
| L | 与第二级同 L |
| bias V_cascode_gate | 由 padding device 生成（见 `bias-generator/level-shifter-bias.md`）|

Cc 选值与 plain Miller 同：Cc = gm_1 / (2π · GBW)。

## GBW 提升原理

plain Miller 的 fp2' = gm_2 / (2π·CL)；Ahuja 通过 current buffer / cascode 隔离前馈路径 → 改变非主极点与 zero 在 s 平面的位置（消除 RHP zero + 调整 fp2）。fp2 是否上移取决于 cascode 节点等效电阻 / 电容；不能简单写"ro 提升 → fp2 高"。

加上 RHP zero 消除 → PM 在更高频段保持 → 可用更高 GBW（gm_1 大 / Cc 小）→ 速度提升 30-50%。

## 头压代价

cascode device 占 1× Vdsat（典型 0.15-0.25 V），这意味着输出摆幅 V_out_pp 被压缩 1×Vdsat。

@ VDD = 1.8 V：原 swing ≈ 1.5 V → Ahuja 后 ≈ 1.3 V（损 13%）。

→ 低压工艺（VDD < 1V）下 Ahuja 头压紧张，慎用。

## 验证清单

- [ ] AC：实测 RHP zero 不存在（vs plain Miller）
- [ ] AC：GBW 比 plain Miller 提升（同 Cc 下）
- [ ] AC：PM ≥ 60° + 高频性能优
- [ ] dc_snapshot：cascode device saturation（V_cascode_internal 在合理 V 范围）
- [ ] PVT corner：cascode bias 跟随 + GBW 漂 < 30%

## 常见误区

| 心里想 | 现实 |
|---|---|
| "Ahuja 是 nulling Rz 的简化" | 错——两个完全不同的方法；Ahuja 通过 cascode 阻断前馈，不需 Rz |
| "Ahuja 与 cascode load 一样" | 不一样——cascode load 在第二级输出，Ahuja cascode 在 Cc 路径上 |
| "Ahuja 总比 nulling Rz 好" | 不是——nulling Rz 在标准 1.8V 工艺简单 + 头压零；Ahuja 适合速度优先 |
| "Ahuja 不需要 bias" | 需要 bias V_cascode_gate（来自 bias chain）|

## 不在本章范围

- plain Miller / nulling Rz → 对应 chapter
- nested Miller（三级） → chapter `nested-miller`
- 寄生 Miller → chapter `parasitic-miller`
- 故障 debug → chapter `troubleshooting`
- cascode 物理详细 → `blocks/base-cells/cascode/`
- 完整二级 opamp 含 Ahuja 设计 → `blocks/two-stage-ota/`
