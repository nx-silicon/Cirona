---
chapter: architecture
parent: three-stage-ota
summary: |
  Three-stage opamp 拓扑细节（Stage1 5T + Stage2 NMOS-CS + Stage3 PMOS-CS +
  Nested Miller Compensation NMC）+ variants 文字描述（NMC / MNMC / NGCC /
  Active feedback）+ 与其他 OTA 4D 对比（gain ceiling 突破 100 dB）+ 适用场景。
tokens: ~1300
prerequisite_chapters: []
related_knowledge:
  - blocks/5t-ota
  - blocks/two-stage-ota
  - blocks/base-cells/common-source
  - blocks/base-cells/miller-compensation
---

# Three-Stage Opamp Architecture

## 拓扑本质

**Three-stage opamp = 3 个 high-gain 级联 + Nested Miller Compensation 突破单 / 双级 gain ceiling**。

物理本质：
1. **Stage1**：差分输入级（5T 或 cascode），gain 30-40 dB
2. **Stage2**：单管 CS 放大级（反相），gain 30-40 dB
3. **Stage3**：单管 CS 输出级（反相，rail-to-rail），gain 20-30 dB
4. **NMC（Nested Miller Compensation）**：2 个 Miller cap + 2 个 nulling Rc
   控制 3 个极点位置 → loop stability

```
3-stage 数学模型：
  total_gain = gm_stage1 · ro_stage1 × gm_stage2 · ro_stage2 × gm_stage3 · ro_stage3
            ≈ 100-130 dB（3 × 35 dB 典型）

3 个原始极点（无补偿）：
  f_p1 (stage1 输出节点)
  f_p2 (stage2 输出节点)
  f_p3 (stage3 输出节点 = vout)
  → 3 个独立 RC 极点，loop 经过 -180° 时 gain > 0 dB → 必振荡

NMC 补偿后：
  f_p1' = dominant pole（被 Cc1 推到 ~kHz）
  f_p2' = secondary pole（被 Cc2 推高，仍 < f_p3）
  f_p3' = high freq pole
  → pole splitting × 2，PM > 60° 可达
```

**关键约束**：
- **Gain ceiling 突破**：3-stage 是 OPAMP 唯一能稳定到 100+ dB 的拓扑（gain-boosted 2-stage 复杂度同量级）
- **NMC 复杂度**：2 个 Miller cap + 2 个 nulling Rc 互相耦合，sizing 难度远大于 2-stage
- **GBW 受限**：Cc1 主导 GBW = gm_stage1 / Cc1，Cc1 大于 2-stage Cc → 3-stage GBW 通常 < 30 MHz

## Standard variant（V4 reference: NMOS-input + NMC）

```
Stage 1: 5T NMOS-input + PMOS mirror load (5T-style)
  - MN1, MN2 (NMOS diff pair, S=ntail)
  - MP1 (diode), MP2 (mirror) (PMOS load)
  - MN_tail (NMOS, G=vbias_n)
  - L_diff = 2 µm 长 L 提 ro

Stage 2: NMOS-CS + PMOS current-source load (反相)
  - MN3 (NMOS-CS, G=v1_out, S=vss, D=v2_out)
  - MP3 (PMOS load, G=vbias_p, S=vdd, D=v2_out)

Stage 3: PMOS-CS + NMOS current-source load (反相，rail-to-rail 输出)
  - MP4 (PMOS-CS, G=v2_out, S=vdd, D=vout)
  - MN4 (NMOS load, G=vbias_n, S=vss, D=vout)
  - L=Lmin（drive + speed 双优先）

Bias chain: NMOS diode → PMOS diode（共 vbias_n + vbias_p 两节点）
  - MN_bias diode → vbias_n
  - MN_bias2 (G=vbias_n) → vbias_p mid
  - MP_bias diode → vbias_p

Compensation: NMC（2 Cc/Rz pairs）
  - Cc1 + Rc1: outer Miller (跨 stage 2+3, v1_out ↔ vout via Rc1↔vout)
  - Cc2 + Rc2: inner Miller (跨 stage3, v2_out ↔ vout via Rc2↔vout)
```

V4 `reference-design.md` 提供此 13 MOSFET 完整网表。**新设计先 load reference**——
NMC 补偿网络复杂，hand-wire 几乎必踩 trap。

## Variants（从 reference 怎么改）

### Variant 1: MNMC（Multipath Nested Miller Compensation）

适用：低功耗 + 高 GBW（NMC 限 GBW 时升级）。

**怎么改 reference**：
- 加 feed-forward path（input 直接耦合到 stage3）
- 或加 inner feedforward stage（stage1 → stage3 直接路径）
- 减少有效相位累积 → GBW 可提升 2-3×

物理对照：
- GBW ↑↑（30 → 100 MHz 量级）
- 复杂度 ↑（多极点 + 多 zero）
- 适合高速 LDO + audio op-amp

### Variant 2: NGCC（Nested Gm-C Compensation）

适用：低 power 设计（NMC 大 Cc 占面积 + 大 GBW 牺牲 power）。

**怎么改 reference**：
- 把 NMC 的 Cc + Rc 改为 gm-C tow-thomas 结构
- 用 OTA-based 补偿替代 passive Cc/Rc

物理对照：
- 面积小（无大 cap）
- 复杂度 ↑（额外 OTA）
- power 收益视设计决定

### Variant 3: Active Feedback Compensation

适用：极致高速 + 大 CL drive（class-AB 类应用）。

**怎么改 reference**：
- Cc + Rc 替换为 active feedback amplifier（小 OTA）
- Active feedback 让有效 gm 提升

物理对照：
- GBW 与 NMC 类似但 sizing margin 大
- 复杂度高（额外 OTA + matching）

### Variant 4: Stage1 升级 cascode（提 gain 上限）

**怎么改 reference**：
- Stage1 5T → FC-OTA 或 telescopic cascode
- gain 单级 30-40 → 60-80 dB
- 总 gain 130-150 dB（顶级 instrumentation amp）

物理对照：
- gain ↑↑↑
- power ↑（cascode bias chain）
- 复杂度 ↑↑（cascode + NMC 复合）

## 4D Trade-off：Three-Stage vs 其他 OTA

| 维度 | 5T | FC | Tele | 2-stage | Class-AB | **Three-Stage** |
|---|---|---|---|---|---|---|
| **Gain** | 40-55 | 60-80 | 60-80 | 80-100 | 65-80 | **100-130 dB** ⭐ |
| **GBW** | 1-50 MHz | 30-100 | 30-120 | 10-50 | 10-30 | **5-30 MHz**（NMC 限）|
| **PM** | 易 | 中 | 中 | 难 | 难 | **最难**（3 极点 + 2 Cc/Rz）|
| **Power** | 低 | 中-高 | 中 | 较高 | 中 | **高**（300-1000+ µW）|
| **Swing** | ≈1V | 0.6-0.8V | 0.4-0.6V | ≈1.6V | rail-rail | **≈1.6V**（stage3 单管）|
| **Max output I** | µA | µA | µA | mA | mA-10mA | **mA**（stage3 大 m）|
| **复杂度** | 最简单 | 中-高 | 中 | 复杂 | 最复杂 | **最复杂**（13 MOSFET + 2 Cc/Rz NMC）|
| **典型适用** | buffer | LDO EA | ADC | LDO EA | 大 drive | **超高 gain LDO / instrumentation** |

> **3-stage vs 2-stage**：
> - **2-stage**：gain 80-100 dB / GBW 50 MHz / PM 容易
> - **3-stage**：gain 100-130 dB / GBW 30 MHz（NMC 限）/ PM 难
> - **何时升 3-stage**：gain 要求 > 100 dB 时（典型严苛 LDO + instrumentation）

## When to use Three-Stage Opamp

- ✅ Gain ≥ 100 dB（2-stage 物理上限 ~100 dB）
- ✅ 严苛 LDO loop gain（line reg < 0.1% / load reg < 1 mV）
- ✅ Precision instrumentation amp（CMRR > 100 dB）
- ✅ 高精度 ADC reference buffer（≥ 14-bit）
- ✅ Driving 大 CL + 高 gain（2-stage 不够）

## When NOT to use Three-Stage Opamp

- ❌ Gain < 80 dB → 2-stage 简单
- ❌ 高速 (GBW > 50 MHz) → NMC 限速；用 active feedback variant 或 2-stage cascode
- ❌ Power-tight (< 200 µW) → 3-stage 至少 300 µW（3 个 stage 都需 quiescent 电流）
- ❌ 低噪 → 3 stage thermal noise 累加（input-referred 主导但 stage2/3 也贡献）
- ❌ 简单应用（buffer / 数字接口）→ 5T-OTA 简单太多
- ❌ 大 drive but gain < 100 dB → class-AB 2-stage 更适合

## Related

- 6 OTA 拓扑详细对比：`blocks/5t-ota/architecture` / `folded-cascode-ota` / `telescopic-ota` / `two-stage-ota` / `class-ab-ota`
- Class-A 2-stage 对照（升级到 3-stage 的物理增量）：`blocks/two-stage-ota`
- Stage2 / Stage3 CS 物理：`blocks/base-cells/common-source`
- Miller 补偿单级数学：`blocks/base-cells/miller-compensation`
- NMC 补偿物理（pole splitting × 2 + RHP zero × 2 + nulling Rc 双消） → `ac-stability.md` ⭐ 灵魂章
- 设计推进顺序（4 stage sizing 互锁） → `sizing-typical.md`
