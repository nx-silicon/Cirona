---
type: knowledge
domain: circuit
name: cmfb
version: 1.0
summary: |
  共模反馈（CMFB）：全差分电路输出共模闭环约束器。
  连续时间（resistive / source-follower / EA）+ 开关电容两大实现族。
  覆盖检测点 / 注入点 / 极性 / 加载 / 环路稳定性五个核心维度。

chapters:
  - name: continuous-time
    summary: 连续时间 CMFB（resistive divider / source-follower buffer / 误差放大器）—— 加载 / BW / 注入点
    tokens: ~800
  - name: switched-capacitor
    summary: 开关电容 CMFB —— 时钟相位 / kT/C / 纹波 / 离散时间稳定性
    tokens: ~700
  - name: troubleshooting
    summary: 共模漂移 / 环路振荡 / 极性反 / 加载过重 / SC 纹波 五大典型故障
    tokens: ~600

trigger:
  explicit:
    user_selected_pack: cmfb
  implicit:
    keywords:
      - cmfb
      - 共模反馈
      - common-mode feedback
      - 共模漂移
      - 全差分
      - fully differential
      - vcm
    circuit_dependency_of:
      - blocks/ota-fc
      - blocks/telescopic-ota
      - blocks/5t-ota
      - blocks/comparator
      - systems/adc-pipeline
      - systems/sar-adc

related:
  skills:
    - circuit-method/ac-feedback-loop-method
    - circuit-method/signal-tracing
    - circuit-method/bias-tree-reasoning
    - circuit-method/device-sizing
  knowledge:
    - blocks/base-cells/differential-pair
    - blocks/base-cells/active-load
    - blocks/base-cells/bias-generator
    - simulators/ngspice
  tools:
    - simulate
    - dc_snapshot
    - op_point_check

hierarchy: base-cell
applicable_pdks: any
applicable_simulators: any
authors: ["cirona team"]
---

# 共模反馈（Common-Mode Feedback, CMFB）

## Quick Facts

- **核心作用**：全差分电路第二条环路——主环定差分增益，CMFB 定**输出共模电平**；缺 CMFB 共模会漂到器件离开 saturation
- **物理本质**：检测两输出平均值 → 与 Vcm_ref 比较 → 反馈调节注入点（PMOS load gate / tail / cascode bias）拉回平均
- **三大变体**：CT R-divider（加载输出）/ CT source-follower（缓冲，耗 headroom）/ SC（零静态加载，相位敏感）
- **极性是死线**：检测 / 注入接错 = **正反馈推 rail**；极性验证用 **vcm_out 注入扰动**（不是改 Vcm_ref），看 vcmfb_ctrl 是否驱动共模拉回
- **BW_cmfb < 0.5 × GBW_ota**：超过会和主环耦合，复合 PM 退化
- **R_sense ≥ 5 × Rout_ota**（CT 硬约束）/ **C_hold ≈ 1-3 × C_sense**（SC 经验，比例小则纹波大但建立快）
- **检测点 ≠ 注入点**：检测在输出，注入在 PMOS load gate / tail / 折叠 bias，选错侵蚀差分通路 swing

## Cheatsheet（CT vs SC 实现速选）

| 维度 | CT（R-divider / SF / EA） | SC |
|---|---|---|
| 静态加载主 OTA | **有**（R-divider）/ 小（SF）/ 几乎无（EA-direct）| **无** |
| Headroom 代价 | 0（R）/ 1×Vov（SF）/ 0（EA）| 0 |
| 时钟需求 | 无 | **必需** ≥ 10×BW_cmfb |
| 噪声主项 | 4kT·R / SF flicker / EA noise | kT/C_sense |
| 适用 | 一般 CT OTA | SC 放大器 / 离散时间积分器 |

具体 sizing 范围（BW_cmfb / R_sense / C_sense / A_cmfb 等）见对应 chapter。

## When to load this knowledge

- 设计全差分 OTA / 比较器预放大 / SC 放大器 / 全差分滤波器
- dc_snapshot 输出共模偏 Vcm_ref > 50mV / 差分增益正常但 swing 异常
- 全差分 AC 仿真共模通路振铃

## When NOT to load

- 单端输出电路（无共模反馈需求）/ 仅做差分通路分析 / 仅做 bias chain 设计

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `continuous-time` | 设计连续时间 CMFB（默认起点）/ 选 R-divider vs SF | ~800 | ✅ |
| `switched-capacitor` | 设计 SC 放大器 / 离散时间积分器的 CMFB | ~700 | ✅ |
| `troubleshooting` | 共模漂移 / 振荡 / 极性问题 debug | ~600 | ✅ |

## Related

- Skill `circuit-method/ac-feedback-loop-method` —— CMFB 是反馈环，断环测 PM
- Skill `circuit-method/signal-tracing` —— 共模异常先反推"vcm 是谁决定的"
- Skill `circuit-method/bias-tree-reasoning` —— CMFB 注入点常在 bias chain 上
- Knowledge `blocks/base-cells/differential-pair` / `active-load` / `bias-generator`
- Tool `simulate` + `dc_snapshot` + `op_point_check`

## 不属于本 knowledge 范围（明确划界）

- OTA 主环差分通路设计 / 补偿 → `blocks/ota-*/ac-stability.md`
- bias chain 整体设计（含 EA 内部 bias）→ `blocks/base-cells/bias-generator`
- active load 拓扑选择 → `blocks/base-cells/active-load`
- gm/Id sizing 方法学 → skill `circuit-method/device-sizing`
- layout 匹配 / 数字校准 CMFB → V4 不在范围
