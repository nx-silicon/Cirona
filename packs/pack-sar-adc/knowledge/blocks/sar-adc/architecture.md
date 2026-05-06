---
chapter: architecture
parent: sar-adc
summary: |
  4 拓扑变体对比（charge-redistribution / bottom-plate sampling / merged-cap
  switching / asynchronous）+ ENOB 决策树 + 7 sizing pitfalls（C_unit kT/C
  noise / CDAC σ(C)/C matching / bootstrap C_b droop / comparator offset /
  VREF ringing / SAR FSM timing margin / charge injection）。物理推导见
  base-cell（comparator-latch / switch）。
tokens: ~1700
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/comparator
  - blocks/bandgap
  - blocks/base-cells/switch
  - blocks/base-cells/comparator-latch
---

# SAR ADC 架构

## 拓扑选择三轴

SAR ADC 拓扑由三个**独立**决策组合：

| 轴 | 选项 | 关键决策依据 |
|---|---|---|
| Sampling location | top-plate / bottom-plate | ENOB target（top-plate 受 signal-dependent charge injection 限）|
| DAC switching | conventional / monotonic / merged-cap (MCS) | 功耗 budget（MCS 减 ~85% switching energy）|
| Clock 模式 | synchronous / asynchronous | conversion rate（async 内部 ready 触发，2× speed 提升）|

**典型组合**（按工程实践）：

| 组合 | 落地拓扑 | 应用 |
|---|---|---|
| top-plate + conventional + sync | **Charge-redistribution**（经典）| 教学 + 通用 8-12 bit |
| bottom-plate + conventional + sync | **Bottom-plate sampling** | > 12-bit 高精度 SAR |
| top-plate + MCS + sync | **Merged-cap (monotonic)** | 低功耗 SAR / IoT |
| top-plate + conventional + async | **Asynchronous SAR** | 高速 SAR（≥ 100 MS/s）|

## 4 拓扑变体对比

| 拓扑 | ENOB 上限 | conversion rate | switching energy | clock 复杂度 | 关键限制 |
|---|---|---|---|---|---|
| **Charge-redistribution**（经典）| 10–12 bit | fclk / (N+2) | 1× （baseline）| 简单 | top-plate signal-dependent charge injection |
| **Bottom-plate sampling** | 12–14 bit | fclk / (N+3) | 1.2× | 复杂（dummy switch + non-overlap）| 时序要求严 |
| **Merged-cap (monotonic)** | 10–12 bit | fclk / (N+2) | **0.15×** | 中（switching scheme）| trade-off ENOB linearity |
| **Asynchronous** | 10–12 bit | **2× sync** | 1.1× | 内部 ready signal | timing margin 设计 |

> **物理推导出处**：comparator (StrongARM) / S&H switch (bootstrapped) / kT/C noise / CDAC matching 物理推导见各自 base-cell 或 block knowledge（`blocks/base-cells/comparator-latch/strongarm` / `blocks/base-cells/switch/bootstrapped` / `blocks/comparator/architecture`）。本表是应用层数值范围摘要。

## ENOB / SFDR 决策树（按 spec 反推）

| Spec 关键字 | 推荐拓扑 |
|---|---|
| 8-10 bit / 1-10 MS/s / 通用 | **Charge-redistribution**（默认）|
| 10-12 bit / IoT / 极低功耗（µW 级）| **Merged-cap (monotonic)** |
| 12-14 bit / 高精度 / 仪器仪表 | **Bottom-plate sampling**（+ digital calibration）|
| 8-10 bit / 高速（≥ 100 MS/s）| **Asynchronous** SAR |
| > 14-bit / 高精度 + 速度 | hybrid pipelined-SAR（超本章范围）|
| > 10 MS/s / 多通道 | **Asynchronous** + time-interleaved（2-4 channel）|

**Iron Law**：选错家族（如用 conventional 追 14-bit）= ENOB 差 2-3 bit，sizing 救不回——必须 challenge 拓扑或加 calibration（[L0 Iron Law 6](../../../src/agent_engine/prompt_compiler.py#_IRON_LAWS_DEFAULT)）。

## ⚠️ Common sizing pitfalls

> 这一节是 SAR ADC 系统级 sizing 决策的避坑提示。完整 device-level sizing（comparator input pair / S&H bootstrapped switch / CDAC unit cap）见对应 block / base-cell knowledge。

### Pitfall 1: C_unit 选小 → kT/C noise 决定 ENOB thermal limit

**症状**：MC 仿真 SNDR @ Nyquist 比 SQNR 上限低 3+ dB；增 input swing 不能 recover；ENOB 卡在 (N − 1) bit

**因果**：sample cap 上的 thermal noise 方差 `V²_n = k·T / C_total`。对 N-bit ADC：`SNR_thermal = V²_FS / (12 × k·T/C_total) = V²_FS · C_total / (12 k·T)`。要 SNR_thermal ≥ 6.02·N + 1.76 dB（即 ENOB ≤ N），等价于：

```
C_total ≥ 12 · k·T · 2^(2N) / V²_FS
       = 12 · 4.14e-21 · 2^(2N) / V²_FS @ 27°C

10-bit / V_FS = 1V  → C_total ≥ 50 fF
12-bit / V_FS = 1V  → C_total ≥ 800 fF
14-bit / V_FS = 1V  → C_total ≥ 13 pF
```

**修复**：先按 `C_total = 12·k·T·2^(2N)/V²_FS` 算 thermal floor，加 4× margin 留 quantization + nonlinearity headroom。`C_unit = C_total / 2^N`。

### Pitfall 2: CDAC matching σ(C)/C → INL/DNL 漂

**症状**：DC ramp 测 DNL 出现 spike > 0.5 LSB（特别是 MSB transition 处 2^(N-1) → 2^(N-1)+1）；INL > 1 LSB

**因果**：binary-weighted CDAC 的 INL 主要由 capacitor matching 决定。worst-case INL 在 MSB transition：
```
random unit mismatch RMS:  σ(INL_max) ≈ σ_unit / C_unit × √(2^N − 1)  (LSB units)
3σ INL < 0.5 LSB →         σ_unit / C_unit ≤ 0.5 / (3·√(2^N − 1))
```

若要无校准、保守覆盖 systematic gradient / parasitic，可加经验目标 `σ_unit/C_unit ≲ 1/(2^N·3)`（保守设计目标，**非 RMS 公式直接推论**）：

```
10-bit / σ(C)/C ≤ 0.03%   (very conservative; 必须 PDK MC 验证)
12-bit / σ(C)/C ≤ 0.008%  (通常需大 unit cap + calibration)
14-bit / σ(C)/C ≤ 0.002%  (必须 digital calibration / DEM)
```

**修复**：(a) 增 unit cap 面积（matching 改善 ∝ √Area）/ (b) common-centroid layout / (c) > 12-bit 加 digital calibration（DAC trim / split-MSB）。

### Pitfall 3: Bootstrap cap C_b droop → Ron 非线性 → THD 退化

**症状**：tb_dynamic FFT 在 nyquist 附近 SFDR < 60 dB；THD-3 高于 SFDR；ENOB(fin) > ENOB(DC)

**因果**：bootstrapped switch 在 sample phase 期间，gate 跟 source 抬高维持 Vgs ≈ V_clk。但 C_b 上的电荷在 hold phase（约 1/(2·fs) 时间）受 leak / parasitic load 而 droop ΔV_Cb ≈ I_leak·t_hold/C_b。**droop 大 → Vgs 跨摆幅不恒定 → Ron 非线性 → THD-3 主导 SFDR**。

**修复**：C_b 选 ≥ 5–10× C_load_gate（Cgs_M_sw + parasitic）；1 pF 是 10-bit / 10 MS/s + gate parasitic ~100 fF 的保守起点。**不要要求 `Vds_M_sw` 全期 < 50 mV**——acquisition 初期 Vds 可很大，正常。验证 (a) aperture 前 `|V(vinp) − V(vsamp)| < LSB/4`、(b) Ron(Vin) variation 在 SFDR budget 内、(c) Vgs droop 不引起 THD。详见 `blocks/base-cells/switch/bootstrapped`。

### Pitfall 4: Comparator offset σ_OS > LSB → ENOB 直接损失

**症状**：MC σ_ENOB > 0.5 bit，individual MC sample 在 N-1 bit 卡住；DNL 全 code 偏移

**因果**：SAR ADC 中 comparator offset 不是 input-referred random noise——它**系统性地 shift** 每次 bit decision threshold。每 bit decision 都受 same offset 影响 → 全 code DC offset，但更糟糕的是非线性扩散到 INL（因 DAC threshold 不再是 binary-weighted 准确点）。

```
要 ENOB ≥ N − 0.5 bit → σ_OS << LSB / 2 = V_FS / 2^(N+1)
10-bit / V_FS = 1V → σ_OS ≤ ~0.5 mV  (StrongARM W=10µm/L=1µm 5-15 mV，offset 远超!)
                  → 必须 offset 校准（dynamic / digital trim）
```

**修复**：(a) input pair Pelgrom matching（W·L 加大）/ (b) offset auto-zero（chopper-style 校准 phase）/ (c) digital trim（calibration 时算 offset 加补偿到 SAR FSM）/ (d) DEM。详见 `blocks/comparator/architecture` Pitfall 1。

### Pitfall 5: VREFP / VREFN ringing → 下次 bit 比较错

**症状**：tb_linearity DNL 在 mid-code（特别 MSB transition）出现 ±1 LSB spike，但单点 settling 看似 OK；增 settling time（slow conversion）后 DNL 改善

**因果**：CDAC switching 瞬间从 ref buffer 抽取大瞬态电流（~ C·V_step / Δt）。如果 ref buffer 输出阻抗高（typical bandgap+LDO ≈ 100 mΩ-1 Ω）→ ref 电压抖动 → next bit comparison 用错误 ref 值 → DNL spike。

**修复**：(a) 按 worst switching charge sizing reservoir `ΔV_ref ≈ ΔQ_switch/C_decap`，目标 `ΔV_ref < LSB/4`（`100×C_total` 只能 first-pass heuristic）/ (b) low-Z ref buffer（class-AB / opamp）/ (c) on-chip local decap + package/off-chip 分层 / (d) 加 settling time。**ref noise budget**：σ_ref < LSB/4 = V_FS/(4·2^N)。

### Pitfall 6: SAR FSM clock skew → comparator valid 与 DAC switching latch 不对齐

**症状**：individual MC sample DNL 看 OK，但跨 corner（FF / SS）DNL 漂大 > 1 LSB；fclk 升高时 DNL 退化

**因果**：SAR FSM 是 multi-cycle 时序——每 bit cycle 内：(1) DAC switch 到新 trial code → (2) settle ≥ N+1·τ → (3) comparator latch → (4) FSM 写 SAR 寄存器 → (5) 下次 bit。**任意阶段 timing margin < 0**（如 comparator metastability + FSM setup violation）→ bit decision 错误，跨 corner 暴露。

**修复**：(a) 各阶段保 ≥ 20% margin（async SAR 用 internal ready signal 自适应）/ (b) comparator clock 边沿 ≤ 30 ps 减 metastability（参考 `blocks/comparator` Pitfall 2）/ (c) DAC settling 留 N+1·τ 完整周期。

### Pitfall 7: Top-plate sampling charge injection → signal-dependent offset

**症状**：DC ramp 测 INL 在 mid-code 周围弯曲；offset 随 Vin 变化（不是恒定 offset）

**因果**：top-plate sampling 时 S&H switch 关断瞬间，channel charge `Q_ch ≈ Cox · W · L · (Vgs − Vth)` 注入 sample cap。**Vgs 取决于 Vin**（NMOS switch 时 Vgs = Vclk − Vin）→ injected charge 信号相关 → 引入 Vin² 项 → mid-code INL 弯曲。

**修复**：(a) bottom-plate sampling — bottom switch 先断、top plate 仍由 VCM/low-Z 钳住，让 charge injection 主要成 common-mode/constant error 而非直接注入高阻 comparator input（>12-bit SAR 常用）/ (b) dummy switch（half-size + reverse clock 一阶 cancellation，需 layout matching）/ (c) bootstrapped switch 近似恒定 Vgs 减 signal-dependent injection。详见 `blocks/base-cells/switch/troubleshooting`。

## 验证清单（架构选好后）

- [ ] 拓扑与 spec 匹配（参考 § ENOB 决策树）
- [ ] C_total thermal floor ≥ `12·k·T·2^(2N)/V²_FS × margin`；C_unit 另由 matching / parasitic / PDK density 定（避 Pitfall 1）
- [ ] CDAC matching 同时检查 RMS random mismatch 与 empirical no-cal target（避 Pitfall 2）
- [ ] C_b ≥ 5-10× C_load_gate，并验证 aperture settling / Ron(Vin) / Vgs droop（避 Pitfall 3）
- [ ] comparator residual offset < budget（naked StrongARM 不够时加 preamp / auto-zero / trim，避 Pitfall 4）
- [ ] VREF reservoir 按 `ΔQ_switch/ΔV_ref` sizing；`100×C_total` 仅作 first-pass heuristic（避 Pitfall 5）
- [ ] SAR FSM 各阶段 ≥ 20% timing margin（避 Pitfall 6）
- [ ] > 10-bit 用 bottom-plate 或 dummy switch（避 Pitfall 7）
- [ ] 加载 `blocks/comparator/reference-design` 复用 StrongARM 子模块
- [ ] 加载 `blocks/base-cells/switch/bootstrapped` 复用 S&H 子模块
- [ ] 加载 `blocks/bandgap/reference-design` 提供 VREFP / VREFN

## 常见架构误区

| 心里想 | 现实 |
|---|---|
| "增 C_unit 总能改善 ENOB" | thermal ∝ √C / matching ∝ √Area；4× area 才换 1 bit ENOB（Pitfall 1+2）|
| "comparator offset 加大 W 就行" | σ_OS ∝ 1/√(WL)，超 12-bit 必须 digital calibration（Pitfall 4）|
| "ref 直接接 bandgap 即可" | bandgap 输出阻抗高，DAC switching 让 ref ringing → 必须 buffer + 分层去耦（Pitfall 5）|
| "top-plate sampling 简单就用" | > 12-bit signal-dependent charge injection 引入 INL bend；必须 bottom-plate（Pitfall 7）|

## 不在本章范围

- **CDAC unit cap layout / common-centroid / dummy ring** → 数字 / mixed-signal layout knowledge
- **Bootstrapped switch 内部 helper 时序** → `blocks/base-cells/switch/bootstrapped`
- **StrongARM comparator 物理 / sizing** → `blocks/comparator/{architecture, reference-design}` + `blocks/base-cells/comparator-latch/strongarm`
- **bandgap reference 设计** → `blocks/bandgap`
- **Pipeline / Σ-Δ / flash ADC 拓扑** → 各自 block（W7+ 后续）
- **Calibration 算法**（DAC trim / DEM / split-MSB）→ 校准 + 数字辅助 knowledge
- **FFT post-processing**（计算 ENOB/SFDR/SNDR）→ 主机侧分析脚本
- **multi-channel time-interleaved ADC** → time-interleaving + offset/gain calibration knowledge
