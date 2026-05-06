---
chapter: troubleshooting
parent: sar-adc
summary: |
  SAR ADC 系统级失败模式 + 物理因果链 + 根因可能性表。涵盖 ENOB 不达标 /
  DNL 超 1 LSB / INL 弯曲 / SFDR 偏低 / metastability 错误 / VREF ringing /
  cross-corner 退化等。诊断流程引用 systematic-debugging skill。
tokens: ~1700
prerequisite_chapters:
  - architecture
  - noise-budget
  - sizing-typical
  - timing
related_skills:
  - meta-cognitive/systematic-debugging
  - circuit-method/signal-tracing
  - circuit-method/device-sizing
---

# SAR ADC Troubleshooting

> 通用诊断顺序见 `skill: systematic-debugging`（4-phase）+ `skill: signal-tracing`
> （信号反推）。本章节给的是 **SAR ADC 拓扑特有**的失败模式 + 物理因果链 +
> 根因可能性表。子模块 troubleshooting（比较器 metastable / bootstrap droop /
> bandgap startup）见各自 base-cell + block。

## 诊断顺序（**SAR 推荐顺序**）

> 这是 SAR ADC 系统级**推荐诊断顺序**——SAR 误差源多（噪声 + matching +
> timing + offset），盲目调任一项救不了别的。**按 ENOB → DNL/INL → SFDR
> → cross-corner 顺序排查**，每一步定位是哪类故障。

```
1. ENOB MC σ 大（> 0.3 bit）→ 看是 systematic（offset 偏）还是 random（thermal/jitter）
   ↓
2. systematic 偏 → 确认 offset / VREF / sizing typo（失败模式 1, 4, 5）
   random 抖 → 确认 thermal noise / jitter / metastable（失败模式 2, 6, 8）
   ↓
3. DC ramp DNL/INL 看具体哪些 code 出问题
   - MSB transition spike → CDAC matching（模式 4）
   - mid-code 弯曲 → top-plate charge injection（模式 9）
   - 全频带漂 → clock skew / FSM setup（模式 6）
   ↓
4. Dynamic FFT (Nyquist input) SFDR / THD 看 large-signal nonlinearity
   - SFDR < 60 dB + THD-3 大 → bootstrap C_b droop（模式 7）
   - VREF coupling spurs → VREF ringing（模式 5）
   ↓
5. cross-corner 退化 → SS / FF 跑全 sweep 看哪个时序撞墙（模式 8 + timing.md）
```

## 失败模式 1：ENOB 卡 (N − 1) bit thermal limit

**症状**：MC ENOB stat 几乎全 < N−0.5 bit；增 input swing 不能改善；不同
input 频率 ENOB 差异 < 0.1 bit。

### 物理因果链
```
σ_total² = σ²_kTC + σ²_OS + σ²_n,comp + σ²_ref + σ²_jitter + σ²_quant
ENOB = N − loss
loss = (10·log10(σ_total² / σ²_quant)) / 6.02
```

ENOB 卡 N−1 → σ_total ≈ 2× σ_quant → 某项 σ_i 主导（占 σ_total > 70%）。

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| **C_total < kT/C floor**（最常见）| 算 σ_kTC = √(kT/C_total) vs LSB/4 | C_total ↑（详见 sizing-typical Phase B）|
| Comparator σ_n,comp 大 | 测 comparator MC random offset 分量 | input pair Id ↑ 或加 preamp |
| VREF ref noise | 测 VREF 在 sample point 的 RMS | low-Z buffer + decap（noise-budget Phase D）|
| 噪声预算分配错（某项占 > 50%）| 计算 σ²_i / σ²_total 各源占比 | 重做 noise budget（见 noise-budget.md）|

### Anti-pattern
- ❌ **盲目加大 C_total 想救 ENOB**：C_total ↑ 4× 才换 1 bit thermal；jitter / offset 不动是无用功
- ❌ **直接换 14-bit calibration 想救 10-bit ENOB**：根因还在某项 budget 超，先做 noise budget 分配验证

---

## 失败模式 2：ENOB MC σ 大（> 0.5 bit）

> **不是 systematic loss，而是跨 sample 抖**。多次 conversion 同 input 结果
> 不一致。

### 物理因果链
```
random per-sample variation 来自：
1. thermal noise（kT/C, comparator, VREF noise）
2. clock jitter（aperture）
3. metastable error rate（per-sample 不收敛）
```

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| Comparator metastable rate > 1e-3 | tb_metastable 跑 1e6 conversion 看错误率 | 增 t_decide cycle 时序（见 timing.md 范例 2）|
| Aperture jitter 主导（high-freq input）| 测 ENOB(fin) 看是否 fin ↑ 时退化 | 增 clock buffer 边沿陡（见 timing.md）|
| Thermal noise 主导（C_total 不够）| 见模式 1 | 见模式 1 |

> **区分技巧**：DC input ENOB OK + Nyquist input ENOB 差 → jitter；DC + Nyquist 都差 → thermal/metastable。

---

## 失败模式 3：DNL / INL 超 1 LSB

**症状**：tb_linearity DC ramp DNL spike > 1 LSB；INL > 1.5 LSB。

### 子模式 3a: MSB transition spike（CDAC matching）

```
DNL spike at code 2^(N-1) → 2^(N-1) - 1：
σ(INL_max) ≈ σ_unit/C_unit × √(2^N − 1)
```

修复：增 C_unit area（matching ∝ √Area）；> 12-bit 必加 calibration（DAC trim）。

### 子模式 3b: 全频带 DNL 漂（clock skew / FSM setup）

修复：见模式 6。

### 子模式 3c: Mid-code DNL 弯曲（top-plate charge injection）

```
top-plate sample 时 channel charge `Q_ch ∝ Vgs - Vth`，Vgs 取决于 Vin →
signal-dependent charge injection → mid-code 弯曲（不是恒定 offset）
```

修复：bottom-plate sampling 或 dummy switch（半 size + 反相 clock）；
> 12-bit SAR 标配 bottom-plate（见 architecture.md Pitfall 7）。

---

## 失败模式 4：Comparator offset > LSB → 全 code 偏移 + INL 退化

**症状**：DC ramp DNL 全 code 偏移（systematic）；INL 不在零中心；
所有 conversion 都偏一个方向 ~ 5-10 mV。

### 物理因果链
```
SAR comparator offset 系统性 shift 每次 bit decision threshold：
- 全 code DC offset（gain error 中性）
- 但 INL 在 code 边界不再准确 binary-weighted → INL 弯曲
```

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| Naked StrongARM σ_OS = 5-15 mV @ vpdk180nm | input pair MC σ_OS | 加 preamp + Pelgrom matching（W·L ↑）|
| Calibration plan 缺失 | 看 SAR FSM 是否有 trim register | 数字 trim + DAC adjustment |

> **10-bit 以上 SAR 不做 calibration 必失败**。详见 `noise-budget.md` 范例 2。

### 边界判断
- 10-bit / V_FS=1V: σ_OS budget 0.5 mV → preamp + sizing 可达
- 12-bit / V_FS=1V: σ_OS budget 0.12 mV → 必须 digital trim
- 14-bit: σ_OS budget 30 µV → 必须 chopper / auto-zero + trim

---

## 失败模式 5：VREF ringing → MSB transition DNL spike

**症状**：tb_linearity DNL 在 MSB transition 处 spike ≥ 1 LSB；single-cycle
settling 看似 OK；增 settling time（slow conversion）后 DNL 改善。

### 物理因果链

见 `architecture.md` Pitfall 5 + `noise-budget.md` 范例 3。简短：

```
CDAC switching 抽 ΔQ_switch ≈ C_total × V_FS 从 ref buffer
ΔV_ref = ΔQ_switch / C_decap (instantaneous)
→ next bit 比较用错 ref → DNL spike
```

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| C_decap < 100× C_total | 看 tran VREF settling 时间 | 加 on-chip + package + off-chip 三层去耦 |
| Ref buffer Z_out 高（直接 bandgap 输出）| Z_out 测量 | 加 low-Z buffer（class-AB / opamp）|
| Buffer BW 不够 | 测 buffer settling τ vs cycle 时序 | 增 buffer Iq |

---

## 失败模式 6：Cross-corner DNL 退化（FF/SS）

**症状**：TT @ 27°C DNL OK；FF/SS / -40°C / 125°C 跑出 DNL > 1 LSB。

详见 `timing.md` 范例 1（DAC settle 不够）+ 范例 3（FSM setup violation）。

### 根因可能性表

| 根因 | corner | 修复 |
|---|---|---|
| DAC settle 时间不够 | SS @ -40°C / 125°C | t_dac 增 50% margin（降 f_clk 或减 N+2）|
| FSM setup violation | FF + clock skew | clock tree 平衡 + 减 skew |
| Comparator metastable | SS @ 125°C | t_decide 增 50%（见 timing 范例 2）|

> **SS @ 125°C 是 SAR ADC sign-off 关键 corner**——必须跑全 sweep 验证 timing margin。

---

## 失败模式 7：SFDR < 60 dB + THD-3 主导

**症状**：tb_dynamic FFT 在 Nyquist 测 SFDR < 60 dB；THD-3 是 SFDR 主导谐波；
ENOB(DC) > ENOB(fin)；DC linearity OK。

### 物理因果链
```
S&H 非线性 → input 信号 V³ 项 → THD-3 spurs
最常见：bootstrap switch C_b droop → Vgs 不恒定 → Ron(Vin) 非线性
```

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| Bootstrap C_b droop | tb_dynamic 看 V(C_b) over hold phase | C_b ≥ 5-10× Cgs_M_sw |
| Bootstrap Ron(Vin) variation | 扫 Ron vs Vin 看是否单调 | C_b ↑ 或换 differential bootstrap |
| Top-plate sampling charge inj | 仅在 top-plate scheme 出现 | bottom-plate 或 dummy switch |
| VREF ringing → next-bit error | tran 看 VREF settle | 见模式 5 |

> 详见 `architecture.md` Pitfall 3（C_b droop） + Pitfall 7（charge injection）。

---

## 失败模式 8：Async SAR 不收敛（settle detector / metastable detector 失效）

> **仅 async SAR 适用**。

**症状**：async SAR 测 conversion 时间不一致（应该 average ~ 6-8 cycles）；
偶发 timeout。

### 根因可能性表

| 根因 | 修复 |
|---|---|
| Settle detector threshold 偏 | adjust threshold based on cap stack 实测 settling |
| Metastable detector miss | 加冗余 wait timeout |
| Internal ready signal racing | 网表布局 + clock buffer 边沿 < 50 ps |

---

## 失败模式 9：Top-plate charge injection → mid-code INL bend

详见 `architecture.md` Pitfall 7。

修复：bottom-plate sampling（标配 > 12-bit）+ dummy switch（半 size + 反相 clock）。

---

## 失败模式 10：Pipeline / 多通道 mismatch（time-interleaved 特有）

> **仅 time-interleaved SAR 适用**（单通道 SAR 跳过）。

**症状**：FFT 看到 fs/M (M=channels) 处 spurs；ENOB 退化随通道数。

### 修复
- Channel offset / gain mismatch：digital calibration
- Channel timing skew：clock distribution 平衡 + on-chip trim
- 详见 time-interleaved + offset/gain calibration knowledge（不在本章）

---

## When to load this chapter

- ENOB / SNDR / SFDR / DNL / INL 仿真后 spec 不达标
- 看到 tb_linearity 或 tb_dynamic 异常先回 `noise-budget.md` 验 budget 分配
- agent 调 sizing 撞壁（多次试都没收敛）
- cross-corner 仿真发现 timing 退化

## Related

- **噪声 budget 分配（5 噪声源 LSB）** → `noise-budget.md`（灵魂章）
- **设计推进顺序 + sizing 起点** → `sizing-typical.md`
- **拓扑选型 + 7 sizing pitfalls** → `architecture.md`
- **同步 / 异步 SAR 时序** → `timing.md`
- **Reference design + standard testbench** → `reference-design.md`
- **比较器 metastability + offset** → `blocks/comparator/{architecture, timing-stability, troubleshooting}`
- **bootstrap switch acquisition** → `blocks/base-cells/switch/bootstrapped`
- **VREF buffer 设计** → `blocks/base-cells/output-stage`
- **bandgap startup + TC** → `blocks/bandgap/{architecture, startup, troubleshooting}`
- **通用诊断方法** → `skill: systematic-debugging` / `signal-tracing`
