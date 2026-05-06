---
type: knowledge
domain: circuit
name: comparator
version: 1.0
summary: |
  比较器系统级设计知识：4 种主流拓扑（StrongARM / dynamic-comparator /
  preamp+latch / continuous-time）选择 + 关键 sizing pitfalls + StrongARM
  reference netlist。事实+因果格式，按需加载。物理实现细节（offset 推导 /
  metastability / kickback）在 `blocks/base-cells/comparator-latch/`，
  本 knowledge 关注系统级拓扑选型与应用接口。

chapters:
  - name: architecture
    summary: 4 拓扑变体（StrongARM / dynamic / preamp+latch / continuous-time）+ 选择决策树（speed/offset/kickback/power）+ 7 sizing pitfalls + 验证清单
    tokens: ~1500
  - name: sizing-typical
    summary: spec → device 因果（σ_OS / T_decide / kickback / jitter）+ 6 步推进顺序（σ_OS budget → input pair → regen → tail switch → clock edge → preamp）+ 4 拓扑变体顺序差异 + @vpdk180nm 起点表
    tokens: ~1500
  - name: timing-stability
    summary: ⭐ 灵魂章 — τ_reg 物理 + metastability 错误率指数 decay + clock edge / aperture jitter / latency 时序预算 + 4 失稳调整范例（metastability / jitter / short-through / V(tail)）
    tokens: ~1700
  - name: troubleshooting
    summary: 10 类失败模式（σ_OS 超 / metastable / kickback / jitter / clock race / cross-corner / tail switch / hysteresis 振荡 / preamp 不够 / 电源耦合）+ 推荐诊断顺序 + 根因表
    tokens: ~1700
  - name: reference-design
    summary: Production-grade StrongARM 9-MOSFET comparator reference + standard cir/tb 路径 + sizing 起点 + clock 时序约束
    tokens: ~900

trigger:
  explicit:
    user_selected_pack: comparator
  implicit:
    keywords:
      - comparator
      - 比较器
      - StrongARM
      - strong arm
      - strongarm
      - sense amplifier
      - slicer
      - regenerative
      - dynamic comparator
      - 动态比较器
      - preamp latch
      - preamp and latch
      - 预放大锁存
      - continuous-time comparator
      - hysteresis comparator
      - 迟滞比较器
      - latch comparator
    keywords_debug:
      - metastability
      - 元稳态
      - kickback
      - 回踢
      - 回踢噪声
      - offset 大
      - comparator offset
      - regen too slow
      - 再生太慢
      - decision time fail
      - 判决时间
      - clock race
    circuit_dependency_of:
      - systems/sar-adc
      - systems/adc-pipeline
      - systems/adc-flash
      - blocks/serdes-rx
      - blocks/pll-pfd     # PFD 内 comparator-style 触发器

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
    - meta-cognitive/systematic-debugging
  knowledge:
    - blocks/base-cells/comparator-latch     # 物理实现 source of truth
    - blocks/base-cells/differential-pair    # input pair matching
    - blocks/base-cells/switch               # clock-gating + reset
    - blocks/base-cells/cascode              # preamp gain stage
    - simulators/ngspice
    - pdks/vpdk180nm
  tools:
    - simulate
    - dc_snapshot
    - op_point_check
    - causal_trace

hierarchy: block
applicable_pdks: any
applicable_simulators: [ngspice, hspice, spectre]
authors: ["cirona team"]
---

# Comparator 设计知识

## Quick Facts

- Comparator = 输入差分采样 + 增益放大 + 阈值再生（rail-to-rail 输出）
- **拓扑选择三轴**：(1) clocked vs continuous-time / (2) static vs dynamic（功耗）/ (3) 是否有 preamp（offset / kickback 隔离）
- **clocked dynamic（StrongARM 系）默认**：高速 ADC / SerDes RX；低静态功耗（仅时钟 CV²f）；offset 5-30 mV 可校准
- **preamp + latch**：高精度（< 5 mV offset）/ kickback 敏感场合（SAR-DAC reference / pipeline residue）；preamp 静态功耗换隔离
- **continuous-time（hysteresis）**：慢速控制环 / 阈值检测 / power-on reset；不需要 clock 但功耗持续
- **dynamic-comparator（open-loop / charge-domain，非 regenerative latch）**：clocked 采样 + 动态放大，通常输出有限摆幅并接数字 buffer/latch；与 StrongARM 的 cross-coupled regeneration 分开；offset 偏大但面积/功耗最低

## Cheatsheet（典型 spec @ vpdk180nm，VDD=1.8V）

| 拓扑 | offset σ | speed | kickback | static power | 典型应用 |
|---|---|---|---|---|---|
| **StrongARM**（默认）| 5 – 30 mV | 1 – 10 GHz | 中 | 0（动态） | ADC 主比较器 / SerDes RX |
| **Preamp + StrongARM** | 1 – 5 mV | 0.5 – 5 GHz | **小**（preamp 隔离）| ~10-100 µW | 高精度 SAR / pipeline |
| **Dynamic comparator**（无 regenerative latch）| 10 – 50 mV | 1 – 5 GHz | 中 | 0 | 低功耗 flash ADC / 低分辨率 |
| **Continuous-time + hysteresis** | 1 – 10 mV | 100 kHz – 10 MHz | 小 | 1 – 100 µA | 阈值检测 / POR / 慢控制环 |

| 关键参数 | 典型范围 | 影响因素 |
|---|---|---|
| Decision time T_decide | 100 ps – 5 ns | `T_decide ≈ τ_reg · ln(V_logic / ΔV_initial)`，其中 `τ_reg = C_node / gm_regen` |
| Clock evaluate phase | 5×–20× τ_reg | metastability 错误率 1e-5 → 1e-9 |
| Input common-mode range | 0.3V – VDD-0.3V | input pair 极性（NMOS 高 ICM / PMOS 低 ICM） |
| Aperture jitter | 0.1 – 5 ps | clock buffer + input pair gm |

## When to load this knowledge

- 用户提到"比较器" / "comparator" / "StrongARM" / 想做 ADC 主比较器
- 设计 SAR / pipeline / flash ADC 的子模块（比较器 = 关键 building block）
- 设计 SerDes RX slicer 或 PFD（比较器风格触发器）
- 调试 metastability / kickback / offset 不达标

## When NOT to load

- 数字 flip-flop / SRAM cell 设计 → 数字 IC 标准库
- 比较器内部物理推导（offset σ / regen 时间 / metastability 公式）→ 直接读 `blocks/base-cells/comparator-latch/strongarm.md`（已有完整推导）
- ADC 完整系统设计（SAR 算法 / 时序逻辑 / 残差放大）→ `systems/adc-*`（W8+ 计划）

## Chapter Index

| Chapter | 何时加载 | Mandatory by stage | tokens | 状态 |
|---|---|---|---|---|
| `architecture` | 选拓扑 / 评估 4 变体 / sizing 决策 | 架构必读 | ~1500 | ✅ |
| `sizing-typical` | 6 步推进顺序 + 起点表 | sizing 阶段必读 | ~1500 | ✅ |
| **`timing-stability`** ⭐ | **τ_reg / metastable / jitter 任一相关**（comparator 灵魂章）| Tran 验证 + sign-off 必读 | ~1700 | ✅ |
| `troubleshooting` | σ_OS / metastable / kickback / jitter 任一 FAIL | Debug 必读 | ~1700 | ✅ |
| **`reference-design`** | **写 comparator .cir 之前必读** | 网表生成阶段必读 | ~900 | ✅ |

### Stage-driven mandatory loading

| 阶段 | 必读 chapters |
|---|---|
| 架构筛选 | `architecture` + `blocks/base-cells/comparator-latch/index` |
| **Sizing**（**严格顺序**：σ_OS → input pair → regen → tail → clock）| `sizing-typical` + `architecture` § Pitfalls + `blocks/base-cells/comparator-latch/strongarm` § sizing 范例 + **`pdks/<project_pdk>/index`** |
| **网表 + DC OP** | **`reference-design`** + `blocks/base-cells/comparator-latch/strongarm` + **`pdks/<project_pdk>/index`** + **`simulators/ngspice/index`** |
| **Tran 时序 + Metastability MC** | `timing-stability` + `reference-design` § 验证清单 + **`simulators/ngspice/analyses`**（pulse 边沿 / .meas 时序）|
| **Cross-corner timing 验证** | `timing-stability` § 失稳范例 + SS @ 125°C 关键 corner |
| **Debug（metastability / kickback / offset / cross-corner）**| `troubleshooting` 推荐诊断顺序 + 对应模式 + base-cell troubleshooting |

> ⚠️ **强制约定**：
> 1. **本系统级 knowledge 是 base-cell `comparator-latch/` 的应用层补充**，不替代物理推导
> 2. **timing-stability 必读用于 high-speed SAR / 高速 comparator**：metastable 错误率指数 decay → 必须按 spec BER 反推 t_alloc 倍数
> 3. **σ_OS budget 决定是否加 preamp**：10-bit 以上 SAR comparator 单 sizing 几乎不可能 < LSB/2，必须 calibration（preamp / auto-zero / digital trim）
> 4. simulate / generate_testbench 调用前必须**同时**load base-cell strongarm chapter + `pdks/<project_pdk>/index` + `simulators/ngspice/index`

## Related

- `blocks/base-cells/comparator-latch` 物理 source of truth（σ_OS / τ_reg / metastability / kickback 推导）
- `blocks/base-cells/differential-pair` input pair Pelgrom matching
- `blocks/base-cells/switch` clock-gating / reset
- `skill: device-sizing` / `signal-tracing` 通用方法
- `blocks/sar-adc/{noise-budget, timing}` 系统级集成

## 不在本 knowledge 范围

- 物理推导（σ_OS / τ_reg / metastability / kickback 公式起点）→ `blocks/base-cells/comparator-latch/strongarm`
- 5 类详细物理 troubleshooting → `blocks/base-cells/comparator-latch/troubleshooting`
- 完整 ADC 设计（SAR 算法 / FSM / 残差放大）→ `systems/sar-adc`
- Offset 数字校准（DAC trim / DEM）→ ADC 系统
- VCO / PLL phase detector → `systems/pll`
