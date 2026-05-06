---
chapter: troubleshooting
parent: source-follower
summary: dropout 边缘 / body effect Av 偏离 1 / 大电流驱动饱和 三类对照
tokens: ~400
related_skills:
  - circuit-method/signal-tracing
---

# Source-Follower 故障诊断

## 症状 1：dropout 比预期大（vout 距 vin 偏远）

**物理事实**：NMOS SF dropout = Vth_eff(VSB) + Vov（不可避免）。
body effect 不只让 Av 偏低，**直接抬升 dropout 50-200 mV**（VSB > 0 让 Vth_eff > Vth0）。

**修复方向**：
- 减 Vov（gm/Id ↑，**弱反型/中等反型方向**；强反型对应大 Vov 是反方向）：节省 ~100mV
- 选 low-Vth 工艺（lvt device）：节省 100-150mV（如工艺支持）
- **改用 PMOS pass FET**（不是 SF）：dropout = Iload × R_DS(on)，可 < 100mV—— 这是 LDO 标准做法
- body effect 无法降——除非 deep n-well 工艺让 source-body 短接

## 症状 2：Av < 0.7（远低于 1）

**根因**：
- body effect 严重（vsb 大）
- Rload 过小（pull-down 强）
- gmb 接近 gm（弱反型 + body bias 大）

**验证**：dc_snapshot 看 Vsb，gmb = ∂Id/∂Vsb 数值。

**修复**：
- PMOS SF（n-well 接 source 时无 body effect）
- 减 Rload pull-down 强度 / 改 ideal current source
- 强反型（让 gm 大，gmb/gm 比例小）

## 症状 3：大电流驱动时 SF 饱和 / 无法保持 Av=1

**原因**：
- Iload 远超 SF device W/L 能流通的最大 Id_sat
- SF 撞 triode → Av 突变 / 大失真

**判别**：dc_snapshot M.Vds < Vov → triode.

**修复**：
- W ↑（让 Id_sat ↑，正比于 W）
- m 多 finger 拆开（layout / matching 益）
- 改用 push-pull / class AB output stage（两 SF 共驱动 Iload，电流分担）

## 症状 4：tail current source 撞地（NMOS SF 时）

**条件**：vin - Vth - Vov_M = Vds_tail < Vov_tail → tail triode

**修复**：
- 提升 vin 工作范围（如可改 spec）
- 减 Vov_M（gm/Id ↑）
- 减 Vov_tail（tail W ↑）
- 用 cascoded tail 也无济于事（cascoded tail 需要更高 vds_tail）—— 这是 SF 物理限制

## 不在本章范围

- **PMOS pass FET 设计**（LDO 标准 output 设备）→ `blocks/ldo/architecture.md`
- **class AB output stage**（解决大电流驱动）→ `blocks/base-cells/output-stage`
- **output buffer 在 OTA 输出端整体设计**——见 `blocks/two-stage-ota`
