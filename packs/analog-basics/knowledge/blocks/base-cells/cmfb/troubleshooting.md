---
chapter: troubleshooting
parent: cmfb
summary: |
  CMFB 五大故障：共模漂移 / 极性反 / 环路振荡 / 加载侵蚀主 OTA / SC 纹波。
  含 CT 与 SC 通用诊断流程
tokens: ~650
prerequisite_chapters:
  - continuous-time
  - switched-capacitor
related_skills:
  - circuit-method/signal-tracing
  - circuit-method/ac-feedback-loop-method
  - meta-cognitive/systematic-debugging
related_knowledge:
  - blocks/base-cells/active-load
---

# CMFB 故障诊断

> ⚠️ **使用规则**：本章是事实对照表。**思维过程**用 skill `circuit-method/signal-tracing`
> 沿信号路径反推（"vcm 是谁决定的？vcmfb_ctrl 是谁决定的？"）；环路稳定性问题用
> `ac-feedback-loop-method` 的通用断环思路。

---

## 症状 1：输出共模漂移（Vcm_out 偏离 Vcm_ref > 50 mV）

**表现**：dc_snapshot 显示 (voutp + voutn)/2 偏离 Vcm_ref；常伴 vcmfb_ctrl 卡在 rail 附近。

**物理因果**：CMFB 失去调节能力——通常是极性反 / 注入点没权限 / EA 饱和。

**诊断顺序**（按廉价度）：

| 检查项 | 动作 | 判断依据 |
|---|---|---|
| EA 是否饱和 | dc_snapshot 看 vcmfb_ctrl | 卡 rail（< 100mV 或 > VDD-100mV）→ EA 饱和 → 极性 / 注入点出问题 |
| **极性验证**（关键） | 在 vcm_out 注入扰动 +50 mV（不是改 Vcm_ref），看 vcmfb_ctrl 反向调节使 vcm_out 拉回 | **正确负反馈**：vcm_out ↑ → vcmfb_ctrl 调节方向使 vcm_out 回降；若 vcmfb_ctrl 反向 → 正反馈，极性反 |
| Vcm_ref 跟踪验证（次要）| Vcm_ref 上调 50 mV，看 vcm_out 反应 | 闭环跟踪：vcm_out 应**上升**至新 Vcm_ref（这是参考变化的跟踪，不是负反馈极性验证）|
| 注入点权限 | 看 vcmfb_ctrl 接到 PMOS load gate / 折叠 bias / cascode bias | 与 OTA 拓扑核对（见 chapter `continuous-time` 注入点表）|
| 加载量 | R_sense（CT）/ C_sense（SC）| R_sense < 5 × Rout_ota 或 C_sense < 100 fF 都可能引起精度不足 |

**修复方向**（按根因）：

| 根因 | 修复 | 因果 |
|---|---|---|
| 极性反 | 反转 EA 差分输入接线（vcm_sense ↔ Vcm_ref）或反转注入点连接 | 极性反 = 正反馈推 rail，必须硬纠正 |
| R_sense 太小（CT）| 提到 ≥ 5 × Rout_ota（200kΩ-1MΩ）| 加载减小，主 OTA gain 恢复，CMFB 调节范围回 |
| 注入点错（如接 cascode bias 但没权限）| 改接 PMOS load gate | 调 load gate 直接调电流 → 输出共模 |

**❌ 不要做的事**：
- ❌ 调 Vcm_ref 数值"补偿"漂移——掩盖根因
- ❌ 增大 EA gain 强行拉回——极性错时增益越大越快 rail

---

## 症状 2：CMFB 环路振铃 / 共模不收敛

**表现**：tran 仿真共模通路持续振铃（典型 100 kHz - 10 MHz 纹波，幅度 10-100 mV）。

**物理因果**：CMFB 环路 PM 不足——通常是 BW_cmfb 太接近主 OTA GBW，或 SC 的 C_hold/C_sense 比例错。

**诊断**（用 skill `ac-feedback-loop-method` 的断环思路）：

1. 断 CMFB 环（在 vcmfb_ctrl → 注入点之间断，加 Rfb=1G/Cfb=1F），注入小信号到 vcmfb_ctrl
2. 跑 .ac dec 100 1 1G，测 PM
3. 若 PM < 45° → CMFB 自身 / 与主环耦合的 PM 问题

**修复方向**（CT）：

| 根因 | 修复 | 因果 |
|---|---|---|
| BW_cmfb 太高（> 0.5 × GBW_ota）| 减小 EA gm（减 W 或 减 bias）| BW_cmfb ↓ → 与主 OTA 极点距离 ↑ → PM 改善 |
| EA 输出节点附加极点低 | 减 C 在 vcmfb_ctrl 节点（或加 small Rzero）| 推高极点，增 PM |
| R-divider 引入的输出极点 | R_sense ↑（推低主 OTA 输出极点同时增大 PM？需仿真）| R-divider 极点 = 1/(2π·R·Cload)，trade-off |

**修复方向**（SC）：

| 根因 | 修复 | 因果 |
|---|---|---|
| C_hold < 2 × C_sense | 增 C_hold 到 ≥ 2 × C_sense | 每周期纹波 ↓，A_eff 也 ↓（建立慢但稳）|
| fclk < 10 × BW_cmfb_target | 提 fclk 或降 BW_cmfb_target | 离散时间镜像 fold-back 问题 |
| 时钟相位重叠 | 加大非交叠间隔 ≥ 1 ns | 重叠 → vout 直接灌 Vcm_ref，破坏建立 |

**❌ 不要做的事**：
- ❌ 增大 EA gain 想"强行收敛"——增益大 PM 更差
- ❌ 仅在 TT 角验证 PM —— SS 角 BW_cmfb 自然下降可能恶化 PM；FF 角加快可能撞主环

---

## 症状 3：加 CMFB 后主 OTA 差分增益 / GBW 显著退化

**表现**：差分 AC 仿真显示 加 CMFB 后 gain 下降 > 3 dB 或 GBW 下降 > 20%。

**物理因果**：CMFB 检测网络加载主 OTA 输出，或注入点路径侵蚀差分通路 swing。

**诊断**：

1. dc_snapshot 看 Rout_ota 在 加 / 不加 CMFB 时的值
2. 看 R_sense 的实际增益保持比例：gain_factor = R_sense / (R_sense + Rout_ota)；R_sense=5×Rout 时约 0.83（约 -1.6 dB）
3. 检查注入点是否同时影响差分通路（如接到 PMOS load gate → 也调 load 上拉电流，理论上对差分对称，但 mismatch 可能引入 offset）

**修复方向**：

| 根因 | 修复 |
|---|---|
| R_sense 太小 | R_sense ↑ 到 ≥ 10 × Rout_ota |
| 输出节点是高阻 cascode（Rout 太大）| 改用 source-follower 缓冲检测（chapter `continuous-time` 变体 B）|
| 任何 R-divider 都不行 | 改用 SC CMFB（零静态加载，chapter `switched-capacitor`）|

---

## 症状 4：启动时共模漂到 rail（power-up 失败）

**表现**：上电瞬态显示 vout 走到 0 或 VDD，永不恢复。

**物理因果**：上电时 CMFB EA 还没建立 bias → vcmfb_ctrl 不可控 → PMOS load 全开或全关 → 输出推 rail。

**修复方向**：
- 加 startup helper（先用 weak pull-up/pull-down 把 vcmfb_ctrl 拉到合理初值）
- bias chain 上电顺序：先建 EA bias 再启主 OTA
- 检查 bias chain 是否有 stuck-at-zero 节点（β-multiplier 双稳态）→ 见 `blocks/base-cells/bias-generator/startup-helper.md`

---

## 症状 5（SC 专项）：稳态共模有持续纹波（10 mV - 100 mV）

**表现**：tran 仿真稳态后 vcm_out 在每个时钟周期有 mV 级周期性跳变。

**物理因果**：每周期电荷转移 + 寄生 + charge injection 不平衡。

**修复方向**：

| 根因 | 修复 |
|---|---|
| C_par 寄生过大（> 0.2 × C_sense）| 减小开关 W / 优化 layout |
| 底板切换顺序错 | S2（参考侧）先于 S1（输出侧）断开 |
| 时钟摆幅不足导致 Ron 大 | 提 Vh 或加 bootstrap 开关（见 `blocks/base-cells/switch/bootstrapped.md`）|
| C_hold 过小 | C_hold ↑ 到 ≥ 3 × C_sense |

---

## 关联 skill（诊断思维过程）

CMFB 异常的诊断思维框架：
- **沿信号路径反推**：用 skill `circuit-method/signal-tracing`（"vcm_out 是谁决定的？vcmfb_ctrl 是谁决定的？EA 输入对差异是谁决定的？"）
- **断环测稳定性**：用 skill `circuit-method/ac-feedback-loop-method`（CMFB 是反馈环，振铃问题用通用断环思路测 PM）
- **根因优先**：用 skill `meta-cognitive/systematic-debugging`（不要先调 EA gain，先确认根因在极性 / 加载 / 注入点 / 增益不足哪个）

CMFB 特定症状的"是谁决定"指引：
- vcmfb_ctrl 卡 rail → EA 饱和 → 检查极性 / 注入点权限 / Vcm_ref 是否在 EA 输出可达范围
- vcm_out 偏 + vcmfb_ctrl 中轨 → CMFB 增益不足 → 看 A_cmfb 是否 < 20 dB
- 振铃 → 断环测 PM，对照 BW_cmfb / GBW_ota 比例

## 不在本章范围

- **OTA 主环路本身的 PM 问题**——见 `blocks/<对应 OTA>/ac-stability.md`（CMFB 故障 ≠ 主环故障）
- **bias chain 启动失败**（β-multiplier stuck）——见 `blocks/base-cells/bias-generator/startup-helper.md`
- **layout-induced charge injection 不对称**——layout knowledge（V4 不在范围）
- **数字校准 CMFB residual offset 补偿**——本 cell 不覆盖
- **kT/C 噪声 vs SNR 系统级权衡**——见 `systems/adc-*` 章节
