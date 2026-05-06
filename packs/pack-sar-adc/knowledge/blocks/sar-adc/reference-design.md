---
chapter: reference-design
parent: sar-adc
summary: |
  10-bit binary-weighted charge-redistribution SAR ADC reference (CDAC +
  StrongARM comparator + bootstrapped S&H + SAR FSM behavioral) + standard
  cir/tb 路径 + sizing 起点 + clock 时序约束 + 4 testbench (dc_op / linearity /
  dynamic / timing)。Iron Law: 写 SAR ADC 必先复用本章 inline 拓扑骨架 +
  子模块 reference (comparator / bootstrapped switch). SAR FSM 当 behavioral
  black-box；具体 RTL 实现属于数字 IC 范围。
tokens: ~1300
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/comparator
  - blocks/bandgap
  - blocks/base-cells/switch
  - simulators/ngspice
  - pdks/vpdk180nm
---

# 10-bit SAR ADC Reference Design

## Iron Law

**Reference design 优先**：写 SAR ADC 时**必须**先复用本章 § Core topology 的 inline 骨架 + 三个子模块 reference：

1. **StrongARM comparator** ← `blocks/comparator/reference-design.md` (W7 d3ef72b commit)
2. **Bootstrapped sample switch** ← `blocks/base-cells/switch/bootstrapped.md`
3. **VREFP / VREFN bandgap reference** ← `blocks/bandgap/reference-design.md` (W7 5a3b166 commit)

当前 sar-adc 包还没有 `assets/reference_designs/` 资产（后续若补，可通过 `load_knowledge(name='sar-adc', asset='reference_designs/<file>')` 拿）；本章 inline 拓扑 + 4 testbench 模板即 canonical reference。SAR FSM 是 digital 子系统，本章用 ngspice behavioral subckt 占位（spec ≤ 10-bit 通用），具体 RTL 实现交由数字团队。

## Quick reference

```
Canonical topology    : 本章 § Core topology（inline + 3 子模块 reference）
DC OP testbench       : 本章 § tb_dc_op.sp 模板
Linearity (DNL/INL) tb: 本章 § tb_linearity.sp 模板
Dynamic (FFT/ENOB) tb : 本章 § tb_dynamic.sp 模板
Clock timing tb       : 本章 § tb_clock_timing.sp 模板
```

## Standard subckt port order

```spice
.subckt sar_adc_10bit vinp vinn vrefp vrefn vdd vss clk dout<9> dout<8> ... dout<0> eoc
```

> ⚠️ **本 reference 单端 SAR**（vinp 单端输入 + vinn 接 V_CM 中点）；differential SAR 需要双 CDAC 阵列 + 双 sampling switch（架构变体，超本 reference）。`dout<9:0>` 输出按 MSB-first 编号；`eoc` (end of conversion) 是 SAR FSM 的 done flag。

## Core topology — 10-bit binary CDAC + StrongARM + bootstrap S&H

```
                                        VREFP / VREFN
                                          (来自 bandgap+buffer)
                                              │
                  ┌───────────────────────────┴──────────────────┐
                  │                                              │
                Bottom-plate switches ×10 (TG)                  │
                d0_b d1_b ... d9_b                              │
                  │     │       │                               │
              [C_dum][C0]   [C1] ... [C9]    binary-weighted    │
              =1C   =1C    =2C ... =512C    CDAC array         │
                  │     │       │                               │
                  └─────┴───────┴───────● vsamp（top plate）   │
                                        │                       │
                              [Bootstrap switch]                 │
                                        │                       │
                              ●─────────●─── vinp（信号）       │
                                                                │
                              [StrongARM comparator]            │
                              vsamp ↔ vcm_ref → voutp/voutn     │
                                          │                     │
                              ┌───────────┴───────────┐         │
                              │  SAR FSM (digital)    │←── clk  │
                              │  clk_cmp / clk_dac    │         │
                              │  d0..d9 / eoc         │─────────┘
                              └───────────┬───────────┘
                                          │
                                       dout<9:0> + eoc
```

**关键 connectivity rules**（SAR ADC 实战 traps codify）：

| 子模块 | gate / 关键端 | 关键正确性 |
|---|---|---|
| Bootstrap S&H switch | gate=clk_sample, conduction terminals=vinp/vsamp, body per switch reference | `blocks/base-cells/switch/bootstrapped` Iron Law；不依赖 MOS S/D 命名做 correctness；C_b ≥ 5–10× C_gate（避 Pitfall 3）|
| C_dummy | top=vsamp, bottom=vss | 1× C_unit (binary-weighted 完整性) |
| C_i (i=0..9) | top=vsamp, bottom=d_i_b | 2^i × C_unit；common-centroid layout（避 Pitfall 2）|
| Bottom-plate switch X_sw_i | input=vrefp / vrefn, output=d_i_b, control=d_i (SAR FSM) | TG 开关 rail-to-rail；charge injection 用 dummy switch（W/L=半 size 反相 clock）|
| StrongARM comparator | vp=vsamp, vn=vcm_ref, clk_cmp from FSM | `blocks/comparator/reference-design` Iron Law；residual offset after sizing/calibration < LSB/2（避 Pitfall 4）|
| SAR FSM | clk → 内部 clk_cmp/clk_dac generator + 10-bit register + eoc | behavioral 占位；timing margin ≥ 20%（避 Pitfall 6）|
| VREFP / VREFN | from bandgap + low-Z reference buffer + effective reservoir cap | buffer 实现属于 output-stage / OTA / reference-buffer knowledge；不要把 current mirror 当 VREF buffer 用 |

> **Bottom-plate switching scheme**：CDAC bit i 的 bottom 切换 vrefp（trial=1）↔ vrefn（trial=0）；SAR FSM 在每 bit cycle 内 (1) latch comparator output → (2) update SAR register → (3) drive switches d_i → (4) wait DAC settling ≥ N+1·τ → (5) trigger next clk_cmp。

## SAR conversion sequence (N=10, synchronous reference: 12 cycles per conversion)

| Cycle | 阶段 | DAC code | comparator |
|---|---|---|---|
| 0 | Sample (S&H ON, all bits = mid-code) | 0x200（MSB=1, 余 0）| inactive |
| 1 | MSB trial | 0x200 | latch → bit 9 |
| 2 | bit 8 trial | 0x200 \| (bit 9) → 0x300 or 0x100 | latch → bit 8 |
| ... | ... | ... | ... |
| 10 | bit 0 trial | full 9-bit code + bit 0 trial | latch → bit 0 |
| 11 | Load output (eoc=1) | final 10-bit code | inactive |

**Effective conversion rate**：本同步 reference `f_conv = f_clk / 12`（120 MHz → 10 MS/s）。其它同步 SAR 视 sample / load overlap 可用 N+1 或 N+2 cycles。Asynchronous SAR 是 event-driven，speed 用等效平均 cycles 表述，10-bit 设计当 comparator/DAC settling 允许时常见 ~6–8 cycles。

## Sizing 起点 (vpdk180nm, VDD=1.8V, V_FS=1V, 10-bit / 10 MS/s, ENOB target ≥ 9 bit)

| 参数 | role | 起点 | derivation chain |
|---|---|---|---|
| `C_total,kT/C` | sampled CDAC total cap thermal floor | ≥ 0.21 pF | `12·k·T·2^(2N)/V²_FS = 52 fF @ 27°C`；4× margin → 0.21 pF（避 Pitfall 1）|
| `C_unit` | binary CDAC unit cap | 10–50 fF | practical floor 通常由 matching / parasitic / layout 决定，不是 kT/C；从 PDK cap density + MC mismatch 选（避 Pitfall 2）|
| `C_total` | total CDAC capacitance | 10.2–51.2 pF | `2^N × C_unit` for unsplit 10-bit binary array；split-cap / bridge-cap variants 减面积 + VREF kick |
| MOM/MIM unit area | unit cap layout | PDK / MC value | 不假设 4 µm² 给 50 fF 或 σ(C)/C=0.05%；从 PDK density 与 Pelgrom cap mismatch 验证 |
| `C_b` (bootstrap) | sample switch boost cap | 1 pF | ≥ 5–10× Cgs_M_sw；hold phase < 100 ns 时 droop < LSB（避 Pitfall 3）|
| `W/L_M_sw` (sample switch) | bootstrapped NMOS | 20 µm / 0.18 µm | require `exp(-T_acq/(Ron·C_total)) < 1/2^(N+1)`；等价 `Ron < T_acq / (C_total · (N+1)·ln2)` |
| `f_clk` | external clock | 120 MHz | 12 cycles per conversion → 10 MS/s |
| `comparator` (StrongARM) | input pair / regen / tail | W=10µ/L=0.36µ input pair；W=4µ/L=0.18µ regen；W=20µ/L=0.18µ tail | naked StrongARM σ_OS 仍是 mV-level；10-bit / 1V FS budget `LSB/2 ≈ 0.49 mV` 必须 preamp / auto-zero / digital trim |
| **`C_decap_vrefp`** | VREF 去耦 cap | effective ≥ 100× C_total（含 off-chip / package）；on-chip per area budget | 5 nF 纯 on-chip 面积代价高；按 `ΔQ_switch / ΔV_ref` 与 settling/ringing 验证（避 Pitfall 5）|
| Bottom-plate switch (TG) | rail-to-rail switching | W=2µ/L=0.18µ NMOS+PMOS each | 速度 vs charge injection trade-off |
| Dummy switch (per bit) | charge injection cancel | half W of main switch + reverse clock | 避 Pitfall 7（top-plate charge injection）|

> ⚠️ **Comparator offset σ_OS ≤ 0.5 mV 是 10-bit / 1V FS sub-LSB budget，不是 naked StrongARM sizing 预期**。`blocks/comparator/reference-design` 起点是 mV-level offset；10-bit SAR 若要不丢 DC accuracy，需配 preamp / auto-zero / digital trim。单纯加大 input pair 只能按 `1/√(WL)` 改善，要压 σ_OS 到 0.5 mV 通常不实际。

## Standard testbench 摘要

完整 4 testbench 由用户根据 spec 实例化。每 tb 关键点：

### `tb_dc_op.sp`（DC 静态）

`Vrefp/Vrefn = 1.5/0.5V (V_FS=1V)`、`Vinp DC=1.0V (mid-code)`、`Vclk PULSE 30p edge / 4n PW / 8n period (125 MHz)`、`.tran 1n 200n`。期望 eoc=1 + dout<9:0>=0x200。

### `tb_linearity.sp`（DNL / INL）

Vinp DC ramp（vrefn → vrefp，2^N+ buckets），每 bucket ≥100 次 conversion stat，post-process `DNL[i]=(count[i]−1)/total`、`INL=cumsum(DNL)`。**Monte Carlo 必跑**（CDAC matching 主导 INL）。

### `tb_dynamic.sp`（FFT / ENOB / SFDR）

Vinp = `sin(2π·fin·t)` coherent freq（fin × 2^M / fs = 整数避 leakage），跑 2^M+ 次 conversion，主机 FFT 算 SNDR/SFDR/THD/ENOB。典型 fin = fs/4 或 fs/2。

### `tb_clock_timing.sp`（SAR FSM timing margin）

加 ±20% clock jitter + 跨 corner FF/SS + 增 fclk 看 DNL 是否退化。**margin ≥ 20%** sign-off（避 Pitfall 6）。

## 已知设计陷阱（教科书 + W7 子模块教训）

7 个 sizing pitfalls 详细诊断见 `chapter=architecture` § Pitfall 1-7。每个表现 + 修复要点：

- C_unit < kT/C floor → ENOB 卡 N-1（Pitfall 1）；CDAC σ(C)/C 太大 → DNL spike at MSB（Pitfall 2）
- Comparator offset > LSB → 必须 calibration（Pitfall 4）；VREF ringing → 分层去耦 + low-Z buffer（Pitfall 5）
- Top-plate charge injection → bottom-plate / dummy switch（Pitfall 7）；SAR clock skew → ≥20% margin / async（Pitfall 6）
- bootstrap C_b droop → C_b ≥ 5-10× Cgs_M_sw（Pitfall 3）

## When to use / NOT use

✅ 8–12 bit SAR ADC（charge-redistribution 经典）；mixed-signal SoC 内部 ADC；传感器读出；PMIC monitoring。

❌ > 12-bit（用 bottom-plate variant + calibration）；> 100 MS/s（用 asynchronous + time-interleaved）；ultra-low power < 1 µW/MS/s（用 merged-cap monotonic）。

## 不在本章范围

- **拓扑对比 / ENOB 决策树 / 7 sizing pitfalls** → `chapter=architecture`
- **StrongARM comparator 物理 + sizing** → `blocks/comparator/{architecture, reference-design}`
- **Bootstrapped switch 内部 helper / charge management** → `blocks/base-cells/switch/bootstrapped`
- **bandgap reference 设计** → `blocks/bandgap`
- **CDAC unit cap layout** → 数字 / mixed-signal layout knowledge
- **SAR FSM RTL 实现** → 数字 IC / Verilog SystemVerilog knowledge
- **FFT post-processing**（ENOB / SFDR / SNDR 计算）→ 主机侧分析脚本（Python / MATLAB）
- **Pipeline / Σ-Δ / flash ADC** → 各自架构（W7+ 后续）
