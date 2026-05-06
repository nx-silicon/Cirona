---
chapter: sizing-typical
parent: two-stage-ota
summary: |
  2-stage Miller OTA 顶层 spec → device 约束的因果链 + 拓扑特定推进顺序
  ⭐（先 stage1 → 再 stage2 → 最后 Miller cap，跨级耦合让乱序必反复推翻）+
  起点表（@vpdk180nm）+ trade-off 表。
tokens: ~1500
prerequisite_chapters:
  - architecture
related_skills:
  - device_sizing
related_knowledge:
  - blocks/5t-ota
  - blocks/base-cells/common-source
  - blocks/base-cells/miller-compensation
  - blocks/base-cells/differential-pair
---

# Two-Stage OTA Sizing Typical Ranges

> 通用 sizing 方法见 `skill: device-sizing` 通用 sizing 流程 + Iron Law: NO PARAMETER WITHOUT EXPLICIT DERIVATION。
> 单 device 物理推导见对应 base-cell（`differential-pair` / `common-source` /
> `miller-compensation`）。本章节给的是 **2-stage 拓扑特有**的：(1) spec → device
> 约束的两级分配；(2) 跨级耦合（GBW = gm1/Cc + p2 = gm6/CL）；(3) 推进顺序
> （**stage1 先，stage2 后，Miller 最后**）；(4) 起点表（@vpdk180nm）。

## 顶层 spec → device 约束（拓扑特定因果链）

| OTA spec | 决定的 device 量 | 关键公式 |
|---|---|---|
| GBW | gm1 / Cc | gm1 = 2π · GBW · Cc（Miller 补偿后 Cc 替代 CL）|
| DC gain | gm1·ro1 × gm6·ro6 | 两级乘积（≥ 80 dB）|
| PM | gm6 / CL > 3 × GBW | 非主极点 p2 = gm6 / (2π · CL) |
| RHP zero | 1 / (Cc · (1/gm6 − Rz)) | Rz = 1/gm6 让 zero → ∞（设计目标）|
| Iq budget | I_stage1 + I_stage2 | 典型 I_stage2 = 4-10 × I_stage1 |
| Output swing | VDD − \|Vov_MP6\| − Vov_MN6 | rail-to-rail（单管输出）|
| Slew rate | I_stage2 / CL | stage2 决定大信号 settling |
| Noise（input-referred）| gm1 + (gm_load/gm1)² | stage1 主导（前级噪声 referred 不受 stage2 衰减）|

## 拓扑特定的设计推进顺序 ⭐（**两级耦合让顺序至关重要**）

> 通用 sizing 流程见 device-sizing skill。本节给 **2-stage 拓扑特有**的推进
> 顺序——两级耦合 + Miller 补偿三件套（Cc / Rz / gm6）让乱序 sizing 必反复推翻：
> stage2 的 gm6 还没确定时无法选 Cc / Rz；stage1 的 gm1 + ro 还没确定时
> 无法算 stage2 的 I 比例。**严格顺序：stage1 → stage2 → Miller**。

### Phase A — Stage 1 sizing（先做，独立完成）

#### A.1 由 GBW + Cc 反算 stage1 gm

```
Cc 起点 = CL / 4   （后面 Phase C 再细调）
gm1 = 2π · GBW · Cc
gm/Id = 12-15（stage1 noise 主导，倾向 weak inversion）
Id_stage1 = gm1 / (gm/Id)         ← 即 I_diff_branch（双管平分 I_tail）
I_tail_stage1 = 2 × Id_stage1
```

#### A.2 选 stage1 5T 各管 W/L

参照 `blocks/5t-ota/sizing-typical`：
- M_diff (MP1/MP2)：W 起点，L_diff = 0.5 µm（matching + ro）
- M_load (MN3/MN4)：L_load = 1 µm（**比 input pair 长**，gain ceiling + 噪声）
- M_tail (MPTAIL)：W/L 起点，I_tail = 2 × Id_stage1

#### A.3 验证 stage1 gain（独立！不带 stage2）

期望 stage1 gain 30-50 dB（gm1 × (ro_M1 ‖ ro_MN4)）。**不要在这一步追求
> 50 dB**——cascade gain 由两级乘积，stage1 30 dB + stage2 50 dB = 80 dB
即可达 spec。

### Phase B — Stage 2 sizing（依赖 Phase A 的 gm1 / Cc）

#### B.1 由 PM 反算 gm6 下限

```
PM > 60° 要求 p2 > 3 × GBW
p2 = gm6 / (2π · CL)
gm6 ≥ 3 × GBW × 2π × CL = 3 × (gm1 / Cc) × CL
    = 3 × gm1 × (CL / Cc)
```

如果 Cc = CL/4 → gm6 ≥ 12 × gm1（**stage2 gm 远大于 stage1**）。

#### B.2 选 stage2 I（slew rate + p2 双约束）

```
slew rate 约束：SR = I_stage2 / CL ≥ spec
p2 约束     ：gm6 ≥ 12 × gm1
gm6 = (gm/Id)_stage2 × Id_stage2
gm/Id_stage2 = 8-12（stage2 用 strong inversion，gm/W 大）
Id_stage2 = gm6 / (gm/Id)_stage2
典型 I_stage2 / I_stage1 = 4-10
```

#### B.3 选 stage2 MN6 / MP6 W/L

```
W_stage2_n / L_stage2_n：stage2 NMOS-CS
W_stage2_p / L_stage2_p：stage2 PMOS load (mirror MPBIAS)
L_stage2 起点 = 0.5-1.0 µm（gain ↑ 但 fT ↓，trade-off）
W_stage2 由 gm6 + Vov_target 反算
μp / μn ≈ 1/4 → W_stage2_p ≈ 4 × W_stage2_n（同 Vov）
```

#### B.4 验证 stage2 DC bias

- vx（stage1 输出 / stage2 输入）应该 ≈ VDD/2（stage2 静态工作点）
- vbp 给 MP6 → I_stage2 = ibias × (W_MP6/W_MPBIAS)，验证 mirror ratio 对

> ⚠️ **若 vx 不在 VDD/2 附近**：stage1 mirror 不平衡（MN3/MN4 sizing typo
> 或 MP1/MP2 sizing typo）→ 先回 Phase A 修，不要在 Phase B 调 stage2 救。

### Phase C — Miller compensation sizing（依赖 Phase A + Phase B 的 gm1 / gm6）

#### C.1 微调 Cc（在 GBW 和 PM 之间平衡）

```
GBW = gm1 / (2π · Cc)        ← Cc ↑ → GBW ↓
p2 / GBW > 3 ⇔ Cc / CL > gm1 / gm6 / 3   ← Cc 上限不能比 CL 太小

如果 Phase A 默认 Cc = CL/4 后 PM < 60° → 增大 Cc（30% 步长）
如果 GBW 严重不足 → 减小 Cc（同时检查 PM 没崩）
```

#### C.2 选 nulling Rz（消 RHP zero）

```
Rz = 1 / gm6      ← 让 RHP zero → ∞（设计目标）
Rz < 1 / gm6      ← RHP zero 仍在 RHP，PM 倒退
Rz > 1 / gm6      ← zero 推到 LHP（增 PM，但浪费 BW）
```

实际工程中：先用 `Rz = 1 / gm6` 起点跑 AC，看 PM。如果 PM 仍紧（55-60°），
可以稍微增大 Rz 把 zero 推到 LHP，做一些 PM 增强。

> **Cc 与 Rz 的关系**：
> - Cc 决定主极点位置（GBW）
> - Rz 决定零点位置（RHP zero 是否被消）
> - 单调 Cc 不能完全救 PM——必须 Cc + Rz 配合

### Phase D — Tran 验证（slew rate + 大信号 settling）

```
.tran 仿真 input step 50% supply
观察：
- slew rate（上升+下降）应 ≥ spec
- settling time 到 ±0.1% 范围
- 没有 ringing（PM 太紧的标志）
```

如果 ringing 严重 → 增大 Cc 或 Rz。如果 slew 不够 → 增大 m_stage2（同时
重验 PM 因为 gm6 也 ↑）。

### 推荐建议（不强制）

> 这 4 phase 是**严格顺序**，不是机械流程。**stage1 sizing 不能与 stage2 并
> 行做**——stage2 gm6 依赖 stage1 gm1 + Cc。Miller cap Cc 不能与 stage1/stage2
> 并行选——Cc 依赖 gm6 + CL。**违反顺序最常见后果**：sizing 三件套（stage1/stage2/Miller）
> 反复推翻，10+ turn 不收敛。

## Cross-stage 强耦合（**不能拆开看**）

| 跨级关系 | 公式 | 含义 |
|---|---|---|
| GBW ↔ Cc | GBW = gm1 / (2π · Cc) | Cc 直接限 GBW |
| PM ↔ gm6 / Cc | gm6 / CL > 3 × gm1 / Cc | stage2 gm 必须远大于 stage1 |
| Slew ↔ I_stage2 | SR = I_stage2 / CL | stage2 电流决定大信号 |
| RHP zero ↔ Rz × gm6 | zero = 1 / (Cc·(1/gm6 − Rz)) | Rz = 1/gm6 让 zero → ∞ |

## 起点表（@vpdk180nm，VDD=1.8V，ibias=20µA，CL=5pF）

| Device | role | W | L | m | gm/Id | Vov | 关键约束 |
|---|---|---|---|---|---|---|---|
| MP1, MP2 | PMOS input pair | 20 µm | 0.5 µm | 1 | ~12 | 0.18 V | gm1 决定（GBW + noise）|
| MN3, MN4 | NMOS mirror load | 10 µm | **1 µm** ⭐ | 1 | ~8 | 0.30 V | L > input pair L（gain + noise）|
| MPTAIL | PMOS tail | 20 µm | 0.5 µm | 1 | ~10 | 0.20 V | I_tail = 2 × Id_stage1 = 20µA |
| MNBIAS | NMOS diode（bias ref）| 5 µm | 1 µm | 1 | — | — | mirror reference |
| MPBIAS | PMOS diode（bias ref）| 10 µm | 1 µm | 1 | — | — | mirror reference |
| **MN6** | **stage2 NMOS-CS** | 50 µm | 0.5 µm | 1 | ~10 | 0.20 V | gm6 ≥ 12 × gm1，I_stage2 = 4-10 × I_stage1 |
| **MP6** | **stage2 PMOS load** | 100 µm | 0.5 µm | 1 | ~10 | 0.20 V | μp/μn ≈ 1/4 → W_p ≈ 4 × W_n |
| **CCOMP (Cc)** | Miller cap | 1.5 pF | — | — | — | — | Cc / CL ≈ 0.3（PM 起点）|
| **RZ** | nulling resistor | 2 kΩ | — | — | — | — | Rz = 1/gm6（消 RHP zero）|

⚠️ **数值标 @vpdk180nm**：换工艺时 µ·Cox 不同，要重新算 W。Cc/CL 比例 +
gm/Id + 4-10× I 比例跨工艺通用。

## Trade-off 表（4D：gain / BW / power / swing）

| 调整 | gain | BW | power | swing | 备注 |
|---|---|---|---|---|---|
| Cc ↑（30% 步长）| —（小信号 gain 不变）| ↓ | — | — | PM ↑（推主极点 ↓）|
| L_load ↑（stage1 mirror）| ↑（ro_MN3 ↑ → stage1 gain ↑）| —（与 Cc 决定）| — | — | 总 gain ↑ |
| L_stage2 ↑ | ↑（ro_MN6 / ro_MP6 ↑ → stage2 gain ↑）| —（与 Cc 决定）| — | — | 总 gain ↑ |
| W_diff ↑ | ↑（gm1 ↑）| ↑（gm1 ↑ → GBW = gm1/Cc 同步）| —（同 Id）| — | trade-off：mirror node cap ↑ |
| m_stage2 ↑ | ↑（gm6 ↑）| —（GBW = gm1/Cc 不变）| ↑↑ | — | PM ↑ + slew ↑（**首选**）|
| I_stage1 ↑ | ↑（gm1 ↑）| ↑（gm1 ↑）| ↑ | — | trade-off：noise ↓ 但 power ↑ |
| Rz ↑（细调）| —（小信号 gain 不变）| —（GBW 同）| — | — | RHP zero → LHP（PM ↑，但浪费 BW）|

## 不在本章范围

- **gm/Id 通用 sizing 方法** → `skill: device-sizing`（通用 sizing 流程）
- **stage1 5T 各管单 device 物理推导** → `blocks/5t-ota` + `blocks/base-cells/differential-pair`
- **stage2 CS device 物理推导** → `blocks/base-cells/common-source`
- **Miller 补偿原理 / pole splitting / nulling Rz 推导** → `blocks/base-cells/miller-compensation`
- **何时用 2-stage 何时不用** → `architecture.md`（拓扑选择）
- **Vds-Vdsat 失稳处理** → `bias-headroom.md`
- **AC 极点 + Miller 补偿 PM 详细分析** → `ac-stability.md`

## Related

- `blocks/5t-ota/sizing-typical` stage1 5T 各管 sizing
- `blocks/base-cells/common-source` stage2 CS sizing
- `blocks/base-cells/miller-compensation` pole splitting + RHP zero + Rz
- `skill: device-sizing` 通用 sizing 流程 + R1-R4 铁律
- W6+ sizing-reasoning chapter（`current-mirror` / `differential-pair` / `output-stage` 5 cell）
