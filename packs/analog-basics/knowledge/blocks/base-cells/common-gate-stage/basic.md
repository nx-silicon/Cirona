---
chapter: basic
parent: common-gate-stage
summary: |
  基础共栅级 —— 拓扑 / Rin / Rout / Av / sizing / body effect /
  与 cascode（CS+CG 级联）和 CS 翻转的本质区分
tokens: ~850
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/cascode
  - blocks/base-cells/common-source
  - blocks/base-cells/active-load
---

# 基础共栅级

## 拓扑结构（事实）

```
            VDD
             │
        ┌────┴────┐
        │  Rload  │  (or active load: PMOS mirror / cascode load)
        │   (or   │
        │  PMOS)  │
        └────┬────┘
             ●─── V_out ─→
        ┌────┴────┐
        │   Mn    │←── Vbias_g (DC bias，AC stiff，typically ≥100pF cap to GND)
        │ NMOS CG │
        └────┬────┘
             ●─── V_in / I_in （信号从 source 进入）
             │
        ┌────┴────┐
        │ I_bias  │ (尾电流源 / sensor / 上游 CS drain)
        └────┬────┘
            VSS
```

**核心机制**：
- 信号从 **source 端**注入（电流或低阻电压源）
- gate 是 DC bias，AC 接地 → **不被信号摆**
- 输出在 drain 端（电流变化 → drain 负载转换为电压或下游电流）
- **没有信号方向上的 Miller**：gate 是 AC ground，Cgd 一端接地，不会被信号放大

## 小信号公式（事实 + 因果）

### 输入阻抗 Rin（一阶）

```
Rin = (1/gm) · (1 + R_load/ro)   ≈ 1/(gm + gmb)    @ typical R_load << ro

含 body effect:
Rin ≈ 1/(gm + gmb) ≈ 1/(gm × (1 + η))     where η = gmb/gm ≈ 0.1-0.3
```

**因果**：
- gm 大 → Rin 小（适合 50Ω 匹配 / 电流输入）
- gmb 项让 Rin 比理论 1/gm 小 ~10-30%（body effect 帮忙）
- R_load 大 + ro 有限 → Rin 实际值会比 1/gm 大（drain → source 通过 ro 反馈）

**典型数值**：gm = 1-10 mS（@ Id 10µA-1mA）→ Rin = 100Ω - 10 kΩ。

### 输出阻抗 Rout

```
Rout = ro × (1 + (gm + gmb) × Rs)        # Rs 是 source 端等效阻抗（含 source 寄生 + 上游 sensor）

简化（Rs = 0）：Rout = ro      （CG 自身的 Rout 与 CS 相同）
Rs ≠ 0 时：Rout 被放大（这是 cascode 的本质）
```

### 电压增益 Av

```
Av = (gm + gmb) × (R_load ‖ Rout)
```
**关键**：CG 自身不决定 Av，**drain 负载决定**。这与 CS 一样（CS 也是 -gm·R_load），但符号不同（CG 是同相，CS 是反相）。

| 负载 | Av |
|---|---|
| Resistive R_L | Av = (gm+gmb) × (R_L‖ro) |
| Active load (PMOS mirror，Rout = ro_p) | Av = (gm+gmb) × (ro_n‖ro_p) ≈ gm·ro/2 |
| Cascode load | Av = (gm+gmb) × gm_casc·ro_casc·ro |

## Sizing 关系（事实 + 因果）

### Sizing 起点：源阻抗目标

```
目标 Rin → 反推 gm → 由 gm/Id 表 + Vov 决定 W/L
```

| 量 | 公式 | 因果 |
|---|---|---|
| gm 目标 | gm = 1 / (Rin_target × (1+η))（含 body effect 修正）| 例 50Ω 匹配 + η=0.2 → gm = 16.7 mS（远大于普通 OTA）|
| Id 目标 | Id = gm / (gm/Id)，typically gm/Id = 8-15 | 50Ω 匹配 → Id ≈ 16.7mS / 12 ≈ 1.4 mA（功耗显著）|
| Vov | Vov = 2 × Id / gm = 2/(gm/Id) | gm/Id = 12 → Vov ≈ 167 mV |
| W | 由 gm/Id 表 lookup（不要套长沟道公式）| Id/W 查表（@ 工艺 + Vov）→ W = Id / (Id/W) |
| L | 4-8 × Lmin（matching + ro 改善 → 提升 Rin 准确性）| L 越大 ro 越大 → Rin 公式中 R_load/ro 项越小，Rin 越接近理论 |

### 增益 vs 带宽 trade-off（drain 负载选择）

| 负载选择 | Av | BW | 适用 |
|---|---|---|---|
| 小 R_L（如 1kΩ）| 小（gm·R 几倍）| 高（小 R·Cload）| 宽带 LNA |
| 大 R_L（如 10kΩ）| 中（gm·R 几十倍）| 低 | 中速 LNA / 简单放大 |
| Active mirror load | 大（gm·ro/2 ~ 数百倍）| 低（高 Rout × Cload 极点低）| TIA / 高增益 |
| Cascode load | 极大（gm²·ro²，千倍级）| 极低 | 高精度跨阻 |

## body Effect（NMOS CG 关键）

NMOS CG 的 source 接信号节点 → V_SB > 0（不接 VSS）→ V_th 升高（body effect）。

**影响**：
- gmb / gm 比例 η = gmb/gm 典型 0.1-0.3（n-well 工艺中 PMOS 可关 V_BS = 0 消除）
- **帮助 Rin 减小**（Rin = 1/(gm+gmb)，gmb 是助力）
- **修复**：用 PMOS CG（n-well 隔离 body）/ 用 deep-N-well NMOS（独立 body 接 source）/ 接受 η 影响

## Gate AC Stiffness（关键约束）

gate 必须是"硬"AC 接地。若 gate 节点 AC 阻抗高 → 随信号摆动 → Cgd × ΔVgate 反馈到信号通路 → Miller 效应回归。

**保证方法**：
- gate 旁路电容 ≥ 100 pF 到 GND（@ MHz 频段足以 stiff）
- 若 bias 用 PMOS 电流源生成 → 该电流源输出电阻必须低（典型 < 1 kΩ @ 信号频段）
- RF 频段（GHz）需要 layout 邻近 + 短路径 + 多 via

## 与 cascode（CS+CG 级联）的本质区分

> ⚠️ **必须分清**：本 cell 讲的是 **CG 作为独立输入级**，不是 cascode。

| 维度 | 独立 CG（本 cell）| cascode（CS+CG 级联，见 `blocks/base-cells/cascode`）|
|---|---|---|
| 信号路径 | source 输入 → drain 输出 | gate(底部 CS)输入 → drain(顶部 CG)输出 |
| 主功能 | 低 Rin / 弱 Miller / 宽带前端 | 增益增强（gm·ro²）|
| 底部管 | 信号源 / 电流源 / sensor | CS（提供 gm + 信号增益）|
| 应用 | TIA / LNA / 传感器接口 | OTA 输出级 / 高增益 mirror |

**不要混用**："cascode 是 CG 的应用之一"是对的，但**写 OTA 增益增强时用 cascode 章节**，**写宽带前端时用本 CG 章节**。

## 验证清单

- [ ] dc_snapshot：CG 管在 saturation（Vds > Vov）
- [ ] dc_snapshot：gate bias 节点 DC OK + AC（用 .ac 测 gate 节点对小信号摆幅）
- [ ] AC 仿真：测 Rin 看是否 ≈ 1/(gm+gmb)（实测 vs 理论 误差 < 30%）
- [ ] AC 仿真：测 Av = V_out/V_in（应 = gm × R_load_eff）
- [ ] AC 仿真：测 BW = drain 极点 ≈ 1/(2π·R_load·C_drain)（不是 source 节点）
- [ ] PVT corner：Rin / Av 漂移 < spec

## 常见误区（self-check）

| 心里想 | 现实 |
|---|---|
| "CG 就是 CS 翻一下" | 物理机制完全不一样：CS 是 gate 输入有 Miller / CG 是 source 输入弱 Miller |
| "CG 没 Miller 所以宽带" | 仅当 gate 真 AC stiff 才成立；gate 软偏置时 Miller 还是有 |
| "Rin = 1/gm" | 一阶近似；含 body effect 是 1/(gm+gmb)，含 ro 时还要加修正项 |
| "增大 gm 一定降 Rin" | 是，但 gm 大 → Cgs / Cgd 大 → drain 极点位置可能变（trade-off） |
| "CG 增益由自身决定" | 错，**完全由 drain 负载决定**（gm × R_load） |
| "用 CG 做高源阻抗输入" | 不合适——高源阻抗 + 低 Rin → 信号被 source 端阻抗严重衰减 |

## 不在本章范围

- TIA 跨阻设计（Rf 反馈环 / 整体噪声）→ chapter `tia-application`
- 宽带 LNA 匹配 / NF / IIP3 → chapter `lna-application`
- regulated common-gate（内嵌 OTA）→ chapter `regulated-common-gate`
- 故障 debug → chapter `troubleshooting`
- cascode 增益增强（CS+CG 级联）→ `blocks/base-cells/cascode`
- gm/Id 方法学 → skill `circuit-method/device-sizing`
