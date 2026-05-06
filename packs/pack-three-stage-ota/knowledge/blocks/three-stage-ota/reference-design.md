---
chapter: reference-design
parent: three-stage-ota
summary: |
  Production-grade three-stage opamp reference (Stage1 5T NMOS-input + Stage2
  NMOS-CS + Stage3 PMOS-CS output + Nested Miller Compensation 2 Cc/Rz pairs)
  + standard cir/tb 路径 + sizing 起点 + NMC connectivity 陷阱。Iron Law:
  写 3-stage 必先复用 reference cir，**NMC 补偿网络接错必崩**（2 个 Miller
  cap 跨级位置 / Rz 极性都可错）。
tokens: ~1500
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
  - circuit-method/ac-feedback-loop-method
related_knowledge:
  - blocks/base-cells/miller-compensation
  - blocks/two-stage-ota
  - blocks/5t-ota
---

# Three-Stage Opamp Reference Design

## Iron Law

**Reference design 优先**：写 three-stage opamp 时**必须**先复用本章 § Core
topology 的 inline `.subckt`（13 MOSFET self-contained，包括 bias chain）。
**从零造 3-stage 几乎必踩**：
1. **Nested Miller cap 跨级位置接错** → pole splitting 失效 → 振荡
2. **Nulling Rc 极性接错（应在 vout 一端，不是 stage 输出端）** → RHP zero 不消
3. **Stage 反相极性叠加错** → loop sign 错 → DC latch
4. **Stage1 vbias_n 跨 stage 共享但 W/L 不匹配** → mirror ratio 错

> **3-stage 关键差异 vs 2-stage**：3 stage 串联 → 3 个极点 → loop 经过 -180°
> 时如不补偿必振荡。**NMC（Nested Miller Compensation）三件套**：Cc1（跨
> stage2+3）+ Cc2（跨 stage3）+ Rc1/Rc2 nulling，必须组合配。

## Quick reference

```
Canonical .cir         : 本章 § Core topology（inline subckt，~80 行）
DC OP testbench        : 本章 § tb_dc_op.sp 模板
AC gain/GBW/PM tb      : 本章 § tb_ac_gain_bw.sp 模板（Method C 断环）
Slew + tran tb         : 本章 § tb_slew.sp 模板
Loop AC（详细 PM）tb   : 本章 § tb_loop_ac.sp 模板
```

## Standard subckt port order

```spice
.subckt three_stage_opamp vinp vinn vout ibias vdd vss
```

## Core topology — Stage1 5T + Stage2 NMOS-CS + Stage3 PMOS-CS + NMC (13 MOSFET)

```
Stage 1 (5T NMOS-input)            Stage 2 (NMOS-CS)        Stage 3 (PMOS-CS output)
─────────────────────────         ──────────────────       ─────────────────────────
                VDD                       VDD                       VDD
                 │                         │                         │
                ┌┴┐                       ┌┴┐                       ┌┴┐
              MP1 MP2                   MP3                        MP4 (output)
              (mirror)                (vbias_p)                   G=v2_out, m=20
              S=vdd  S=vdd            S=vdd                       S=vdd
              G=v1_n G=v1_n           G=vbias_p                   D=vout
              D=v1_n D=v1_out         D=v2_out                     │
                │     │                  │                       vout ← OUTPUT
              MN1   MN2                  │                         │
              G=vinp G=vinn              MN3                       MN4 (output sink)
              S=ntail S=ntail            G=v1_out (stage2 input)   G=vbias_n
              D=v1_n D=v1_out            S=vss                     S=vss
                  │                       D=v2_out                  D=vout
              MN_tail                     │                         │
              S=vss, G=vbias_n          v2_out                    vss
              D=ntail                     │
                  │
                vss

Bias chain (NMOS + PMOS diode trio):
  R_p1 ibias↔vbias_n (open R, soft connect)
  MN_bias  diode (D=G=vbias_n, S=vss) → 给 stage1 tail + stage3 sink (MN4)
  MN_bias2 D=vbias_p, G=vbias_n, S=vss → 拉 vbias_p 节点
  MP_bias  diode (D=G=vbias_p, S=vdd) → 给 stage2 load (MP3)

NMC compensation (2 Cc/Rz pairs):
  Cc1 v1_out ↔ vout_comp1
  Rc1 vout ↔ vout_comp1     ← Rc1 必须接 vout（不是 stage1 输出端）
  Cc2 v2_out ↔ vout_comp2
  Rc2 vout ↔ vout_comp2     ← Rc2 必须接 vout（不是 stage2 输出端）

→ 等效：Cc1 跨 (stage 2+3)；Cc2 跨 stage3 单级
```

**3-stage 工作原理 + 反相极性**：
1. **Stage1**：差分非反相 → v1_out（vinp ↑ → v1_out ↑）
2. **Stage2 (NMOS-CS)**：反相 → v2_out（v1_out ↑ → MN3.Vgs ↑ → MN3 sinks
   more → v2_out ↓，反相）
3. **Stage3 (PMOS-CS)**：反相 → vout（v2_out ↓ → MP4.Vsg ↑ → MP4 sources
   more → vout ↑，反相）
4. **总极性**：vinp ↑ → vout ↑ (3 stages: + → − → −  =  +)
   - 总 sign 是 non-inverting at vinp port → 但 negative feedback 需要 vout 接 vinn 端
   - 网表使用：vinn 接 negative feedback；vinp 接 input

**关键 connectivity rules**（NMC 补偿失败模式 codify）：

| 部位 | 关键正确性 |
|---|---|
| Stage1 mirror | MP1.D=G=v1_n diode；MP2.G=v1_n mirror slave；MN1/2 G=vinp/vinn, S=ntail |
| Stage1 tail | MN_tail.G=vbias_n (mirror MN_bias) |
| Stage2 CS | **MN3.G=v1_out**（stage1 真高 gain 输出，**不是 v1_n!**）；MP3.G=vbias_p |
| Stage3 PMOS-CS | **MP4.G=v2_out**；MN4.G=vbias_n（电流源 sink）|
| Bias chain N→P | MN_bias diode → MN_bias2 (G=vbias_n) → MP_bias diode（V→V conversion）|
| **NMC Cc1** | Cc1: v1_out ↔ vout_comp1（intermediate node）|
| **NMC Rc1** | **Rc1: vout ↔ vout_comp1**（一端必须 vout，不是 v1_out 端！）|
| **NMC Cc2** | Cc2: v2_out ↔ vout_comp2 |
| **NMC Rc2** | **Rc2: vout ↔ vout_comp2** |

> ⚠️ **NMC nulling resistor 接法**：每个 nulling Rc 都必须**一端接 vout**
> （不是各 stage 输出端）—— 这样 Rc 与 Cc 串联后形成"Cc 在 input side, Rc
> 在 output side"的 pole-zero cancellation 拓扑。接错让 RHP zero 不消 → PM 崩。

## NMC 补偿物理（**3-stage 灵魂**）

```
3 个未补偿主极点：
  f_p1 = 1/(2π·R_stage1·C_stage1) ≈ 100 kHz - 1 MHz
  f_p2 = 1/(2π·R_stage2·C_stage2) ≈ 1 - 10 MHz
  f_p3 = 1/(2π·R_stage3·CL) ≈ 1 - 100 MHz

加 NMC 后：
  Cc1 让 stage1 输出有效 cap 翻倍 (1+|A_stage2·A_stage3|) → f_p1 推到 ~kHz
  Cc2 让 stage2 输出有效 cap 翻倍 (1+|A_stage3|) → f_p2 推到 ~MHz 但远高于 f_p1
  f_p3 推到更高 (gm_stage3/(CL))

→ pole 分开成 dominant + 2 secondary 极点

GBW = gm_stage1 / Cc1
PM > 60° 要 f_p2' / GBW > 3 (类似 2-stage Miller)，并且 f_p3' 更高

RHP zero（每个 stage 都有）：
  zero_1 = gm_stage_combined / Cc1，用 Rc1 = 1/gm_stage_combined 消除
  zero_2 = gm_stage3 / Cc2，用 Rc2 = 1/gm_stage3 消除
```

> 详细 PM 推导见 `ac-stability.md`。

## Sizing 起点 (vpdk180nm, VDD=1.8V, ibias=20µA, CL=5pF)

| 设备 | role | W | L | m | gm/Id | Vov | 关键约束 |
|---|---|---|---|---|---|---|---|
| **Stage 1 (5T)** | | | | | | | |
| MN1 / MN2 | NMOS diff pair | 50 µm | 2 µm | 4 | ~12 | 0.15 V | **L=2µm** 长 L 提 ro |
| MP1 / MP2 | PMOS mirror load | 25 µm | 2 µm | 2 | ~10 | 0.20 V | gain 优先 |
| MN_tail | NMOS tail | 50 µm | 4 µm | 4 | ~10 | 0.20 V | I_tail = 80 µA |
| **Stage 2 (NMOS-CS)** | | | | | | | |
| MN3 | NMOS-CS | 80 µm | 1 µm | 8 | ~10 | 0.18 V | gm 大 + ro 中等 |
| MP3 | PMOS load (current source) | 40 µm | 1 µm | 4 | ~10 | 0.20 V | I_stage2 = 80 µA |
| **Stage 3 (PMOS-CS, 输出级)** | | | | | | | |
| **MP4** | **PMOS-CS output** | 200 µm | **0.5 µm** | **m=20** | ~10 | 0.20 V | rail-to-rail sourcing；大电流驱动 |
| **MN4** | **NMOS sink (current source)** | 100 µm | **0.5 µm** | **m=10** | ~10 | 0.20 V | I_stage3 = 200 µA |
| **Bias chain** | | | | | | | |
| MN_bias | NMOS diode (vbias_n)| 25 µm | 4 µm | 2 | — | — | 跨 stage 共享 |
| MN_bias2 | NMOS mirror | 25 µm | 4 µm | 2 | — | — | 拉 vbias_p |
| MP_bias | PMOS diode (vbias_p)| 25 µm | 4 µm | 2 | — | — | 给 stage2 load |
| **NMC Compensation** | | | | | | | |
| Cc1 | outer Miller cap (跨 stage 2+3) | 3 pF | — | — | — | — | 主导 pole splitting |
| Rc1 | outer nulling | 3 kΩ | — | — | — | — | Rc1 = 1/gm_stage_combined |
| Cc2 | inner Miller cap (跨 stage3) | 1.5 pF | — | — | — | — | 让 stage2 极点远 |
| Rc2 | inner nulling | 2 kΩ | — | — | — | — | Rc2 = 1/gm_MP4 |

⚠️ **数值标 @vpdk180nm**：换工艺时 µ·Cox / Vth 不同，要重新算。
跨工艺通用：3 stage gain 各 30-40 dB；NMC Cc 起点 Cc1 ≈ 0.5×CL, Cc2 ≈ 0.3×CL；
Rc1 / Rc2 = 1/gm_at_corresponding_stage（实测 gm，不是 sizing 估算）。

## Standard testbench 摘要

### tb_dc_op.sp（DC + 各 stage 静态点）
Vinp/Vinn DC=VCM；Rfb=1G + Cfb=1F；`.op` 后 print v(x1.v1_out) v(x1.v2_out)
v(x1.vbias_n) v(x1.vbias_p)；期望 v1_out ≈ VDD/2、v2_out ≈ VDD/2、vout ≈ VCM。

### tb_ac_gain_bw.sp（Method C 断环 AC，CL=5pF）
期望 gain ≥ 100 dB / GBW 5-15 MHz / PM ≥ 50°。

### tb_loop_ac.sp（loop AC + 详细 PM 分析）
3-stage 极点多，需 dec 200 细扫看 phase 形状（不只单点 PM）。

### tb_slew.sp（slew rate 验证）
大信号 step 看 SR + ringing；3-stage NMC 调好不应 ringing。

## 已知设计陷阱（NMC 特有 + V3 实战）

| 陷阱 | 表现 | 修复 |
|---|---|---|
| **NMC Rc 接错（Rc 一端不是 vout）**| RHP zero 不消 → PM 崩 | Rc1: vout↔vout_comp1；Rc2: vout↔vout_comp2 |
| **Cc 跨级错（Cc1 不是 v1_out↔vout）**| pole splitting 失效 | Cc1 两端 = stage1 输出 ↔ output；Cc2 = stage2 输出 ↔ output |
| Stage 反相极性叠加错 | DC latch / 振荡 | 算 loop sign：3-stage NMOS-CS+PMOS-CS = 反+反=正；feedback 正确接 vinn |
| Stage1 mirror typo | v1_out 跑 rail / loop 失锁 | MP1.G=D=v1_n diode；MP2.G=v1_n mirror |
| Stage2/3 偏置 vbias_p/n 跨 stage 共享但 W/L 不匹配 | mirror ratio 错 | bias chain 严格 W/L 同步（m 不同 OK）|
| Cc 太大或太小 | PM 紧或 BW 严重缩水 | Cc1 ≈ 0.5×CL；Cc2 ≈ 0.3×CL 起点 |
| Rc 偏离 1/gm | RHP zero 不完全消 | 实测 gm 后微调 Rc |
| 3 stage gain 分配不均（一级太低）| 总 gain < spec | 每 stage 30-40 dB 起点；某 stage L 短 → 增 L |
| AC vp() 当度数 → PM 错 57× | PM 178° 实际 3° | testbench `set units = degrees` |

## When to use this reference

- ✅ Gain ≥ 100 dB（2-stage 物理上限 ~100 dB，3-stage 突破到 110-130 dB）
- ✅ Driving 大 CL（≥ 10 pF）+ 高 gain（2-stage Miller 不够）
- ✅ 严苛 LDO（loop gain ≥ 100 dB / line reg < 0.1%）
- ✅ Precision instrumentation amp（高 gain 主导）
- ✅ Audio amp（高 gain + rail-to-rail）

## When NOT to use

- ❌ Gain < 80 dB → 2-stage 简单太多
- ❌ 高速 GBW > 30 MHz → NMC 补偿严重限速
- ❌ Power-tight (< 200 µW) → 3-stage 至少 300 µW
- ❌ 低 noise spec → 3 stage thermal noise 累加
- ❌ 数字混合信号 SoC (面积代价高) → 2-stage 通常够用

## 不在本章范围

- **NMC 补偿物理推导（pole splitting × 2 / RHP zero × 2 / Rc nulling 双消）** → `ac-stability.md` ⭐
- **跨级耦合 + bias 链 sizing** → `sizing-typical.md`
- **拓扑选型（NMC vs MNMC vs NGCC vs active feedback）** → `architecture.md`
- **失败模式（gain 低 / PM 紧 / DC latch）** → `troubleshooting.md`
- **3 stage 各级 5T / CS 内部约束** → `blocks/5t-ota` + `blocks/base-cells/common-source`
- **Miller 补偿单级数学** → `blocks/base-cells/miller-compensation`
