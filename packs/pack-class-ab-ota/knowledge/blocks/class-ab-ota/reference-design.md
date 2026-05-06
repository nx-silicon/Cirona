---
chapter: reference-design
parent: class-ab-ota
summary: |
  Production-grade Class-AB output stage 2-stage opamp reference (Stage1 5T
  NMOS-input + Stage2 class-AB push-pull + floating bias generator + Miller
  compensation Cc/Rz) + standard cir/tb 路径 + sizing 起点 + quiescent-current
  control connectivity 陷阱。Iron Law: 写 class-AB 必先复用 reference cir，
  floating bias 接错必造成 quiescent 失控 + crossover distortion。
tokens: ~1500
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
  - circuit-method/ac-feedback-loop-method
related_knowledge:
  - blocks/base-cells/output-stage
  - blocks/base-cells/miller-compensation
  - blocks/5t-ota
  - blocks/two-stage-ota
---

# Class-AB OTA Reference Design

## Iron Law

**Reference design 优先**：写 class-AB OTA 时**必须**先复用本章 § Core topology
的 inline `.subckt`（22 MOSFET self-contained）。**从零造 class-AB 几乎必踩**：
1. **Floating bias 接错** → quiescent current 失控（10× 偏移）→ 静态功耗超 spec
2. **VGP / VGN 接错（output gate ↔ floating bias node 极性）** → push-pull
   不工作 → 单边输出（degenerated 5T）
3. **Stage1 偏置（vbias_n）跨 stage 共享但 W/L 不匹配** → mirror ratio 错 →
   AB output bias 失配
4. **Miller cap 接错（vrc_mid 应在 v1_out 一端，不是 vout）** → pole splitting
   失效

> **V3 实战教训**（class_ab_opamp v3.0）：22 MOSFET stage2 对内部 4 节点
> （vmid_p_ab / vmid_n_ab / VGP / VGN）必须严格按下方 connectivity rules 接，
> 任一节点接错让 output stage 单边导通或全 off。

## Quick reference

```
Canonical .cir         : 本章 § Core topology（inline subckt，~85 行）
DC OP testbench        : 本章 § tb_dc_op.sp 模板（必查 IQ + VGP/VGN bias）
AC gain/GBW/PM tb      : 本章 § tb_ac_gain_bw.sp 模板（Method C 断环）
Slew rate / large-signal tb : 本章 § tb_slew.sp 模板（class-AB 专用）
Output drive tb        : 本章 § tb_drive.sp 模板（max output current 验证）
```

## Standard subckt port order

```spice
.subckt class_ab_opamp vinp vinn vout ibias vdd vss
```

> ⚠️ class-AB OTA 是 **2-stage opamp**（不是单级 OTA），但 stage2 是 class-AB
> push-pull（不是 class-A CS）。port order 与 2-stage opamp 同。

## Core topology — Stage1 5T + Stage2 class-AB push-pull (22 MOSFET)

完整 ASCII / SPICE netlist 见 V3 模板 `class_ab_opamp.cir` (3.0)。结构概要：

```
Stage 1 (5T)                Stage 2 (Class-AB push-pull)
─────────────────           ─────────────────────────────────────
MN1/MN2  diff pair          Bias gen: MP_ab_bias1/2 (PMOS)
                                      MN_ab_bias2/3 (NMOS, mirror vbias_n)
MP1/MP2  mirror load        vmid gen: MP/N_ab_mid_top + MP/N_ab_mid_bot (4 stacked diodes)
MN_tail  tail switch        Driver:   MP_ab_src (G=v1_out, S=vdd, D=VGP)
                                      MN_ab_src (G=vbias_n, S=vss, D=VGN)
MN_bias  diode + R_connect            MP_ab_mid (G=vmid_p_ab, S=VGP, D=VGN, floating)
   (vbias_n 跨 stage 共享)            MN_ab_mid (G=vmid_n_ab, S=VGN, D=VGP, floating)
                            Output:   MP_ab_out (G=VGP, S=vdd, D=vout, m=10)  ← rail-to-rail sourcing
                                      MN_ab_out (G=VGN, S=vss, D=vout, m=10)  ← rail-to-rail sinking
                            Compensation: Cc_miller (vrc_mid ↔ v1_out, 5pF)
                                          Rc_null   (vout ↔ vrc_mid, 2kΩ)
```

**Class-AB 工作原理**（详见 bias-headroom.md ⭐）：v1_out 通过 MP_ab_src
反相驱动 VGP；vbias_n 固定 VGN；4 个 vmid 管 + middle PMOS/NMOS 锁定
VGP - VGN 之差 → 锁 IQ_quiescent。大信号时一边推大电流，另一边 cutoff（push-pull）。

**关键 connectivity rules**（V3 实战 traps codify）：

| 部位 | 关键正确性 |
|---|---|
| Stage1 mirror | MP1.D=G=v1_n diode；MP2.G=v1_n mirror slave；MN1/2 G=vinp/vinn, S=ntail |
| Stage1 tail | MN_tail.G=vbias_n（mirror MN_bias）；⭐ **vbias_n 跨 stage 共享**：Stage2 的 MN_ab_bias2/3/src 都用 vbias_n |
| **Floating bias 链** | MP_ab_bias1 G=D=pbias (diode)；MP_ab_bias2 G=pbias；MN_ab_bias2/3 G=vbias_n；4 个 vmid stacked diode (D=G)：MP/N_ab_mid_top/bot 形成 vmid_p_ab ≈ VDD - 2·\|Vgs_p\|，vmid_n_ab ≈ 2·Vgs_n |
| **Class-AB middle (floating)** | MP_ab_mid: S=VGP, D=VGN, G=vmid_p_ab；MN_ab_mid: S=VGN, D=VGP, G=vmid_n_ab |
| **Class-AB driver** | MP_ab_src: G=v1_out, S=vdd, D=VGP（⚠️ G 必须接 v1_out 不是 v1_n）；MN_ab_src: G=vbias_n, S=vss, D=VGN |
| **Class-AB output** | MP_ab_out: G=VGP, S=vdd, D=vout (m=10)；MN_ab_out: G=VGN, S=vss, D=vout (m=10) |
| **Miller comp** | Rc_null: vout ↔ vrc_mid；Cc_miller: vrc_mid ↔ v1_out（⚠️ Cc 一端必须 v1_out，不是 vout）|

## Floating bias 物理（**class-AB 灵魂**）

`VGP - VGN ≈ vmid_p_ab - vmid_n_ab` （by 4 floating bias devices）→ 决定
`IQ_quiescent = kp·(VDD-VGP-|Vth_p|)²/2 = kn·(VGN-Vth_n)²/2`，PVT 跟踪好。
完整推导见 `bias-headroom.md` § Quiescent Current Control。

## Sizing 起点 (vpdk180nm, VDD=1.8V, ibias=20µA, CL=5pF)

| 设备 | role | W | L | m | gm/Id | Vov | 关键约束 |
|---|---|---|---|---|---|---|---|
| **Stage 1** | | | | | | | |
| MN1 / MN2 | NMOS diff pair | 40 µm | 1 µm | 4 | ~12 | 0.15 V | gm 主导 + 长 L 提 ro |
| MP1 / MP2 | PMOS mirror load | 20 µm | 1 µm | 2 | ~10 | 0.20 V | μp/μn × W 比例平衡 Id |
| MN_tail | NMOS tail | 40 µm | 2 µm | 4 | ~10 | 0.20 V | I_tail = 4 × ibias = 80 µA |
| MN_bias | NMOS diode (bias ref) | 20 µm | 2 µm | 2 | — | — | 跨 stage 共享 vbias_n |
| R_connect | bias R (ibias→vbias_n) | 10 Ω | — | — | — | — | soft connect |
| **Stage 2 — Bias gen** | | | | | | | |
| MN_ab_bias2 / MN_ab_bias3 | NMOS mirror (vbias_n)| 20 µm | 2 µm | 1 | — | — | 拉 pbias / vmid_p_ab 节点 |
| MP_ab_bias1 / MP_ab_bias2 | PMOS bias gen | 10 µm | 1 µm | 1 | — | — | pbias diode + mirror |
| **Stage 2 — vmid gen** | | | | | | | |
| MN_ab_mid_top / _bot | NMOS stacked diode | 10 / 10 µm | 0.5 / 0.5 µm | 1 / 1 | — | — | 形成 vmid_n_ab ≈ 2×Vgs_n ≈ 1.0V |
| MP_ab_mid_top / _bot | PMOS stacked diode | 10 / 10 µm | 0.5 / 0.5 µm | 1 / 1 | — | — | 形成 vmid_p_ab ≈ VDD - 2×\|Vgs_p\| ≈ 0.8V |
| **Stage 2 — Class-AB driver** | | | | | | | |
| MP_ab_src | PMOS input (G=v1_out)| 10 µm | 1 µm | 2 | ~10 | 0.18 V | source follower，拉 VGP |
| MN_ab_src | NMOS固定 bias (G=vbias_n)| 20 µm | 2 µm | 2 | ~10 | 0.20 V | 固定 VGN 静态点 |
| MP_ab_mid | PMOS middle | 10 µm | 0.5 µm | 1 | ~10 | 0.18 V | floating bias driver |
| MN_ab_mid | NMOS middle | 10 µm | 0.5 µm | 1 | ~10 | 0.18 V | 同上 |
| **Stage 2 — Output (大！)** | | | | | | | |
| MP_ab_out | **PMOS pull-up** | 200 µm | 0.5 µm | **m=10** | ~10 | 0.20 V | rail-to-rail sourcing；m × W 大 |
| MN_ab_out | **NMOS pull-down** | 100 µm | 0.5 µm | **m=10** | ~10 | 0.20 V | rail-to-rail sinking；与 PMOS 比例 ≈ μp/μn = 1/2 |
| **Compensation** | | | | | | | |
| Cc_miller | Miller cap | 5 pF | — | — | — | — | Cc / CL ≈ 1 (large) for class-AB stability |
| Rc_null | nulling Rz | 2 kΩ | — | — | — | — | Rz = 1/gm_MN_ab_out |

⚠️ **数值标 @vpdk180nm**：换工艺时 µ·Cox / Vth 不同，要重新算。
跨工艺通用：output PMOS / NMOS 比例 ≈ μn/μp ≈ 2-3 + Cc / CL ≈ 1（class-AB 比 class-A 2-stage 大）+ floating bias 同密度。

## Standard testbench 关键内容

### tb_dc_op.sp（DC + IQ）
Vinp/Vinn DC=VCM；Rfb=1G + Cfb=1F；`.op` 后 print v(x1.v1_out) v(x1.VGP) v(x1.VGN)
v(x1.vmid_p_ab) v(x1.vmid_n_ab) + abs(@m.x1.mp_ab_out[id]) + abs(@m.x1.mn_ab_out[id])。
期望：v(vout) ≈ VCM；IQ_P ≈ IQ_N ≈ 50-150 µA。

### tb_ac_gain_bw.sp（Method C 断环 AC）
同 2-stage OTA 模板，加 CL=5pF。期望 gain ≥ 65 dB / GBW ≥ 10 MHz / PM ≥ 45°。

### tb_slew.sp（slew rate — class-AB 关键）
Vinp PULSE(VCM-0.3 VCM+0.3) 0.6V step；`.tran 1n 5u`；`.meas tran sr_pos DERIV v(vout)
AT=...`；期望 SR± ≥ 7 V/µs（push-pull 对称）。

### tb_drive.sp（最大输出电流）
强制 Vout PULSE(0.4 1.4)；`.meas tran iout_max max abs(@m.x1.mp_ab_out[id])`；
期望 I_out_max ≥ 5 mA @ vout = VCM - 0.5V。

## 已知设计陷阱（class-AB 特有 + V3 实战）

| 陷阱 | 表现 | 修复 |
|---|---|---|
| **Floating bias 接错**（vmid_p_ab / vmid_n_ab 节点接到错误的 stacked device）| IQ 失控 10× 偏 / 单边导通 | 严格按本章 connectivity rules |
| **VGP / VGN 接错**（output gate 接到错误的 floating node）| push-pull 不工作，输出 single-ended | VGP=MP_ab_out gate；VGN=MN_ab_out gate |
| **vbias_n 跨 stage 共享但 stage2 mirror W/L 不匹配 stage1**| Stage2 IQ 不准 | MN_ab_bias2/3 / MN_ab_src 与 MN_bias 共 W/L（m 不同 OK）|
| **Output PMOS / NMOS 比例错（应 μn/μp ≈ 2）**| crossover distortion 严重（一边强一边弱）| W_MP_out / W_MN_out ≈ 2 |
| **Output L 选大（> 1µm）**| max output current ↓（gm × Vgs 限）| L=Lmin 或 0.5µm（speed + drive 双优先）|
| **Cc 接 vout 而不是 v1_out**| Miller pole splitting 失效 | Cc 跨 stage2: vrc_mid ↔ v1_out |
| **Cc 太小（< 0.25× CL）**| PM < 45° | Cc ≥ 0.5× CL（class-AB output cap 大、parasitic 大 → Cc 比 class-A 大）|
| **Rc 太小（< 1/gm_MN_out）**| RHP zero 主导 → PM 退化 | Rz = 1/gm_MN_out（实测 gm，不是 sizing 估算）|
| AC vp() 当度数 → PM 错 57× | PM 178° 实际 3° | testbench `set units = degrees` |

## When to use this reference

- ✅ Output drives 大 CL (> 5 pF) 或大电流 (> 1 mA) → class-A 2-stage 不够
- ✅ Rail-to-rail output 需求（vout swing > VDD - 0.4V）
- ✅ Slew rate ≥ 5 V/µs + low quiescent power（class-A push-pull 同时实现难）
- ✅ Headphone driver / line driver / LDO output stage（从 OPAMP 角度）

## When NOT to use

- ❌ Low gain (< 60 dB) → 5T-OTA 简单
- ❌ High gain (> 90 dB) + 不需大 drive → 2-stage class-A 简单
- ❌ 高频应用（> 50 MHz GBW）→ class-AB output stage parasitic 大，BW 限
- ❌ 低噪声应用（input-referred noise < 5 nV/√Hz）→ class-AB output 引入 thermal noise
- ❌ 静态功耗 < 50 µW → class-AB IQ ≥ 100 µA（quiescent control 不能太低 → crossover）

## 不在本章范围

- **Class-AB 物理（floating bias / quiescent control / crossover distortion 因果链）** → `bias-headroom.md` ⭐ 灵魂章
- **AC stability + Miller 补偿（Cc / Rz / RHP zero / class-AB 特有非线性极点）** → `ac-stability.md`
- **拓扑选型（Monticelli / current-mirror class-AB / 4 variants）** → `architecture.md`
- **设计推进顺序（stage1 → floating bias → output devices → Miller）** → `sizing-typical.md`
- **失败模式 + cross-corner 退化** → `troubleshooting.md`
- **Stage1 5T 内部约束** → `blocks/5t-ota`
- **Output stage class-AB 物理推导（push-pull operation / dead-zone）** → `blocks/base-cells/output-stage`
- **Miller 补偿 RHP zero / pole splitting 数学推导** → `blocks/base-cells/miller-compensation`
