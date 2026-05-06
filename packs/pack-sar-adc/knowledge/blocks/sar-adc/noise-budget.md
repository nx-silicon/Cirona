---
chapter: noise-budget
parent: sar-adc
summary: |
  ⭐ SAR ADC 噪声 / 误差预算分配 — 把 LSB 切给 5 个噪声源（kT/C 采样 / 比较器
  offset / 比较器噪声 / VREF noise / aperture jitter）+ 量化噪声基线。R1 KVL
  式因果反推 + R2 budget 分配铁律 + 失稳调整范例（C 不够 / offset 超 budget /
  VREF ringing）。配 ENOB / SNDR sign-off 流程使用。
tokens: ~2000
prerequisite_chapters:
  - architecture
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/comparator
  - blocks/bandgap
  - blocks/base-cells/switch
---

# SAR ADC Noise Budget Reasoning

> 通用 vds-vdsat 推理范式见 `skill: device-sizing`。本章节给的是 **SAR ADC
> 拓扑特有的 LSB 噪声预算分配**——将每个 ADC 误差源（thermal / matching /
> jitter / quantization）映射到 LSB 比例并相加，类似 OTA 的 4-stack headroom
> budget。**这是 SAR 的灵魂章**：sizing 决策的物理上限来自这里，不是来自单个
> device 的 W/L。

## 核心物理：LSB 是预算单位

10-bit / V_FS=1V 的 SAR ADC：
```
LSB = V_FS / 2^N = 1V / 1024 = 0.977 mV
σ_quant = LSB / √12 = 0.282 mV       (量化噪声 RMS，理论下限)
SQNR = 6.02·N + 1.76 = 61.96 dB      (理想 ENOB = N)
```

**ENOB 损失定义**：实际 SNDR ≤ SQNR，差值就是各噪声源累计代价：
```
SNDR(dB) = 10·log10( σ²_signal / σ²_total_noise )
        = 10·log10( (V_FS/√8)² / Σ σ²_i )

ENOB = (SNDR − 1.76) / 6.02
ENOB_loss = N − ENOB = 各噪声源 σ²_i 累加导致的 dB 损失 / 6.02
```

> **设计起点（数学修正）**：若 σ_total 含 quantization，**ENOB ≥ N−0.5 需
> σ_total ≤ LSB/√6**（非 LSB/2）；σ_total=LSB/2 仅 ≈ N−0.8 bit。`LSB/4 per
> random source` 是 V4 baseline（约 N−1 bit）——简单 + 留 margin，非 N−0.5
> 严格预算。下面给 baseline 5 噪声源分配（要 N−0.5 需收紧）。

## 5 噪声源 + LSB 预算分配

| 噪声源 | RMS 公式（input-referred）| 可接受 σ | 设计抓手 |
|---|---|---|---|
| **量化** | LSB/√12 | 不可消（物理下限）| N（位数）|
| **kT/C 采样** | √(k·T/C_total) | LSB/4 | C_total ↑ |
| **比较器 noise** | σ_n,comp（input-referred） | LSB/4 | input pair gm + integration time |
| **比较器 offset σ_OS** | σ_OS（systematic）| **LSB/2** ⚠️ | 校准（sizing 改善有限）|
| **VREF noise** | σ_n,ref / √2 | LSB/4 | low-Z buffer + decap |
| **aperture jitter** | 2π·f_in·σ_t × V_FS/√8 | LSB/4 | clock buffer 边沿 |

**RMS 累加铁律**：
```
σ²_total = σ²_quant + σ²_kTC + σ²_comp + σ²_ref + σ²_jitter
σ_total ≤ LSB/√6 → ENOB ≥ N−0.5（严格）；σ_total ≤ LSB/2 → N−0.8（宽松）
σ_OS（systematic）单独 sign-off
```

> **R2 budget 铁律**：`LSB/4 per random source` 是 V4 baseline（4 源 RSS ≈
> 0.56·LSB → N−1 级别）。**严格 N−0.5** 需先扣 quantization：σ²_extra =
> (LSB/√12)²，再 RSS 分配。σ_OS 单独 sign-off，不并入随机 RSS。

## ⭐ 范例 1：thermal floor 推 C_total 起点

### 症状
spec：10-bit / V_FS=1V / ENOB ≥ 9 bit @ 27°C。

### R1 KVL 反推
```
σ²_kTC = k·T / C_total                                (sample cap thermal noise)
要 σ_kTC ≤ LSB/4 = 244µV
→ C_total ≥ k·T / (LSB/4)² = 4.14e-21 / (244µV)² = 70 fF

若严格要 σ_kTC = LSB/4 等贡献：C_total ≥ 70 fF
若 4× margin（含 quantization / 余量）：C_total ≥ 280 fF
```

12-bit / V_FS=1V 同理 C_total ≥ ~1 pF；14-bit ≥ 16 pF。

### R3 推理路径
```
spec ENOB target → LSB/4 thermal budget → C_total floor
  ↓
inspect_node('vsamp') → C_total cap 是否足够（含 dummy + 寄生）
  ↓
但 C_total 过大 → input driver 难（Rsource × C_total 决定 acquisition time）
  ↓
trade-off：取 4× thermal floor + 留 matching margin
```

> **R2 铁律**：**先按 kT/C 算 C_total floor，再按 matching 决定 C_unit**。
> 不要倒过来——先决定 C_unit 后才算 C_total 通常不够。

### 不要做（anti-pattern）
- ❌ **把 C_total 当唯一 ENOB 抓手**：C_total ↑ 4× 才换 1 bit thermal ENOB；offset / jitter 不动是无用功
- ❌ **对 14-bit 要 thermal floor 不用 calibration**：14-bit thermal C_total ≥ 16 pF + matching ≥ 14-bit → die area > 0.05 mm²
- ❌ **VDD ↑ 提 V_FS 想救 thermal**：单边 SAR V_FS 受输入 ICMR 限；differential SAR 才能 V_FS = 2 × VDD

## ⭐ 范例 2：comparator offset σ_OS > LSB/2 → ENOB 直接掉

### 症状
spec：10-bit / σ_OS budget = LSB/2 = 0.49 mV。
naked StrongARM σ_OS sizing 后实测 5-15 mV → ENOB 大幅 < N。

### R1 KVL 反推
```
σ²_OS = AVT² / (W·L) + (Vov/2)² · AB² / (W·L)
        ↑                    ↑
      Vth 失配主项       β 失配次项

要 σ_OS = 0.49 mV，AVT = 5 mV·µm（vpdk180nm）：
  W·L ≥ AVT² / σ²_OS = (5mV·µm)² / (0.49 mV)² = 100 µm²
  → W=10µm × L=10µm（巨大！面积代价高）
```

**面积 1/√(W·L) scaling 让裸 StrongARM 几乎不可能 < LSB/2 @ 10-bit + 1V FS**。

### 三条调节路径（**必须组合**）

**路径 A — 加 preamp**（gain 20-30 dB，把 latch σ_OS / gain 看到 input 端 reduce）：
- 见 `blocks/comparator/architecture` Pitfall 5 + reference-design preamp variant
- 副作用：preamp 静态功耗（10-100µW）+ 速度限于 preamp BW

**路径 B — Auto-zero / chopper**（采样阶段把 offset 存到 cap 上抵消）：
- 速度损失 ~ 50%（每周期一阶段做 auto-zero）
- 适合 ≤ 1 MS/s 慢 SAR

**路径 C — Digital trim / DEM / calibration**（数字校准）：
- 标配 ≥ 12-bit SAR ADC
- 增数字 area + 一次性 trim 流程；不影响速度

> **R2 铁律**：**10-bit 以上 SAR 必须组合多种 offset 抑制**，单 sizing
> 路径在 vpdk180nm 几乎不可能 < LSB/2（除非 W·L > 100 µm² 单管，layout
> 代价过高）。

### 不要做
- ❌ **靠加大 input pair 单 W·L 想压 σ_OS 到 LSB/2**：1/√(WL) scaling 慢，
  10× 面积才换 √10 = 3.2× σ_OS 改善
- ❌ **跳过 calibration plan**：14-bit SAR 不做 calibration 必失败

## ⭐ 范例 3：VREF ringing → 下次 bit 比较错

### 症状
tb_linearity 测 DNL 在 MSB transition 处出现 ±1 LSB spike，但 single-cycle
settling 看似 OK。增 settling time（slow conversion）后 DNL 改善。

### R1 KCL 反推
```
CDAC switching 瞬间从 ref buffer 抽取大瞬态电流：
  ΔQ_switch = C_total × ΔV_step
  ΔV_step worst case = V_FS（MSB transition）
  ΔQ_switch ≈ C_total × V_FS

ref buffer 输出阻抗 R_ref + 去耦 cap C_decap：
  ΔV_ref = ΔQ_switch / C_decap (instantaneous)
                                 (慢于 buffer 1/(BW · 2π) 时还要叠加 buffer transient)

要 ΔV_ref < LSB/4：
  C_decap ≥ ΔQ_switch / (LSB/4) = C_total × V_FS / (V_FS / 2^(N+2))
                                = C_total × 2^(N+2)
  10-bit → C_decap ≥ 4096 × C_total
  实际 ≈ 100× C_total（worst-case ΔV_step 不是每周期都 worst）
```

### 三条调节路径（**层叠分配**）
1. **on-chip local decap**（紧贴 CDAC，短引线）：50-200× C_total
2. **package decap**（数十 nF 级）：低频 + 中频去耦
3. **off-chip decap**（µF 级）：DC + 低频 PSRR

**ref buffer 选 low-Z**（class-AB / opamp，输出阻抗 < 0.1 Ω）—— 单纯 bandgap
+ 阻性 resistor divider 输出阻抗太高（k Ω）。

### R2 铁律：层叠去耦
```
on-chip C_decap × R_buffer_BW    → 中高频 (MHz - GHz) 抑制
package C_decap × R_package_L    → 低中频 (100kHz-10MHz) 抑制
off-chip C_decap × R_PCB_L       → 低频 (Hz-100kHz) 抑制
```

每层各自承担一段频率 → **三层分配，不要单一 cap "包打天下"**。

### 不要做
- ❌ **直接把 bandgap 输出当 VREF**：bandgap 输出阻抗 100s Ω，无法承受 µA-mA
  瞬态 → ringing 必发生
- ❌ **靠加 settling time 救 ringing**：ringing 时间常数由 RC 决定，>10×τ 才
  完全 settle → 速度损失大；更好是降 ringing 幅值

## ⭐ 范例 4：aperture jitter → high-frequency input ENOB 退化

### 症状
DC 测 ENOB 9.5 bit OK，但 fin = fs/2 测 ENOB < 8 bit。

### R1 KVL 反推
```
sample 时 input 信号瞬时变化率：
  dV/dt = 2π · f_in · A_signal       (sin 信号最大斜率处)
σ_t (clock jitter) → σ_V (input-referred):
  σ_V = (dV/dt) × σ_t = 2π · f_in · A · σ_t

要 σ_V ≤ LSB/4 = 244µV @ 10-bit / V_FS=1V (A_signal=V_FS/2=0.5V):
  σ_t ≤ LSB/4 / (2π · f_in · 0.5V)
  
  fin = fs/2 = 5 MHz → σ_t ≤ 16 ps
  fin = fs/2 = 50 MHz → σ_t ≤ 1.6 ps    ⚠️ 极严
  fin = fs/2 = 500 MHz → σ_t ≤ 160 fs   ⚠️ PLL 级 jitter
```

**Aperture jitter 限制 SAR ADC 高速应用** —— Nyquist 越高，jitter 要求越严。

### 调节路径
| 路径 | 效果 |
|---|---|
| Clock buffer 大驱动 + 边沿 ≤ 30 ps | 减 buffer 链 jitter 累积 |
| 用 LC-VCO PLL（不是 ring-VCO）| jitter 100s fs 级 |
| 减 Vin 摆幅 A_signal | 直接减 dV/dt（牺牲 SNR）|
| 限 fin（only baseband） | 物理上回避 jitter 限 |

### R2 铁律
**SAR ADC 不是 jitter 友好的拓扑** —— 高速 SAR（≥ 100 MS/s @ Nyquist
input）必须配高质量 clock；这是为什么 high-speed SAR 常用 time-interleaved
+ 共享低 jitter clock。

### 不要做
- ❌ **靠 oversampling 减 jitter 影响**：SAR ADC 不是 Σ-Δ，不能用 OSR 减 jitter
- ❌ **clock 链最末级用小 buffer 省 power**：边沿 100 ps+ → jitter 累积 → ENOB 损失大于 power 节省

## ⭐ 范例 5：comparator thermal noise（latch integration noise）

```
σ²_n,comp ≈ (8·k·T·γ) / (3·gm_in·t_int)
gm_in × t_int ≥ 8·k·T·γ / (3 · σ²_n,comp)
```

通常 **comparator thermal 不是主导**（offset σ_OS 是）—— 12-bit 以上 + 已校
准 σ_OS 后才主导。修复路径：增 gm_in（W ↑ 或 Id ↑）/ 增 t_int / 加 preamp /
多次 latching averaging。详见 `blocks/comparator/timing-stability`。

---

## 噪声预算 sign-off 流程（**SAR 推荐顺序**）

> 这是 **SAR 拓扑特有**的噪声预算推进顺序。**严格顺序**：从最大 budget
> 项倒推 sizing。乱序会反复推翻 C_total / W_in_pair / C_decap 等三件套。

### Phase A — Quantization budget (固定)
σ_quant = LSB/√12（不可调）。**ENOB ≥ N−0.5（严格）**: σ_total ≤ LSB/√6 →
σ_extra² = (LSB/√12)²。**ENOB ≥ N−1（V4 baseline）**: σ_total ≤ LSB/2 → 每
随机源 σ ≤ LSB/4 (4 源 RSS) 是合理起点。

### Phase B — kT/C thermal floor (定 C_total)
```
分配 σ_kTC ≤ LSB/4
C_total ≥ k·T / (LSB/4)²
此值是 thermal floor → 实际取 4× margin + matching 余量
```

### Phase C — Comparator offset budget (定 calibration plan)
```
分配 σ_OS ≤ LSB/2（系统性 offset 单独占 RMS budget 的"系统性份额"）
naked StrongARM σ_OS = 5-15 mV @ 10-bit 必须 calibration
决策：preamp / auto-zero / digital trim 三选一或组合
```

### Phase D — VREF noise + aperture jitter (定 buffer / clock)
```
分配 σ_ref ≤ LSB/4 → C_decap × R_buffer 起点
分配 σ_jitter ≤ LSB/4 → clock buffer 边沿 + PLL 选型
```

### Phase E — Comparator thermal noise (定 input pair gm)
```
σ_n,comp ≤ LSB/4 → gm_in × t_int 起点
通常 gm_in 由 σ_OS sizing 已决定（W·L 大），此项自动满足
```

### Phase F — Verify total budget
```
σ²_total = Σ σ²_i
ENOB_actual = (10·log10(V²_FS/8/σ²_total) − 1.76) / 6.02
对比 ENOB_spec → 调最差项
```

> **激活式表述**：上述 Phase A→F 是**推荐顺序**而非机械步骤。SAR ADC noise
> budget 的耦合性强（σ_OS 和 σ_n,comp 共用 input pair sizing；C_total 同时
> 影响 thermal + matching），熟练设计师可能从 Phase C（偏置最严的 offset）
> 倒推 calibration 决策，再回 Phase B 调 C_total。**核心是 5 噪声源等
> √5 分配，等到差距大才 break 平均**。

## 配套工具

| 工具 | 用途 | 何时调 |
|---|---|---|
| `simulate` `tb_linearity.sp` MC | 验 σ_OS + DNL/INL | sizing 完整 calibration plan 后 sign-off |
| `simulate` `tb_dynamic.sp` FFT | 验 ENOB / SNDR / SFDR | Nyquist input + 多频点 |
| `dc_snapshot` 看 V(vsamp) acquisition | 验 t_acq 充分（exp 衰减 < LSB/2）| acquisition phase 调 R_on / C_total |
| `inspect_node('vrefp')` ringing | 验 ΔV_ref < LSB/4 | DAC switching 后看 settling |

## When to load this chapter

- 设计 SAR ADC + spec 含 ENOB / SNDR / SFDR target
- ENOB MC 不达标（不知道哪个噪声源主导）
- 评估是否需要 calibration（offset / DAC matching）
- 决定 C_total / C_decap / clock 选型

## Related

- **W6+ R1-R4 推理铁律**：`skill: device-sizing` 通用 sizing 流程（噪声预算适用同一推理）
- **比较器 offset 抑制**：`blocks/comparator/architecture` Pitfall 1+5（preamp / Pelgrom）
- **VREF buffer 设计**：`blocks/base-cells/output-stage` (low-Z buffer) + `blocks/bandgap`
- **CDAC matching 详细分析**：`architecture.md` Pitfall 2 + `sizing-typical.md` Phase B
- **kT/C 物理推导**：`simulators/ngspice/measurements`（noise tb 写法）
- W6+ sizing 范例（W6+ sizing-2 P0-D-H 5 cell sizing-reasoning chapter）
