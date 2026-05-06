---
type: knowledge
domain: circuit
name: output-stage
version: 1.0
summary: |
  输出级（output stage）：CMOS Class-AB / Push-Pull 双向驱动拓扑。
  覆盖偏置展开 / 静态电流 Iq / 交越失真 / 摆幅 / 大信号稳定性。

chapters:
  - name: class-ab
    summary: Class-AB 输出级 —— 偏置展开网络 / Iq 控制 / 交越失真 / 短路电流 / 自适应偏置
    tokens: ~900
  - name: push-pull
    summary: 互补 SF / 互补 CS 拓扑结构对照 —— Class A vs Class AB 概念区分
    tokens: ~600
  - name: troubleshooting
    summary: Iq 漂移 / 死区 / shoot-through / 大信号 PM 退化 / 摆幅不足 五大典型故障
    tokens: ~600
  - name: sizing-reasoning
    summary: |
      R4 架构-sizing 互锁铁律 — LDO Pass FET 实例化 (Vsg_pass 由 EA 输出
      范围决定; W 算超大不可行 → 回架构层换 EA 不死磕 W) + buffer 级
      caveat + Pass FET sizing TB 模板 + 100mA LDO Pass worked example
    tokens: ~1700

trigger:
  explicit:
    user_selected_pack: output-stage
  implicit:
    keywords:
      - output stage
      - 输出级
      - class ab
      - class-ab
      - push pull
      - push-pull
      - 互补源跟随
      - rail-to-rail
      - 大信号驱动
    circuit_dependency_of:
      - blocks/ldo
      - blocks/two-stage-ota
      - blocks/buffer
      - blocks/headphone-amp

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
    - circuit-method/ac-feedback-loop-method
  knowledge:
    - blocks/base-cells/source-follower
    - blocks/base-cells/common-source
    - blocks/base-cells/bias-generator
    - blocks/base-cells/miller-compensation
  tools:
    - simulate
    - dc_snapshot
    - op_point_check

hierarchy: base-cell
applicable_pdks: any
applicable_simulators: any
authors: ["cirona team"]
---

# 输出级（Output Stage）

## Quick Facts

- **核心作用**：把高阻 OTA 输出（kΩ-MΩ）转成低阻驱动（Ω-kΩ）→ 驱动电阻负载 / 大电容 / rail-to-rail 摆幅
- **两大结构维度**：（1）拓扑 push-pull（互补 SF / 互补 CS）—— 决定增益 / Rout / 摆幅；（2）偏置 Class A / AB / B —— 决定 Iq / 效率 / 交越失真
- **Class A vs Class AB 本质差别**：Class A 单方向 SR = Ibias/Cload；**Class AB 双向 SR = Imax/Cload，Imax ≫ Iq**（强反型 (Vgs-Vth)² 增长）
- **Iq 选择有上下限**：下限 = 避死区（典型 0.05-0.2 × Imax）；上限 = 静态功耗预算
- **偏置 diode unit 必须跟踪输出 unit PVT**：同类型 + 同 W/L + layout 邻近；**Iq 由 Iref × (m_out / m_diode) 决定**，不能单独改 diode W（破坏 tracking）
- **大信号稳定性独特问题**：输出级 gm 随工作点变化（小信号 gm_q → 大信号 gm 大 10×+）→ 主极点位置漂移 → 静态 PM ok 不代表大信号 PM ok
- **NMOS / PMOS 不对称**：μn / μp ≈ 2.5-3.5×，PMOS 输出管 W 通常 = 2-3× NMOS 来匹配 sink/source 对称
- **互补 SF Rout = 1/(gmP+gmN)**（小，稳定好）；**互补 CS Rout = roP‖roN**（大，需 Miller 补偿）

## Cheatsheet（拓扑 × 偏置 矩阵）

| 拓扑 | 偏置 | 增益 | Rout | 典型应用 |
|---|---|---|---|---|
| 互补 SF | Class A | ≈ 1 | 1/gm | 简单缓冲（少见 AB 化）|
| 互补 SF | **Class AB** | ≈ 1 | 1/(gmP+gmN) | LDO pass / OPamp 输出缓冲（**最常见**）|
| 单管 CS + 电流源负载 | Class A | -gm·(roP‖roN) | roP‖roN | **经典二级 OTA 第二级**（不是互补 CS）|
| 互补 CS | Class AB | -(gmP+gmN)·(roP‖roN)（大信号 gm 升）| roP‖roN | 高驱动 / Class-AB 输出变体（需 nested Miller）|

## When to load this knowledge

- 设计需要驱动外部负载（电阻 / 大 Cload）的 OPamp / LDO / driver
- 二级 OTA 第二级评估 Class A → AB 改造
- 看到输出 SR 不对称 / 交越失真 / 大信号瞬态尖峰 / 静态 PM 与大信号 PM 不一致

## When NOT to load

- 内部高阻输出节点（不驱动负载）→ 用 active-load 直接做输出
- OTA 内部级间节点 → 不需要输出级
- 数字驱动（CMOS inverter buffer）→ 那是数字 IO，不在本 cell

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `class-ab` | Class-AB 偏置 / Iq sizing / 交越失真 debug | ~900 | ✅ |
| `push-pull` | 选互补 SF vs 互补 CS / Class A vs AB 对比 | ~600 | ✅ |
| `troubleshooting` | Iq 漂移 / 死区 / shoot-through / 大信号 PM | ~600 | ✅ |
| `sizing-reasoning` | LDO Pass FET W 反推 / EA 输出范围互锁 / R4 架构兜底 | ~1700 | ✅ |

## Related

- Skill `circuit-method/device-sizing` —— 输出管 W 由 SR / Imax 决定，**不是**小信号增益
- Skill `circuit-method/signal-tracing` —— Iq 漂移先反推 Vbias 是谁决定的
- Skill `circuit-method/ac-feedback-loop-method` —— 大信号 PM 必须在最坏 gm 下验证
- Knowledge `blocks/base-cells/source-follower` / `common-source` —— 输出级是 SF 或 CS 的双器件版本
- Knowledge `blocks/base-cells/bias-generator` —— 偏置展开网络借用 bias chain
- Knowledge `blocks/base-cells/miller-compensation` —— 互补 CS 输出级必配 Miller 补偿

## 不属于本 knowledge 范围（明确划界）

- 数字 CMOS inverter / 大尺寸 IO buffer → 数字 IO knowledge（V4 不在范围）
- LDO pass FET 整体设计（含反馈环）→ `blocks/ldo/architecture.md`
- 二级 OTA 整体补偿策略 → `blocks/two-stage-ota/ac-stability.md`
- Layout 中输出管 finger interleaving / EM 设计 → layout knowledge（V4 不在范围）
