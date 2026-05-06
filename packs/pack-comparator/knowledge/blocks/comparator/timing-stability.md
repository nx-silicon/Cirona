---
chapter: timing-stability
parent: comparator
summary: |
  ⭐ Comparator 时序稳定性（"灵魂章"，类比 OTA ac-stability）— τ_reg 物理 +
  metastability error rate 指数 decay + clock edge / aperture jitter / latency
  时序预算 + 失稳调整范例。Comparator 没传统 PM，但有 dynamic stability —
  metastability 错误率 ↔ regen 时间预算 是核心约束。物理推导见 base-cell。
tokens: ~1700
prerequisite_chapters:
  - architecture
related_skills:
  - circuit-method/signal-tracing
  - meta-cognitive/systematic-debugging
related_knowledge:
  - blocks/base-cells/comparator-latch
  - simulators/ngspice
---

# Comparator Timing & Stability

> 物理推导（τ_reg 起源 / metastability 概率公式 / aperture jitter 转换）见
> `blocks/base-cells/comparator-latch/strongarm.md`。本章节给的是 **comparator
> 拓扑特有**的：(1) StrongARM 三相工作流时序预算；(2) τ_reg / metastability
> 指数 decay；(3) clock edge ↔ aperture jitter 转换；(4) 时序失稳调整范例。

## 三相工作流时序预算（StrongARM 默认）

```
Phase 1 (Reset): CK=0, T_reset
   - voutp/voutn 充到 VDD（reset PMOS 主导）
   - tail switch off, sp/sn 浮空
Phase 2 (Evaluate): CK=VDD start, T_evaluate
   - tail switch on, input pair 放电 sp/sn
   - bridge 让 voutp/voutn ↔ sp/sn 跟随
   - 初始差分 ΔV_initial 在 sp/sn 上建立
Phase 3 (Regen): T_evaluate 末段
   - voutp/voutn 跌出 PMOS regen 阈值
   - cross-coupled regen 启动正反馈
   - voutp/voutn 一边跌到 0，一边升到 VDD
```

### 时序预算（典型）

| 阶段 | 物理 | 典型值（vpdk180nm @ fclk=500MHz）|
|---|---|---|
| T_reset | RC settle voutp/voutn → VDD | 200-500 ps |
| T_evaluate | sp/sn 放电 + ΔV_initial 建立 | 200-500 ps |
| T_regen | regen + ln(V_logic / ΔV_initial) | 200-1000 ps（取决于 ΔV_input）|
| T_total | reset + evaluate + regen + setup | 1-2 ns @ 500 MHz fclk |

> **fclk 上限**：T_total < 1/fclk × duty / 50%（典型 50% duty CK=VDD = T_evaluate + T_regen）。
> 500 MHz fclk → CK=VDD 时间 ≤ 1 ns，需要 T_evaluate + T_regen ≤ 1 ns。

## τ_reg：regen 时间常数（**comparator 灵魂物理**）

```
τ_reg = C_node / gm_regen
       = (Cgs_M_LP + Cgs_M_LN + Cdb_others) / gm_M_LP
       
其中：
  C_node ≈ 100-500 fF (vpdk180nm regen pair W=4µ/L=0.18µ)
  gm_M_LP ≈ √(2·µp·Cox·W/L · |Id|) ≈ 200-500 µS
  τ_reg ≈ 100-500 ps
```

### Regen 决策时间公式

```
T_decide = τ_reg × ln(V_logic / ΔV_input)

V_logic = 数字逻辑识别电压差（typical V_DD/2 = 0.9V）
ΔV_input = sp/sn 初始差分（在 evaluate 末段值）
ΔV_input ≈ gm_input × ΔV_diff_input × T_evaluate / C_sp_node

worst case ΔV_input = LSB/2（在 1 LSB 决策边界）：
  10-bit / V_FS=1V → ΔV_input = 0.49 mV
  T_decide_worst = τ_reg × ln(0.9V / 0.49mV) = 7.6 × τ_reg
  
typical ΔV_input = LSB → T_decide_typical = 6.5 × τ_reg
```

> **R2 决策时间铁律**：T_evaluate phase 必须 ≥ 7-10 × τ_reg，否则 worst-case
> 输入差分（< LSB/2）会 metastable。**ADC 高速场景下 τ_reg 是 fclk 上限 物理
> 来源**——τ_reg = 200 ps + 10× 余量 → CK=VDD ≥ 2 ns → fclk ≤ 250 MHz。

## Metastability error rate（**条件指数 decay**）

```
P(metastable) ≈ P(|ΔV_initial| < V_threshold) · exp(-t_alloc / τ_reg)

t_alloc = 实际给定的 regen / resolve 时间
τ_reg  = comparator 设计参数
P(|ΔV_initial| < V_threshold) = 输入差分落入近阈值小窗口的概率
                                （取决于输入分布 + ADC LSB scale）
```

**完整 metastability 概率有两项**：
1. **前置项**：input 落入 critical window（差分小到不能在 t_alloc 内 resolve）的概率
2. **指数项**：已落入 critical window 后，t_alloc 内仍未 resolve 的条件概率

### Conditional exp tail 快速估算表

下表给的是**已落入 critical window 时**的 conditional resolve failure rate：

| t_alloc / τ_reg | conditional exp tail | 应用 |
|---|---|---|
| 5× | 6.7e-3 | 慢 SAR (10 MS/s)，可容 |
| 10× | 4.5e-5 | 中速 SAR (100 MS/s) |
| 15× | 3.1e-7 | 高速 SAR (>500 MS/s) |
| 20× | 2.1e-9 | 仪器级 / 容错严苛 |
| 25× | 1.4e-11 | 通信 SerDes RX (BER < 1e-12) |

> **系统总错误率**还要乘前置项 `P(|ΔV_initial| < V_threshold)`——SAR ADC 中
> 这等于 input 落入 ±LSB/2 周边窗口的概率。**指数 decay 物理**：每加一个 τ_reg，
> conditional tail 减 e ≈ 2.7×。**不要靠"运气"减 metastable**——按 BER spec
> 反推 t_alloc 倍数。

### 失败模式：t_alloc < 5× τ_reg

```
症状：tb_metastab_mc 跑 1e6 conversion 后错误率 > 1e-3
影响：ADC ENOB 退化 0.5+ bit；SerDes BER > spec
诊断：算 (t_alloc, τ_reg) 比例
修复：
  - 增 t_alloc（减 fclk 或减 N+2 cycles in SAR）
  - 减 τ_reg（增 gm_regen 或减 C_node，见架构 Pitfall 3）
  - 加 preamp（gain × g_m → 减需要的 ΔV_input → 减 ln(...)）
  - Async SAR（自适应等 comparator done）
```

## ⭐ 范例 1：metastability 错误率 > spec（high-speed SAR）

### 症状
spec：fclk=500 MHz / SAR conversion N+2=12 cycle / 错误率 < 1e-7。
实测错误率 ≈ 1e-4。

### R1 KVL 反推
```
T_per_cycle = 1/500MHz = 2 ns
T_evaluate ≈ 1 ns（duty 50%）
T_regen 占 ~ 1 ns
τ_reg = 200 ps（实测 / sizing）
t_alloc / τ_reg = 1 ns / 200 ps = 5
conditional exp tail ≈ exp(-5) = 6.7e-3
系统总错误率 = 6.7e-3 × P(input 落入 critical window) → 远高于 spec 1e-7 不达标
```

### 三条调节路径
**路径 A — 减 τ_reg**（架构 sizing）：
- 增 gm_regen（W·L 减但 Id 增）
- 减 C_node（W·L 减小，但不能太小破速度）
- 见架构 Pitfall 3：W·L_regen ≤ 1 µm²

**路径 B — 增 t_alloc**（系统时序）：
- 减 fclk（spec 不允许）
- 加 async SAR（自适应等）

**路径 C — 减需要 ΔV_input**：
- 加 preamp（gain × g_m_preamp → ΔV_input 进 latch 已 × gain）
- ln(V_logic / (ΔV_input × A_preamp)) 减 → t_alloc 需求减

### Anti-pattern
- ❌ **靠加大 W_regen 想减 τ_reg**：C_node ↑ 主导 → τ_reg 反而增（架构 Pitfall 3）
- ❌ **靠 input ΔV 大平均掉 metastable**：错误是非线性，averaging 不消
- ❌ **加 latch 后 buffer 想"消" metastable**：错误信号已 propagate

## ⭐ 范例 2：Aperture jitter 主导 SNDR（high-frequency input）

### 症状
spec：10-bit SAR @ 100 MS/s / Nyquist input 50 MHz / SNDR ≥ 60 dB。
DC 测 SNDR 60 dB OK；fin = fs/2 测 SNDR 55 dB（jitter 限制）。

### R1 KVL 反推
```
σ_aperture = σ_t,clock × (input dV/dt at sample)
           = σ_t,clock × 2π·f_in × A_signal

σ_t,clock 来源：
  - PLL jitter (~ 1-5 ps RMS)
  - clock buffer chain accumulation (~ 0.5-2 ps per stage)
  - clock distribution skew

要 σ_aperture ≤ LSB/4 = 244µV:
  σ_t,clock ≤ LSB/4 / (2π · f_in · A) 
           = 244µV / (2π · 50MHz · 0.5V)
           ≈ 1.6 ps  ⚠️ 极严
```

### 调节路径
| 路径 | 怎么做 | 效果 |
|---|---|---|
| Clock edge ↑（30 ps → 15 ps）| 增 clock buffer 末级 W | 减 buffer 链 σ_t 累积 |
| LC-VCO PLL（不是 ring-VCO）| 高质量 clock source | jitter 100s fs 级 |
| 减 input swing | A_signal ↓ | 直接减 σ_aperture（牺牲 SNR）|
| 限 fin（baseband only）| 物理回避 | 应用层决策 |

### R2 铁律
**SAR ADC 不是 jitter 友好的拓扑**——高速 SAR @ Nyquist 必须配高质量 clock。
详见 `systems/pll`（W9+）。

## ⭐ 范例 3：Clock edge 太慢 → CV²f short-through

### 症状
tb_tran 在 CK 上升 / 下降边沿期出现 100 mV+ 毛刺；CV²f 实测比理论高 2-3×。

### R1 物理因果
```
CK 边沿期间（CK 从 0 到 VDD 上升）：
  - reset PMOS（M_RP）: 当 CK < VDD − |Vtp| 时 ON → voutp 与 vdd 仍连
  - tail NMOS（M_TAIL）: 当 CK > Vth_n (≈ 0.5V) 时 ON → tail 已开始放电
  - 重叠窗口约 30-100 ps（边沿期里 CK 从 Vth_n 到 VDD-|Vtp| 的时间）

通过 voutp → reset PMOS → vdd → vss → tail NMOS → vss 的 short-through 通路
有瞬态电流，bigger if edge 慢
```

### 修复
```
edge rate ≤ 30 ps (90% rise/fall) → short-through 窗口 < 30 ps → 损耗可控
edge rate ≥ 100 ps → CV²f 翻倍 + 毛刺大
```

> 详见 architecture Pitfall 7。

## ⭐ 范例 4：Tail switch 太弱 → V(tail) 抬高 → metastability

### 症状
tb_metastab_mc 错误率比理论高 5-10×；DC tb_dc_op 看 V(tail) 在 evaluate
phase 偏高（应 ~ 0.25V，实测 ~ 0.5V）。

### R1 物理因果
```
M_TAIL 是 rail-driven clock switch（不是 biased current source）：
  R_on_tail = 1 / (µn·Cox·W/L · (Vov_tail))
  Vov_tail ≈ VDD - Vth_n ≈ 1.3V (CK=VDD)
  
W_tail 太小 → R_on 大 → 在固定 input pair gm 下：
  V(tail) = V_input - Vgs_input ↑ (input pair Vds ↓)
  sp/sn 放电斜率 ↓（受 R_on_tail 限）
  ΔV_input on sp/sn 减 → t_alloc 需求增 → metastability ↑
```

### 修复
```
W_tail ↑（典型 8 → 12-20 µm @ vpdk180nm）→ R_on_tail ↓
检查 V(tail) evaluate 中段值是否 ≤ Vov_input + 50 mV

副作用：
  - clock load ↑ → CV²f ↑（CK 转换功耗）
  - W_tail 大 → tail node parasitic cap 增（轻微影响）
```

详见 architecture Pitfall 4。

## 多极点 / 类 PM 分析（可选 — preamp + StrongARM 系统）

```
Preamp + StrongARM 复合架构有 2-3 个时间常数：
  τ_preamp = 1/(2π · BW_preamp) ≈ 100 ps - 1 ns
  τ_evaluate = 由 sp/sn RC 决定 ≈ 100-500 ps
  τ_regen = 100-500 ps

类 PM = 任意两 τ 接近 → response ringing / aperture noise
要求：BW_preamp >> 1/T_evaluate （preamp 已 settle 到 latch 起点）
       即 BW_preamp ≥ 5 × f_clk
```

## ngspice testbench 关键

### tb_metastab_mc.sp（metastability 错误率验证）

详见 `blocks/base-cells/comparator-latch/strongarm.md` § Metastability。
基本流程：
- input slow ramp 覆盖 ±3σ_OS 区间
- clock 周期采样 + 统计输出方向是否正确
- 错误率 = 错误次数 / 总次数；目标 < 1e-7（高速 SAR）

### tb_aperture_jitter.sp

```spice
* Vinp 用 sin 信号 + 在 sample 时刻加 σ_t jitter
Vinp vinp 0 SIN(VCM A_signal f_in)
Vclk clk 0 PULSE(0 1.8 5n+JITTER 30p 30p 1n 2n) $ JITTER 是 stochastic delay
* MC sweep JITTER ~ N(0, σ_t)
```

主机侧 post-process 算 SNDR / σ_aperture。

## 不在本章范围

- **σ_OS / τ_reg / metastability 物理公式起点**（Pelgrom / square-law / regen
  thermal noise）→ `blocks/base-cells/comparator-latch/strongarm`
- **σ_OS sizing 范例（input pair W·L 反推）** → `sizing-typical.md` Step 1-2 +
  base-cell § sizing 范例
- **clock generator / non-overlap circuit** → `blocks/base-cells/switch` +
  clock distribution knowledge
- **PLL jitter source** → `systems/pll`（W9+）
- **Async SAR ready signal** → `blocks/sar-adc/timing.md`（非 comparator 子模块层）
- **架构选型（4 变体对比 / 决策树）** → `architecture.md`

## Related

- `architecture.md` Pitfall 2 (clock edge), Pitfall 3 (W·L_regen), Pitfall 4 (tail switch), Pitfall 7 (short-through)
- `sizing-typical.md` Step 4-5 (tail switch + clock edge sizing)
- `reference-design.md` clock edge spec + tb_tran_clock 模板
- `blocks/base-cells/comparator-latch/strongarm` σ_OS / τ_reg / metastability 物理 source of truth
- `blocks/sar-adc/timing` SAR ADC 系统级 timing（comparator metastable 进 ADC ENOB）
- `simulators/ngspice/analyses` MC sweep / pulse / .meas 时序写法
