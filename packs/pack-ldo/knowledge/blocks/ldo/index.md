---
type: knowledge
domain: circuit
name: ldo
version: 1.0
summary: |
  PMOS-pass / NMOS-pass LDO 设计知识：架构选择 / EA 拓扑 / AC 稳定性 /
  PSRR / 负载瞬态 / troubleshooting。事实+因果格式，按需加载。

chapters:
  - name: reference-design
    summary: |
      Production-grade LDO reference (PMOS-pass + 2-stage EA + Miller) —
      standard cir/tb 路径 + EA stage2 接对 + bias chain 标准结构（LDO v3
      H-005/H-006 实战卡点已 codify）。Iron Law: 写 LDO 必先复用此 reference。
    tokens: ~900
  - name: architecture
    summary: PMOS / NMOS pass 选择 + EA 拓扑（5T / cascode / 双级）+ EA polarity 决策 + Pass FET sizing 反推
    tokens: ~900
  - name: standard-tests
    summary: |
      LDO 标准测试套件（Line/Load reg + AC log-spaced sweep + PSRR + Tran + DC OP 多点含 @0mA）
      + testbench 7 条硬约束（Method C 断环 / vp() 度数 / Tran reference 用 V_pre_step / @0mA 必须最小负载 / etc.）
      + 4 条设计规则（输出级必须有可控最小负载支路、bleeder 用镜像 Mbias 不用 vref-gate）。
      Iron Law: LDO 验证缺 P0 任一项 = 未完成。
    tokens: ~1100
  - name: ac-stability
    summary: 主极点 / 次极点位置 + 断环 testbench + 补偿策略
    tokens: ~800
  - name: psrr
    summary: PSRR 频段特性 + EA gain 关系 + 提升手段 + V3 实测的 shape sanity check
    tokens: ~700
  - name: overshoot
    summary: 负载瞬态过冲分析 + EA slew rate + Cload trade-off + Tran testbench
    tokens: ~600
  - name: troubleshooting
    summary: 不稳定 / DC offset / 启动失败 / PSRR 偏低 / Iq 超 spec 5 类症状对照
    tokens: ~700

trigger:
  explicit:
    user_selected_pack: ldo
  implicit:
    keywords:
      - LDO
      - 线性稳压
      - low dropout
      - regulator
      - voltage regulator
    keywords_debug:    # debug 阶段触发 troubleshooting + architecture chapters
      - dropout
      - pass FET in triode
      - sizing not converging
      - device in triode
      - DC OP FAIL
      - Iload stress
      - PSRR low
      - Iq over spec
      - startup fail
    circuit_dependency_of:
      - power-management
      - bandgap-with-ldo
      - pmic

related:
  skills:
    - circuit-method/ac-feedback-loop-method
    - circuit-method/signal-tracing
    - circuit-method/device-sizing
    - meta-cognitive/systematic-debugging
    - meta-cognitive/verification-before-completion
  knowledge:
    - blocks/base-cells/current-mirror
    - blocks/base-cells/differential-pair
    - blocks/base-cells/cascode
    - blocks/base-cells/common-source
    - blocks/base-cells/miller-compensation
    - blocks/bandgap         # Vref 来源
    - simulators/ngspice
    - pdks/vpdk180nm
  tools:
    - simulate
    - dc_snapshot
    - op_point_check
    - causal_trace
    - expectation_compare

hierarchy: block
applicable_pdks: any
applicable_simulators: [ngspice, hspice, spectre]
authors: ["cirona team"]
---

# LDO 设计知识

## Quick Facts

- LDO = pass FET + 反馈环 + EA + Vref；输出受控复制 Vref 到 Vout（差一个分压系数）

- 拓扑选择两个轴：**pass 极性**（PMOS / NMOS）+ **EA 拓扑**（5T / cascode / 双级）

- **5T-EA 不能做 LDO**：5T gain 25-35 dB，LDO loop 需要 50-70 dB——必须 cascode 或双级 EA

- **EA polarity 由 Vref / VDD / 工艺共同决定**（按 input pair vcm 范围算，不要硬编码 0.8V/1.0V 这种数）：
  - `vcm_max = VDD − |Vth_p| − Vdsat_tail`（PMOS pair 上限：tail 头空间够 + PMOS 输入不饱和）
  - `vcm_min = Vth_n + Vdsat_tail`（NMOS pair 下限：tail 头空间够 + NMOS 不关）
  - `Vdsat_tail` 取约 0.1V
  - **决策规则**：
    - `Vref > vcm_max` → 选 **NMOS** input pair（PMOS 撑不住高 vcm）
    - `Vref < vcm_min` → 选 **PMOS** input pair（NMOS 撑不住低 vcm）
    - `vcm_min ≤ Vref ≤ vcm_max` 且 `vcm_max − vcm_min` 充裕 → 默认 **PMOS** pair（噪声更优）
    - `vcm_max − vcm_min` 不够（rail 紧张）或 Vref 接近边界 → **折叠 cascode** EA（rail-to-rail input range）

- **主极点几乎总在输出节点**：fp_main = 1/(2π·Rout·Cload)，nF 级 Cload → 1-100 kHz

- **PSRR 形状是免费 sanity check**：PSRR 应在 DC 最高 + 单调下降；如果 PSRR DC 低 / 高频高 → loop 没增益（categorical failure，不是数字议价）

- **Iload 改变 UGF 5-10×**：gm_pass ∝ √Id，Iload_max / Iload_min 全 corner 都要测 PM

- **ESR 是补偿的一部分**：Cload-ESR 引入零点抵消次极点；纯陶瓷 cap (ESR ~ 10mΩ) PM 会崩

## ⭐ Spec Ceiling Table（拓扑能力上限 — 设计前必查）

> **Iron Law**：开始 sizing 前，**必须**对账目标 spec 与本表。任何 spec 超过对应拓扑的 ceiling →
> 不能靠 trim/sizing 救，必须换拓扑 / 改架构 / declare hypothesis。

### EA 拓扑能力上限

| Spec | 5T-EA | cascode-EA | **双级 EA**（默认）| 双级 + cascode stage1 | 双级 + post-LDO 二级 |
|---|---|---|---|---|---|
| **DC loop gain T₀** | 25-35 dB ❌ LDO 不够 | 50-60 dB | **50-70 dB** | 70-90 dB | 90+ dB |
| **PSRR @ DC** | 25-35 dB ❌ | 50-60 dB | 50-70 dB | 60-80 dB | > 80 dB |
| **PSRR @ 1kHz** | 同 DC ±5 dB | 同 DC | 同 DC | 同 DC | 同 DC |
| **PSRR @ 100kHz** | < DC（fp1 退化）| 30-40 dB | 30-50 dB | 40-60 dB | 50-70 dB |
| **PSRR @ 1MHz** | < 30 dB | 20-30 dB | 20-40 dB（Cload+ESR）| 30-50 dB | 40-60 dB |
| **PM @ Imax + corner** | 难（5T 拓扑限）| ≥ 45° | ≥ 45° | ≥ 45° | ≥ 45° |
| **Iq** | 5-20 µA | 15-40 µA | 20-50 µA | 30-70 µA | 40-90 µA |

### Pass FET 拓扑能力上限

| Spec | PMOS-pass（默认）| NMOS-pass + boost |
|---|---|---|
| **dropout @ 10mA** | ≤ 50 mV | < 50 mV |
| **dropout @ 100mA** | 200-500 mV（W=2000-3000µm）| **< 50 mV** |
| **响应速度** | 中（Cgs_pass 大）| 快 |
| **PSRR @ HF** | 受 Cload+ESR | 较好 |
| **复杂度** | 低（VDD 直驱）| 高（需 Vboost > Vin）|

### LDO Topology 选择（A/B/C 三拓扑）

| Topology | EA 结构 | PM @ all Iload | 适用 |
|---|---|---|---|
| **A**（PMOS-CS 5T 双级）| 5T diff + PMOS-CS stage2 + Miller | 0-Iload 难全 PM > 45°（LHP zero 漂）| 通用单负载点 |
| **B**（PMOS-input 5T + SF + Miller）⭐ | 5T + Source Follower + Miller | **0-Iload_max 全 PM > 45°** | **0-30mA 全负载范围（demo 04 默认）** |
| **C**（FC + buffer）| Folded-cascode + buffer stage | 与 A 类似 | 高 PSRR 应用 |

### Spec → 必选拓扑路径

```
spec PSRR DC ≤ 35 dB        → 5T-EA OK（罕见 spec）
spec PSRR DC 35-60 dB       → cascode-EA 或双级 EA
spec PSRR DC 50-70 dB       → 双级 EA（**默认**）
spec PSRR DC 60-80 dB       → 双级 + cascode stage1
spec PSRR DC > 80 dB        → 上述 + post-LDO 二级（系统级）
spec PSRR @ 1MHz > 50 dB    → 大 Cload + low-ESR ceramic / 多级 / active filter（不能只靠 EA）
spec dropout < 50mV @ 100mA → 必 NMOS-pass + Vboost（超出 PMOS-pass 标准范围）
spec PM > 45° at 0-Iload_max → 必选 B 拓扑（PMOS-input + SF + Miller）
spec Iq < 10µA              → 必须低功耗 EA + 削减 bias mirror legs
spec Vref < 0.8V            → EA polarity 改 PMOS diff-pair
spec Vref 0.8-1.0V          → folded cascode EA
spec Vref ≥ 1.0V            → NMOS diff-pair EA（默认）
```

**详细机理**：见 `architecture.md` § EA 拓扑选择 / `psrr.md` § 频段特性。

---

## Cheatsheet（典型 spec @ vpdk180nm，VDD=1.8V，Vout=1.2V，双级 EA）

| Spec | 典型范围 | 影响因素 |
|---|---|---|
| Iload | 1 – 50 mA | pass FET sizing |
| dropout @ 10mA | ≤ 50 mV | pass FET R_DS(on) |
| line regulation | < 5 mV/V | EA DC gain |
| load regulation | < 10 mV (1→10mA) | loop gain (gm_pass × Rout × T) |
| **DC loop gain T₀** | **50 – 70 dB** | **EA topology**（5T 不够 ≥40dB，必双级 / cascode） |
| UGF | 100 kHz – 2 MHz | 主极点位置 + Iload |
| PM | ≥ 45° （全 Iload）| 极点分离 + 补偿 |
| PSRR @ DC / 1kHz | 50 – 60 dB | T(f) |
| PSRR @ 1MHz | 30 – 50 dB | Cload + ESR |
| Iq (EA) | 10 – 50 µA | EA bias（双级双倍）|
| 负载瞬态过冲（1→50mA, 1µs 边）| < 50 mV | Cload + EA slew |

## When to load this knowledge

- 用户提到"做 LDO" / "稳压器" / "regulator"
- 设计 PMIC / bandgap+LDO 复合电路时（依赖 LDO 子模块）
- 调试 PSRR / 过冲 / 稳定性问题
- 已选 pdk + simulator，需要决定 LDO 架构

## When NOT to load

- 用户问的是 buck / boost converter（开关电源）→ 不同架构
- 用户问的是 reference voltage（bandgap）→ 用 `blocks/bandgap/`
- charge-pump regulator → 不在本 knowledge 范围

## Chapter Index

| Chapter | 何时加载 | Mandatory by stage | tokens | 状态 |
|---|---|---|---|---|
| **`reference-design`** | **写 LDO .cir 之前必读** | **网表生成阶段必读** | ~900 | ✅ Week 5 |
| `architecture` | 选拓扑 / 评估 EA 类型 / **任何 sizing 决策** | **架构 + sizing 必读** | ~900 | ✅ Week 2 |
| **`standard-tests`** | **写 testbench / 跑验证之前必读** | **任何 LDO 验证阶段必读**——P0 测试集 + 7 条 testbench 硬约束 + 4 条设计规则 | ~1100 | ✅ v4-demo |
| `ac-stability` | 验证 PM / GBW / 调补偿 | AC sim 阶段必读 | ~800 | ✅ Week 2 |
| `psrr` | 调 PSRR / 解读频段特性 / shape sanity check | PSRR sim 必读 | ~700 | ✅ Week 3 |
| `overshoot` | 调负载瞬态 / EA slew rate | Tran sim 必读 | ~600 | ✅ Week 3 |
| `troubleshooting` | debug 不稳 / DC offset / startup fail / PSRR / Iq / **dropout 边缘 / device triode** | **任何 simulate FAIL 后必读**；sizing 改 2 次未收敛必读 | ~700 | ✅ Week 3 |

### Stage-driven mandatory loading

| 阶段 | 必读 chapters（按需可叠加更多）|
|---|---|
| 架构筛选 | `architecture` |
| Sizing | `architecture`（含 Pass FET sizing 反推公式）+ **`pdks/<project_pdk>/index`**（μCox / Vth / Lmin 起点）|
| **网表 + DC OP** | **`reference-design`**（必读，复用 standard cir 而非从零写）+ `architecture` + **`pdks/<project_pdk>/index`**（模型名 / .lib section）+ **`simulators/ngspice/index`**（lib 路径写法）|
| **写 testbench / 跑验证** | **`standard-tests`**（必读 P0 测试集 + 7 条硬约束 + 4 条设计规则）+ **`reference-design`**（复用标准 testbench）|
| AC PM/GBW | `ac-stability` + `standard-tests` § Conv-1/2/3 + **`simulators/ngspice/analyses`** |
| AC PSRR | `psrr` + `standard-tests` § LDO-T6 + **`simulators/ngspice/analyses`** |
| Tran 过冲 | `overshoot` + `standard-tests` § Conv-4（reference 用 V_pre_step）+ `simulators/ngspice/analyses` |
| Line reg / Load reg | `standard-tests` § LDO-T3/T4（**Vin ±10% 范围，必含 @0mA**）|
| **Debug（任何 FAIL）** | **`troubleshooting` + `simulators/ngspice/common-errors`**（按症状关键字定位修复）+ 重读 sizing 相关 architecture 节 |
| **Sizing 不收敛（同轴改 ≥ 2 次）** | **`troubleshooting` § 症状 2（pass FET triode）+ architecture § Pass FET sizing**——本章里有 dropout = Iload × R_DS(on) 反推公式 |

> ⚠️ **强制约定**：任何 simulate / generate_testbench 调用前**必须先 load** `pdks/<project_pdk>/index` + `simulators/ngspice/index`——这两个章节包含 vpdk180nm 模型名 (nch/pch 不是 nch_18)、`.lib '...' <corner>` 写法、vp() 弧度坑等"agent 反复踩"的硬约束。漏 load 即被 v1/v2/v3 已踩过的坑卡住，浪费 10+ turn。

## Related

- **Skill `circuit-method/ac-feedback-loop-method`** —— 通用 AC 断环思路（断点选择 / Rfb 1G / Cfb 1F），LDO 特定断点见本 knowledge `chapter=ac-stability`
- **Skill `circuit-method/signal-tracing`** —— DC 漂 / region 错时反推上游
- **Skill `circuit-method/device-sizing`** —— pass FET / EA 输入对 / mirror sizing
- **Knowledge `blocks/bandgap`** —— Vref 来源 + 启动行为（影响 LDO startup）
- **Knowledge `blocks/base-cells/miller-compensation`** —— Miller Cc + nulling resistor
- **Tool `simulate` + `dc_snapshot` + `causal_trace`** —— 仿真 + 状态拿取 + 因果追溯

## 不属于本 knowledge 范围（明确划界）

- **5T-OTA / cascode-OTA / 双级 OTA 各自的 sizing**——见 `blocks/ota-*`（LDO EA 是其复用，本 knowledge 仅给 EA 选型决策不重复 sizing 细节）
- **Miller 补偿原理 / RHP zero / nulling resistor**——见 `blocks/base-cells/miller-compensation/`
- **bandgap startup / TC**——见 `blocks/bandgap/`
- **buck / boost / 开关电源**——不在本 knowledge 范围（不同架构家族）
- **ngspice 具体 .ac 卡 / setplot / vp 弧度**——见 `simulators/ngspice/analyses.md`
- **AC 断环通用思路**（哪里断 / 为什么 1G+1F）——见 skill `circuit-method/ac-feedback-loop-method`
