---
chapter: architecture
parent: class-ab-ota
summary: |
  Class-AB OTA 拓扑细节（Stage1 5T + Stage2 class-AB push-pull + floating
  bias generator + Miller compensation）+ variants 文字描述（Monticelli /
  current-mirror class-AB / FVF / 简化 source-follower）+ 与其他 OTA 4D
  对比（output drive + slew rate + rail-to-rail）+ 适用场景。
tokens: ~1300
prerequisite_chapters: []
related_knowledge:
  - blocks/5t-ota
  - blocks/two-stage-ota
  - blocks/base-cells/output-stage
  - blocks/base-cells/miller-compensation
---

# Class-AB OTA Architecture

## 拓扑本质

**Class-AB OTA = Stage1 高 gain 差分放大 + Stage2 push-pull 输出级（动态 IQ）**。

物理本质：
1. **Stage1（5T 或 cascode）**：差分输入 → 高 gain 输出 v1_out（与 class-A 2-stage 同）
2. **Stage2 关键差异**：把 class-A CS（单管 + 电流源 load）换成 **push-pull 双管**
   - **MP_ab_out** (PMOS pull-up)：source vout 大电流（信号高时）
   - **MN_ab_out** (NMOS pull-down)：sink vout 大电流（信号低时）
   - 两管由 floating bias 控制，**静态时都微导通（quiescent IQ）**
3. **Floating bias 三件套**：决定 VGP - VGN 差值 → 决定 IQ
   - vmid_p_ab / vmid_n_ab：stacked diode 生成参考电压
   - MP_ab_mid / MN_ab_mid：让 VGP / VGN 跟随 v1_out 信号 + 维持 floating bias 差

```
Class-AB 数学模型：
  IQ_quiescent = kp · (VGP - VDD - Vth_p)² / 2 = kn · (VGN - Vth_n)² / 2
  
  动态信号 v1_out 摆 → VGP / VGN 同步摆动（差值锁定）：
    v1_out ↑ → VGP ↓（PMOS source follower）+ VGN ↓
    → MP_ab_out 推大电流 sourcing；MN_ab_out 接近 cutoff
    → vout ↑（rail-to-rail capable）

  反向：v1_out ↓ → VGP ↑ + VGN ↑ → MN_ab_out 大电流 sinking → vout ↓
```

**关键约束**：
- **Quiescent current control**：IQ_AB 由 floating bias 之差精确锁定，PVT 跟踪好
- **Output stage gain**：大电流瞬间 push-pull 推挽放大；类似 g_m × Rout 但 g_m 是 PMOS+NMOS 并联（动态值）
- **Crossover region**：信号过零附近 PMOS 和 NMOS 都微导通（不是完全 off → 无 dead zone，是 class-AB 与 class-B 关键差异）

## Standard variant（V4 reference: NMOS-input + Miller）

```
Stage 1: 5T NMOS-input + PMOS mirror load (5T)
  - MN1, MN2 (NMOS diff pair, S=ntail)
  - MP1 (diode), MP2 (mirror) (PMOS load)
  - MN_tail (NMOS, G=vbias_n shared)

Stage 2: Class-AB push-pull (~14 MOSFET)
  - 4 个 floating bias 管：MP_ab_bias1/2 + MN_ab_bias2/3 (mirror chain)
  - 4 个 vmid 管：MP_ab_mid_top/bot + MN_ab_mid_top/bot (stacked diode pairs)
  - 2 个 mid driver：MP_ab_mid + MN_ab_mid (floating between VGP and VGN)
  - 2 个 input：MP_ab_src (G=v1_out, source follower) + MN_ab_src (G=vbias_n, fixed)
  - 2 个 output：MP_ab_out (pull-up, m=10) + MN_ab_out (pull-down, m=10)

Bias chain：
  - R_connect (10Ω, ibias→vbias_n) + MN_bias (NMOS diode) → vbias_n
  - vbias_n 跨 stage 共享：stage1 tail + stage2 NMOS mirror 全用

Compensation: Cc + Rz Miller (vrc_mid ↔ v1_out)
```

V4 `reference-design.md` 提供此 22 MOSFET 完整网表。**新设计先 load reference**——
floating bias + push-pull 接错几乎不可避免（V3 实战教训）。

## Variants（从 reference 怎么改）

### Variant 1: Monticelli class-AB（最经典 / 教材风格）

适用：教学 + 简化 + 不强求最优 IQ control。

**怎么改 reference**：
- 简化 floating bias：去掉 vmid_p_ab / vmid_n_ab 双 stacked diode generator
- 直接 floating cap (C_float) + 两 diode 串联 between VGP and VGN
- 2 个 floating R 给两 output gate 提供 pull
- 总 device 减半（~10 MOSFET）

物理对照：
- IQ control 精度 ↓（PVT 漂大 30-50%）
- 拓扑简单，layout area ↓
- 适合 < 1 mA output drive；> 1 mA 时优势消失

### Variant 2: Current-mirror class-AB（Folded class-AB）

适用：低 VDD（< 1.0V）+ 需要保留 Stage1 cascode 提 gain。

**怎么改 reference**：
- Stage1 改 FC-OTA（folded cascode）→ gain 70-80 dB
- Stage2 用 current-mirror（不是直接 voltage-driven）：
  - input current 通过 mirror 翻倍到 output devices
  - 没有 floating bias 链，靠 mirror ratio 锁 IQ

物理对照：
- gain ↑↑（Stage1 + Stage2 = 90-110 dB）
- VDD 下限 < 1.0V（cascode + mirror 都可低压）
- 复杂度 ↑（output devices 还要 cascode 保 ro）
- power ↑（mirror branch 多）

### Variant 3: FVF class-AB（Flipped Voltage Follower）

适用：极致 slew rate（≥ 50 V/µs）+ 高速 LDO output stage。

**怎么改 reference**：
- Stage2 用 FVF（Flipped Voltage Follower）replace push-pull
- FVF：local feedback loop 让 output Vds 几乎不变 → 输出阻抗超低（< 1Ω）

物理对照：
- output drive 极强（mA 级 sourcing/sinking）
- slew rate 极高（local loop 自适应 drive）
- gain ↓（FVF 是 buffer 不是 amp）→ 总 gain 主要由 stage1 决定
- 复杂度 ↑（local feedback 设计 + stability）

### Variant 4: Simplified source-follower class-AB

适用：极简 / unity-gain buffer / IO 驱动。

**怎么改 reference**：
- 去掉 floating bias 完全
- Output 用 PMOS / NMOS source follower 直接 driven by v1_out
- 静态 IQ 由 stage1 输出阻抗 + load 决定（不是 floating bias）

物理对照：
- gain ↓↓（buffer 接近 1）
- IQ control 不精确
- 极简，常见 IO buffer

## 4D Trade-off：Class-AB OTA vs 其他 OTA

| 维度 | 5T | FC | Tele | 2-stage class-A | **Class-AB** |
|---|---|---|---|---|---|
| **Gain** | 40-55 dB | 60-80 dB | 60-80 dB | 80-100 dB | **65-80 dB**（stage1 + class-AB output 不像 class-A 输出 stage 提 gain）|
| **GBW** | 1-50 MHz | 30-100 MHz | 30-120 MHz | 10-50 MHz | **10-30 MHz**（Cc / output cap 大限）|
| **PM** | 易 | 中 | 中 | 难（Miller）| **难**（class-AB 输出 cap 大 + nonlinear pole）|
| **Power**（quiescent）| 低 | 中-高 | 中 | 较高 | **中**（IQ 100-200µA 含 stage1 + AB quiescent）|
| **Swing** | ≈ 1.0V | 0.6-0.8V | 0.4-0.6V | ≈ 1.6V | **≈ 1.6V (rail-to-rail)** |
| **Max output current** ⭐ | µA-100µA | µA | µA | mA（class-A，limited by I_stage2）| **mA-10mA**（class-AB push-pull 大 m）⭐ |
| **Slew rate** ⭐ | gm/CL（低）| I_branch/CL | I_branch/CL | I_stage2/CL | **dynamic >> I_quiescent/CL**（动态电流远超静态）⭐ |
| **复杂度** | 最简单 | 中-高 | 中 | 复杂 | **最复杂**（22 MOSFET + floating bias）|
| **典型适用** | 简单 buffer | LDO EA | ADC | LDO EA / rail-rail | **大电流 driver / headphone / LDO output / 大 CL** |

> **Class-AB 与 class-A 2-stage 关键差异**：
> - **Class-A 2-stage**：output stage I_stage2 静态电流恒定（~100-500 µA），slew rate 受限（SR ≤ I_stage2 / CL）；max output current ≤ I_stage2
> - **Class-AB**：静态电流低（~ 50-100 µA），但 **动态电流可远超静态**（push-pull 一边推大电流，另一边 cutoff）→ 同样 quiescent power 下 SR + max drive 大幅提升

## When to use Class-AB OTA

- ✅ Driving 大电容负载（CL ≥ 5 pF）+ slew rate spec
- ✅ 大输出电流 (≥ 1 mA) — class-A 静态电流过大 / class-AB 动态电流推满
- ✅ Rail-to-rail output (vout swing > VDD - 0.4V)
- ✅ Battery-powered (低静态功耗 + 大动态 drive)
- ✅ Audio / headphone driver / line driver / LDO output stage
- ✅ Driving 大 CL 但 power-tight（class-A 不行）

## When NOT to use Class-AB OTA

- ❌ Low gain (< 60 dB) → 5T-OTA 简单太多
- ❌ High gain (> 90 dB) + 不需大 drive → 2-stage class-A 简单
- ❌ 高速 GBW > 50 MHz → class-AB output cap 大限速度
- ❌ 低噪声 (input-referred noise < 5 nV/√Hz) → output stage thermal noise 大
- ❌ Power-tight < 50 µA → IQ_AB ≥ 50 µA (crossover 控制下限)
- ❌ 高线性度 (THD < -80 dB @ Nyquist) → AB-class crossover 引入小非线性

## Related

- 5 OTA 拓扑详细对比：`blocks/5t-ota/architecture` / `folded-cascode-ota` / `telescopic-ota` / `two-stage-ota`
- Class-A 2-stage 对照：`blocks/two-stage-ota`（class-A CS output → 替换为 class-AB push-pull）
- Output stage 物理：`blocks/base-cells/output-stage`（class-A vs class-AB vs class-B）
- Miller 补偿：`blocks/base-cells/miller-compensation`
- Floating bias + crossover 详细物理 → `bias-headroom.md` ⭐ 灵魂章
- 设计推进顺序 → `sizing-typical.md`
