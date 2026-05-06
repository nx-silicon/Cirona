---
type: knowledge
domain: circuit
name: comparator-latch
version: 1.0
summary: |
  比较器锁存（comparator-latch）：交叉耦合正反馈再生 + 输入差分采样 + 时钟评估。
  三大变体：StrongARM（动态采样+再生）/ static latch（双稳态保持）/ dynamic latch（动态预充+评估）。
  覆盖 offset / metastability / kickback / aperture 关键性能指标。

chapters:
  - name: strongarm
    summary: StrongARM 动态比较器 —— 预充电 / 评估 / 再生三相 / kickback / offset 推导
    tokens: ~800
  - name: static-latch
    summary: 静态锁存 —— 双稳态交叉耦合 / 持续 hold / digital interface
    tokens: ~600
  - name: dynamic-latch
    summary: 动态锁存 —— clock-driven 预充 + 评估 / 比 static 更省功耗 / leakage 限
    tokens: ~600
  - name: troubleshooting
    summary: offset 大 / metastability / kickback / 时钟 race / 电源耦合
    tokens: ~600

trigger:
  explicit:
    user_selected_pack: comparator-latch
  implicit:
    keywords:
      - comparator
      - 比较器
      - latch
      - 锁存
      - strongarm
      - regenerative
      - metastability
      - 元稳态
      - kickback
    circuit_dependency_of:
      - systems/sar-adc
      - systems/adc-pipeline
      - systems/adc-flash
      - blocks/serdes-rx

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
  knowledge:
    - blocks/base-cells/differential-pair
    - blocks/base-cells/switch
  tools:
    - simulate
    - dc_snapshot

hierarchy: base-cell
applicable_pdks: any
applicable_simulators: any
authors: ["cirona team"]
---

# 比较器锁存（Comparator Latch）

## Quick Facts

- **核心机制**：交叉耦合正反馈把输入差分（mV 级）再生到全摆幅数字输出（VDD/VSS 级）
- **关键时序三相位**（StrongARM 典型）：
  - **reset/precharge**：内部节点充电到 rail，差分对预备
  - **evaluate（采样）**：差分输入产生小不平衡（~mV）
  - **regenerate（再生）**：交叉耦合放大不平衡到 rail-to-rail
- **offset 来源**：input pair Vth 失配（Pelgrom σ ∝ 1/√(WL)）/ tail 电流失配 / 内部节点电容失配；典型 σ_OS = 5-30 mV @ 标准 sizing
- **metastability（元稳态）**：输入初始差分 ΔV 很小时，再生时间 T_reg = τ_reg·ln(V_logic/ΔV) 可能超过 evaluate 时间 → 输出未达 rail；概率 P_meta = P(ΔV < V_threshold) × exp(-T_evaluate/τ_reg)；典型每 1e6-1e9 次比较 1 次（取决于 evaluate/τ_reg 比与输入分布）
- **kickback noise**：内部节点摆动通过 Cgd 反向耦合到输入端 → 干扰前级（特别是高阻 ADC reference）；典型 kickback charge = Cgd × ΔV_internal
- **aperture window**：评估相位的有效"采样时间" = 几 ps（StrongARM 典型 5-20 ps @ 180nm）→ jitter 大时 SNR 受限
- **三变体决策**：
  - StrongARM：高速 / 低功耗 / 大 ADC（典型选择）；offset 较大但可校准
  - static latch：保持时间长 / 数字接口 / leak-free；不适合高速比较
  - dynamic latch：clock-driven，比 static 省功耗 / 速度高；leakage 限制保持时间

## Cheatsheet（三变体对照）

| 维度 | StrongARM 比较器 | Static latch | Dynamic latch |
|---|---|---|---|
| 输入类型 | **差分模拟**（mV 级）| 数字（rail-to-rail） | 数字（rail-to-rail） |
| 时钟数 | 1（CK）| 0（持续 power）| 1（CK）|
| 静态功耗 | 0（仅时钟阶跃损耗 CV²f）| 显著（cross-coupled 持续电流）| ~0 |
| 速度 | 高（1-10 GHz @ 180nm）| 中 | 高 |
| Offset | 5-30 mV | N/A（数字）| N/A |
| 保持时间 | 1 个时钟周期 | 持续 | 受 leakage 限（~µs）|
| 应用 | ADC 比较 / SerDes RX | digital flip-flop | clock-gated dynamic logic |

## When to load this knowledge

- 设计 ADC 比较器（SAR / pipeline / flash）
- 高速 SerDes RX slicer
- 选 comparator 拓扑（速度 / offset / 功耗 trade-off）
- 看到 ADC INL/DNL 异常或 metastability 错误率超标 → 调查比较器 offset / kickback

## When NOT to load

- 数字 flip-flop 设计（标准库 cell）→ 数字 IC knowledge
- 单端比较（如 hysteresis comparator） → analog comparator with reference
- VCO / PLL phase detector → systems/pll

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `strongarm` | ADC 主比较器 / 高速差分模拟比较 | ~800 | ✅ |
| `static-latch` | 数字 flip-flop / 长时间保持 | ~600 | ✅ |
| `dynamic-latch` | clock-gated logic / 低功耗保持 | ~600 | ✅ |
| `troubleshooting` | offset / metastability / kickback / 时序 | ~600 | ✅ |

## Related

- Skill `circuit-method/device-sizing` —— input pair Pelgrom matching 决定 offset
- Skill `circuit-method/signal-tracing` —— offset / metastability 错误率不达标先反推
- Knowledge `blocks/base-cells/differential-pair` —— StrongARM input pair 是 diff pair 的特殊采样形式
- Knowledge `blocks/base-cells/switch` —— dynamic latch / strongarm 内部用 switch 控时序

## 不属于本 knowledge 范围（明确划界）

- 完整 ADC 设计（SAR 算法 / 残差放大器）→ `systems/adc-*`
- 比较器 offset 校准（数字辅助）→ ADC 系统 + 校准 knowledge
- noise-cancelling preamp + comparator → 高精度比较器架构
- VCO/PLL 内 PFD → `systems/pll`
- 时钟生成 / non-overlap → 时钟分配 knowledge
