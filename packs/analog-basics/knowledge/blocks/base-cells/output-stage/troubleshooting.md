---
chapter: troubleshooting
parent: output-stage
summary: |
  输出级五大故障：Iq PVT 漂移 / 死区交越失真 / 摆幅不足 / shoot-through 瞬态尖峰 /
  大信号 PM 退化
tokens: ~600
prerequisite_chapters:
  - class-ab
  - push-pull
related_skills:
  - circuit-method/signal-tracing
  - circuit-method/ac-feedback-loop-method
  - meta-cognitive/systematic-debugging
related_knowledge:
  - blocks/base-cells/bias-generator
  - blocks/base-cells/miller-compensation
---

# 输出级故障诊断

> ⚠️ **使用规则**：本章是事实对照表。**思维过程**用 skill `circuit-method/signal-tracing`
> 沿信号路径反推（"Iq 是谁决定的？SR 是谁限制的？"）；环路稳定性用
> `ac-feedback-loop-method` 的最坏 gm PM 验证思路。

---

## 症状 1：Iq PVT 漂移 > 30%

**表现**：标称 Iq = 50 µA，FF 角变 80 µA，SS 角变 25 µA。

**物理因果**：偏置展开网络 Vbias 不跟踪 PVT
- V_th 温度系数（约 -2 mV/°C） → 高温 |Vgs_P|+Vgs_N 减小 → Vbias 不变 → diode 上 Vov 调整 → Iq 漂
- 工艺角 V_th 变化 ±50 mV → Iq 指数级响应

**诊断检查项**：

| 检查项 | 动作 | 判断 |
|---|---|---|
| diode 偏置管型号 | netlist review | 必须与输出管同型（NMOS-NMOS / PMOS-PMOS）|
| diode 偏置管尺寸 | 看 netlist W·L vs 输出管 | **必须 W 同 + L 同**（PVT tracking 硬要求；只能靠 m 比例做 Iq 缩放）|
| Layout 邻近 | layout review（如有）| diode 与输出管邻近放置（共质心 / 交叉指）|
| 是否有"理想电压源"代替 diode | netlist 看 spreader | 理想源不跟工艺，会漂 |

**修复**：用 diode-connected 偏置对，**diode 与输出管同尺寸**（chapter `class-ab` §A）。

---

## 症状 2：交越失真 / 死区缺口

**表现**：tran 输出波形零交叉处出现台阶 / 跳变 / dead zone；THD > -50 dB @ 1V_pp。

**物理因果**：
- Iq 过小 → 零交叉处 (gm_P + gm_N)_min 不足
- 或 Vbias 临界 < |Vth_p| + Vth_n → 严格死区（两管全 cutoff）

**诊断**：
1. dc_snapshot 在零交叉点附近扫 V_out → 看 (gm_P + gm_N) 最小值
2. 若 Vbias < |Vth_p| + Vth_n → 严格死区
3. 若 Vbias 勉强够但 PVT 最差角下不够 → 边缘死区

**修复方向**：

| 根因 | 修复（按用户洞察：diode 与输出管同尺寸，**不**改 diode W）| 因果 |
|---|---|---|
| Iq 太小 | 增 **Iref** 或增 **m_out:m_diode 比例** → Iq ↑ → gm_min ↑ | THD ∝ 1/(gm_min × R_load) |
| Vspread 不够（严格死区）| 整体 W ↓（输出 + diode 同步）→ Vov ↑ → Vspread ↑；或 diode 串多个（增加 floating Vbe stack）| 给 V_th 漂移留 ≥ 50-100 mV 余量 |
| 想偏 Class-A 多一些（增 gm_min）| 整体 W ↓ → Vov ↑ → 偏置点偏离 cutoff → 大 gm_q | 代价：摆幅压缩 + 静态功耗 ↑ |

**❌ 不要**：
- 单独改 diode W（破坏 PVT tracking）
- 靠负反馈"压住"交越失真（环路 BW 有限，高频失真压不住）

---

## 症状 3：输出摆幅不足

**表现**：扫 V_out_max / V_out_min 达不到设计目标。

**物理因果**（CS 与 SF 完全不同）：
- **互补 CS**：Vdsat 过大 → 摆幅被压缩（典型 V_out_max = VDD - |Vdsat_p|，目标 ≤ 200 mV @ 180nm）
- **互补 SF**：Vgs + body effect 限制 → 摆幅 ≈ VDD - (Vgs_n + |Vgs_p|) ≈ VDD - 1.2 V，远小于 CS

**诊断**：
- op_point_check 看 Mp / Mn 区域和 Vdsat
- 拓扑确认（互补 CS or SF）—— 用错"VDD - 200mV"指标会误判 SF 摆幅

**修复方向**：

| 根因 | 修复 |
|---|---|
| W 选小 → Vdsat 大 | 增 W（从 SR / Imax 重新推算）|
| Vbias 偏大让输出管进强反型 | 减 Vbias 余量到 50-100 mV |
| body effect 偷走 Vov | NMOS 用 deep N-well 隔离 / 增 W 补偿 |

**注意**：W 增大 → Cgate 增 → 前级负担加重 → SR 限制可能反而恶化（trade-off 必查）。

---

## 症状 4：Shoot-through 电流尖峰

**表现**：tran 仿真 IDD 在过渡瞬间出现 > 5 × Iq 的尖峰；电源 ripple 异常。

**物理因果**：大信号过渡时两管同时强导通：
- 互补 SF：输入快速变 → spreader 内电压差未及时调整 → 短暂 Mp + Mn 都开
- 互补 CS：输入摆幅大时 → V_GS_p 与 V_GS_n 同时 ≫ V_th

**诊断**：tran 看 IDD 波形，过渡沿越快、Iq 越大 → shoot-through 越严重。

**修复方向**：

| 根因 | 修复（不改 diode W）| 代价 |
|---|---|---|
| 过渡沿太快 | 前级输出加小串联 R 限速 | SR 略降 |
| Iq 太大 | 减 **Iref** 或减 **m_out:m_diode 比例** → Iq ↓ | 静态 gm_min 降 → 交越失真风险 ↑ |
| 想偏 Class-B 多一些（减 shoot-through）| 整体 W ↑（输出 + diode 同步）→ Vov ↓ → Vspread 收窄 → 偏置点接近 cutoff | 导通余量变小 → 交越失真容忍度低 |
| Spreader 带宽不够 | 检查 diode 节点 par cap → 减 layout par | 复杂 |

**❌ 不要**加滤波电容到 VDD 解决——治标不治本，功耗仍超。

---

## 症状 5：大信号瞬态 PM 退化（小信号 PM ok 但阶跃后振铃）

**表现**：AC 仿真静态点 PM = 65°（ok），但 .tran 阶跃响应明显 ringing；settling 不收敛。

**物理因果**：Class-AB gm 随工作点变化 → 大信号 gm_P + gm_N ≫ gm_q → 主极点位置漂 → PM 实际工作点小很多。

**诊断**：
1. 在小信号点跑 AC：PM_q
2. 在大信号最坏点（输出 ±0.5 × swing）跑 AC：PM_max_gm
3. PM_max_gm < 45° → 大信号失稳

**修复方向**：

| 根因 | 修复 | 因果 |
|---|---|---|
| Cc Miller 按 gm_q 算偏小 | Cc 重算按 gm_max → Cc_new = Cc_old × (gm_max / gm_q) | UGB 降 → 速度损失换稳定 |
| 单 Miller 不够 | 改 nested Miller 或 Ahuja current-buffer Miller | 见 `blocks/base-cells/miller-compensation` |
| 输出级 Rout 太大（互补 CS）| 后接 SF buffer 把 Rout 降到 1/gm | 多一级，复杂度 + |

---

## 关联 skill（诊断思维过程）

输出级故障诊断思维框架：
- **沿信号路径反推**：用 skill `circuit-method/signal-tracing`（"Iq 是谁决定的？SR 是谁限制的？摆幅是谁压缩的？"）
- **环路稳定性最坏 gm 验证**：用 skill `circuit-method/ac-feedback-loop-method`（Class-AB gm 大信号 ≫ gm_q，必须在最坏 gm 下查 PM）
- **根因优先**：用 skill `meta-cognitive/systematic-debugging`（不要先调输出管 W，先确认根因在偏置链 / 前级 / 补偿哪个）

输出级特定症状的"是谁决定"指引：
- Iq 不对 → 偏置链（Iref / diode 比例 / Vspread）
- SR 不对 → Imax 或 Cload 或前级 gate 驱动能力
- 摆幅不对 → Vdsat（CS）/ Vgs+body effect（SF）
- 大信号 PM 不对 → gm_max 工作点 / Cc / Rout 链

## 不在本章范围

- 偏置展开网络具体设计（diode 管 sizing）→ chapter `class-ab`
- 互补 SF vs CS 拓扑结构选择 → chapter `push-pull`
- 完整环路 Miller 补偿设计 → `blocks/base-cells/miller-compensation`
- Layout 导致的 mismatch / EM 问题 → layout knowledge（V4 不在范围）
- LDO 整体反馈环 debug → `blocks/ldo/troubleshooting.md`
