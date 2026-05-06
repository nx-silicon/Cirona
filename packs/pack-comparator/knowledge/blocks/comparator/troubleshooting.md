---
chapter: troubleshooting
parent: comparator
summary: |
  StrongARM comparator 系统级失败模式 + 物理因果链 + 根因可能性表。涵盖 σ_OS
  超 spec / metastability 错误率 / kickback 大 / clock race / 电源耦合 /
  cross-corner 退化等。诊断流程引用 systematic-debugging skill。base-cell
  `comparator-latch/troubleshooting` 是物理细节 source of truth；本章合并
  architecture 7 pitfalls 给系统级根因表 + 推荐诊断顺序。
tokens: ~1700
prerequisite_chapters:
  - architecture
  - sizing-typical
  - timing-stability
related_skills:
  - meta-cognitive/systematic-debugging
  - circuit-method/signal-tracing
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/comparator-latch
  - blocks/base-cells/differential-pair
---

# Comparator Troubleshooting

> 通用诊断顺序见 `skill: systematic-debugging`（4-phase）+ `skill: signal-tracing`
> （信号反推）。本章节给的是 **comparator 拓扑特有**的失败模式 + 物理因果链 +
> 根因可能性表。物理细节（σ_OS Pelgrom / τ_reg thermal / kickback charge）见
> `blocks/base-cells/comparator-latch/troubleshooting`；本章合并 architecture
> 7 pitfalls + base-cell 5 类故障给系统级根因表 + 推荐诊断顺序。

## 诊断顺序（**comparator 推荐顺序**）

> 这是 comparator 系统级**推荐诊断顺序**——comparator 故障源多（offset /
> metastable / kickback / clock / 电源），盲目调任一项救不了别的。**按 σ_OS
> → metastable rate → kickback → clock race → cross-corner 顺序排查**。

```
1. tb_dc_op 看 region：所有 device saturation？
   - 任一 triode → 见模式 7（cross-corner 时序 / V(tail) 异常）
   - 全 saturation → 进步骤 2
   ↓
2. MC σ_OS 测量（tb_metastab_mc 或专门 tb_offset）
   - σ_OS > LSB/2 → 见模式 1（offset 超 spec）
   - σ_OS OK → 进步骤 3
   ↓
3. tb_metastab_mc 跑 1e6 conversion 算错误率
   - 错误率 > spec → 见模式 2（metastability 错误率超）
   - 错误率 OK → 进步骤 4
   ↓
4. tb_kickback 测 Vinp 端瞬态电压
   - kickback > LSB/4 → 见模式 3（kickback 大）
   - kickback OK → 进步骤 5
   ↓
5. tb_clock_race / tb_aperture
   - jitter 超 → 见模式 4（aperture jitter）
   - clock race → 见模式 5（CK 边沿 short-through）
   ↓
6. 跨 corner 跑全 sweep
   - SS @ 125°C metastable 退化 → 见模式 6
```

## 失败模式 1：σ_OS > LSB/2 (10-bit ADC 应用)

**症状**：ADC ENOB MC σ > 0.5 bit；DNL 全 code 偏移；individual MC sample
偏一个方向 5-15 mV。

### 物理因果链

详见 `architecture.md` Pitfall 1 + `sizing-typical.md` Step 1-2。简短：

```
σ²_OS = AVT² / (W·L) + (Vov/2)² · AB² / (W·L)
       ↑                  ↑
     Vth 失配主项     β 失配次项

要 σ_OS = 0.49 mV @ 10-bit:
  W·L ≥ 100 µm² (vpdk180nm AVT=5mV·µm)
  实际 sizing 受面积 / 电容限制 → 必须 calibration
```

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| Naked StrongARM W·L 不够 | input pair MC σ_OS | 加 preamp + Pelgrom matching（W·L ↑）|
| **Calibration plan 缺失**（最常见 10-bit）| 看 SAR FSM 是否有 trim register | 加 preamp / auto-zero / digital trim |
| Vov > 0.25V 让 β 项主导 | 算 (Vov/2)²·AB² 比 AVT² 项大小 | 减 Vov 到 0.10-0.15V |
| L_INP = Lmin（σ_Vth 大）| 看 L_INP < 0.36 µm | L_INP = 2× Lmin 起 |

### 边界判断
- 10-bit / V_FS=1V → σ_OS budget 0.49 mV → preamp + sizing 可达
- 12-bit / V_FS=1V → σ_OS budget 0.12 mV → 必须 digital trim
- 14-bit → σ_OS budget 30 µV → 必须 chopper / auto-zero + trim

详见 `blocks/sar-adc/noise-budget.md` 范例 2。

---

## 失败模式 2：Metastability 错误率超 spec

**症状**：tb_metastab_mc 1e6 conversion 后错误率 > 1e-7（spec for high-speed
SAR）；ADC ENOB MC σ > 0.3 bit（非 systematic）。

详见 `timing-stability.md` 范例 1。简短根因表：

| 根因 | 验证 | 修复 |
|---|---|---|
| t_alloc / τ_reg < 5 | 算 cycle_time / τ_reg | 减 fclk / async SAR / 加 preamp |
| τ_reg 太大（C_node 主导）| 算 C_node × gm⁻¹ | 减 W·L_regen ≤ 1 µm² |
| Tail switch 太弱 → ΔV_input 小 | 看 V(tail) evaluate 偏 | 增 W_tail（见模式 7）|

### Anti-pattern
- ❌ **加大 W_regen 想减 τ_reg**：C_node ↑ 反向（架构 Pitfall 3）
- ❌ **靠 input ΔV 大平均掉 metastable**：错误是非线性
- ❌ **加 latch 后 buffer 想"消" metastable**：错误信号已 propagate

---

## 失败模式 3：Kickback 大（preamp / source impedance 敏感）

**症状**：Vinp 端测出瞬态电压 spike > LSB/4；ADC linearity 退化；MC ENOB σ 大。

### 物理因果链

```
StrongARM regen 时 voutp / voutn rail-to-rail 转换：
  ΔV_voutp ≈ VDD = 1.8V
  Cgd_input × ΔV_voutp = injected charge to input
  Cgd × 1.8V × W_input ≈ 2-5 fC (W_input=4µm)

source impedance R_source 转换 charge → V spike：
  ΔV_input_spike = (Cgd · ΔV_voutp) / (C_source)
                 = R_source × kickback_charge / T_settle
```

### 根因可能性表

| 根因 | 修复 |
|---|---|
| 无 preamp 隔离 | 加 preamp（5T-OTA / cascode-OTA）|
| Source impedance 高（前级 OTA 输出）| 加 source follower buffer |
| Cgd_input 大（input pair W 大）| 减 W_input（trade-off：σ_OS 增）|
| Sample cap 小 | 增 C_sample → 平摊 charge |

> 详见 `architecture.md` Pitfall 5（preamp gain 不够时 kickback 仍大）。

---

## 失败模式 4：Aperture jitter 主导 SNR（high-frequency input）

**症状**：DC 测 ENOB OK（fin = DC）；Nyquist input 测 ENOB 退化 0.5+ bit；
MC SNDR(fin) 退化。

详见 `timing-stability.md` 范例 2。简短根因表：

| 根因 | 修复 |
|---|---|
| Clock buffer 边沿慢 | 增最末级 W；fanout ≤ 4 |
| PLL jitter 大 | 换 LC-VCO（不是 ring-VCO）|
| Clock distribution skew | 平衡 clock tree |
| **应用 fin 太高** | 限 fin ≤ baseband / 加 anti-alias filter |

---

## 失败模式 5：Clock race / CK 边沿 short-through

**症状**：tb_tran 在 CK 上升 / 下降边沿期出现 100 mV+ 毛刺；CV²f 实测比理论
高 2-3×；comparator decision time 偏长。

详见 `architecture.md` Pitfall 7 + `timing-stability.md` 范例 3。

| 根因 | 修复 |
|---|---|
| Clock edge > 100 ps | clock buffer 链最末级 W ↑；edge ≤ 30 ps |
| Reset PMOS / Tail NMOS 同时导通窗口宽 | 见 above（edge 短即可压缩窗口）|
| **two-phase non-overlap 误用 single-clock subckt** | 选 two-phase variant 或加 wrapper |

---

## 失败模式 6：Cross-corner 退化（FF/SS）

**症状**：TT @ 27°C 测 OK；FF / SS / -40 / 125°C 跑出 σ_OS 漂或 metastable
错误率退化。

### 根因可能性表

| 根因 | corner | 修复 |
|---|---|---|
| τ_reg @ SS 退化 30% | SS / 125°C | 加 t_alloc 余量（减 fclk 或 async SAR）|
| σ_OS @ FF 退化（Vth 漂）| FF / -40°C | 增 W·L_input 或加 preamp |
| Vth shift @ -40°C 让 input pair 进 weak inversion | -40°C | 增 Vov_input 起点（保 strong inversion）|
| Clock edge 跨 corner 退化 | SS 慢 | clock buffer 增 margin |

> **SS @ 125°C 是 comparator 关键 corner**——τ_reg 最大 + Vth 最低（offset
> 推 random）+ V(tail) 最难驱动。**必须跑全 sweep 验证**。

---

## 失败模式 7：Tail switch / V(tail) 异常

详见 `architecture.md` Pitfall 4 + `timing-stability.md` 范例 4。

| 根因 | 验证 | 修复 |
|---|---|---|
| Tail switch W 太小 → R_on 大 | tb_tran 看 V(tail) evaluate 中段值 | W_tail ↑（8µ → 12-20µ）|
| Clock edge 慢让 tail switch 不充分 | 看 dCK/dt at switch 进入 | clock edge ≤ 30 ps |
| Input pair 进 triode（V(tail) 太低 + V_inp 高）| dc_snapshot region | 检查 ICM range 与 input pair Vov |

---

## 失败模式 8：Continuous-time hysteresis 振荡

> 仅 continuous-time + hysteresis 比较器适用。

**症状**：input slow ramp 跨阈值时输出多次切换；POR 信号多次毛刺。

### 物理因果链

详见 `architecture.md` Pitfall 6：
```
hysteresis 比较器 V_hys < 3σ_input_noise → 输入噪声让输出在 hysteresis 带
内振荡
```

### 修复
- V_hys ≥ 5σ_input_noise（典型 input noise 1-3 mV → V_hys ≥ 10-20 mV）
- POR / 阈值检测取 V_hys = 50-100 mV 留 corner margin

---

## 失败模式 9：Preamp gain 不够 → kickback 优势消失

> 仅 preamp + StrongARM 适用。

详见 `architecture.md` Pitfall 5。

| 根因 | 修复 |
|---|---|
| Preamp gain < 20 dB | preamp 升级 5T-OTA → cascode-OTA / FC-OTA |
| Preamp 输出阻抗高 | 加 source follower buffer 隔离 latch |

---

## 失败模式 10：电源耦合（VDD ripple → comparator output spurs）

**症状**：tb_psrr 测 PSRR < 30 dB；ADC FFT 看到 VDD 频率 spurs。

### 物理因果链
```
StrongARM 没有 PSRR 抑制机制（reset PMOS S 接 vdd 直接耦合）
preamp + StrongARM 由 preamp PSRR 决定（OTA 拓扑）
```

### 修复
- 加 preamp（OTA 提供 PSRR 抑制）
- 增 on-chip decap 在 VDD 局部
- LDO 后级 + bandgap reference 提供 clean VDD

---

## When to load this chapter

- σ_OS / metastability / kickback / aperture jitter 任一不达标
- 看到 tb_dc_op / tb_tran / tb_metastab_mc 异常
- agent 调 sizing 撞壁（多次试都没收敛）
- cross-corner 仿真发现退化

## Related

- **σ_OS / τ_reg / metastability 物理推导** → `blocks/base-cells/comparator-latch/strongarm`
- **5 类详细物理 troubleshooting** → `blocks/base-cells/comparator-latch/troubleshooting`
- **设计推进顺序 + sizing 起点** → `sizing-typical.md`
- **τ_reg / metastability error rate / aperture jitter / clock edge 时序分析** → `timing-stability.md` ⭐
- **拓扑选型 + 7 sizing pitfalls** → `architecture.md`
- **Reference design + standard testbench** → `reference-design.md`
- **SAR ADC ENOB 集成** → `blocks/sar-adc/{noise-budget, timing, troubleshooting}`
- **通用诊断方法** → `skill: systematic-debugging` / `signal-tracing`
