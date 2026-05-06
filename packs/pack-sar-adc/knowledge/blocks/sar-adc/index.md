---
type: knowledge
domain: circuit
name: sar-adc
version: 1.0
summary: |
  SAR (Successive Approximation Register) ADC 系统级设计知识：4 种主流拓扑
  （charge-redistribution / bottom-plate sampling / merged-cap switching /
  asynchronous）选择 + 关键 sizing pitfalls + 10-bit reference design。复用
  comparator + bandgap + base-cells/switch（bootstrapped）作为子模块。本
  knowledge 关注系统级架构选型与子模块整合，物理实现细节引用 base-cell。

chapters:
  - name: architecture
    summary: 4 拓扑变体（charge-redistribution / bottom-plate / monotonic / async）+ ENOB/SFDR 决策树 + 7 sizing pitfalls + 验证清单
    tokens: ~1700
  - name: noise-budget
    summary: ⭐ 灵魂章 — 5 噪声源 LSB 预算分配（kT/C / σ_OS / comparator noise / VREF / jitter）+ R1 KVL + R2 等√5 分配铁律 + 5 个 R1-R4 失稳调整范例 + Phase A→F sign-off 流程
    tokens: ~2000
  - name: sizing-typical
    summary: spec → 子模块约束因果（跨子模块强耦合）+ Phase A→G 严格设计推进顺序（noise budget → C_total → matching → comparator → C_b → VREF → FSM timing）+ @vpdk180nm 起点表
    tokens: ~1700
  - name: timing
    summary: 同步 SAR 12 cycle 时序分配 + 异步 SAR ready signal 自适应 + DAC settle / comparator metastable / FSM setup 跨 corner 失稳范例
    tokens: ~1500
  - name: troubleshooting
    summary: 10 类失败模式（ENOB 卡 N-1 / ENOB σ 大 / DNL spike / offset 偏 / VREF ringing / cross-corner / SFDR / async / charge inj / time-interleaved）+ 推荐诊断顺序 + 根因表
    tokens: ~1700
  - name: reference-design
    summary: 10-bit charge-redistribution SAR ADC reference (CDAC + StrongARM + bootstrap S&H + SAR FSM) + standard cir/tb 路径 + sizing 起点 + clock 时序约束
    tokens: ~1300

trigger:
  explicit:
    user_selected_pack: sar-adc
  implicit:
    keywords:
      - SAR
      - SAR ADC
      - ADC
      - A/D converter
      - 逐次逼近
      - 逐次逼近 ADC
      - 逐次逼近寄存器
      - 模数转换
      - 模数转换器
      - charge redistribution
      - 电荷再分配
      - successive approximation
      - asynchronous SAR
      - 异步 SAR
      - split cap
      - merged cap switching
      - capacitive DAC
      - CDAC
      - binary-weighted DAC
      - sample and hold
      - 采样保持
      - bootstrapped switch
      - 自举开关
      - 电容 DAC
    keywords_debug:
      - DNL
      - INL
      - 微分非线性
      - 积分非线性
      - ENOB
      - SFDR
      - kT/C noise
      - SAR cycle
      - DAC settling
      - reference ringing
      - VREF ringing
      - 参考电压抖动
      - missing code
      - 失码
      - charge injection
      - 电荷注入
      - clock feedthrough
      - 时钟馈通
      - aperture jitter
      - 孔径抖动
    circuit_dependency_of:
      - systems/serdes-rx       # SerDes RX slicer 风格 SAR
      - blocks/sensor-frontend  # 传感器读出 ADC
      - blocks/pmic             # PMIC 内部 ADC
      - blocks/mixed-signal-soc

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
    - meta-cognitive/systematic-debugging
    - meta-cognitive/verification-before-completion
  knowledge:
    - blocks/comparator                      # SAR 主比较器（StrongARM）
    - blocks/bandgap                         # VREFP / VREFN 来源
    - blocks/base-cells/switch               # bootstrapped + transmission-gate
    - blocks/base-cells/comparator-latch     # comparator 物理细节
    - blocks/base-cells/output-stage         # low-Z VREF buffer implementation patterns
    - simulators/ngspice
    - pdks/vpdk180nm
  tools:
    - simulate
    - dc_snapshot
    - op_point_check
    - causal_trace
    - expectation_compare

hierarchy: system
applicable_pdks: any
applicable_simulators: [ngspice, hspice, spectre]
authors: ["cirona team"]
---

# SAR ADC 设计知识

## Quick Facts

- SAR ADC = S&H + capacitive DAC (CDAC) + comparator + SAR FSM；N 个时钟周期内 binary-search Vin
- **拓扑三轴**：sampling location (top/bottom plate) + switching (conventional/MCS/monotonic) + clock (sync/async)
- **Charge-redistribution**（默认）8–12 bit / **Bottom-plate**（>12 bit）/ **MCS**（低功耗）/ **Async**（高速）
- **CDAC matching → INL/DNL 上限**：`σ_unit/C_unit ≲ 1/(2^N·3)` 是无校准保守目标；RMS random mismatch 推导见 `chapter=architecture`
- **kT/C noise → ENOB thermal limit**：`C_total ≥ 12·k·T·2^(2N) / V_FS²`；10-bit / 1V FS → C_total ≥ ~50 fF
- **comparator offset > LSB → ENOB 直接损失**——offset calibration 是 > 10-bit SAR 标配
- **VREFP/VREFN ringing**：DAC switching 让 ref 抖动 → 必须 low-Z buffer + 大去耦 cap

## Cheatsheet（典型 spec @ vpdk180nm，VDD=1.8V，10-bit）

| Spec | 典型范围 | 影响因素 |
|---|---|---|
| Resolution N | 8 – 14 bit（>14 需校准）| CDAC matching + comparator offset |
| Sample rate | 100 kS/s – 100 MS/s | fclk × 1/(N+2) cycles |
| ENOB | N − 0.5 to N − 1.5 bit | kT/C noise + offset + DNL/INL |
| SFDR | 6N + 8 dB（理想）| CDAC matching + S&H linearity |
| INL / DNL | < 1 LSB / < 0.5 LSB | CDAC σ(C)/C |
| Power | 1 µW/MS/s（low-power MCS）– 100 µW/MS/s（conventional）| switching energy + comparator power |
| Latency | N+2 cycles | sample (1) + N bits + load (1) |
| Input impedance | C_total（DAC sample cap）| 决定 driver requirement |

> 4 拓扑 ENOB / speed / power 详细对比见 `chapter=architecture` § 4 拓扑变体对比表。

## When to load this knowledge

- 用户提到"做 SAR ADC" / "SAR" / "ADC" / "逐次逼近"
- 设计 mixed-signal SoC 内部 ADC（传感器读出 / PMIC monitoring / SerDes RX slicer）
- 调试 ENOB / SFDR / DNL / INL / metastability 不达标
- 选 ADC 架构（SAR vs pipeline vs Σ-Δ）

## When NOT to load

- pipeline ADC（残差放大架构）→ `blocks/adc-pipeline`（W7+ 后续）
- Σ-Δ ADC（oversampling）→ `blocks/adc-sigma-delta`（W7+ 后续）
- flash ADC（一周期完成，2^N comparators）→ `blocks/adc-flash`（W7+ 后续）
- 比较器内部物理 → `blocks/base-cells/comparator-latch/strongarm`
- CDAC unit cap layout → 数字 / mixed-signal layout knowledge
- Vref / 偏置生成 → `blocks/bandgap`

## Chapter Index

| Chapter | 何时加载 | Mandatory by stage | tokens | 状态 |
|---|---|---|---|---|
| `architecture` | 选拓扑 / 评估 4 变体 / sizing 决策 | 架构 + sizing 必读 | ~1700 | ✅ |
| **`noise-budget`** ⭐ | **任何 SAR sizing 必先读**（LSB 预算分配）| **sizing 阶段先于 W/L 决策必读** | ~2000 | ✅ |
| `sizing-typical` | sizing 7-phase 推进 + 起点表 | sizing 阶段必读 | ~1700 | ✅ |
| `timing` | 时序 cycle 分配 / metastable / cross-corner | sizing + tran 阶段必读 | ~1500 | ✅ |
| `troubleshooting` | ENOB / DNL/INL / SFDR / cross-corner 任一 FAIL | Debug 必读 | ~1700 | ✅ |
| **`reference-design`** | **写 SAR ADC .cir 之前必读** | 网表生成阶段必读 | ~1300 | ✅ |

### Stage-driven mandatory loading

| 阶段 | 必读 chapters |
|---|---|
| 架构筛选 | `architecture` + `blocks/comparator/index` + **`noise-budget`** ⭐ |
| **Sizing**（**严格顺序**：noise budget → C_total → matching → comparator → C_b → VREF → FSM）| **`noise-budget`** + `sizing-typical` + `blocks/comparator/sizing-typical` + `blocks/base-cells/switch/bootstrapped` + **`pdks/<project_pdk>/index`** |
| **网表 + DC OP** | **`reference-design`** + `blocks/comparator/reference-design` + `blocks/base-cells/switch/bootstrapped` + **`pdks/<project_pdk>/index`** + **`simulators/ngspice/index`** |
| Linearity / Dynamic + tran | `reference-design` § tb_linearity / tb_dynamic + `timing` + Monte Carlo + 主机侧 FFT |
| **Cross-corner timing 验证** | `timing` § 跨 corner 验证清单 + SS @ 125°C 关键 corner |
| **Debug（任何 FAIL）**| `troubleshooting` 先看推荐诊断顺序 + 对应失败模式 + base-cell troubleshooting |

> ⚠️ **强制约定（SAR ADC 特有）**：
> 1. **noise-budget 必先于 sizing**：sizing 数值起点都从 LSB 预算反推
> 2. **组合系统**：simulate 前必同时 load `blocks/comparator` + `blocks/base-cells/switch/bootstrapped` + `pdks/<project_pdk>/index`
> 3. **CDAC matching = INL/DNL 上限**：> 12-bit 必计划 calibration
> 4. **Linearity 验证不能跳**：tb_dnl / tb_inl Monte Carlo 是 sign-off 必备
> 5. **SS @ 125°C** 是 timing 关键 corner（DAC settle + comparator metastable 都最差）

## Related

- **`blocks/comparator`** — SAR 主比较器子模块（StrongARM 拓扑）
- **`blocks/bandgap`** — VREFP / VREFN reference 来源
- **`blocks/base-cells/switch`** — bootstrapped (S&H) + transmission-gate (CDAC switching)
- **`blocks/base-cells/comparator-latch`** — 比较器物理 source of truth
- **Skill `circuit-method/device-sizing`** — kT/C noise + CDAC matching sizing
- **Skill `circuit-method/signal-tracing`** — DNL/INL spike 反推 CDAC matching path

## 不属于本 knowledge 范围

- **比较器 / S&H switch / bandgap 子模块物理细节** → 各自 base-cell + block knowledge
- **CDAC unit cap layout / common-centroid / dummy ring** → 数字 / mixed-signal layout knowledge
- **Pipeline / Σ-Δ / flash ADC** → 各自架构（W7+ 后续）
- **Calibration 算法**（DAC trim / DEM / split-MSB）→ 校准 + 数字辅助 knowledge
- **FFT post-processing**（计算 ENOB/SFDR/SNDR）→ 主机侧分析脚本
- **clock generation / non-overlap circuit** → `blocks/base-cells/switch` + clock distribution knowledge
