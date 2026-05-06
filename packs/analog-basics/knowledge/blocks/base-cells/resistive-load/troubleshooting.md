---
chapter: troubleshooting
parent: resistive-load
summary: |
  电阻负载五大故障：Av 不达标 / Vout swing 撞 rail / 噪声超预算 /
  BW 受限 / TCR PVT 漂移
tokens: ~500
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/signal-tracing
  - meta-cognitive/systematic-debugging
related_knowledge:
  - blocks/base-cells/active-load
---

# 电阻负载故障诊断

> ⚠️ **使用规则**：本章是事实对照表。**思维过程**用 skill `circuit-method/signal-tracing`
> 沿信号路径反推（"Av 是谁决定的？swing 是谁压缩的？"）。

---

## 症状 1：Av 不达标（实测 < 设计 50%）

**表现**：spec Av = 10，实测 Av = 5。

**物理因果**：Av = -gm × (R ‖ ro)，三种可能：
- gm 不对（M_drv sizing / region 错）
- R 不对（实际 R 与 netlist 不符 — PVT 漂或 layout R 寄生）
- R 接近 ro_drv，简化公式不再成立

**诊断**：

| 检查项 | 动作 | 判断 |
|---|---|---|
| gm 实测 | dc_snapshot + AC 测 V_out/V_in vs Id | gm = 2·Id/Vov；与设计目标 ±10% |
| M_drv region | dc_snapshot Vds vs Vov | 必须 Vds > Vov（saturation）|
| R 实际值 | DC sweep 测 R = ΔV/ΔI | poly TCR + sheet R spread → ±10% 漂正常 |
| R vs ro 比例 | R/ro_drv | > 0.3 → 必须用 Av = -gm·(R‖ro) 重算 |

**修复方向**：

| 根因 | 修复 |
|---|---|
| gm 不够 | 增 W_drv 或 增 Id |
| R 实际偏小（PVT）| poly + 蛇形布局精度通常 ±5%；超 ±10% 检查 layout 寄生分流 |
| R/ro 太接近 | 增 L_drv 提 ro / 减 R 让简化公式恢复 / 接受降低 Av |

---

## 症状 2：Vout 静态点不在中央（撞 rail）

**表现**：V_out_Q < 200 mV 或 > VDD - 200 mV。

**物理因果**：V_out_Q = VDD - I_DC·R。
- 若 V_out_Q 太低 → I·R 太大（I 大 / R 大）
- 若 V_out_Q 太高 → I·R 太小（I 小 / R 小）

**诊断**：dc_snapshot 看 V_out_Q + I_DC + R，验证 V_out_Q = VDD - I·R。

**修复方向**（取决于 spec 优先级）：

| 根因 | 修复 |
|---|---|
| V_out_Q 太低 | 减 I_DC（牺牲 gm + Av）或 减 R（牺牲 Av）|
| V_out_Q 太高 | 增 I_DC 或 增 R（同时增 Av） |
| 需保 Av 又保 swing | 切换 active load（gm·ro 不依赖 V_drop） |

---

## 症状 3：输出噪声超预算

**表现**：noise 谱密度在 R 主导频段超 spec。

**物理因果**：v_n_R = √(4kT·R)。
- R = 10 kΩ → 13 nV/√Hz
- R = 50 kΩ → 28 nV/√Hz
- 输入参考 = v_n / |Av| = v_n / (gm·R)

**修复方向**：

| 根因 | 修复 | 代价 |
|---|---|---|
| R 太大 noise 主导 | 减 R + 增 gm 保 Av | I_DC 增 / 功耗增 |
| 输入参考还是大 | 切换 active load —— 比较时**必须先折算到同一参考点**（4kT·γ·gm vs 4kT·R 不能直接比；active load 通常降低等效输入噪声但牺牲线性度/摆幅）| 失去线性度优势 |
| 需要极低噪声 | 增 W_drv 让 gm 大 + 减 R → v_n_in_referred 减小 | 面积大 + Cgs 增 → BW 损 |

**关键洞察**：v_n_in = √(4kT·R) / (gm·R) = √(4kT/(gm²·R))。**R 越大，输入参考噪声越小**（gm 不变时）；但 R 大 → V_drop 大 → swing 紧。trade-off。

---

## 症状 4：BW 受限

**表现**：spec BW = 100 MHz，实测 = 30 MHz。

**物理因果**：fp = 1/(2π·R·C_par)。

**诊断**：
- AC 测 -3 dB 频率
- 看 C_par 实际值（含 Miller × Cgd）

**修复方向**：

| 根因 | 修复 |
|---|---|
| C_par 大 | 减下级 Cgs / layout 减 metal par / cascode 减 Miller × Cgd |
| R 太大 | 减 R（牺牲 Av） |
| 需保 BW 保 Av | shunt-peaking inductor（chapter `broadband-load`）|

---

## 症状 5：TCR PVT 漂导致 Av / V_out 漂

**表现**：PVT corner 下 Av 漂 ±15% / V_out_Q 漂 ±50 mV。

**物理因果**：
- poly TCR ±500 ppm/°C × ΔT 100°C → ±5% R 漂
- 工艺 sheet R spread ±15-20% → ±15% R 漂
- 总和 ±20% → Av 漂同步

**修复方向**：

| 根因 | 修复 |
|---|---|
| poly resistor 漂大 | 用 silicide poly（TCR ±100 ppm/°C）或 P+ poly resistor |
| sheet R spread | trim / replica 校正（用复杂电路抵消）|
| 严格 spec | 切到 active load（mirror load 用 bias chain 跟踪 PVT 更稳）|

**❌ 不要**：
- 单凭 hardcoded R 值设计 → 必须按 PDK ±工艺 corner 验证
- 用 well resistor 做精度 spec → ±5000 ppm/°C 不够

---

## 关联 skill（诊断思维过程）

电阻负载故障诊断框架：
- **沿信号路径反推**：用 skill `circuit-method/signal-tracing`（"Av = gm·R 哪个不对？swing = VDD - I·R 哪个变了？"）
- **根因优先**：用 skill `meta-cognitive/systematic-debugging`（不要先调 W/L，先确认 gm vs R vs ro 哪个是瓶颈）

电阻负载特定症状的"是谁决定"指引：
- Av 不对 → gm（M_drv sizing）vs R（layout / PVT）vs R/ro 简化破坏
- swing 不对 → V_drop = I·R 是双 knob
- noise 不对 → 4kT·R 选 R 还是 v_n_in 优化
- BW 不对 → R·C_par 主极点
- PVT 漂 → TCR + sheet R spread

## 不在本章范围

- 基础公式 / 五变体选择 → chapter `basic`
- TIA Rf 应用 → chapter `tia-feedback-resistor`
- RF / shunt-peaking → chapter `broadband-load`
- active load 切换决策 → `blocks/base-cells/active-load/`
- layout matching / EM → layout knowledge（V4 不在范围）
