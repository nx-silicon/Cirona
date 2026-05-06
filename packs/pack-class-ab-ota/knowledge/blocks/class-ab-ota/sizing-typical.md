---
chapter: sizing-typical
parent: class-ab-ota
summary: |
  Class-AB OTA 顶层 spec → device 约束的因果链 + 拓扑特定推进顺序（**严格
  顺序**：Stage1 → Floating bias 链 → Output devices 大 m → Miller cap；
  跨子模块强耦合让乱序必反复推翻）+ 起点表（@vpdk180nm）+ trade-off 表。
  引用 bias-headroom 做 quiescent control，不重复。
tokens: ~1600
prerequisite_chapters:
  - architecture
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/5t-ota
  - blocks/base-cells/output-stage
  - blocks/base-cells/miller-compensation
---

# Class-AB OTA Sizing Typical Ranges

> 通用 sizing 流程见 `skill: device-sizing`。Stage1 5T sizing 见
> `blocks/5t-ota/sizing-typical`。Class-AB output stage 物理见
> `blocks/base-cells/output-stage`。本章节给的是 **class-AB OTA 拓扑特有**的：
> (1) spec → 子模块约束（含 quiescent IQ + max output current）；(2) 跨级
> 耦合（Stage1 ↔ floating bias ↔ output W·m ↔ Miller）；(3) 推进顺序（**严格
> 顺序**）；(4) 起点表（@vpdk180nm）。

## 顶层 spec → device 约束（拓扑特定因果链）

| Class-AB spec | 决定的 device 量 | 关键公式 |
|---|---|---|
| GBW | gm_M1 / Cc | gm_M1 = 2π · GBW · Cc（同 2-stage class-A）|
| DC gain | gm1·ro1 × g_m_AB·ro_AB | output stage gain ≈ (g_m_PMOS + g_m_NMOS) × Rout（动态值）|
| PM | gm_AB / CL > 3 × GBW | output stage gm 是 push-pull 双管贡献 |
| **IQ_quiescent** ⭐ | floating bias VGP - VGN 差值 | IQ = kp · (VDD - VGP - \|Vth_p\|)² / 2 = kn · (VGN - Vth_n)² / 2 |
| **Max output current** ⭐ | W · m × output FETs | I_max ≈ µ·Cox · W·m / L · (Vov_max)² / 2；Vov_max 受 v1_out 摆幅限 |
| **Slew rate** ⭐ | I_max（动态）/ CL | dynamic SR远超 IQ/CL（push-pull 不受静态限）|
| Output swing | VDD - \|Vds_MP_out_min\| - Vds_MN_out_min | rail-to-rail 接近 |
| Crossover region | IQ_quiescent + 信号 V_x_over | 必须 IQ ≥ 临界值避 dead zone |
| Miller cap Cc | Cc / CL ≈ 0.5-1（大于 class-A）| output stage cap 大 + nonlinear → 需大 Cc |

## 跨子模块强耦合（**class-AB 特有**）

| 跨子模块关系 | 公式 | 含义 |
|---|---|---|
| Stage1 v1_out static ↔ VGP/VGN | v1_out → MP_ab_src.G → VGP；vbias_n → MN_ab_src.G → VGN | Stage1 mirror 偏 → VGP/VGN 偏 → IQ 偏 |
| **Floating bias 锁 IQ ↔ output sizing** | IQ = kp·(VGP-VDD-Vth_p)² = kn·(VGN-Vth_n)² | output W·m 决 kp/kn → IQ 由 floating bias 严格控 |
| **Output W·m ↔ max drive** | I_max ∝ W·m | 大 m 是 class-AB 输出强 drive 关键 |
| **Cc ↔ output stage cap** | gm_AB / CL > 3 × GBW；GBW = gm1/Cc | Cc 大 → GBW 低（typical Cc/CL ≈ 1）|
| **Floating bias chain 同密度** | bias 支路 m × 主支路 m 比例 | 同 telescopic wide-swing 铁律 |

## 拓扑特定的设计推进顺序 ⭐（**5 阶段严格顺序**）

> 通用 sizing 流程见 device-sizing skill。本节给 **class-AB 拓扑特有**的
> 推进顺序——5 阶段互锁（Stage1 决定 v1_out 静态 → floating bias 决定 VGP/VGN
> 静态 → output W·m 决定 IQ + max drive → Miller 决定 PM）。**严格顺序**：
> 任意阶段乱序都让 IQ 失控或 max drive 不达 spec。

### Phase A — Stage1 sizing（同 2-stage class-A）

参照 `blocks/5t-ota/sizing-typical` + `blocks/two-stage-ota/sizing-typical`
Phase A：

```
gm1 = 2π × GBW × Cc                   (Cc 起点 0.5× CL，比 class-A 大)
gm/Id = 12-15
Id_per_side = gm1 / (gm/Id)
I_tail = 2 × Id_per_side
```

V4 reference 起点：W_diff=40µm/L=1µm/m=4，I_tail = 4 × ibias = 80 µA。

### Phase B — Floating bias 链 sizing（**class-AB 关键**）

> **R2 同密度铁律**：bias 支路（MN_ab_bias2/3 / MP_ab_bias1/2）必须按
> stage1 vbias_n 同 W/L（m 倍数控制电流）；mid generator (MP_ab_mid_top/bot
> / MN_ab_mid_top/bot) 与 output device W/L 同比例（保 Vgs match）。

```
Floating bias chain:
  ibias → R_connect → vbias_n（NMOS diode MN_bias）
  vbias_n → MN_ab_bias2 (D=pbias) → pbias mirror to MP_ab_bias1 (PMOS diode)
  pbias → MP_ab_bias2 (D=vmid_p_ab)
  vbias_n → MN_ab_bias3 (D=vmid_p_ab) ← stacking with MP_ab_bias2 at same node
  vmid_p_ab gen: MP_ab_mid_top + MP_ab_mid_bot stacked diode → vmid_p_ab ≈ VDD - 2·|Vgs_p|
  vmid_n_ab gen: MN_ab_mid_top + MN_ab_mid_bot stacked diode → vmid_n_ab ≈ 2·Vgs_n
  
sizing：
  MN_ab_bias2/3 = MN_bias W/L (m=1, vs MN_bias m=2)
  MP_ab_bias1/2 W=10µm/L=1µm (PMOS)
  vmid 4 管：W=10µm/L=0.5µm (matched to output L)
```

> **floating bias 物理**：vmid_p_ab 比 VDD 低 2·|Vgs_p|（约 1.0V）；vmid_n_ab
> 高于 vss 2·Vgs_n（约 1.0V）。这两个值之差 + middle device Vgs 决定 VGP - VGN。
> **改 W/L 不只改电流，还会改 Vgs 锁住 floating bias 平衡点**。

### Phase C — Output device sizing（**class-AB 灵魂**）

```
spec：max output current I_out_max（如 5 mA 给 LDO）
       quiescent current IQ_AB（如 50 µA，控 crossover）
       
output PMOS / NMOS 比例：W_p / W_n ≈ μ_n / μ_p ≈ 2-3
       (vpdk180nm: μ_n/μ_p ≈ 2.5-3 → W_p ≈ 2 × W_n if 同 Vov)

I_out_max = µ_n·Cox · W·m / L · (Vov_max)² / 2
       Vov_max ≈ VDD/2 - Vth - margin ≈ 0.5-0.6V (when output gates 拉到极限)
       要 I_max = 5 mA → W·m / L · (0.6V)² / 2 = 5e-3 / (200µ × 4 × 0.7) ≈ 0.045 m
       L=Lmin=0.18µm → W·m ≈ 8 m·µm = 200µm × m=10
       
quiescent IQ control：由 floating bias VGP - VGN 决定（见 bias-headroom.md）
```

V4 reference 起点：MP_ab_out W=200µm/m=10；MN_ab_out W=100µm/m=10（PMOS 2× NMOS）。

> **关键 trade-off**：W·m ↑ → max drive ↑ + parasitic cap ↑ → Cc 必须 ↑ → GBW ↓。
> **大 drive ⇄ 高 BW** 不可兼得。

### Phase D — Miller compensation sizing

```
Cc 起点：Cc / CL ≈ 0.5-1（class-AB 大于 class-A）
       因 output stage cap 大 + nonlinear pole 复杂
       V4 reference 默认 Cc=5pF, CL=5pF → Cc/CL=1

GBW = gm1 / Cc ≈ 200µS / 5pF = 6.4 MHz   (V4 baseline 10-15 MHz @ Cc=5pF, gm1 大)

PM > 60° 要求 gm_AB / CL > 3 × GBW
       gm_AB = gm_MP_out + gm_MN_out (push-pull 时只有一管贡献，但 quiescent 时两管 gm 都进)
       quiescent: gm_AB ≈ 2 × gm_single ≈ 1-2 mS（output devices 大 m 决定）
       gm_AB / CL = 2mS / 5pF = 400 MHz >> 3 × GBW（足够 margin）

Rz 起点：Rz = 1 / gm_MN_out ≈ 1 / 1 mS = 1 kΩ
       V4 reference 用 2 kΩ（PMOS+NMOS 平均，留 margin）
```

### Phase E — Tran 验证

```
.tran 大信号 step：
  - SR+ / SR- ≥ spec（class-AB 应对称）
  - 无 settling ringing（PM 紧）
  - I_out_max 满足 spec（push-pull rail-to-rail）

.tran 小信号 + IQ 监测：
  - quiescent state IQ ≈ 设计 target ± 20% PVT
  - crossover point 信号 swing 时 PMOS+NMOS 都微导通（无 dead zone）
```

### 推荐建议（不强制）

> 这 5 phase 是 **class-AB 拓扑特有**的推进顺序，不是机械流程。**Phase A
> （Stage1）必须最先**——它决定 v1_out 静态点，进而决定 VGP / VGN 静态。
> **Phase B（Floating bias chain）必须先于 Phase C（output W·m）**——因为
> output IQ 由 floating bias 锁定，要 floating bias 落点对了 output sizing
> 才能算 IQ。**Phase D（Miller）可以与 C 并行做**——但实际中 Cc/CL ratio
> 受 output device 大小影响（W·m 大 → parasitic 大 → Cc 必须大）。

## 起点表（@vpdk180nm，VDD=1.8V，ibias=20µA，CL=5pF，IQ_AB target ≈ 100µA）

| 设备 | role | W | L | m | gm/Id | Vov | 关键约束 |
|---|---|---|---|---|---|---|---|
| **Stage 1** | | | | | | | |
| MN1 / MN2 | NMOS diff pair | 40 µm | 1 µm | 4 | ~12 | 0.15 V | Stage1 5T 标准 |
| MP1 / MP2 | PMOS mirror | 20 µm | 1 µm | 2 | ~10 | 0.20 V | μ 比例平衡 |
| MN_tail | NMOS tail | 40 µm | 2 µm | 4 | ~10 | 0.20 V | I_tail = 80 µA |
| MN_bias | NMOS diode (bias ref) | 20 µm | 2 µm | 2 | — | — | 跨 stage 共享 vbias_n |
| **Floating bias** | | | | | | | |
| MN_ab_bias2/3 | NMOS mirror | 20 µm | 2 µm | 1 | — | — | 同 MN_bias W/L（m 不同）|
| MP_ab_bias1/2 | PMOS bias | 10 µm | 1 µm | 1 | — | — | PMOS bias generator |
| MP_ab_mid_top/bot | PMOS stacked diode | 10 / 10 µm | 0.5 / 0.5 µm | 1 / 1 | — | — | vmid_p_ab generator |
| MN_ab_mid_top/bot | NMOS stacked diode | 10 / 10 µm | 0.5 / 0.5 µm | 1 / 1 | — | — | vmid_n_ab generator |
| **Class-AB middle** | | | | | | | |
| MP_ab_src | PMOS input (G=v1_out)| 10 µm | 1 µm | 2 | ~10 | 0.18 V | source follower → VGP |
| MN_ab_src | NMOS固定 bias (G=vbias_n)| 20 µm | 2 µm | 2 | ~10 | 0.20 V | 固定 VGN |
| MP_ab_mid | PMOS middle | 10 µm | 0.5 µm | 1 | ~10 | 0.18 V | floating driver |
| MN_ab_mid | NMOS middle | 10 µm | 0.5 µm | 1 | ~10 | 0.18 V | 同上对侧 |
| **Output (大！)** | | | | | | | |
| **MP_ab_out** | **PMOS pull-up** | 200 µm | **0.5 µm** | **m=10** | ~10 | 0.20 V | rail-rail sourcing |
| **MN_ab_out** | **NMOS pull-down** | 100 µm | **0.5 µm** | **m=10** | ~10 | 0.20 V | rail-rail sinking；W=W_p/2 |
| **Compensation** | | | | | | | |
| Cc_miller | Miller cap | **5 pF** | — | — | — | — | Cc / CL ≈ 1（class-AB 大）|
| Rc_null | nulling Rz | 2 kΩ | — | — | — | — | Rz = 1/gm_MN_out（实测）|

⚠️ **数值标 @vpdk180nm**：换工艺时 µ·Cox / Vth / μn/μp 不同，要重新算。
跨工艺通用：output PMOS / NMOS W 比例 ≈ μn/μp + Cc/CL ≈ 1（class-AB 比 class-A 大）+ floating bias 同密度铁律 + output L=Lmin（drive + speed 双优先）。

## Trade-off 表（按 class-AB FOM 维度）

| 调整 | gain | GBW | IQ | I_max drive | SR | PM | 备注 |
|---|---|---|---|---|---|---|---|
| W·m_output ↑（200×10 → 400×10）| ↑（gm_AB ↑）| —（GBW=gm1/Cc）| ↑（floating bias 锁不变）| ↑↑ | ↑（动态电流大）| ↓（output cap ↑ → 需 Cc ↑）| **drive 优先时首选** |
| L_output ↑（0.5 → 1µm）| ↑（ro ↑）| ↓（output cap ↑）| ↓（fT ↓）| ↓ | ↓ | — | 不建议（drive 优先要 L=Lmin）|
| Floating bias 偏 → IQ ↑ | —（小信号不变）| — | ↑ | —（max 不变）| — | — | crossover 改善但 power ↑ |
| Cc ↑（3 → 5 → 10pF）| —（小信号不变）| ↓ | — | — | — | ↑（PM ↑）| **PM 紧时首选** |
| Stage1 m_diff ↑（gm1 ↑）| ↑（stage1 gain ↑）| ↑（GBW ↑）| — | — | — | ↓ | 同 2-stage |
| Cc / CL ratio ↑（大 CL 时）| —| ↓ | — | — | — | ↑ | 大 CL spec 必做 |
| 简化 floating bias（去 vmid 链）| —| — | ↑↑（PVT 漂大）| — | — | — | Monticelli variant；不推荐 |
| Output 用 cascode（FVF）| ↑（ro ↑）| ↓ | — | ↑↑（local feedback）| ↑↑ | ↓ | FVF variant；高速 LDO 用 |

## 不在本章范围

- **gm/Id 通用 sizing 方法** → `skill: device-sizing`（通用 sizing 流程）
- **Stage1 5T sizing 详细**（input pair + mirror + tail）→ `blocks/5t-ota/sizing-typical`
- **Output stage 物理推导（class-A vs class-AB vs class-B / push-pull operation）** → `blocks/base-cells/output-stage`
- **Miller 补偿原理 / RHP zero / Rz nulling 数学** → `blocks/base-cells/miller-compensation`
- **何时用 class-AB 何时不用** → `architecture.md`（拓扑选择）
- **Quiescent control + crossover distortion 物理** → `bias-headroom.md` ⭐ 灵魂章
- **Vds-Vdsat 失稳处理（floating bias 节点 triode）** → `bias-headroom.md`
- **AC 极点 + Miller PM 详细分析** → `ac-stability.md`

## Related

- `bias-headroom.md` ⭐ Quiescent control + floating bias R1/R2 推理 + crossover 范例
- `ac-stability.md` Miller + class-AB 特有非线性极点
- `blocks/5t-ota/sizing-typical` Stage1 sizing
- `blocks/two-stage-ota/sizing-typical` 2-stage class-A 对照
- `blocks/base-cells/output-stage` output stage 物理（class-A/B/AB 对比）
- `blocks/base-cells/miller-compensation` Miller comp + Rz nulling
- `skill: device-sizing` 通用 sizing 流程 + R1-R4 铁律
