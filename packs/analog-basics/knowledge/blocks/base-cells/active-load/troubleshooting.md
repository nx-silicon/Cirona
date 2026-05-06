---
chapter: troubleshooting
parent: active-load
summary: |
  Active load 五大故障：增益塌陷（load triode）/ 差分不对称（mirror Vds 调制）/
  BW 慢（高阻节点 RC）/ matching 失配 / cascode 底部管 triode
tokens: ~600
prerequisite_chapters:
  - mirror-load
  - cascode-load
related_skills:
  - circuit-method/signal-tracing
  - circuit-method/systematic-debugging
related_knowledge:
  - blocks/base-cells/cascode
---

# Active Load 故障诊断

> ⚠️ **使用规则**：本章是事实对照表。**思维过程**用 skill `circuit-method/signal-tracing`
> 沿信号路径反推（"Av 是谁决定的？M_load.Vds 是谁决定的？"）。

---

## 症状 1：增益异常低（实测 Av < 设计 50%）

**表现**：5T-OTA 设计 Av = 60 dB，实测仅 35 dB。

**物理因果**：
- mirror-load M4 进入 triode → ro 从数百 kΩ 跌至数百 Ω → 增益塌陷
- 或 cascode-load 底部管 M4a 进入 triode（Vbcp 偏置错）
- 或 输出节点有意外低阻分支（ESD / 寄生 nwell 接触）

**诊断顺序**：

| 检查项 | 动作 | 判断 |
|---|---|---|
| Load region | dc_snapshot 看 M_load Vds vs Vov | Vds < Vov → triode → ro 塌；通常由 Vout 过高（接近 VDD）或 Vbias_load 偏低触发 |
| 输出节点 DC | 看 V_out 静态值 | V_out 接近 VDD → M_load 撞 triode 边缘 |
| Cascode bias | 看 Vbcp / cascode 底部管 Vds | M4a.Vds < Vov → Vbcp 偏低；用 skill `signal-tracing` 反推 |
| 寄生路径 | netlist review V_out 节点的所有连接 | 多余 ESD / nwell tap 路径 → 隐藏 R 拉低 ro |

**修复方向**：

| 根因 | 修复 | ❌ 不要 |
|---|---|---|
| mirror M4 triode | 增 V_drain（让 V_out 中央化）| 调 M4 的 W |
| cascode M4a triode | 改 Vbcp（调 padding device sizing）| 调 M4a 的 W/L |
| 寄生低阻路径 | layout review + 移除 | 强行 sizing 补偿 |

---

## 症状 2：差分对输出电流不对称（两路 Iout 偏差 > 3%）

**表现**：5T-OTA 在 Vin_diff = 0 时 V_out 偏离 Vcm。

**物理因果**：mirror load 两支路 Vds_load 不相等 → ro 调制误差。

**诊断**：dc_snapshot 看左右两路 M_load 的 Vds 差距：
- M3.Vds（diode 那侧）= VDD - Vgs_load（固定）
- M4.Vds（mirror out 那侧）= VDD - V_out（随信号变）
- 差异通常 100-500 mV @ 中央化 V_out

**修复方向**：

| 根因 | 修复 | 因果 |
|---|---|---|
| Vds 调制（差异 > 200mV）| 改 cascode-load 屏蔽 | M4 Vds 被钉在 Vbcp - Vgs_M4b 与 V_out 解耦 |
| Vds 调制（轻微）| 增 L_load → ro 升 → λ·ΔVds 项小 | Av 与 mismatch 同时改善 |

**❌ 不要**：
- 调 W_load ratio 来补不对称（治标不治本，PVT 仍漂）
- 用理想电流源替代 mirror ref（破坏信号路径转换）

---

## 症状 3：高频增益下降比预期快（极点频率偏低）

**表现**：spec BW = 100 MHz，实测 -3 dB 在 30 MHz。

**物理因果**：高阻输出节点 RC 主极点：fp = 1/(2π · ro_load‖ro_drv · C_out)。
- C_out = Cgd_load + Cgd_drv + Cdb_load + Cdb_drv + C_wiring + 下级 Cgs

**诊断**：
- AC 仿真 magnitude bode 看 -3dB 频率
- C_out 实测 vs 预算（含 layout par）

**修复方向**：

| 根因 | 修复 | 代价 |
|---|---|---|
| C_out 大 | 减 layout par / 减下级 Cgs | layout 优化 |
| ro 太大（高 Av 设计）| 减 L_load 或 减 cascode 层数 | Av 减少 |

**❌ 不要**：盲目减 L_load —— 会同时降 ro，Av 损失抵消 BW 改善。

---

## 症状 4：mismatch 失配大（systematic 或 random）

**表现**：MC 仿真 σ(V_out_offset) > 5 mV，spec 要求 < 2 mV。

**物理因果**：
- σ(ΔVth) = AVT / √(W·L)（Pelgrom）
- σ(Δβ/β) = AB / √(W·L)
- L 太小（< 0.5 µm）→ σ_Vth > 5 mV @ AVT = 5 mV·µm

**修复方向**：

| 根因 | 修复 | 代价 |
|---|---|---|
| L 太小 | L ↑ 到 1-2 µm | 面积 + Cgs 增 |
| W 太小 | W ↑ | 面积 + Cgs 增 |
| layout 失配 | 共质心 / 交叉指 / 邻近 | layout 工作 |
| Vov_load 太小（< 80 mV）| Vov ↑ 到 0.1-0.2V | swing 损一点点 |

---

## 症状 5（cascode 专项）：cascode 底部管 triode

**表现**：dc_snapshot M4a.Vds < Vov_M4a。

**物理因果**（cascode 章关键物理审查点）：
- M4a.Vds = Vbcp - Vgs_M4b（不是 M4a 自己决定）
- Vbcp 偏低 → M4a.Vds 不够

**修复方向**（沿信号路径反向）：
- 调节生成 Vbcp 的 padding device sizing 提 Vbcp
- **不**调 M4a 的 W/L（不是 M4a 的问题）

详细 cascode bias 物理见 `blocks/base-cells/cascode/troubleshooting.md`。

---

## 关联 skill（诊断思维过程）

Active load 异常诊断框架：
- **沿信号路径反推**：用 skill `circuit-method/signal-tracing`（"M_load.Vds 是谁决定的？Av 是谁决定的？"）
- **根因优先**：用 skill `meta-cognitive/systematic-debugging`（不要先调 W/L，先确认根因在 region / Vds / mismatch / parasitic 哪个）

Active load 特定症状的"是谁决定"指引：
- 增益不对 → ro 不对（load triode 或 寄生路径）/ gm_drv 不对
- 不对称 → Vds 调制（mirror load 经典问题）
- BW 不对 → C_out × R_load 主极点
- mismatch → σ ∝ 1/√(WL) 增大 W·L

## 通用原则

- 改 load sizing 之前先确认 load 在 saturation（dc_snapshot）
- 不要在 base-cell 内做"自适应"偏置 → load bias 是上层 circuit 责任
- Vov_load < 80 mV → matching 极差（避免）
- 高阻 V_out 节点只能有一条信号路径到地（多余低阻分支必须消除）

## 不在本章范围

- diode/mirror/cascode 拓扑详细 → 对应 chapter
- gm/Id sizing 方法 → skill `circuit-method/device-sizing`
- 完整 5T-OTA / FC / telescopic 故障诊断 → `blocks/ota-*/troubleshooting.md`
- cascode bias 物理详细 → `blocks/base-cells/cascode/`
- layout 失配 → layout knowledge（V4 不在范围）
