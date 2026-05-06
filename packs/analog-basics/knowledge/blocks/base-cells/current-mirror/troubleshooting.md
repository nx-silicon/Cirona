---
chapter: troubleshooting
parent: current-mirror
summary: |
  current_mirror 4 变体共享 troubleshooting：输出 triode / 比例偏移 / supply
  敏感 / 启动失败 / cascode 底部管 triode（最常见物理误区）
tokens: ~550
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/signal-tracing
  - circuit-method/causal-chain-debug
  - meta-cognitive/systematic-debugging
---

# Current Mirror 故障诊断

> ⚠️ **使用规则**：本章给的是**症状对照表**——每条都是 Knowledge 层的"事实+因果"。
> 真正的诊断**思维过程**用 skill `circuit-method/signal-tracing`：
> State expectation → Observe → Identify deviation → Trace upstream → Verify cheapest。

---

## 症状 1：输出电流严重偏低或塌陷

**表现**：
- dc_snapshot 显示 Iout ≪ 设计值（如 设计 10µA 实测 0.5µA）
- M_out 的 Vds < Vdsat（triode）

**物理因果**：M_out 进了 triode 区域 = M_out 的 Vds 被上层 Vout 拉低到 < Vov。

**关键澄清**：
- M_out 的 Vds = **Vout - Vss**（由上层负载决定，**不是 mirror 自己决定**）
- 若 Vout 被上层电路（如 OTA 输出节点撞轨）拉低 → M_out triode
- **不要**调 M_out 的 W/L 解决 triode（W/L 不影响 Vds_sat = Vov，调 W 只让 Vov 变小但 compliance 仍受 Vout 限制）

**修复方向**（**不在 mirror 内部**）：
- 上层 compliance 设计：让 Vout_min ≥ Vds_sat + 100mV（典型 200-300mV 余量）
- 减少负载（让 Vout 自然抬高）
- 升级到 cascode mirror **不能**修这个（cascode 反而更需要 compliance）

→ **追溯思路**：用 skill `circuit-method/signal-tracing`，问"M_out.Vds 是谁决定的？"

---

## 症状 2：两路电流比例偏离设计 > 2%

**表现**：dc_snapshot Iout / Iref ≠ (W/L)_out / (W/L)_ref（误差 > 2%）

**可能原因 → 验证 → 修复**：

| 原因 | 验证 | 修复 |
|---|---|---|
| Vds 调制（ref vs out 支路 Vds 差）| dc_snapshot 看 M_ref.Vds vs M_out.Vds，差 > 200mV 时调制误差大 | 用 cascode mirror 屏蔽 Vout 影响 |
| Pelgrom mismatch（L 太小）| MC 仿真看 σ，L < 0.5µm 时 σ_Vth > 5mV | L ↑ 到 1-2µm，σ 改善 √L |
| W ratio 实现镜像（不是 m）| netlist 看 W ratio vs m | 改 m = N，layout 用交叉指 |
| Vgs source 不同电位 | dc_snapshot 看 M_ref.source vs M_out.source 是否真共 vss | 修电路，source 必须共节点 |

---

## 症状 3：电流随 VDD 变化 > 5%

**表现**：sweep VDD ±10%，Iout 偏移 > 5%

**物理因果**：line sensitivity 问题。simple mirror 的 Iref 由参考支路 R 给（Iref = (VDD-Vss)/R_ref）→ VDD 变 → Iref 变 → Iout 跟着变。

**修复**（**不在 mirror 自身**）：
- 换 PTAT bandgap-derived Iref：见 `blocks/base-cells/bias-generator/beta-multiplier.md`
- 加 cascoded mirror（仅减小 Vds 调制误差，**不**消除 Iref 的 VDD 依赖）

→ 追溯：mirror 是"复制"，Iref 错→Iout 必错。问题在 Iref 来源不在 mirror。

---

## 症状 4：启动失败（Iout 一直 0）

**表现**：power-up 后 dc_snapshot 显示 Iref / Iout 都是 0

**可能原因**：
- Iref 来源没"上电"（β-multiplier 的双稳态 stuck 在零电流点）→ 见 `blocks/base-cells/bias-generator/startup-helper.md`
- M_ref 在 cutoff（Vgs < Vth）→ 上游 bias 路径断
- 反馈环未闭合 → 见 ngspice convergence chapter（"反馈环未闭合 → DC 漂"）

**修复**：startup helper 强制 kick / 检查 bias chain 路径完整性

---

## 症状 5（cascode 变体特有）：cascode 底部管 triode

**表现**（cascoded mirror 用法）：dc_snapshot 显示 M_out（cascode 底部管）的 Vds < Vdsat

**关键物理事实**（V3 lessons 反复踩坑）：
- cascode 底部 M_out 的 **Vds = Vbc - Vgs_cascode**（Vbc 是 cascode 偏置电压）
- Vgs_cascode = Vth + Vov ≈ 0.5-0.7V
- 如果 Vbc 设计太低（如 0.7V）→ M_out.Vds = 0.7 - 0.6 = 0.1V → triode

**这不是 M_out 的 W/L 问题**，是 **Vbc 偏置生成不对**。

**修复方向**（沿因果链反向）：
- 调节生成 Vbc 的偏置 padding device 提高 Vbc：
  - 减小 padding device 的 W → padding 的 Vov 增大 → Vbc 升高
  - 或增大 padding device 的 L → 同样目的
- 不要调 M_out 的 W/L（M_out.Vds 不是 M_out 自己决定的！）

详细物理 + sizing 见 `blocks/base-cells/cascode/troubleshooting.md`（Week 3 写）。

---

## 通用诊断流程（用 skill）

遇到任何 mirror 异常先**不要**改 W/L 救：

1. **State expectation**：mirror 设计目标是什么（Iout / Rout / 比例 / mismatch）？
2. **Observe**：dc_snapshot 拿 M_ref / M_out 的 Vgs / Vds / Id / region
3. **Identify deviation**：哪个不合预期？是 Iref 错还是 Iout 错？region 错还是数值错？
4. **Trace upstream**：
   - Iref 错 → 上游 bias chain
   - Iout region 错 → 上游 Vout（compliance 节点）
   - 比例错 → Vds 调制 / mismatch / W ratio 错
5. **Verify cheapest**：dc_snapshot 看上游而不是直接改 W 重仿

完整 mental model 见 skill `circuit-method/signal-tracing`。

## 不在本章范围

- **cascode bias 生成具体电路**（padding device sizing）→ `blocks/base-cells/cascode/` chapter=biasing
- **β-multiplier startup**——见 `blocks/base-cells/bias-generator/startup-helper.md`
- **layout-induced systematic mismatch**——layout knowledge（V4 不在范围）
- **MC mismatch 测量方法**——见 skill `circuit-method/monte-carlo-mismatch-method`
- **Pelgrom 系数工艺值**——见 `pdks/<工艺>/`
