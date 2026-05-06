---
chapter: troubleshooting
parent: miller-compensation
summary: |
  Miller 补偿五大故障：PM 不达标 / RHP zero 没消 / 大 Cload 失稳 /
  nested Miller 极点距离不够 / 寄生 Miller 限 BW
tokens: ~600
prerequisite_chapters:
  - plain-miller
  - nulling-resistor
  - parasitic-miller
related_skills:
  - circuit-method/ac-feedback-loop-method
  - circuit-method/signal-tracing
  - meta-cognitive/systematic-debugging
related_knowledge: []
---

# Miller 补偿故障诊断

> ⚠️ **使用规则**：本章是事实对照表。**思维过程**用 skill `circuit-method/ac-feedback-loop-method`
> 断环测 PM；用 skill `circuit-method/signal-tracing` 反推"PM 不足是哪一极点 / 哪个 zero 主导"。

---

## 症状 1：PM 在 GBW 处 < 60° spec

**表现**：AC 闭环 phase 在 GBW 频率 < 120° → PM = 180-phase < 60°。

**物理因果**（按可能性）：
- RHP zero 在 GBW 附近吃掉 PM（plain Miller 经典问题）
- fp2 离 GBW 太近（fp2 / GBW < 3）
- 大 Cload 让 fp2 过低
- Cc 太大让 GBW 紧贴 fp2
- 大信号 gm 工作点变化（Class-AB 输出级）

**诊断**：

| 检查项 | 动作 |
|---|---|
| zero 位置 | 找 magnitude 在 GBW 附近的 +20 dB/dec 转折 → RHP zero |
| fp2 位置 | gm_2/(2π·CL) 公式估 vs 实测 |
| 工作点 | 大信号瞬态 gm 跑到最大值，重 AC 测 |
| Cc 选值 | GBW × Cc / gm_1 比例 |

**修复方向**：

| 根因 | 修复 |
|---|---|
| RHP zero 主导 | 加 nulling Rz（chapter `nulling-resistor`）或 Ahuja-style |
| fp2 太低 | 减 Cload（限制不大）或增 gm_2（增 Iout 第二级） |
| Cc 太大 | 减 Cc → GBW 升（但同时让 zero 也升，需重新平衡 PM）|
| 大信号 gm | 按最坏 gm 设计 Cc（保守）|

---

## 症状 2：加 nulling Rz 后 zero 没消

**表现**：AC magnitude 在某频率仍有 +20 dB/dec → zero 未推到 LHP / ∞。

**物理因果**：
- Rz < 1/gm_2 → zero 仍在 RHP（未充分前馈抵消）
- Rz = 1/gm_2 → zero 推到 ∞（理论完全消除）
- Rz > 1/gm_2 → zero 移到 LHP（不是回到 RHP，但位置过低也可能改变 PM）

**诊断**：
- 测 gm_2（实际工作点）
- 测 Rz（实际值，含 PVT）
- 比较 Rz × gm_2（应 = 1 ± 50%）

**修复**：
- 调 Rz 到 ≈ 1/gm_2（典型 Rz target = 1.5/gm_2 给余量，让 zero 落在 LHP 但不过低）
- 用 triode-MOS Rz 跟踪 gm_2 PVT（chapter `nulling-resistor`）
- 在 PVT corner 都验证 zero 位置（应在 LHP 或 ≥ 10× GBW）

---

## 症状 3：大 Cload 引起失稳

**表现**：Cload 加大（如从 5 pF 到 50 pF）后 PM 急速下降 → 振铃。

**物理因果**：fp2 = gm_2/(2π·CL)，Cload 大 10× → fp2 低 10× → fp2 / GBW < 1 → PM 崩。

**修复方向**：

| 根因 | 修复 |
|---|---|
| Cload 远超原设计 | 增 gm_2（增 Iout 第二级电流）|
| 低速应用可接受小 GBW | 减 Cc 等比保 GBW，但牺牲速度 |
| 极大 Cload（µF 级，LDO/audio）| 升级 nested Miller（chapter `nested-miller`）|
| 二级不够 | 升级三级 opamp + nested Miller |

---

## 症状 4（nested 专项）：3 极点距离不够

**表现**：三级 opamp 加 nested Miller 后 PM 仍 < 60°。

**物理因果**：fp1 / fp2 / fp3 距离不对（理想分布是 log-equally spaced 或 fp(i+1)/fp(i) ≥ 3）。

**诊断**：
- 找 3 个极点位置（log scale 上画出）
- 检查比例 fp2/fp1 + fp3/fp2

**修复**：
- 调 Cc1 让 fp1 更低
- 调 Cc2 让 fp2 适当（不过低也不过高）
- 各级 nulling Rz 都加，消所有 RHP zero

---

## 症状 5（parasitic Miller 专项）：高速 CS BW 不达标

**表现**：spec BW = 5 GHz，实测 1.5 GHz；输入节点电容大。

**物理因果**：C_in_Miller = Cgd × (1+|Av|) 限制 input BW。

**诊断**：
- 测 input 节点电容（vs 公式）
- 检查 Av_CS 大小

**修复方向**（详见 chapter `parasitic-miller` § 对策）：
- **Cascode**（消 Miller 倍增 → BW 5-10× 提升）
- **Source-follower buffer**（前置 → 减 R_source）
- **改用 CG**（输入端是 source，不被 Miller 影响）
- **Neutralization**（RF 窄带 only）

---

## 关联 skill（诊断思维过程）

Miller 补偿诊断框架：
- **断环测 PM**：用 skill `circuit-method/ac-feedback-loop-method`（这是反馈环 PM 调试）
- **沿信号路径反推**：用 skill `circuit-method/signal-tracing`（"PM 损失是哪个极点 / zero 主导"）
- **根因优先**：用 skill `meta-cognitive/systematic-debugging`（不要先调 Cc，先确认根因）

特定症状的"是谁决定"指引：
- PM 不达标 → 极点 / RHP zero / 大 Cload 哪个主导
- zero 没消 → Rz·gm_2 比例
- 大 Cload → fp2 = gm_2 / CL 关系
- 高速 CS BW → parasitic Miller × Cgd × (1+Av)

## 不在本章范围

- 各 chapter 详细 → 对应章节
- 完整二级 opamp / 三级 opamp → `blocks/two-stage-ota` / `blocks/three-stage-ota`
- LDO 反馈环 → `blocks/ldo/`
- LNA / 高速 CS BW debug → `blocks/lna-cmos`
