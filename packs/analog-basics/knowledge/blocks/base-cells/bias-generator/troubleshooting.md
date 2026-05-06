---
chapter: troubleshooting
parent: bias-generator
summary: |
  Bias chain 五大故障：启动失败（stuck-at-zero）/ Iref PVT 漂大 / 内部节点 stuck /
  噪声耦合 / replica 反馈失稳
tokens: ~500
prerequisite_chapters:
  - basic-mirror-tree
  - beta-multiplier
  - startup-helper
related_skills:
  - circuit-method/signal-tracing
  - circuit-method/bias-tree-reasoning
  - meta-cognitive/systematic-debugging
related_knowledge: []
---

# Bias Generator 故障诊断

> ⚠️ **使用规则**：本章是事实对照表。**思维过程**用 skill `circuit-method/bias-tree-reasoning`
> 沿 bias chain 逐节点反推（"vb_n 是谁决定的？vbpc 是谁决定的？整树是哪条支路 stuck？"）。

---

## 症状 1：启动失败（上电后 I_bias = 0）

**表现**：tran VDD ramp 后 dc_snapshot 显示 vb_n / vb_p / I_bias 都为零或 rail-stuck。

**物理因果**（取决于 bias 类型）：
- **β-multiplier**：双稳态 stuck-at-zero（详见 chapter `startup-helper`）
- **basic mirror tree**：Iref 自身没起来（bandgap startup 失败）
- **任何自偏置**：上电序列错 / VDD ramp 太快

**诊断**：

| 检查项 | 动作 |
|---|---|
| 是否 β-multiplier | 看是否有 startup helper（chapter `startup-helper`）|
| Iref 是否启动 | 追溯到 Iref 来源（bandgap output 是否上来）|
| VDD ramp speed | 不同 ramp speed 都试（1µs / 100µs / 10ms）|

**修复**：
- β-multiplier 必须配 startup helper
- bandgap 自身需有 startup
- VDD ramp 太快时加大 startup helper W

---

## 症状 2：I_bias PVT 漂 > spec

**表现**：spec ±20%，实测 PVT corner ±50%。

**物理因果**：
- R_set 漂（poly TCR ±500 ppm/°C × ΔT 100°C → ±5%）
- 工艺 sheet R spread ±15-20%
- μ + V_th 漂（β-multiplier 公式包含两者）
- mirror L 太短 → λ·Vds 调制大

**修复**：

| 根因 | 修复 |
|---|---|
| R_set 漂大 | 用 silicide poly（TCR 低）/ trim |
| mirror L 太短 | L ↑ 到 4-8 × Lmin |
| 严格 spec | 数字 trim 校正（DAC/programmable resistor）|

---

## 症状 3：内部节点 stuck（部分电路启动，部分不启动）

**表现**：tran 看到 bias 部分支路 OK，部分支路 vb 在 cutoff。

**物理因果**：bias chain 中某节点没建立（断链）。

**诊断**（用 signal-tracing skill）：
1. dc_snapshot 列出所有 bias 节点（vb_n / vb_p / vbpc / vbnc / vb_tail / 等）
2. 找哪个节点偏离设计
3. 沿 bias chain 反推"该节点是谁决定的"
4. 通常上游某个 mirror 管 cutoff（W 太小 + Iref 不够）

**修复**：依靠 signal-tracing 找根因；通常增 Iref 或调失败 mirror 管 sizing。

---

## 症状 4：bias 噪声耦合到主电路

**表现**：input-referred noise 测量 → 发现 bias chain 噪声占比显著（如 30-50%）。

**物理因果**：
- mirror 管 thermal + 1/f noise
- 通过 gm 注入到主电路（OTA tail 是经典路径）

**诊断**：noise 仿真分别看各支路贡献。

**修复**：

| 根因 | 修复 |
|---|---|
| OTA tail mirror 1/f 大 | 增 W·L of M_tail（√(WL) 关系）|
| 多支路并联耦合 | 用 cascode bias 提升 mirror Rout |
| bias rail 受 supply noise 干扰 | 加 bypass cap on bias rail |

---

## 症状 5（replica 专项）：反馈环不稳定 / 振铃

**表现**：tran replica EA 输出 vbias 振铃；dc_snapshot 不收敛。

**物理因果**：见 chapter `replica` § 稳定性约束。

**诊断**：用 skill `circuit-method/ac-feedback-loop-method` 断 replica EA 环测 PM。

**修复**：减 EA bandwidth / 加 EA Cc / 拉开主次极点距离。

---

## 关联 skill（诊断思维过程）

Bias chain 故障诊断框架：
- **沿 bias 路径反推**：用 skill `circuit-method/bias-tree-reasoning`（每个节点是谁决定的）
- **根因优先**：用 skill `meta-cognitive/systematic-debugging`（不要先调 W，先确认根因）
- **反馈环稳定性**：用 skill `circuit-method/ac-feedback-loop-method`（如有 replica）

特定症状的"是谁决定"指引：
- 启动失败 → β-multiplier 双稳态 / startup helper / bandgap upstream
- I_bias PVT 漂 → R_set / 工艺 spread / mirror L
- 内部节点 stuck → bias chain 上游某 mirror 失败
- 噪声 → mirror 管 thermal/flicker（W·L 决定）
- replica 振铃 → EA 反馈环 PM 不足

## 不在本章范围

- 各 chapter（basic-mirror-tree / β-multiplier / replica / level-shifter / startup-helper）详细 → 对应章节
- bandgap reference 自身故障 → `blocks/bandgap/troubleshooting`
- LDO 反馈环故障（含 EA）→ `blocks/ldo/troubleshooting`
- OTA tail mismatch / Pelgrom → `blocks/base-cells/differential-pair/`
