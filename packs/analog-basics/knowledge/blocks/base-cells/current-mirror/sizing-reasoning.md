---
chapter: sizing-reasoning
parent: current-mirror
summary: |
  R2 CMOS 镜像铁律在 current-mirror 的具体化 + 一份单管 sizing TB 模板 +
  50µA NMOS reference 管 worked example。pre-sim sizing 通用 sizing 流程 Step 4
  选旋钮时 LLM read 这章, 拿 TB 改三处即跑 simulate.
tokens: ~1400
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/device-sizing
  - circuit-method/bias-tree-reasoning
related_knowledge:
  - blocks/base-cells/cascode
  - blocks/base-cells/bias-generator
---

# current-mirror — sizing reasoning（铁律 + TB + worked example）

> Chapter 用途：当 LLM 在 pre-sim sizing 通用 sizing 流程（L0）Step 4 选旋钮时遇到
> 电流镜结构，应 read 这一章，得到 R2 镜像铁律的具体化 + 一份单管 sizing
> TB 模板 + 一份完整 worked example。

## R2 CMOS 镜像铁律 — current-mirror 实例化

电流镜由 reference 管（diode-connected, M_ref, Iref 灌入）和一/多个 output
管（M_out_i, mirror 出 Iout_i = Iref · (W/L)_out_i / (W/L)_ref · m_factor_ratio）
组成。

**铁律**：要改 M_out 的 (W/L, Vov, Vdsat, gm/Id)，**不能直接动 M_out**——
W/L 决定的是镜像比，盲改 W/L 会让 Iout 偏离 spec。正确做法：

1. 先确定 **整条镜像支路的 Iref / Iout 比 (M_ratio)**（spec 决定，不可变）
2. 改 **M_ref 的 (W, L)** 调到目标 Vov / Vdsat
3. M_out 的 (W, L) **跟随 M_ref 改**（保持 M_ratio 不变）—— W_out = W_ref ·
   M_ratio，L_out = L_ref（一般 L 不动）

**反例**（v9 实证 LLM 易犯）：直接改 M_out 的 W → Iout 跟着变 → 上层电路
（如 cascode bias 链）整条偏置漂移 → 弄崩别的 device。

## Sizing TB Template — 单管查 W/L

当不知道某 NMOS / PMOS（含 reference 管）该取多少 (W, L) 才能在某 (Id, Vov)
工作点时，搭单管 TB 实测：

```spice
* tb_single_nmos_size.sp
.include "<pdk_path>/vpdk180nm.lib"

V_DD vdd 0 1.8
V_DS d  0 0.5            $ target Vds (set to expected operating Vds)
V_GS g  0 0.7            $ sweep this
V_BS b  0 0              $ Vbs = 0 (NMOS source-bulk-tied)

X1 d g 0 b nch_18 W=10u L=0.18u m=1

.dc V_GS 0.4 1.2 0.01
.print dc V(d) V(g) I(V_DS) @m.x1.m1[gm] @m.x1.m1[gds] @m.x1.m1[vth] @m.x1.m1[vdsat]
.end
```

**用法**：
- 设 V_DS 为目标 Vds（不是 Vdsat！Vdsat 是结果，不是输入）
- sweep V_GS 找让 Id 命中 target 的 Vgs
- 读 .op 得到对应 W 下的 (gm, gds, Vth, Vdsat) → 反算 W 取多少满足 (Id,
  Vov) 双约束
- PMOS 把 nch_18 换 pch_18，rails 对调

LLM 自己 read 这个模板 → 改 W / target_Id / Vds / model 三处即可，不需要
从零写 SPICE。

## Worked Example — 一个 50µA, gm/Id=10 的 NMOS reference 管

**Spec**：
- Iref = 50 µA
- target gm/Id = 10 → Vov ≈ 0.2 V（gm/Id ≈ 2/Vov 弱反型估算 / 中反型实测）
- target Vds = 0.4 V（留 Vdsat 0.2 V + 200mV 裕度）
- L = 0.18 µm（最小）

**Derivation**：
1. spec → (Id=50µA, gm/Id=10) → Vov ≈ 0.2 V
2. (Id, Vov) → 查 vpdk180nm gm/Id 表：W/L ≈ 25:1 @ Vov=0.2V, Id=50µA → W ≈ 4.5 µm
3. KVL chain: Vds_M_ref = Vgs_M_ref（diode-connected）≈ Vth + Vov ≈ 0.5 V
   ✓ > Vdsat=0.2V，margin = 0.3V，OK
4. Cross-check: 跑上面单管 TB 验证 W=4.5µm, V_DS=0.5V 时 Id 是否 ≈ 50µA、
   Vdsat 是否 ≈ 0.2V

**Output 管**：
- 假设需要 Iout = 100µA（mirror ratio = 2:1）
- W_out = W_ref · 2 = 9 µm；L_out = L_ref = 0.18 µm；m_out = 1（或 W_out=W_ref
  / m_out=2 都行，选哪种取决于 layout matching 要求）

**Cross-check**：
- Iout / Iref = (W_out/L_out · m_out) / (W_ref/L_ref · m_ref) = 2 ✓
- M_out Vds 由下游负载决定（如接 cascode 上管 source）→ KVL 链反推
  确认 Vds > Vdsat

## Cross-references

- L0 Sizing Framework Step 4（R2 铁律源头）
- `<base-cells>/cascode/sizing-reasoning.md`（如果 mirror 接 cascode 上面）
- `<base-cells>/bias-generator/sizing-reasoning.md`（mirror 是 bias-tree
  的核心结构）
