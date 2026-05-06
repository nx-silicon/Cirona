---
type: knowledge
domain: circuit
name: common-gate-stage
version: 1.0
summary: |
  共栅级（common-gate stage）：source 输入 / gate AC 接地 / drain 输出。
  低输入阻抗（≈1/gm）+ 弱 Miller。
  覆盖 basic / TIA / LNA / regulated-cascode 四个应用场景。

chapters:
  - name: basic
    summary: 基础共栅级 —— Rin/Rout/Av 公式 / sizing / body effect / 与 cascode 区分
    tokens: ~800
  - name: tia-application
    summary: 共栅级在 TIA 前端的应用 —— 跨阻增益 / Rf 反馈 / 噪声 / BW
    tokens: ~700
  - name: lna-application
    summary: 共栅级在宽带 LNA 的应用 —— 输入匹配 / NF / IIP3 / RF 频段考虑
    tokens: ~700
  - name: regulated-common-gate
    summary: Regulated common-gate —— 内嵌反馈 OTA 把源节点钉住 / Rin 降到 1/(gm·A) / 稳定性
    tokens: ~700
  - name: troubleshooting
    summary: Rin 实际偏大 / 增益不足 / BW 受限 / gate bias 软 / drain 极点过低 五大故障
    tokens: ~600

trigger:
  explicit:
    user_selected_pack: common-gate-stage
  implicit:
    keywords:
      - common gate
      - 共栅
      - common-gate-stage
      - tia
      - 跨阻
      - lna
      - 低输入阻抗
      - regulated cascode
    circuit_dependency_of:
      - blocks/lna-cmos
      - blocks/tia
      - blocks/photodetector-frontend
      - blocks/ota-fc
      - blocks/telescopic-ota

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
    - circuit-method/ac-feedback-loop-method
  knowledge:
    - blocks/base-cells/cascode
    - blocks/base-cells/common-source
    - blocks/base-cells/active-load
    - blocks/base-cells/resistive-load
  tools:
    - simulate
    - dc_snapshot
    - op_point_check

hierarchy: base-cell
applicable_pdks: any
applicable_simulators: any
authors: ["cirona team"]
---

# 共栅级（Common-Gate Stage）

## Quick Facts

- **拓扑特征**：source = 信号输入，gate = AC 接地（DC bias），drain = 输出。这与 common-source（gate=输入）刚好相反
- **核心价值**：低输入阻抗（Rin ≈ 1/gm）+ **弱 Miller**（gate 是 bias 不是信号 → Cgd 不被信号摆幅放大）→ 适合宽带 / 电流输入接口
- **Rin 一阶**：`Rin ≈ 1/(gm + gmb)`（含 body effect），实际还受 ro / 漏端负载 / 源端寄生影响——不是固定值
- **不是 CS 翻转**：CG 用 source 接收信号 + drain 负载转换；CS 用 gate 接收信号 + drain 负载放大。物理机制不一样
- **与 cascode 的区别**：cascode 是**级联结构**内嵌的 CG（用于增益增强）；CG **作为输入级独立存在**（用于低 Rin / 宽带）。本 cell 仅讲独立 CG，cascode 内嵌见 `blocks/base-cells/cascode`
- **gate AC stiffness 是死线**：gate 必须有"硬"AC 接地（典型 ≥ 100 pF cap 或低 Rout 偏置网络）；否则 gate 也会随信号摆 → Miller 隔离失效
- **Av = gm × R_load**（drain 负载决定）：CG 自身不限制增益，整体增益由 drain 端 R 或 active load 设定
- **Vov 决定 Rin 量级**：典型 gm/Id = 8-15 → Vov 130-250 mV → Rin = Vov/(2·Id) ≈ 数 kΩ - 数百 kΩ（@ µA-mA bias）

## Cheatsheet（CG vs CS vs cascode 一表对比）

| 拓扑 | 信号输入端 | gate | drain | 关键作用 |
|---|---|---|---|---|
| common-source（CS）| gate | 信号 | 输出 | 电压增益 -gm·Rload；**有** Miller（Cgd × (1+Av)）|
| **common-gate（CG）** | **source** | **DC bias（AC ground）** | **输出** | 低 Rin + 弱 Miller；输入是电流型 |
| cascode（嵌入 CS 之上）| 来自下方 CS 的 drain | DC bias | 输出 | 提升 Rout 增 gain；本质上是 CG 用法但作为级联内嵌 |

## When to load this knowledge

- 设计 TIA（光电接收前端）/ 宽带 LNA / 传感器电流输入接口
- 选 CG vs CS 拓扑决策时（高源阻抗 → CS；低源阻抗 / 电流输入 → CG）
- 设计 regulated-cascode（CG 是其核心结构）

## When NOT to load

- 高源阻抗电压输入 → 用 common-source
- cascode 增益增强（CS 上叠 CG）→ 用 `blocks/base-cells/cascode`
- 输出缓冲 / 低 Rout → 用 source-follower

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `basic` | CG 基本原理 / Rin/Av 推导 / 与 CS 区分 | ~800 | ✅ |
| `tia-application` | TIA 前端 sizing / Rf 反馈 / 噪声 | ~700 | ✅ |
| `lna-application` | 宽带 LNA 匹配 / NF / RF 频段 | ~700 | ✅ |
| `regulated-common-gate` | 高 ro 应用 / OTA 反馈钉住源节点 | ~700 | ✅ |
| `troubleshooting` | Rin 偏大 / 增益不足 / BW / gate bias | ~600 | ✅ |

## Related

- Skill `circuit-method/signal-tracing` —— Rin / Av 异常先反推"是 gm 不够还是 R_load 不够"
- Skill `circuit-method/ac-feedback-loop-method` —— regulated CG 是反馈环，断环测 PM
- Knowledge `blocks/base-cells/cascode` —— cascode 是 CG 的级联用法
- Knowledge `blocks/base-cells/active-load` / `resistive-load` —— drain 负载选择决定增益

## 不属于本 knowledge 范围（明确划界）

- cascode 增益增强（CS+CG 级联）→ `blocks/base-cells/cascode`
- TIA 整体反馈环 / Rf 选择推导 → 本 cell `tia-application` chapter（仅讲 CG 在 TIA 中的角色，整体 TIA 设计见未来 `blocks/tia`）
- LNA 匹配网络 / S 参数 / IIP3 全套推导 → 仅给 CG 应用要点；详细见未来 `blocks/lna-cmos`
- gm/Id 方法学 → skill `circuit-method/device-sizing`
- body 连接 / well 隔离 layout → layout knowledge（V4 不在范围）
