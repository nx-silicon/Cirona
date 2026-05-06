---
chapter: architecture
parent: two-stage-ota
summary: |
  Two-stage Miller OTA 架构层级化决策（L1 instance）+ Stage1 input pair 极性
  IRON LAW（NMOS floor + PMOS ceiling）+ 拓扑细节（5T-stage1 + CS-stage2 +
  Miller 补偿）+ 4 variants + 与其他 OTA 4D 对比。
  Iron Law: Step 0 必做 Stage1 input pair 极性 self-check（Vcm_in vs CM range
  ceiling/floor），违反 = sub-threshold = gm 损 50-100×。
tokens: ~1300
prerequisite_chapters: []
related_skills:
  - architecture_decomposition
  - circuit-method/device-sizing
related_knowledge:
  - blocks/5t-ota
  - blocks/folded-cascode-ota
  - blocks/base-cells/miller-compensation
  - blocks/base-cells/common-source
  - blocks/base-cells/differential-pair/cm-range
---

# Two-Stage OTA Architecture

## 架构层级化决策（L1 instance）

> **方法论入口**：见 L1 skill `architecture_decomposition`。本章是该方法论在 **Two-Stage OTA 电路族**上的具体 instance。Step 0 必须**逐层** self-check，**任一层违反物理约束** → 必须换该层选择 OR declare hypothesis。

Two-Stage OTA 用层级（顺序自上而下决策）：

| 层 | 决策内容 | spec 物理约束 | 详见 |
|---|---|---|---|
| **L1** 拓扑大类 | 2-stage Miller / 2-stage cascode-stage1 / 3-stage nested | gain / GBW | `index.md` § Spec Ceiling Table |
| **L2 Stage1 input pair 极性** ⭐ | **PMOS / NMOS / rail-to-rail** | **Vcm_in 位置 vs PMOS ceiling 与 NMOS floor** | 本章 § "Stage1 Input Pair 极性 — IRON LAW" + `base-cells/differential-pair/cm-range` |
| **L3** Stage1 mirror 类型 | simple / cascoded / wide-swing | swing / gain | `index.md` § Spec Ceiling Table |
| **L4** Stage2 极性（与 Stage1 互补）| NMOS-CS / PMOS-CS | 由 stage1 输出 vx 极性决定 | 本章 § Variant |
| **L5** Bias 方式 | NMOS-diode + PMOS-diode 链 / replica / β-multiplier | PSRR / area | reference-design.md |
| **L6** 补偿方式 | Miller Cc + Rz / cascode-comp / load-only | PM @ all corner | `ac-stability.md` |

**经典 LDO EA 应用（Vcm_in = Vfb）**：选 L2 必参 LDO PACK 同款 ceiling/floor 公式（Vfb 是 Stage1 input pair 的 CM）。详见下文。

**Demo 04 实证（L2 漏检的代价）**：vpdk55nm，Vfb=Vcm_in=0.9V，VDD=1.2V，agent 选 PMOS-input pair（误，没自检 ceiling）。PMOS ceiling = 1.2 − 0.35 − 0.1 = 0.75V。Vcm_in 0.9V > 0.75V，违 150mV → M1/M2 sub-threshold → ID 60nA vs 设计 5µA → gm ×1/83 → AC 全垮，调参救不了。

## Stage1 Input Pair 极性 — IRON LAW

> **L2 self-check（必做，写 Stage1 前）**：用 PDK 实测的 \|Vth_p\| / Vth_n + Vdsat_tail（典型 0.1V）数值代入下面公式，对照 Vcm_in 位置。详细公式 + 跨 PDK 数据见 `base-cells/differential-pair/cm-range.md`。

### 双向公式

```
PMOS-input pair (tail at top)：
    Vcm_max (ceiling) = VDD − |Vth_p| − Vdsat_tail
    [若违反 → MP1/MP2 sub-threshold → gm 损 50-100×]

NMOS-input pair (tail at bottom)：
    Vcm_min (floor)   = Vth_n + Vdsat_tail
    [若违反 → tail 进 triode → DC OP 漂]
```

### 决策规则

| Vcm_in 位置 | 必选 Stage1 input pair | 备注 |
|---|---|---|
| Vcm_in ≥ Vcm_ceiling_PMOS（PMOS ceiling 违）| **NMOS-input pair**（→ Variant 1）| PMOS pair sub-threshold，gm 灾难 |
| Vcm_in ≤ Vcm_floor_NMOS（NMOS floor 违）| **PMOS-input pair**（默认 reference）| NMOS tail triode，DC OP 漂 |
| Vcm_in 落两个上限之间（健康区间）| 看 noise / 1/f 取舍（PMOS 噪声低 1.5-3×）| 双向都 OK |
| Vcm_in 同时违两个上限 | **rail-to-rail（PMOS+NMOS 并联）**或 folded-cascode tail | 极少见，需要确认 spec |

### 应用场景的 Vcm_in 来源

| 应用 | Vcm_in 来源 | 典型值 |
|---|---|---|
| LDO EA | Vfb（feedback node）| ≈ Vref 或分压结果 |
| ADC sample-and-hold | Vref / Vsig | 中间电平 ~VDD/2 |
| 通用差分接收器 | input source 工作点 | 视应用 |

### 跨 PDK 数据（vpdk 系列）

| PDK | VDD | \|Vth_p\| | Vth_n | PMOS pair Vcm ceiling | NMOS pair Vcm floor |
|---|---|---|---|---|---|
| vpdk180nm | 1.8 V | 0.45 V | 0.40 V | **1.25 V** | 0.50 V |
| vpdk55nm  | 1.2 V | 0.35 V | 0.30 V | **0.75 V** | 0.40 V |
| vpdk7nm   | 0.8 V | 0.25 V | 0.25 V | **0.45 V** | 0.35 V |

详见 `base-cells/differential-pair/cm-range`。

### Step 0 写 Stage1 前必做

```
1. 查 PDK constants: |Vth_p|, Vth_n, VDD
2. 计算 PMOS ceiling = VDD − |Vth_p| − 0.1
3. 计算 NMOS floor   = Vth_n + 0.1
4. 对照 Vcm_in（如 LDO EA = Vfb）：决定 input pair 极性
5. 在 Step 0 报告里写明「Vcm_in=?V, PMOS ceiling=?V, NMOS floor=?V, 选 ?-pair, 理由 ?」
```

**判别（仿真后）**：dc_snapshot 看 tail Vds（NMOS tail triode = floor 违）/ inspect_device 看 MP1 gm 实测 vs 设计期望（gm < 1/10 期望 = PMOS ceiling 违，sub-threshold）。

## 拓扑本质

**两级级联 = 5T 第一级（高 gain，紧 swing）+ CS 第二级（高 swing，rail-to-rail）+ Miller 极点分裂**。

物理本质：
1. **第一级**专注 gain ceiling（gm × ro，约 30-50 dB），swing 不重要（第一级
   输出 vx 只是中间节点）
2. **第二级**专注 swing + 大电流驱动能力（rail-to-rail 输出，I_stage2 远大
   于 I_stage1，slew rate 决定）
3. **Miller cap (Cc)** 跨第二级，把 stage1 输出节点的极点压低（主极点）+
   把 stage2 输出节点的极点推高（次极点），形成 **极点分裂（pole splitting）**

```
两级 OTA：gain = gm1 × ro1 × gm6 × ro6
GBW    = gm1 / (2π · Cc)         ← 不是 / CL（Miller 补偿后）
PM     由 Cc/CL 比例 + Rz nulling 共同决定
```

**关键约束**：Miller 补偿引入 **RHP zero** at `1 / (Cc × (1/gm6))`——单看
就让 PM 倒退。**nulling resistor Rz = 1/gm6** 把 RHP zero 推到无穷远（或
LHP），这是 2-stage 必须做的"补偿的补偿"。

## Standard variant（V4 reference: PMOS-input + NMOS mirror + NMOS-CS stage2）

```
Stage 1 (5T 结构, PMOS-input)
  - MPTAIL: PMOS tail（top tail, S=vdd）
  - MP1, MP2: PMOS diff pair（S=ntail, G=vinp/vinn）
  - MN3 (diode), MN4 (mirror): NMOS mirror load（S=vss）
  - vx 是 stage1 真高增益输出节点（MP2.D = MN4.D）；vx_l 是 diode 端

Stage 2 (NMOS CS)
  - MN6: NMOS CS amp（G=vx，stage1 高增益输出）
  - MP6: PMOS current source load（G=vbp，mirror MPBIAS）

Bias chain
  - MNBIAS（NMOS diode @ ibias）→ MNSINKP（mirror）→ MPBIAS（PMOS diode）→ vbp
  - vbp 同时给 MPTAIL（stage1 tail）+ MP6（stage2 load）

Miller compensation
  - Cc：vx ↔ vout（跨 stage2，从 stage1 输出到 stage2 输出）
  - Rz：series with Cc（在 vx 一端）—— 抵消 RHP zero
```

V4 `reference-design.md` 提供此变体的 production-grade 网表。**新设计先 load
reference design**——LDO v3 H-005 教训：手写时 MN6.G 误接 vx_l 而非 vx →
stage2 不放大 → loop gain 30 dB 偏低，浪费 5+ turn 修。

## Variants（从 reference 怎么改）

### Variant 1: NMOS-input + PMOS mirror + PMOS-CS stage2（low-VCM 场景）

适用：VCM 接近 0V（0.2-0.5V @VDD=1.8V），需要 input pair 在低 VCM 下 saturate；
NMOS-input 在低噪要求下用 large W 时 flicker 较大但 thermal 较小。

**怎么改 reference**：
- Stage 1: MP1/MP2 → NMOS（type 反转），S=ntail（bottom tail，NMOS）
- Stage 1 mirror load: MN3/MN4 → PMOS（S=vdd, top mirror）
- Stage 1 tail: PMOS → NMOS（bottom tail）
- Stage 2: MN6 → PMOS-CS（S=vdd, G=vx）；MP6 → NMOS current source load
- bias chain N/P 镜像翻转

物理对照：
- VCM 范围：[Vov_ntail + Vth_n, Vth_n + Vov_ntail + 几百 mV]
- 噪声：NMOS-input flicker 较 PMOS 大 1.5-3×（同 W·L）；thermal 较小
- Rail-to-rail swing 仍保留（stage2 都是单管）

### Variant 2: Cascode in Stage 1（提 stage1 gain，减总 power）

适用：希望降总 power 但保 100 dB total gain；stage1 加 cascode 提 gain 30→50
dB → stage2 不需要那么大 gm，可以省电流。

**怎么改 reference**：
- Stage 1 mirror load → cascoded mirror（加 NMOS cascode）
- Stage 1 输入对 → 加 PMOS cascode（telescopic-style）
- Stage 2 不变

物理对照：
- gain ↑（stage1 50 dB + stage2 40 dB ≈ 90 dB）
- power ↓（stage2 I 可减半）
- swing ↑（stage2 仍 rail-to-rail，stage1 内部 swing 不影响输出）
- 复杂度 ↑（更接近 2-stage cascode-OTA，独立类别）

### Variant 3: Class-AB output stage（rail-to-rail + 大驱动）

适用：driving 大 CL（> 10 pF）+ 需要快 slew rate；典型 LDO 大电流 EA。

**怎么改 reference**：
- Stage 2 NMOS-CS + PMOS-load → class-AB push-pull（NMOS pull-down + PMOS pull-up
  共 gate 控制）
- 需要额外 floating bias（保 quiescent current）

物理对照：
- Slew rate 大幅提升（不再受单边静态电流限制）
- Power efficiency 提升（quiescent 小，dynamic 大）
- 复杂度大幅 ↑（class-AB bias 设计独立章节）

> Class-AB 详细设计见 `blocks/base-cells/output-stage` 中的 class-AB 子章。

### Variant 4: Fully-differential 2-stage OTA + CMFB

适用：高 PSRR / 大信号 differential ADC / 需要 differential rail-to-rail 输出。

**怎么改 reference**：
- 保留两侧 stage1 输出 vx_l / vx_r（不收敛到 SE）
- Stage 2 复制成两个对称 CS（一个 vout_p，一个 vout_n）
- 加 CMFB 控制两 stage2 输出的共模电平

物理对照：
- swing × 2（差分有效摆幅）
- 共模噪声大幅抑制
- CMFB 闭环引入额外极点 → PM 设计更难

## 4D Trade-off：Two-Stage OTA vs 其他 OTA

| 维度 | 5T | FC | Tele | **2-stage** |
|---|---|---|---|---|
| **Gain** | 40-55 dB | 60-80 dB | 60-80 dB | **80-100 dB**（gm·ro × gm·ro）|
| **GBW**（@CL=5pF）| 1-50 MHz | 30-100 MHz | 30-120 MHz | **10-50 MHz**（受 Miller Cc 限）|
| **PM** | 易（单极点）| 中（fold + cascode 极点）| 中 | **难**（Miller Cc / Rz / RHP zero 三件套要 tune）|
| **Power**（300-1000µW）| 30-100 µW | 200-800 µW | 100-500 µW | **300-1000 µW**（双级，stage2 大电流）|
| **Swing**（VDD=1.8V）| ≈ 1.0V | 0.6-0.8V | 0.4-0.6V | **≈ 1.6V（rail-to-rail）**（stage2 单管）|
| **Slew rate** | gm/CL（小）| I_fold / CL | I_branch / CL | **I_stage2 / CL**（最大，单边）|
| **Noise**（input-referred）| 中 | 低 | 低 | 中（stage1 主导）|
| **复杂度** | 最简单 | 中-高 | 中 | **最复杂**（双级 + Miller 补偿）|
| **典型适用** | 简单 buffer | LDO EA / ADC | 高 gain + 低噪 | **LDO EA / 大 CL / rail-rail** |

> **2-stage vs FC**：相同 LDO EA 应用下：
> - **FC**：单级，gain 60-80 dB 够用 + 不需要 Miller，PM 容易；但 swing 0.6-0.8V，
>   不能 rail-to-rail
> - **2-stage**：双级，gain 80-100 dB（多余但有 margin）+ rail-to-rail swing；
>   但 Miller 补偿要调 Cc/Rz，PM 紧
> - **选择**：LDO 输出 dropout < 200mV → 2-stage（rail-to-rail）；dropout > 500mV
>   → FC（更简单）

## When to use Two-Stage OTA

- ✅ Gain > 80 dB（单级 cascode 物理上限是 80-90 dB）
- ✅ Rail-to-rail 输出 swing 需求（5T / FC / Tele 的 cascode 占 headroom 永远做不到）
- ✅ LDO EA loop gain ≥ 80 dB（典型 LDO 严苛 line/load reg）
- ✅ ADC 子模块（采样保持放大器 SHA / PGA）
- ✅ Driving 大 CL（> 5 pF）—— stage2 大电流好驱动

## When NOT to use Two-Stage OTA

- ❌ Gain < 60 dB → 5T 简单
- ❌ Gain 60-80 dB + 不需要 rail-to-rail → FC（更简单，PM 容易）
- ❌ 高速 BW > 100 MHz → 多级 Miller GBW 受限，用 FC 更高速
- ❌ Power-tight 应用（< 200µW）→ 双级最少 ~ 300µW

## Related

- 4 OTA 拓扑详细对比：`blocks/5t-ota/architecture` / `folded-cascode-ota/architecture` / `telescopic-ota/architecture`
- Stage1 (5T) 物理：`blocks/5t-ota`
- Stage2 (CS) 物理：`blocks/base-cells/common-source`
- Miller 补偿原理 + RHP zero + nulling resistor：`blocks/base-cells/miller-compensation`
- 设计推进顺序（先 stage1 → 再 stage2 → 最后 Miller）：`sizing-typical.md`
