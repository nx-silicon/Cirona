---
chapter: sizing-typical
parent: three-stage-ota
summary: |
  Three-stage opamp 顶层 spec → device 约束的因果链 + 拓扑特定推进顺序
  （**严格 4 阶段顺序**：Stage1 → Stage2 → Stage3 → NMC compensation；3
  stage 互锁 + 2 Cc/Rz 互相耦合让乱序必反复推翻）+ 起点表（@vpdk180nm）+
  trade-off 表。
tokens: ~1500
prerequisite_chapters:
  - architecture
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/5t-ota
  - blocks/base-cells/common-source
  - blocks/base-cells/miller-compensation
---

# Three-Stage Opamp Sizing Typical Ranges

> 通用 sizing 流程见 `skill: device-sizing`。Stage1 5T sizing 见
> `blocks/5t-ota/sizing-typical`。Miller 补偿数学见
> `blocks/base-cells/miller-compensation`。本章节给的是 **3-stage 拓扑特有**的：
> (1) spec → 子模块约束（gain 三级分配 + NMC Cc/Rc 互锁）；(2) 跨级耦合；
> (3) 4 阶段严格推进顺序；(4) 起点表（@vpdk180nm）。

## 顶层 spec → 子模块约束（拓扑特定因果链）

| 3-stage spec | 决定的子模块量 | 关键公式 |
|---|---|---|
| GBW | gm_stage1 / Cc1 | GBW = gm1 / (2π · Cc1) |
| DC gain（≥ 100 dB）| gm1·ro1 × gm2·ro2 × gm3·ro3 | 3 stage 乘积；每级 30-40 dB target |
| PM | f_p2' / GBW > 3 + f_p3' >> f_p2' | NMC pole splitting × 2 |
| 2 个 RHP zero | f_z1 / f_z2 用 Rc 消 | Rc1 = 1/gm_stage_combined；Rc2 = 1/gm_MP4 |
| Output swing | VDD - \|Vov_MP4\| - 50mV down to Vov_MN4 + 50mV | rail-to-rail（stage3 单管）|
| Iq budget | I_stage1 + I_stage2 + I_stage3 | 典型 80 + 80 + 200 = 360 µA |
| Max output current | W·m_MP4 × Vov_max | 受 v2_out 摆幅限 |
| Slew rate | I_stage3 / CL | stage3 大 m 决定 |

## 跨级耦合（**3-stage 特有，2 个 Cc 互相耦合**）

| 耦合关系 | 公式 | 含义 |
|---|---|---|
| GBW ↔ Cc1 | GBW = gm1 / Cc1 | Cc1 主导 BW |
| f_p2' ↔ gm_stage_combined / Cc1 | NMC outer Miller | Cc1 让 stage2 极点远 |
| f_p3' ↔ gm_MP4 / CL | Stage3 极点 | 自然主极点候选 |
| **Cc1 vs Cc2 比例** | Cc1 / Cc2 ≈ 2-4 | 让 Cc1 主导 outer，Cc2 inner |
| **Rc1 vs Rc2 不同 gm** | Rc1=1/gm_combined（2+3），Rc2=1/gm_MP4（仅 3）| 2 个不同 RHP zero 各自消 |

## 拓扑特定的设计推进顺序 ⭐（**4 阶段严格 + 跨 NMC 多变量**）

> 通用 sizing 流程见 device-sizing skill。本节给 **3-stage 拓扑特有**的
> 推进顺序——4 阶段互锁（Stage1 决定 v1_out 静态 → Stage2 决定 v2_out → Stage3
> 决定 vout + gm_MP4 → NMC Cc/Rc 决定 PM）。**严格顺序**：跨级 NMC 多变量
> 让乱序必反复推翻。

### Phase A — Stage 1 sizing（同 2-stage class-A）

参照 `blocks/5t-ota/sizing-typical` + `blocks/two-stage-ota/sizing-typical` Phase A：

```
Cc1 起点 = 0.5× CL    (3-stage Cc1 大于 2-stage Cc，因 NMC outer)
gm1 = 2π × GBW × Cc1
gm/Id = 12-15
Id_per_side = gm1 / (gm/Id)
I_tail = 2 × Id_per_side
```

V4 reference 起点：W_diff=50µm/L=2µm/m=4，I_tail=80µA。

> **3-stage Stage1 长 L (L=2µm)**：gain 主导，3 stage 整体高 gain 要求 stage1
> 也贡献多（不仅靠 stage3 大 m）。

### Phase B — Stage 2 sizing

```
Stage2 NMOS-CS：gm2·ro2 ≥ 30 dB（V4 baseline 35 dB）

要 PM > 60° 在 NMC 拓扑下：
  f_p2' = gm_stage_combined / (2π · CL_eff)
  典型 gm_stage2 + gm_stage3 总 push ≥ 12 × gm_stage1（同 2-stage Miller 比例）
  
W·m / L (stage2) 由 gm_stage2 + Vov target 反推
gm/Id = 8-12（strong inversion，gm/W 大）
```

V4 reference 起点：W_cs2=80µm/L=1µm/m=8，gm2 ≈ 1-2 mS。

### Phase C — Stage 3 sizing（**rail-to-rail 输出）

```
Stage3 PMOS-CS：rail-to-rail sourcing
  W·m_MP4 决定 max output current + gm_MP4
  L_MP4 = Lmin（drive + speed 双优先）
  
spec：max output current I_max ≥ 5-10 mA (typical):
  W·m / L · (Vov_max)² / 2 ≥ I_max
  Vov_max ≈ v2_out 摆幅 ≈ 0.6V → W·m ≈ 4000 µm·m
  L=Lmin=0.18µm or 0.5µm → W·m = 200µm × m=20

PMOS / NMOS 比例 (Stage3)：W_p / W_n ≈ μn / μp ≈ 2.5
  V4 reference: MP4=200µm/m=20, MN4=100µm/m=10
```

### Phase D — NMC Compensation sizing

```
Cc1 起点：Cc1 / CL ≈ 0.5-1（V4 baseline Cc1 = 3pF, CL = 5pF → 0.6）
Cc2 起点：Cc2 ≈ Cc1 / 2 (V4 baseline Cc2 = 1.5pF)

Rc1 = 1 / gm_stage_combined
  gm_combined = gm_stage2 × gm_stage3 (cascade，多极点近似)
  实际 gm_combined ≈ √(gm2 · gm3) for first-order analysis
  V4 baseline Rc1 = 3 kΩ

Rc2 = 1 / gm_MP4 (stage3 单管)
  gm_MP4 ≈ 1 mS（@ Id=100µA, Vov=0.2V）
  V4 baseline Rc2 = 2 kΩ

PM > 60° 验证：
  GBW = gm1 / (2π·Cc1) ≈ 200µS / (2π·3pF) = 10.6 MHz
  f_p2' = gm_combined / (2π·Cc2)
        ≈ 1mS / (2π·1.5pF) = 100 MHz
  → f_p2' / GBW ≈ 10 → 余量大
  
  f_p3' = gm_MP4 / (2π·CL) = 1mS / (2π·5pF) = 32 MHz
  → f_p3' > f_p2' 要求 → 需调 Cc2
  → 实际：f_p2' / GBW ≈ 3-5 是设计 sweet spot
```

### 推荐建议（不强制）

> 这 4 phase 是 **3-stage 拓扑特有**的推进顺序，不是机械流程。**Phase A
> （Stage1）必须最先**——它决定 v1_out 静态点，进而决定 stage2 input。
> **Phase D（NMC）必须最后做**——2 个 Cc / Rc 由前 3 stage 的 gm 决定。
> **关键耦合**：Cc1 是 GBW + outer pole，Cc2 是 inner pole；Rc1 / Rc2 用
> 不同 gm（Cc1 跨 stage 2+3 → Rc1 = 1/gm_combined；Cc2 跨 stage3 →
> Rc2 = 1/gm_MP4）。**不要混淆 Rc1 = Rc2 = 1/某 gm**——是 2 个不同 zero。

## 起点表（@vpdk180nm，VDD=1.8V，ibias=20µA，CL=5pF，target gain ≥ 100 dB）

| 设备 | role | W | L | m | gm/Id | Vov | 关键约束 |
|---|---|---|---|---|---|---|---|
| **Stage 1 (5T)** | | | | | | | |
| MN1 / MN2 | NMOS diff pair | 50 µm | **2 µm** | 4 | ~12 | 0.15 V | 长 L 提 ro_M1 |
| MP1 / MP2 | PMOS mirror | 25 µm | 2 µm | 2 | ~10 | 0.20 V | gain 优先 |
| MN_tail | NMOS tail | 50 µm | 4 µm | 4 | ~10 | 0.20 V | I_tail = 80 µA |
| **Stage 2 (NMOS-CS)** | | | | | | | |
| MN3 | NMOS-CS | 80 µm | 1 µm | 8 | ~10 | 0.18 V | gm2 决定 |
| MP3 | PMOS load | 40 µm | 1 µm | 4 | ~10 | 0.20 V | I_stage2 = 80 µA |
| **Stage 3 (PMOS-CS, 输出)** | | | | | | | |
| **MP4** | **PMOS-CS output** | 200 µm | **0.5 µm** | **m=20** | ~10 | 0.20 V | rail-rail sourcing |
| **MN4** | **NMOS sink** | 100 µm | **0.5 µm** | **m=10** | ~10 | 0.20 V | μ 比例 |
| **Bias** | | | | | | | |
| MN_bias / MN_bias2 | NMOS bias chain | 25 µm | 4 µm | 2 | — | — | 共享 vbias_n / vbias_p |
| MP_bias | PMOS diode | 25 µm | 4 µm | 2 | — | — | vbias_p |
| **NMC Compensation** | | | | | | | |
| **Cc1** | outer Miller (跨 2+3) | 3 pF | — | — | — | — | Cc1 / CL ≈ 0.6 |
| **Rc1** | outer nulling | 3 kΩ | — | — | — | — | Rc1 = 1/gm_combined |
| **Cc2** | inner Miller (跨 3) | 1.5 pF | — | — | — | — | Cc2 ≈ Cc1 / 2 |
| **Rc2** | inner nulling | 2 kΩ | — | — | — | — | Rc2 = 1/gm_MP4 |

⚠️ **数值标 @vpdk180nm**：换工艺时 µ·Cox / Vth 不同，要重新算。
跨工艺通用：每 stage gain 30-40 dB；NMC Cc1 ≈ 0.5×CL；Cc2 ≈ Cc1/2；Rc1/Rc2
按各自 gm 反推；output L=Lmin。

## Trade-off 表（按 3-stage FOM 维度）

| 调整 | gain | GBW | PM | I_max | Iq | 备注 |
|---|---|---|---|---|---|---|
| L_diff_stage1 ↑（1 → 2µm）| ↑（ro1 ↑）| —（gm 同）| — | — | — | gain 优先 |
| Cc1 ↑（3 → 5 pF）| —| ↓ | ↑（GBW 减 → PM 余量 ↑）| — | — | PM 紧时首选 |
| Cc2 ↑（1.5 → 3 pF）| —| —（Cc1 主导 GBW）| ↑（inner pole 推低）| — | — | inner stability 调 |
| Rc1 / Rc2 偏离 1/gm | —| —| ↓（RHP zero 不消）| — | — | 实测 gm 后微调 |
| W·m_MP4 ↑（200×20 → 400×20）| ↑（gm3 ↑）| —| ↑（f_p3' ↑）| ↑↑ | ↑ | drive 优先 |
| Stage2 m_cs2 ↑ | ↑（gm2 ↑）| —| ↑（gm_combined ↑ → f_p2' ↑）| — | ↑ | gain + PM 双 优 |
| 加 cascode in stage1 | ↑↑ | —| — | — | ↑（cascode bias）| 130 dB+ 总 gain |

## 不在本章范围

- **gm/Id 通用 sizing 方法** → `skill: device-sizing`（通用 sizing 流程）
- **Stage1 5T sizing 详细** → `blocks/5t-ota/sizing-typical`
- **Common-source 物理（stage2 / stage3 CS）** → `blocks/base-cells/common-source`
- **Miller 补偿单级数学（pole splitting / RHP zero）** → `blocks/base-cells/miller-compensation`
- **NMC pole splitting × 2 + RHP zero × 2 完整推导** → `ac-stability.md` ⭐ 灵魂章
- **何时用 3-stage** → `architecture.md`（拓扑选择）
- **Vds-Vdsat 失稳** → `bias-headroom.md`
- **失败模式 + cross-corner** → `troubleshooting.md`

## Related

- `ac-stability.md` ⭐ NMC 完整推导
- `bias-headroom.md` 跨级 vds-vdsat + 静态点
- `blocks/5t-ota/sizing-typical` Stage1 sizing
- `blocks/two-stage-ota/sizing-typical` 2-stage 对照
- `blocks/base-cells/common-source` Stage2 / Stage3 CS
- `blocks/base-cells/miller-compensation` Miller 单级数学
- `skill: device-sizing` 通用 sizing 流程 + R1-R4 铁律
