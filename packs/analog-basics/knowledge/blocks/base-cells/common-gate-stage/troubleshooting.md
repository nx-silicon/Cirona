---
chapter: troubleshooting
parent: common-gate-stage
summary: |
  CG 五大故障：Rin 实测偏大 / 增益不足 / BW 受限 / gate bias 软（Miller 复活）/
  drain 极点过低 / RCG 不稳定
tokens: ~600
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/signal-tracing
  - circuit-method/ac-feedback-loop-method
  - meta-cognitive/systematic-debugging
related_knowledge:
  - blocks/base-cells/cascode
---

# CG 故障诊断

> ⚠️ **使用规则**：本章是事实对照表。**思维过程**用 skill `circuit-method/signal-tracing`
> 沿信号路径反推（"Rin 是谁决定的？Av 是谁决定的？BW 是谁限制的？"）。

---

## 症状 1：Rin 实测显著偏大（> 2 × 1/gm）

**表现**：AC 测 Rin = 100 Ω，理论 1/gm = 50 Ω。

**物理因果**：
- ro 有限 → Rin = (1/gm) × (1 + R_load/ro)，R_load 大时 Rin 升高
- 上游 source 寄生（layout 走线 / ESD）串入信号路径
- gate AC 不够 stiff → gate 也随信号摆动 → 等效 Rin 升

**诊断顺序**：

| 检查项 | 动作 | 判断 |
|---|---|---|
| ro 影响 | 看 R_load / ro 比例 | R_load > ro/3 → Rin 修正显著；解决：减 R_load 或增 L 提 ro |
| source 寄生 | layout review + 仿真 加 source R | 数十 Ω layout R + ESD R → 显著 |
| gate AC stiffness | AC 仿真看 gate 节点 V 摆幅 | 若 gate 也有摆动（> 5% Vin）→ Cgate 太小或 bias R 太大 |
| body effect | 是否 PMOS 把 body 接 source？或 deep-N-well NMOS？ | 没用 body 隔离时 Rin 反而比理论小（gmb 助力）|

**修复**（按因果反向）：
- ro 限制：增 L → ro ↑ → Rin 公式中 R/ro 项 ↓
- source 寄生：layout 优化 / 增 metal width
- gate AC：增 gate 旁路电容到 ≥ 100 pF；或减 gate bias R

---

## 症状 2：电压增益不足（< 设计目标）

**表现**：AC 测 Av = 5×（14 dB），spec 要求 10×（20 dB）。

**物理因果**：CG 自身**不限制增益**——增益 = (gm+gmb) × R_load_eff。问题在 R_load。

**诊断**：op_point_check 看 V_drain DC（是否被 R_load × Id 上压降吃掉太多 headroom）。

**修复方向**：

| 根因 | 修复 | 因果 |
|---|---|---|
| R_load 太小 | 增 R_load 到 spec 要求 | 受 V_drain headroom 限：R_max = (VDD - V_drain_min) / Id |
| Id 太大压降太多 | 减 Id（但 gm 也降，Rin 升）| trade-off：保 Rin → 维持 gm × R 增益不容易升 |
| Active load 替代 | R_load 换成 PMOS mirror（Rout_load = ro_p）| Av = (gm+gmb) × (ro_n‖ro_p) → 数百倍 |

**❌ 不要**：单纯增 gm 不动 R_load——Av = gm·R_load，gm ↑ 但 Id ↑ → R_load × Id 头压降 ↑，可能撞 headroom 反而恶化。

---

## 症状 3：BW 远低于设计

**表现**：BW spec = 1 GHz，实测 = 100 MHz。

**物理因果**：drain 节点极点：fp_drain = 1/(2π × R_load × C_drain)。

**诊断**：
1. AC 仿真 magnitude bode 看 -3 dB 频率
2. 看 C_drain 实际值（含 Cgd_CG + 下级 Cgs + metal par）
3. 看 R_load 是否过大（高 Av 通常 BW 低）

**修复方向**：

| 根因 | 修复 | 因果 |
|---|---|---|
| C_drain 大 | 减下级 Cgs / layout 减 metal | 直接减极点 RC |
| R_load 太大 | 减 R_load（牺牲增益）或换 shunt-peaking inductor | RF 应用 inductor 补偿 BW |
| **Miller 复活**（gate AC 软）| 增 gate 旁路 cap | gate 摆 → Cgd × (1+Av) 反馈到信号路径 → 输入端等效 C 暴涨 |

---

## 症状 4：gate bias 软（"CG 没 Miller" 失效）

**表现**：BW 突然崩 / Rin 测不准 / NF 异常高。

**物理因果**：gate 节点是高阻 + 信号频段 AC 不够 stiff → gate 也摆 → CG 退化为 CS 行为。

**诊断**：AC 仿真，注入 1 mV 到 source，测 gate 节点 V 摆幅
- < 0.05 mV → gate 真 stiff（OK）
- > 0.5 mV → gate 软（问题）

**修复**：
- 加 gate 旁路 C（到 GND 或 VDD，看极性）≥ 100 pF
- bias 用低 Rout 的 PMOS 电流源 + 大 W
- RF：layout 邻近 + 多 via + 短路径

---

## 症状 5（RCG 专项）：反馈 OTA 不稳定

**表现**：tran 仿真 V_s 节点振铃（典型 100k-10M Hz）；AC 测 OTA loop PM < 45°。

**物理因果**：见 chapter `regulated-common-gate` —— A_OTA × Rout_OTA × Cgate 主极点 vs V_s 节点次极点距离不够。

**修复**（用 skill `circuit-method/ac-feedback-loop-method` 断环测 PM）：

| 根因 | 修复 |
|---|---|
| A_OTA 太快 | 减 OTA bias / 加 Cc | 主极点拉低 → 与次极点拉开 |
| C_s 节点电容太大 | 减下级 Cgs 或 减 sensor C | 次极点推高 |
| Rin·C_s 极点低 | gm 提高 → Rin 减小 → 极点高 | 提 CG bias 电流 |

---

## 通用诊断流程（用 skill）

CG 异常**不要**先调 W：

- **沿信号路径反推**（用 skill `circuit-method/signal-tracing`）：
  - Rin 不对 → gm 不对？还是 ro / R_load 修正项？还是 gate 软？
  - Av 不对 → gm 不对？还是 R_load 不对？还是 V_drain headroom 撞死？
  - BW 不对 → C_drain ? R_load ? Miller 复活？
- **环路稳定性问题**（仅 RCG）：用 skill `circuit-method/ac-feedback-loop-method` 断环测 PM

## 不在本章范围

- 完整 sizing 推导 → chapter `basic`
- TIA 跨阻 noise 推导 → chapter `tia-application`
- LNA NF 推导 → chapter `lna-application`
- RCG 内部 OTA 设计 → chapter `regulated-common-gate` + `blocks/5t-ota`
- cascode（CS+CG 级联）增益 debug → `blocks/base-cells/cascode/troubleshooting.md`
