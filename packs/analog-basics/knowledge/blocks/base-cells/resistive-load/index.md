---
type: knowledge
domain: circuit
name: resistive-load
version: 1.0
summary: |
  电阻负载（resistive load）：用片上电阻替代有源负载提供线性 I→V 转换。
  Av = -gm·R 透明 / 宽带 / 4kTR noise 可预测；面积大 / 增益受限 / TCR 漂移。
  覆盖 basic / TIA Rf / broadband 三个应用 + troubleshooting。

chapters:
  - name: basic
    summary: 基础电阻负载 —— Av/swing/noise 公式 / poly vs diffusion vs well / triode MOS 替代
    tokens: ~700
  - name: tia-feedback-resistor
    summary: 电阻作 TIA Rf —— 跨阻 Z_T = Rf / 噪声 4kT/Rf / Rf·C_PD 极点
    tokens: ~600
  - name: broadband-load
    summary: 宽带 / RF 应用 —— 寄生 cap vs BW / shunt-peaking inductor / 高频补偿
    tokens: ~500
  - name: troubleshooting
    summary: Av 不达标 / swing 不够 / 噪声过大 / BW 受限 / TCR 漂移 五大故障
    tokens: ~500

trigger:
  explicit:
    user_selected_pack: resistive-load
  implicit:
    keywords:
      - resistive load
      - 电阻负载
      - poly resistor
      - feedback resistor
      - tia rf
      - 4kTR
      - broadband load
    circuit_dependency_of:
      - blocks/lna-cmos
      - blocks/tia
      - blocks/photodetector-frontend
      - blocks/voltage-reference

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
  knowledge:
    - blocks/base-cells/active-load
    - blocks/base-cells/common-source
    - blocks/base-cells/common-gate-stage
    - blocks/base-cells/differential-pair
  tools:
    - simulate
    - dc_snapshot
    - op_point_check

hierarchy: base-cell
applicable_pdks: any
applicable_simulators: any
authors: ["cirona team"]
---

# 电阻负载（Resistive Load）

## Quick Facts

- **核心增益关系**：`Av = -gm · R`（线性、与 ro 无关、与工作点几乎无关）—— 比 active-load 更透明
- **优势**：线性度好（电阻不随信号摆动）/ 宽带（无 ro·C 主极点，仅 R·Cpar）/ 噪声可预测（4kTR）/ 工艺独立的设计直觉
- **劣势**：
  - **面积大**：poly resistor ~100-300 Ω/sq → 20kΩ 需 ~100 sq；远大于同等 ro 的 MOS active load
  - **gain ceiling**：gm·R 典型 5-20，远低于 gm·ro 的 active-load（20-80）
  - **headroom 损失**：V_drop = I·R 直接吃 swing
  - **PSRR 差**：电源 noise 直接经 R 传到 V_out（不像 mirror load 有 ro 屏蔽）
  - **TCR 漂移**：poly ±500 ppm/°C / diffusion ±1500 ppm/°C → 增益 + bias 点跟温度走
- **5 个变体**：poly（最常见）/ diffusion（更高 sheet R 但 TCR 差）/ well（最高 sheet R / 线性度差）/ **triode-region MOS**（pseudo-resistor，可调但非线）/ off-chip（精度高但不集成）
- **典型 noise**：20 kΩ → √(4kT·R) ≈ 18 nV/√Hz @ 室温 → 低噪声场合可能主导
- **关键应用域**：TIA Rf 反馈电阻 / 宽带 LNA load / 电压基准 R-divider / 教学原型

## Cheatsheet（实现变体对照）

| 变体 | sheet R | TCR | VCR | Linearity | 适用 |
|---|---|---|---|---|---|
| poly resistor | 100-300 Ω/sq | ±500 ppm/°C | 低 | **优** | 通用首选（精度 + 线性 + matching）|
| diffusion resistor | 50-200 Ω/sq | ±1500 ppm/°C | 中 | 中 | 不推荐（除非不在乎 TCR）|
| well resistor | 1-10 kΩ/sq | ±2000-5000 ppm/°C | **高** | 差 | 极大 R 值（>1 MΩ）/ 不在乎线性度 |
| triode-MOS pseudo-R | 可调（gm 控）| 跟 V_th | 中 | 差（非线）| 面积紧 / 调谐 / replica bias |
| off-chip resistor | — | 精密 | — | 优 | 原型 / 测试板 |

## When to load this knowledge

- 设计宽带 LNA / TIA / 简单原型放大器
- 选 active load vs resistive load 决策（gain vs swing vs noise vs area）
- TIA Rf 反馈电阻 sizing（跨阻 Z_T = Rf）
- 看到 "20 kΩ resistor 18 nV/√Hz" 主导噪声 → 考虑改 active load

## When NOT to load

- 高增益单级（Av > 30）→ active load
- 面积紧 → triode-MOS（本 cell 子变体）或 active load
- 严格匹配（差分 offset）→ active load（但加大 W·L）

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `basic` | 基础公式 / 五变体选择 / triode-MOS 替代 | ~700 | ✅ |
| `tia-feedback-resistor` | TIA 跨阻设计 / Rf·C_PD 极点 | ~600 | ✅ |
| `broadband-load` | 宽带 / RF / shunt-peaking | ~500 | ✅ |
| `troubleshooting` | Av / swing / noise / BW / TCR 漂移 | ~500 | ✅ |

## Related

- Skill `circuit-method/device-sizing` —— 电阻 sizing 由 spec（Av / swing / Imax）反推
- Skill `circuit-method/signal-tracing` —— Av 不对先反推"R 不够还是 gm 不够"
- Knowledge `blocks/base-cells/active-load` —— 对照选择（gain 高用 active / 线性宽带用 resistive）

## 不属于本 knowledge 范围（明确划界）

- 有源负载（diode/mirror/cascode）→ `blocks/base-cells/active-load`
- 完整 TIA 系统（含输出级 + 反馈环 PM） → 未来 `blocks/tia/`
- 完整 LNA（含匹配网络）→ 未来 `blocks/lna-cmos/`
- bandgap reference R-divider → `blocks/bandgap/`
- 电阻物理工艺数据（精确 TCR / mismatch / Pelgrom 系数）→ `pdks/<工艺>/`
