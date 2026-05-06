---
chapter: sizing-typical
parent: comparator
summary: |
  StrongARM comparator 顶层 spec → device 约束的因果链 + 拓扑特定推进顺序
  （**先 σ_OS budget → input pair Pelgrom → regen pair → tail switch → clock
  edge**；其它 4 拓扑变体的 sizing 顺序变体）+ 起点表（@vpdk180nm）+
  trade-off 表。引用 base-cell `comparator-latch/strongarm` 做单 device 详细
  sizing 范例。
tokens: ~1500
prerequisite_chapters:
  - architecture
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/comparator-latch
  - blocks/base-cells/differential-pair
  - blocks/base-cells/switch
---

# Comparator Sizing Typical Ranges

> 通用 sizing 方法见 `skill: device-sizing` 通用 sizing 流程。比较器内部 σ_OS / τ_reg /
> metastability 物理推导见 `blocks/base-cells/comparator-latch/strongarm.md`。
> 本章节给的是 **比较器拓扑特有**的：(1) spec → device 约束传递；(2) 拓扑
> 特定的设计推进顺序；(3) 4 变体推进顺序差异；(4) 起点表（@vpdk180nm）。

## 顶层 spec → device 约束（拓扑特定因果链）

| Comparator spec | 决定的 device 量 | 关键公式 |
|---|---|---|
| σ_OS（offset σ）⭐ | input pair W·L (Pelgrom) | σ²_OS = AVT² / (W·L) + (Vov/2)² · AB² / (W·L) |
| T_decide（决策时间）| τ_reg = C_node / gm_regen | T_decide ≈ τ_reg × ln(V_logic / ΔV_input) |
| Metastability rate | t_alloc / τ_reg | P_meta ≈ exp(-t_alloc / τ_reg) |
| f_clk max | T_decide + reset + setup | T_clk_min ≈ T_decide_worst + T_reset + T_setup |
| Aperture jitter | clock edge dCK/dt | σ_aperture = σ_t,clock / (dCK/dt × time-to-Vth_input) |
| Kickback charge | Cgd_input × ΔV_voutp | injected charge = Cgd × (rail swing 0→VDD) |
| Static power | preamp Iq + clock CV²f | StrongARM 0 static + clock CV²f；preamp 加 Iq |

## 拓扑特定的设计推进顺序 ⭐（**StrongARM 5 决策互锁**）

> 通用 sizing 流程见 device-sizing skill。本节给 **StrongARM 拓扑特有**的
> 推进顺序——σ_OS budget 是上游（决定 input pair W·L），下游所有 sizing 跟着
> 走。**严格顺序：σ_OS → input pair → regen → tail switch → clock**。

### Step 1 — 由 ADC spec 反算 σ_OS budget

```
ADC ENOB 要求 → σ_OS ≤ LSB/2（系统性 offset 单独占 RMS budget）
  10-bit / V_FS=1V → σ_OS ≤ 0.49 mV
  12-bit / V_FS=1V → σ_OS ≤ 0.12 mV    ⚠️ 超 naked StrongARM
  
naked StrongARM W·L 起点：
  W·L ≥ AVT² / σ²_OS = (5mV·µm)² / σ²_OS
  10-bit (0.49 mV) → W·L ≥ 100 µm²    （巨大 → 必须组合 calibration）
  
calibration 决策（≥ 10-bit SAR 必做）：
  - 加 preamp（gain 20-30 dB 把 σ_OS 折回 input 端）
  - Auto-zero phase（cap 存 offset 抵消）
  - Digital trim（数字校准）
```

> **R2 铁律**：单独 sizing 路径几乎不可能 < LSB/2 @ 10-bit。详见
> `architecture.md` Pitfall 1+5。**先做 calibration plan 决策，再决 input pair sizing**。

### Step 2 — Input pair sizing（Pelgrom σ_Vth 主导）

```
input pair Vov 选 0.10-0.15V（σ_OS β 项 vs Vth 项）：
  Vov ≤ 0.15V → Vth 失配主导（Pelgrom 主项，1/√(W·L) scaling）
  Vov ≥ 0.25V → β 失配项与 Vth 项可比 → β/(W·L) 也进 σ_OS

W_INP / L_INP 选取：
  L_INP = 2× Lmin（vpdk180nm 0.36 µm）→ Pelgrom σ_Vth 改善
  W_INP = W·L target / L_INP = 4-10 µm（紧凑版）/ 10-30 µm（精密 SAR）
  
gm_INP 由 W·L + Id 决定（gm/Id ≈ 14 in saturation）
```

### Step 3 — Regen pair sizing（速度 + τ_reg）

```
τ_reg = C_node / gm_regen
gm_regen ∝ √(W·L · Id)            (square-law approx)
C_node ∝ W·L                       (gate + diffusion cap)
→ τ_reg ∝ √(W·L) / √Id ≈ √W      (固定 L, Id)

固定 L_regen / Id_regen：
  W_regen ↑ → gm ↑ √W；C ↑ W → τ_reg 反向 ∝ √W (变差)
  
**结论**：单纯 W ↑ 没用；速度优化要同时考虑 Id 与 L
  - W_regen 起点 4-10 µm（紧凑版）
  - L_regen = Lmin（0.18 µm，速度优先 cascode 不需要）
  - Id_regen 由 tail switch + input pair 决定
```

> **regen pair 不要超过 W·L = 1 µm²**——速度反而劣化（架构 Pitfall 3）。

### Step 4 — Tail switch sizing（R_on + clock 边沿响应）

```
M_TAIL 是 rail-driven clock switch（不是 biased current source）：
  Vov_tail ≈ VDD - Vth_n ≈ 1.3V (CK=VDD)
  V(tail) evaluate phase 中由 R_on_tail × I_input + Vov_input 决定

要求：
  R_on_tail ≤ tail_node_settle / C_tail_node 
            ≤ T_evaluate / (10 × C_tail_node)
  典型 W_tail = 8-20 µm / Lmin → R_on ≈ 100-500 Ω

太弱 (W < 5µm)：
  - V(tail) 抬高 / sp/sn 放电斜率小 → 初始差分小 → metastability 升
  - 见 architecture.md Pitfall 4
```

### Step 5 — Clock edge + Bridge / Reset sizing

```
Clock edge spec：
  edge rate ≤ 30 ps (90% swing rise/fall)
  dCK/dt ≥ 60 V/ns @ 1.8V
  
Buffer chain 设计：
  最末级 W 大（match drive C_clock_load）
  fanout ≤ 4 per stage
  buffer chain 层数 = log₄(C_total_load / C_min)

Bridge / Reset PMOS sizing：
  W_bridge / W_reset 同量级（典型 4 µm / Lmin）
  - 太小：reset 不到 VDD，evaluate phase 起点不一致
  - 太大：CV²f power + clock load 增
```

### Step 6（可选）— Preamp sizing

```
若 spec σ_OS < LSB/2 不满足且 input pair sizing 已 Pelgrom 极限：
  Preamp gain ≥ 20-30 dB（折射 σ_OS 到 input：σ_OS_total ≈ σ_OS_latch / A_preamp）
  Preamp BW ≥ 5× f_clk（不限 comparator 速度）
  
Preamp 拓扑：5T-OTA 或 cascode-OTA（见 blocks/5t-ota）
  典型 input pair W=10µ/L=0.5µ；Itail = 10-50 µA
```

### 推荐建议（不强制）

> 这 6 步是 **StrongARM 拓扑特有**的推进顺序，不是机械流程。**Step 1（σ_OS
> budget + calibration plan）必须先做**——它决定要不要加 preamp，preamp 决定
> 是否包一层 OTA。**Step 2（input pair）耦合 Step 1**：先做 calibration 决策
> 后才能确定 input pair 是否需要超大 W·L。Step 3-5 之间互相耦合较少（regen
> 速度 / tail switch / clock 各自独立 trade-off）。

## 4 拓扑变体的推进顺序差异

| 变体 | 关键差异 | 推进顺序变化 |
|---|---|---|
| **StrongARM**（默认）| 上述 6 步 | 标准顺序 |
| **Preamp + StrongARM** | 加 Step 0：先 sizing preamp（gain + BW + Iq）| Step 0 → 1 → 2 → ... |
| **Dynamic comparator** | 无 cross-coupled regen，无 Step 3 | 1 → 2 → 4 → 5 |
| **Continuous-time hysteresis** | 无 clocked，无 Step 4-5；加 R1/R2 hysteresis ratio | 1 → 2 → V_hys ratio |

## 起点表（@vpdk180nm，VDD=1.8V，fclk ≤ 500 MHz，10-bit ADC σ_OS ≤ 10 mV）

| 设备 | role | W | L | m | gm/Id | Vov | 关键约束 |
|---|---|---|---|---|---|---|---|
| M_INP / M_INN | NMOS input pair | 4 µm | 0.36 µm | 1 | ~14 | 0.10-0.15 V | **L = 2× Lmin** 减 Pelgrom σ_Vth |
| M_TAIL | NMOS tail switch | 8 µm | 0.18 µm | 1 | — | — | rail-driven switch；R_on 主导 |
| M_DP / M_DN | NMOS bridge | 4 µm | 0.18 µm | 1 | — | — | 短沟道速度 |
| M_RP / M_RN | PMOS reset | 4 µm | 0.18 µm | 1 | — | — | 充 voutp/voutn 到 VDD |
| M_LP / M_LN | PMOS regen | 4 µm | 0.18 µm | 1 | — | — | W·L ≤ 1 µm²（架构 Pitfall 3）|
| Preamp(if needed) | 5T-OTA input | 10 µm / 0.5 µm | 1 | ~12 | 0.15 V | gain ≥ 20-30 dB |
| Preamp Itail | 5T-OTA tail | 20 µm / 0.5 µm | 2 | ~10 | 0.20 V | 10-50 µA per leg |

⚠️ **数值标 @vpdk180nm**：换工艺时 AVT / µ·Cox / Vth 不同，要重新算。
跨工艺通用：σ_OS Pelgrom 1/√(W·L) scaling + Vov 0.1-0.15V sweet spot +
W·L_regen ≤ 1 µm² 速度上限 + clock edge ≤ 30 ps。

## Trade-off 表（按 comparator FOM 维度）

| 调整 | σ_OS | speed | kickback | static power | area | 备注 |
|---|---|---|---|---|---|---|
| W·L_input ↑（10× 面积）| ↑↑（√10 = 3.2× 改善）| —（regen 主导速度）| —（Cgd 增同步影响）| — | ↑↑ | 粗暴减 σ_OS 路径 |
| L_input ↑（Lmin → 2×Lmin）| ↑（σ_Vth ↓）| ↓（gm ↓）| — | — | ↑ | sweet spot：double L 减 σ_OS |
| Vov_input ↓（0.25 → 0.10V）| ↑（β 项消失）| ↓（gm ↓ → τ_reg ↑）| — | — | — | weak inversion 边界 |
| W·L_regen ↑ | — | ↓↓（C_node ↑ 但 gm 改善有限）| — | —（CV²f ↑）| ↑ | 反 intuition：regen ↑ 让 τ_reg 劣化 |
| W_tail ↑ | — | ↑（V(tail) 不抬，sp/sn 放电快）| — | —（CV²f ↑）| ↑ | 加 tail switch 是改善 metastability 主路径 |
| Clock edge ↓（100 → 30 ps）| —（σ_OS 不变）| ↑（aperture jitter ↓）| —（短瞬态电流大但快）| —（buffer 大 → CV²f 大）| ↑（buffer chain 大）| 高速 SAR 必做 |
| 加 preamp | ↑↑（折射 σ_OS / preamp gain）| ↓（preamp BW 限速度）| ↑↑（隔离 latch kickback）| ↑（preamp Iq）| ↑ | 10-bit + SAR 标配 |
| 加 chopper / auto-zero | ↑↑↑ | ↓↓（增 phase 周期）| —| ↑（switch CV²f）| ↑↑ | 12-bit 以上慢 SAR / 仪器 |

## 不在本章范围

- **gm/Id 通用 sizing 方法** → `skill: device-sizing`（通用 sizing 流程）
- **input pair / regen pair 单 device 详细物理推导（含 σ_OS / τ_reg / metastability 公式起点）** → `blocks/base-cells/comparator-latch/strongarm` § sizing 范例（10-bit / 100 MSPS SAR ADC 实战）
- **clock generator / non-overlap circuit 详细电路** → `blocks/base-cells/switch` + clock distribution knowledge
- **Preamp 5T-OTA / cascode-OTA 详细 sizing** → `blocks/5t-ota` / `blocks/folded-cascode-ota`
- **架构选型（4 变体对比 / 决策树）** → `architecture.md`
- **τ_reg 决策时间 / metastability error rate / aperture jitter 详细分析** → `timing-stability.md`
- **MC sweep + metastability testbench** → `blocks/base-cells/comparator-latch/strongarm` § Metastability + `simulators/ngspice/analyses` § MC
- **Standard cir + 4 testbench** → `reference-design.md`

## Related

- `architecture.md` 4 拓扑对比 + 7 sizing pitfalls（含 σ_OS / clock edge / regen W·L 详细 trade-off）
- `timing-stability.md` τ_reg / metastability / aperture jitter 完整分析
- `reference-design.md` Standard StrongARM 网表 + sizing 起点
- `blocks/base-cells/comparator-latch/strongarm` 物理 source of truth + sizing 范例
- `blocks/base-cells/differential-pair` Pelgrom matching
- `skill: device-sizing` 通用 sizing 流程 + R1-R4 铁律
