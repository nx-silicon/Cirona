---
chapter: sizing-typical
parent: sar-adc
summary: |
  SAR ADC 顶层 spec → device 约束的因果链 + 拓扑特定推进顺序（**严格顺序**：
  noise-budget → C_total → C_unit/matching → comparator offset 决策 → C_b
  bootstrap → VREF reservoir → SAR FSM timing；跨子模块强耦合让乱序必反复推翻）
  + 起点表（@vpdk180nm 10-bit / 10 MS/s）+ trade-off 表。引用 noise-budget
  做 LSB 预算分配，不重复。
tokens: ~1700
prerequisite_chapters:
  - architecture
  - noise-budget
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/comparator
  - blocks/bandgap
  - blocks/base-cells/switch
---

# SAR ADC Sizing Typical Ranges

> 通用 sizing 方法见 `skill: device-sizing` 通用 sizing 流程。子模块 sizing 见
> `blocks/comparator/sizing-typical` + `blocks/base-cells/switch/bootstrapped`。
> 本章节给的是 **SAR ADC 拓扑特有**的：(1) spec → 子模块约束的因果链；
> (2) 跨子模块耦合（C_total ↔ C_unit ↔ matching ↔ offset budget）；
> (3) **拓扑特定的设计推进顺序**——SAR 的 6 个 sizing 决策互相耦合，乱序必
> 反复推翻。

## 顶层 spec → 子模块约束（拓扑特定因果链）

| ADC spec | 决定的子模块量 | 关键公式 |
|---|---|---|
| ENOB target | σ_total noise budget | σ_total ≤ LSB/2 → 5 噪声源等 √5 分配（见 noise-budget）|
| Sample rate | f_clk + cycles_per_conv | f_conv = f_clk / (N+2) sync；async ≈ N·t_settle + N·t_decide |
| Resolution N | C_total + C_unit matching | C_total ≥ kT/C floor；C_unit 由 σ(C)/C ≤ matching budget 定 |
| V_FS | Vrefp − Vrefn | LSB = V_FS / 2^N → 所有噪声 budget 按 LSB 缩放 |
| INL / DNL | CDAC matching σ_unit / C_unit | DNL spike at MSB ∝ √(2^N − 1) |
| SFDR / THD | S&H linearity + VREF ringing | 受 bootstrap C_b droop + VREF settling 限 |
| Power | I_static (preamp / buffer) + CV²f (CDAC + comparator) | 主要 dynamic power: f_clk × C_total × V_FS² |
| Aperture jitter | clock buffer 边沿 + PLL | σ_jitter × 2π·f_in × A ≤ LSB/4 |

## 跨子模块强耦合（**不能拆开看**）

| 跨子模块关系 | 公式 | 含义 |
|---|---|---|
| C_total ↔ thermal noise | σ_kTC = √(kT/C_total) | C_total ↑ → thermal ↓（直接关系）|
| C_unit ↔ matching | σ_unit/C_unit ∝ 1/√C_unit | C_unit ↑ → matching ↑（√ scaling）|
| C_total ↔ acquisition time | τ_acq = R_on × C_total | C_total ↑ → 慢，更难 settle to LSB/4 |
| Comparator offset σ_OS ↔ ENOB | σ_OS 系统性 ≤ LSB/2 | naked StrongARM 不够 → calibration 必做 |
| C_decap ↔ VREF ringing | ΔV_ref ≈ ΔQ_switch / C_decap | C_decap ≥ 100× C_total（含 off-chip）|
| C_b ↔ bootstrap droop | τ_droop = C_b / I_leak | C_b ↑ → droop ↓（但 bootstrap settling 慢）|

## 拓扑特定的设计推进顺序 ⭐（**6 sizing 决策互锁**）

> 通用 sizing 流程见 device-sizing skill。本节给 **SAR 拓扑特有**的推进
> 顺序——6 个 sizing 决策互相耦合（noise budget 决定 C_total；C_total 决定
> matching budget；matching 决定 C_unit；都决定 area；offset 决定 calibration
> plan；calibration 影响 timing；timing 决定 f_clk）。**严格顺序：先做 noise
> budget，再做 sizing**。

### Phase A — 噪声预算分配（先于任何 sizing）

```
ENOB target → noise budget σ_total ≤ LSB/2
分 5 源（参 noise-budget.md）：
  σ_quant = LSB/√12        (不可调)
  σ_kTC ≤ LSB/4            → C_total floor
  σ_OS ≤ LSB/2             → calibration plan 决策
  σ_n,comp ≤ LSB/4         → comparator gm/Id
  σ_ref ≤ LSB/4            → C_decap + buffer Z_out
  σ_jitter ≤ LSB/4         → clock buffer 边沿
```

> **为什么这步先做**：所有 sizing 决策都在算"满足 budget 的 minimum"。不先
> 算 budget → sizing 反复推翻。**这是 SAR ADC sizing 的灵魂**，
> 见 `noise-budget.md`。

### Phase B — C_total 起点（thermal floor + matching margin）

```
C_total_thermal_floor = k·T / (LSB/4)²  
                      = 70 fF @ 10-bit / V_FS=1V / 27°C
C_total = 4 × thermal_floor             (margin)

# 但实际 C_total 通常由 matching / parasitic / PDK 决定（更紧约束）
C_unit ≥ 10 fF (PDK density 限制 + Pelgrom matching)
C_total = 2^N × C_unit ≥ 10 pF  for 10-bit
```

> **C_total 实际起点比 thermal floor 大 ~50×**——是 matching budget 主导，不是 thermal。
> 14-bit 才让 thermal 成为主限制。

### Phase C — C_unit + CDAC matching 决策

```
σ(C)/C 经验保守 target（无 calibration）：σ(C)/C ≤ 1/(2^N · 3)
  10-bit → σ(C)/C ≤ 0.033%
  12-bit → σ(C)/C ≤ 0.008%      ⚠️ 已超 standard MOM/MIM
  14-bit → σ(C)/C ≤ 0.002%      ⚠️ 必须 calibration

C_unit 起点 (vpdk180nm MOM cap, σ(C)/C @ 1µm² ≈ 0.5%)：
  σ(C)/C ∝ 1/√Area → Area ≥ (0.5% / target σ(C)/C)²
  10-bit / 0.033% target → Area ≥ 230 µm² per unit cap → 大！
  实际 PDK MOM 单位面积 cap ≈ 0.2 fF/µm² → C_unit = 50 fF → Area = 250 µm²
```

> **matching 决定 C_unit area**。10-bit 单 unit 250 µm² × 1024 unit = 0.26 mm²
> CDAC——这是 SAR die area 的主要部分。

### Phase D — Comparator sizing + offset 决策（依赖 LSB / V_FS）

```
σ_OS budget = LSB/2 = 0.49 mV (10-bit / V_FS=1V)
naked StrongARM W·L 起点 (input pair):
  W·L ≥ AVT² / σ²_OS = (5mV·µm)² / (0.49 mV)² = 100 µm²
  → W=20µm × L=5µm 单管（巨大）

实际：> 10-bit 必须组合 calibration（preamp / auto-zero / digital trim）：
  组合 1: preamp (20-30 dB) + StrongARM W·L=10 µm² → σ_OS ≤ 1mV @ input
  组合 2: StrongARM 单管 W·L=20 µm² + digital trim → σ_OS post-trim ≤ 0.5mV
  组合 3: auto-zero phase + StrongARM → σ_OS ≤ 0.5mV @ slow speed

每组合都要算总功耗 + 速度损失 trade-off
```

> **R2 铁律**：**10-bit 以上 SAR comparator 单 sizing 路径几乎不可能 < LSB/2**。
> 必须组合 calibration。详见 `noise-budget.md` 范例 2。

### Phase E — Bootstrap S&H switch sizing

```
要求 (a) acquisition settling: T_acq · 1/(R_on · C_total) ≥ (N+1) · ln(2)
       即 R_on ≤ T_acq / (C_total · (N+1) · ln 2)
   (b) Vgs droop: ΔV_Cb < V_th_n × LSB/V_FS over t_hold
       即 C_b ≥ I_leak × t_hold / (V_th × LSB/V_FS)

vpdk180nm 起点 (10-bit / 10 MS/s, T_acq = 50 ns)：
  R_on ≤ 50 ns / (C_total × 11 × 0.693) = 4.5 kΩ for C_total=1.5pF
  W/L_M_sw ≈ 20 µm / 0.18 µm 给 R_on ≈ 200 Ω @ Vgs=VDD
  C_b = 1 pF（hold phase 50 ns / I_leak 几 nA → droop 几十 µV）
```

详见 `blocks/base-cells/switch/bootstrapped`。

### Phase F — VREF reservoir + buffer

```
ΔV_ref budget ≤ LSB/4 = 244 µV @ 10-bit / V_FS=1V
ΔQ_switch worst case ≈ C_total × V_FS = 1.5 pF × 1V = 1.5 pC
C_decap ≥ ΔQ_switch / ΔV_ref = 1.5 pC / 244 µV ≈ 6 nF (instantaneous)

层叠分配：
  on-chip: 1-5 nF      (中高频抑制)
  package: 10-100 nF   (低中频)
  off-chip: 1-10 µF    (低频 + DC PSRR)

ref buffer: low-Z（class-AB / opamp，输出阻抗 < 0.1 Ω）
  不能用 bandgap + resistor divider 直接当 ref（输出阻抗 100s Ω）
```

### Phase G — SAR FSM clock + timing margin

```
synchronous SAR: f_clk = f_conv × (N+2) = 10 MS/s × 12 = 120 MHz
  cycle_period = 8.3 ns
  per cycle: DAC switch (1 ns) + DAC settling (5 ns) + comparator latch (1 ns) + FSM register (1 ns)
  
asynchronous SAR: 内部 ready signal 自适应
  每 bit cycle ≈ τ_DAC + t_decide + t_FSM ≈ 1.5-2 ns
  10-bit @ 100 MS/s 可达
```

每阶段 timing margin ≥ 20%（FF/SS corner + supply noise）。

### 推荐建议（不强制）

> 这 7 phase 是 **SAR ADC 拓扑特有**的推荐推进顺序，不是机械流程。**Phase A
> （noise budget）必须先于 sizing**——所有数值起点都从 budget 反推。Phase B
> （C_total）和 Phase C（matching）通常一起做，因为 matching 决定 C_unit
> 进而决定 C_total。Phase D（comparator + calibration plan）在 sizing 决策树
> 中**不是越早越好**——需要先知道 C_total / V_FS 才能算 LSB；但 calibration
> 决策（preamp vs auto-zero vs trim）是架构层选择，可以与 Phase A 并行做。

## 起点表（@vpdk180nm，VDD=1.8V，V_FS=1V，10-bit / 10 MS/s, ENOB ≥ 9 bit）

| 参数 | role | 起点 | derivation |
|---|---|---|---|
| C_total | sample CDAC | 10-15 pF | matching 主导（thermal floor 仅 70 fF）|
| C_unit | unit cap | 10-15 fF | C_total / 2^N，PDK MOM density 决定 |
| MOM unit cap area | per cap | 50-75 µm² | matching σ(C)/C ≤ 0.03% |
| C_b | bootstrap | 1 pF | ≥ 5-10× Cgs_M_sw（M_sw W=20µm Cgs ≈ 80 fF）|
| W/L_M_sw | sample switch | 20µm / 0.18µm | R_on ≈ 200Ω @ Vgs=VDD |
| C_decap_ref（on-chip）| VREF reservoir | 1-5 nF | 1000× C_total（一阶估算）|
| W/L input pair (naked StrongARM) | 比较器 input | 10µm / 1.0µm | σ_OS 5mV unsuitable for 10-bit；必须 calibration |
| W/L regen pair | 比较器 regen | 4µm / 0.18µm | speed-optimized；详见 comparator |
| W/L tail switch | 比较器 tail | 20µm / 0.18µm | low R_on |
| f_clk | external clock | 120 MHz | sync (N+2)cycles → 10 MS/s |
| Bottom-plate switch (TG) | CDAC switching | W=2µm/L=0.18µm NMOS+PMOS | charge injection cancel via dummy switch |
| Dummy switch (per bit) | charge injection | half W of main + reverse clock | 一阶 cancellation |
| Calibration plan | offset 抑制 | preamp(20dB) + digital trim | 必备（10-bit / 1V FS budget LSB/2 = 0.49 mV）|

⚠️ **数值标 @vpdk180nm**：换工艺时 cap density / AVT / Vth 不同，要重新算。
跨工艺通用：噪声 budget 分配 + matching 1/√Area scaling + Calibration 组合策略。

## Trade-off 表（按 ADC FOM 维度）

| 调整 | ENOB | speed | power | area | 备注 |
|---|---|---|---|---|---|
| C_total ↑（thermal）| ↑↑（thermal noise ↓）| ↓（acquisition 慢 + driver 重）| ↑（CV²f）| ↑↑ | 14-bit 主限 |
| C_unit ↑（matching）| ↑（DNL/INL ↓）| —（C_total 同步）| ↑ | ↑↑ | 10-12 bit 主限 |
| 加 preamp | ↑（offset ↓）| ↓（preamp BW 限）| ↑（preamp Iq）| ↑ | 10+ bit 标配 |
| Digital trim | ↑（offset ↓）| —（不影响）| —（一次性）| 数字 area ↑ | 12+ bit 必做 |
| Async SAR | —（noise 同）| ↑↑（avg cycles ↓）| ↑（FSM 复杂）| ↑（数字逻辑）| ≥ 50 MS/s 推荐 |
| Bottom-plate sample | ↑（charge inj ↓）| ↓（额外 switch + non-overlap）| ↑（额外 switch power）| ↑ | > 12-bit 必做 |
| Time-interleaved | —（单通道 noise 同）| ↑↑（× channels）| ↑↑ | ↑↑（× channels）| > 100 MS/s 必做 |

## 不在本章范围

- **gm/Id 通用 sizing 方法** → `skill: device-sizing`（通用 sizing 流程）
- **比较器 input pair / regen / tail 详细 sizing** → `blocks/comparator/sizing-typical`（W7）
- **bootstrap switch 内部 helper sizing** → `blocks/base-cells/switch/bootstrapped`
- **VREF buffer 详细电路** → `blocks/base-cells/output-stage` (low-Z buffer)
- **bandgap 设计** → `blocks/bandgap`
- **CDAC unit cap layout（common-centroid / dummy ring）** → 数字 / mixed-signal layout knowledge
- **SAR FSM RTL** → 数字 IC knowledge
- **5 噪声源 LSB 预算分配 R1-R4 推理** → `noise-budget.md`
- **架构选型决策（charge-redistribution / bottom-plate / monotonic / async）** → `architecture.md`
- **Vds-Vdsat 失稳处理（bootstrap switch / comparator triode）** → 各自子模块 troubleshooting

## Related

- `noise-budget.md` ⭐ 5 噪声源 LSB 预算分配 + 推进顺序
- `blocks/comparator/sizing-typical` 子模块 sizing
- `blocks/base-cells/switch/bootstrapped` bootstrap switch
- `blocks/bandgap` VREF 来源
- `skill: device-sizing` 通用 sizing 流程 + R1-R4 铁律
- W6+ sizing-reasoning chapter（5 cell sizing-reasoning）
