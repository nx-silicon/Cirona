---
chapter: timing
parent: sar-adc
summary: |
  SAR ADC 拓扑特有的时序分析 — 同步 SAR 12 cycle 时序分配 / 异步 SAR ready
  signal 自适应 / DAC settling τ / comparator decision time / SAR FSM register
  transparency / clock distribution + jitter。类比 OTA ac-stability：SAR 没
  传统 PM，但有 cycle timing margin 与 metastability 错误率。
tokens: ~1500
prerequisite_chapters:
  - architecture
related_skills:
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/comparator
  - blocks/base-cells/switch
---

# SAR ADC Timing Analysis

> 通用 ngspice tran 时序测量见 `simulators/ngspice/analyses`（pulse / non-overlap）。
> 比较器 metastability / clock 边沿物理见 `blocks/comparator/timing-stability`。
> 本章节给的是 **SAR ADC 拓扑特有**的：(1) 同步 / 异步 cycle 时序分配；
> (2) 跨子模块时序耦合（DAC settle ↔ comparator decide ↔ FSM register）；
> (3) timing margin 与跨 corner 退化模式。

## 同步 SAR 时序（12 cycle / N+2 cycle 标准）

### Cycle 划分

```
T_clk = 1 / f_clk
total = (N + 2) × T_clk      (本 reference 设计 12 cycle for 10-bit)

Cycle 0 (Sample): S&H bootstrap on, bottom-plate switches all to V_CM
Cycle 1-N (Bit trial): 第 i bit cycle 内顺序：
   t=0:           clk_dac rising → bottom-plate switch toggle (vrefp ↔ vrefn)
   t=t_dac:       DAC settled to LSB/4
   t=t_dac+t_d:   clk_cmp rising → StrongARM evaluate
   t=t_dac+t_d+t_decide: comparator output valid
   t=t_dac+t_d+t_decide+t_fsm: SAR register update + ready for next cycle
Cycle N+1 (Load): eoc=1, dout latched to output register
```

### 每 cycle 时序预算（**SAR 推进顺序**）

| 阶段 | 物理 | 典型值 (10-bit / 10MS/s, vpdk180nm) |
|---|---|---|
| t_dac (DAC settle) | RC settle to LSB/4：`(N+2)·τ_dac` | 5 ns（C_total=10pF, R_switch=50Ω → τ=500ps × 11 = 5.5 ns）|
| t_cmp_setup (comparator latch start) | 边沿稳定 + propagation | 200-500 ps |
| t_decide (regen + meta) | `τ_reg · ln(V_logic/ΔV_input)` | 200-500 ps（input ≥ LSB；< LSB 会 metastable）|
| t_fsm (FSM register + decode) | 数字 FF + decoder | 0.5-1 ns |
| total per cycle | sum | 7-8 ns → f_clk ≤ 125 MHz for sync 10-bit |

### **Timing Iron Law**：每阶段 margin ≥ 20%

```
spec timing < 80% × actual minimum timing → 跨 corner 必失败
  - FF corner：所有时序 1.3× faster → 之前 80% margin 现在 +50% 余量
  - SS corner：所有时序 0.7× slower → 之前 80% margin 变 50% 不够 → DNL 退化
```

跨 corner 退化模式典型：
- **DAC settle 不够** (SS): DNL spike at MSB transition（settling 缺 LSB/4 余量）
- **comparator metastable** (SS): DNL random spike + ENOB 退化
- **FSM setup violation** (FF + clock skew): bit decision 错乱 → DNL 全频带漂

## ⭐ 范例 1：DAC settle 不够 → DNL spike at MSB transition

### 症状
跨 corner SS @ -40°C 时 tb_linearity DNL 在 code 0x200 → 0x1FF transition
处出现 +1.5 LSB spike；TT @ 27°C OK。

### R1 KVL 反推
```
DAC settling 是 RC 充放电：
  ΔV_settle(t) = ΔV_step × (1 - exp(-t/τ))
  τ_dac = R_total × C_total
  
R_total = R_switch (TG) + R_buffer (VREF buffer)

要求 settling error < LSB/4：
  exp(-t_dac / τ) < LSB/(4 × ΔV_step)
  t_dac / τ > ln(4 × ΔV_step / LSB)
  worst case ΔV_step = V_FS / 2 (MSB transition):
    t_dac / τ > ln(2^(N+1)) = (N+1)·ln 2
    10-bit → t_dac > 11 × 0.693 × τ = 7.6 τ_dac
```

SS corner τ_dac 增 30% (μ ↓ + Vth ↑ → R_switch ↑) → 设计边界 80% margin 全吃光。

### 三条调节路径
**路径 A — 增 t_dac（降 f_clk）**：
- 直接保 settling 余量 → DNL 救回
- 副作用：sample rate 直接下降

**路径 B — 减 R_switch（增 W_switch）**：
- C_total 同步增（switch parasitic cap）→ τ 反向减得不多
- 推荐：增 W_switch 50% + 增 t_dac 50%

**路径 C — 增 C_decap_ref（减 R_buffer 等效）**：
- VREF 端贡献的 ΔV_ref 减 → DAC settle 同步加快
- 见 `noise-budget.md` Phase F

### R3 推理
```
看到跨 corner DNL spike at MSB
  ↓
inspect_node('vrefp'): 看 VREF settle 时间 vs cycle 时序
  ↓
inspect_node('vsamp'): 看 DAC settle 时间是否 ≥ (N+1)·τ
  ↓
对比 TT vs SS τ_dac: τ 增 30% 是常态
  ↓
调 t_dac (cycle 时序) 或调 R_switch / C_decap
```

### 不要做
- ❌ **加大 C_total 想让 cap "稳"**：τ_dac = R × C 反向增；DAC settle 更慢
- ❌ **跳 SS corner verification 只测 TT**：跨 corner 时序退化是 SAR 实战的主要 fail 模式

## ⭐ 范例 2：Comparator metastable → DNL random spike

### 症状
tb_linearity MC 100 次跑出来 single sample DNL 偶发 ±5 LSB spike（不是
systematic 偏移），频率 ~ 1/1000 conversion；ENOB MC σ ≈ 0.5 bit。

### R1 KVL 反推
```
StrongARM regen: V_out(t) = ΔV_input × exp(t/τ_reg)
要 V_out 达数字 logic level (典型 V_DD/2 = 0.9V)：
  t_decide = τ_reg × ln(V_logic / ΔV_input)
  
最坏情况 ΔV_input = LSB/2 (在 1 LSB 决策边界附近)：
  t_decide_max = τ_reg × ln(V_logic / (LSB/2))
              = τ_reg × ln(2^(N+1) × V_logic / V_FS)
              = τ_reg × (N+1) × ln(V_logic / (V_FS/2))
              ≈ 11 × τ_reg @ 10-bit / V_FS=1V / V_logic=0.9V

如果 cycle 给 t_decide < 11·τ_reg → metastable 概率 ≈ exp(-t_alloc/τ_reg)
  τ_reg = 200 ps，t_alloc = 1 ns → exp(-5) = 0.7%
  τ_reg = 200 ps，t_alloc = 2 ns → exp(-10) = 0.005%
  τ_reg = 200 ps，t_alloc = 3 ns → exp(-15) = 3e-7  ← 实用
```

### 调节路径
| 路径 | 怎么做 | 效果 |
|---|---|---|
| 增 t_decide cycle 分配 | 减 f_clk 或减 N+2 cycles | 直接减 metastable 概率 |
| 减 τ_reg | 增 gm_regen / 减 C_node | regen 更快 |
| 加 preamp | gain 30 dB → ΔV_input × 30 → t_decide 减 | 见 comparator |
| Async SAR | 内部 ready signal 等 comparator done | 自适应避免 metastable |

> **R2 铁律**：metastable 概率 **指数 decay**——cycle 时序加 50% 通常让概率
> 减 1000×。**不要靠"运气"**——按 worst-case input ΔV = LSB/2 算最差 t_decide。

### 不要做
- ❌ **靠 input ΔV 大平均掉 metastable**：错误是非线性，averaging 不消
- ❌ **加 latch 后 buffer 想"消"metastable**：metastable 信号一旦传给后级
  digital 电路会 propagate → 全 SAR FSM 崩

## ⭐ 范例 3：FSM clock skew → bit decision 错乱

### 症状
fclk 100 MHz 时 DNL OK；fclk 升到 130 MHz 时 DNL 全频带退化；不是单点 spike。

### R1 KVL 反推
```
FSM 串行时序：
  t1: clk_cmp rising → comparator latch
  t2: comparator output valid (after t_decide)
  t3: clk_dac rising → SAR register update + DAC switch
  
要求：t3 - t2 ≥ t_setup_FSM (典型 0.5-1 ns @ vpdk180nm)
跨 clock 网络 skew ≤ t3 - t2 - t_setup_FSM
```

f_clk ↑ → cycle 各阶段 budget 同步压缩 → setup margin 先撞墙。

### 修复
| 路径 | 怎么做 |
|---|---|
| Reduce clock skew | 平衡 clock tree balanced；clock buffer 配对 |
| 增 t_decide budget | 见范例 2 |
| Async SAR | 各阶段自触发，不 share global clock 的 setup |

> **跨 corner 影响**：FF corner 让所有时序 30% 快，但 clock skew 不变 →
> setup margin 增加（不是问题）；SS corner 让 setup time 增 + clock 同步慢 →
> setup margin 减少 → 高 fclk 下先撞墙。**跨 corner timing 验证必跑**。

## 异步 SAR (asynchronous) 时序

```
异步 SAR 不依赖 global clock 推进每 cycle，而是用 "ready" 信号自适应：

Bit cycle:
  comparator_done → trigger DAC switch (immediately)
                  → DAC settle (waits internal "settle_done" detector)
                  → trigger next comparator (immediately)
```

**优势**：
- 平均 cycle ≈ τ_DAC + t_decide + t_FSM ≈ 1.5-2 ns（无 worst-case margin 浪费）
- 10-bit @ 100 MS/s 可达；同步 SAR 仅 ~ 30 MS/s

**代价**：
- 需要 settling 检测器 / metastable 检测器
- 数字逻辑复杂（async FSM）
- 跨 corner 仍然需要 cycle 平均时序 budget

> **何时用 async**：≥ 50 MS/s SAR ADC 标配；< 10 MS/s 通常 sync 简单足够。

## CL（输出 driver） 对 timing 的影响

CDAC 的 dout output bus driver：
```
t_load (cycle N+1) = R_driver × C_load_per_pin × (N_bits + ln(2))
  C_load_per_pin = 100 fF (typical pad / ESD / package routing)
  N_bits = 10
  R_driver < t_load / (C_load × (N+1)) = ?
```

通常 SAR ADC 输出是 latched register → 下个 stage（Verilog 数字处理或 SerDes
output buffer），不直接驱动外部 cap。**不用太担心 t_load**——除非 driving
external scope probe（10pF）测试用。

## 跨 corner timing 验证清单

| 检查项 | TT @ 27°C | FF @ -40°C | SS @ 125°C |
|---|---|---|---|
| DAC settle (≥ 7.6 τ) | ✅ | ✅（更快）| ⚠️ 校验 t_dac 余量 |
| comparator metastable | < 1e-6 | < 1e-6 | ⚠️ 校验 t_decide |
| FSM setup margin | ≥ 20% | ✅（更快）| ⚠️ 校验 setup time |
| VREF settle (after switching) | ✅ | ✅ | ⚠️ 校验 buffer BW + decap |
| Clock skew tolerance | ≤ 100 ps | ≤ 70 ps | ≤ 130 ps |
| Aperture jitter | σ_t ≤ 16 ps | σ_t ≤ 16 ps | σ_t ≤ 16 ps（PLL 工艺独立）|

> **SS @ 125°C 是 SAR ADC sign-off 关键 corner**——所有时序最慢 + 最难 settle。

## 不在本章范围

- **比较器 metastability 物理**（τ_reg 推导 + thermal noise 起源）→ `blocks/comparator/timing-stability`（W7）+ `blocks/base-cells/comparator-latch/strongarm`
- **bootstrap switch acquisition settling** → `blocks/base-cells/switch/bootstrapped`
- **VREF buffer + ringing** → `noise-budget.md` § VREF + `blocks/base-cells/output-stage`
- **noise budget 与 timing 联合分析** → `noise-budget.md` Phase F (jitter / metastable noise)
- **clock generation / PLL jitter** → `systems/pll`（W9+）/ clock distribution knowledge
- **SAR FSM RTL** → 数字 IC knowledge

## Related

- `noise-budget.md` ⭐ jitter / metastable noise 入预算
- `blocks/comparator/timing-stability` τ_reg / metastability 物理
- `blocks/base-cells/switch/bootstrapped` acquisition settling
- `simulators/ngspice/analyses` pulse / .meas 时序写法
- `architecture.md` Pitfall 6（SAR FSM clock skew）
