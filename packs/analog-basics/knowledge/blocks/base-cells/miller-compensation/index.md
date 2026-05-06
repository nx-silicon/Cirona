---
type: knowledge
domain: circuit
name: miller-compensation
version: 1.0
summary: |
  Miller 补偿（Miller compensation）：在多级 opamp 中通过反馈电容实现极点分裂 + 频率补偿。
  覆盖 plain Miller / nulling resistor（消 RHP zero）/ Ahuja-style（current buffer）/
  nested Miller（三级）/ **parasitic Miller**（寄生效应分析，用户特别要求）。

chapters:
  - name: plain-miller
    summary: 基础 Miller 补偿 —— Cc 跨第二级 / 极点分裂 / RHP zero / GBW 推导
    tokens: ~700
  - name: nulling-resistor
    summary: Nulling resistor 消 RHP zero —— Rz 与 Cc 串联 / 1/gm2 选值 / PVT
    tokens: ~600
  - name: ahuja-style
    summary: Ahuja current-buffer Miller —— cascode 路径完全消 RHP / 速度优势 / 复杂度
    tokens: ~600
  - name: nested-miller
    summary: 嵌套 Miller —— 三级 opamp 多 Cc / 极点距离设计 / LDO 与音频应用
    tokens: ~700
  - name: parasitic-miller
    summary: 寄生 Miller 效应 —— Cgd × (1+Av) 倍增 / LNA / CS 输入端 / 对策
    tokens: ~700
  - name: troubleshooting
    summary: PM 不足 / RHP zero 没消 / 大 Cload 失稳 / nested Miller 极点距离不够
    tokens: ~600

trigger:
  explicit:
    user_selected_pack: miller-compensation
  implicit:
    keywords:
      - miller compensation
      - miller 补偿
      - cc
      - rhp zero
      - nulling resistor
      - ahuja
      - nested miller
      - parasitic miller
      - 寄生 miller
      - pole splitting
    circuit_dependency_of:
      - blocks/two-stage-ota
      - blocks/ldo
      - blocks/lna-cmos
      - blocks/audio-amplifier

related:
  skills:
    - circuit-method/ac-feedback-loop-method
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
  knowledge:
    - blocks/base-cells/common-source
    - blocks/base-cells/output-stage
    - blocks/base-cells/cascode
  tools:
    - simulate
    - dc_snapshot

hierarchy: base-cell
applicable_pdks: any
applicable_simulators: any
authors: ["cirona team"]
---

# Miller 补偿（Miller Compensation）

## Quick Facts

- **核心机制**：在多级 opamp 第二级（CS 输出级）跨电容 Cc → 通过 Miller 效应把 Cc 等效放大 (1+|Av2|) 倍 → 形成 dominant pole（pole splitting）
- **极点分裂结果**：fp1 ↓（被等效大电容拖低）/ fp2 ↑（output 节点被 short to gnd via Cc）→ 双极点距离拉开 → PM 改善
- **RHP zero 副作用**：Cc 也提供前馈路径 → 引入右半平面零点 ω_z = gm2/Cc → PM 减分（zero 与极点不抵消，加恶化）
- **三大改进版**：
  - `nulling-resistor`：Rz 与 Cc 串联，Rz = 1/gm2 → 把 RHP zero 推到无穷（理想抵消）
  - `Ahuja-style`：用 cascode device 阻断前馈路径 → 完全消 RHP zero + 速度更优
  - `nested-miller`：三级 opamp 用多个 Cc 嵌套 → 适合大 Cload 或音频
- **parasitic Miller**（**用户特别要求章节**）：Cgd 在 CS 输入端被 (1+|Av|) 倍增 → LNA / 高速 CS 主 BW 限制；不是补偿但是**关键现象**
- **GBW 公式**（plain Miller）：`GBW = gm1 / (2π·Cc)` → 由前级 gm 决定，**不**由后级 gm
- **第二极点位置**：`fp2 = gm2 / (2π·CL)` → 由后级 gm 与负载决定
- **PM 60° 准则**：通常要求 fp2 ≥ 3 × GBW（@ 60° margin）

## Cheatsheet（补偿方案对照）

| 方案 | RHP zero | 速度（GBW）| 复杂度 | 应用 |
|---|---|---|---|---|
| plain Miller | **存在** ω_z = gm2/Cc（恶化 PM）| 一般 | 低 | 简单原型 / 不严格 |
| Miller + nulling Rz | 推到 ∞（理想抵消）| 略损（Rz 引入次级寄生）| 低 | **二级 opamp 标配** |
| Ahuja-style（cascode Miller）| **完全消除** | 优（GBW 提升 30-50%）| 中 | 高速 + 严格 PM |
| nested Miller（多级）| 需各级 Rz | 速度受限于内层 | 高 | 三级 opamp / 大 Cload / LDO / 音频 |

## When to load this knowledge

- 设计两级 / 三级 opamp（含主 OTA 频率补偿）
- LDO 反馈环补偿（pass FET 高 Rout × Cload 极点）
- LNA / 高速 CS 评估**寄生 Miller** 影响 BW
- 看到 PM 不足 / RHP zero 干扰 / 大信号失稳 → debug

## When NOT to load

- 单级 opamp（5T-OTA 等，不需 Miller）→ `blocks/5t-ota/`
- regulated cascode（用 OTA 反馈非 Miller）→ `blocks/base-cells/common-gate-stage/regulated-common-gate.md`
- ESR 补偿（LDO 用电容 ESR 引入零点）→ 反馈补偿是另一类机制

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `plain-miller` | 基础原理 / pole splitting / RHP zero | ~700 | ✅ |
| `nulling-resistor` | 二级 opamp 标准消零方法 | ~600 | ✅ |
| `ahuja-style` | 高速 + 大 Cload + 严格 PM | ~600 | ✅ |
| `nested-miller` | 三级 opamp / LDO / 音频 | ~700 | ✅ |
| `parasitic-miller` | LNA / 高速 CS BW 评估 | ~700 | ✅ |
| `troubleshooting` | PM 不达标 / 零点干扰 / 大信号失稳 | ~600 | ✅ |

## Related

- Skill `circuit-method/ac-feedback-loop-method` —— 补偿是反馈环 PM 调节，断环测 PM
- Skill `circuit-method/device-sizing` —— Cc / Rz 选值由 GBW + PM spec 反推
- Knowledge `blocks/base-cells/common-source` —— Miller 寄生发生在 CS 拓扑
- Knowledge `blocks/base-cells/output-stage` —— 互补 CS 输出级是 Miller 补偿的常见目标级

## 不属于本 knowledge 范围（明确划界）

- 单级 OTA 补偿（不需 Miller）→ `blocks/5t-ota/`
- 完整二级 opamp 设计 → `blocks/two-stage-ota/`
- LDO 整体环路 → `blocks/ldo/`
- LNA 完整设计 → `blocks/lna-cmos/`
- gm/Id 方法 → skill `circuit-method/device-sizing`
