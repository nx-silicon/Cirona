---
type: knowledge
domain: circuit
name: folded-cascode-ota
version: 1.0
summary: |
  Folded-cascode OTA (FC-OTA) 设计参考：5 group standard topology + 9-MOSFET
  wide-swing bias tree + reference cir/tb 路径 + 已知 PMOS cascode connectivity
  陷阱。事实+因果格式，**Iron Law: 设计 FC-OTA 必先 load reference-design 章节，
  不要从零造拓扑**（FC bias chain 复杂，从零造几乎必踩 PMOS cascode 接错 trap）。

chapters:
  - name: architecture
    summary: 5 group + 9-bias 拓扑细节 + variants（PMOS-input / fd_cmfb / gain-boosted / low-VDD）+ 与其他 OTA 4D 对比
    tokens: ~1100
  - name: sizing-typical
    summary: spec → device 约束因果 + fold_ratio 耦合规则 + 5 group 同步 sizing 推进顺序 + @vpdk180nm 起点表
    tokens: ~1500
  - name: bias-headroom
    summary: ⭐ Vds/Vdsat 物理约束 + R1 KVL 反推 + R2 镜像约束铁律 + MN5_bottom / MN6_top / MP2_top triode 调整范例（FC 核心新章）
    tokens: ~2000
  - name: ac-stability
    summary: 主极点 vout + fold node 极点 + cascode source 极点 + 单级 cascode 不需 Miller 补偿
    tokens: ~1100
  - name: troubleshooting
    summary: 9 类失败模式（gain 低 / GBW 低 / PM 紧 / cascode triode × 3 / mirror mismatch / swing 紧 / slew rate）+ 根因表
    tokens: ~1700
  - name: reference-design
    summary: production-grade 5 group + 9 bias tree 网表 + standard cir/tb 路径 + sizing 起点 + connectivity 陷阱
    tokens: ~900

trigger:
  explicit:
    user_selected_pack: fc_ota
  implicit:
    keywords:
      - folded cascode
      - folded-cascode
      - FC-OTA
      - fc_ota
      - 折叠共源共栅
      - cascode OTA gain
      - high-gain single-stage OTA

related:
  knowledge:
    - blocks/base-cells/cascode
    - blocks/base-cells/current-mirror/wide-swing
    - blocks/base-cells/differential-pair
    - blocks/5t-ota   # 对比：FC-OTA 是 5T-OTA 的高 gain 升级
    - blocks/telescopic-ota   # 对比：相同 gain 但 swing/ICMR 取舍不同
    - simulators/ngspice
    - pdks/vpdk180nm
  skills:
    - device_sizing
    - ac_feedback_loop_method
    - signal_tracing
  tools:
    - simulate
    - generate_testbench
    - dc_snapshot
    - op_point_check
    - causal_trace
    - inspect_device
    - inspect_node
    - propose_knob

hierarchy: block
applicable_pdks: any
applicable_simulators: [ngspice]
authors: ["cirona team"]
---

# FC-OTA 设计参考

## Quick Facts

- FC-OTA = NMOS 差分对 + PMOS fold + PMOS/NMOS cascode + NMOS mirror（输出端 diff→SE）
- 典型 gain **60-80 dB**（5T 拓扑增益 30-50dB 不够时用），GBW 30-100 MHz @ CL=1pF
- 适用：5T 不够 + telescopic 摆幅紧张的中间需求；LDO EA / ADC 子模块常用
- 9 个 bias tree MOSFET — bias chain 复杂，**从零写几乎必踩 connectivity trap**

## Cheatsheet (vpdk180nm, VDD=1.8V, ibias=10µA)

| Spec | 典型值 | 影响因素 |
|---|---|---|
| DC gain | 60-80 dB | gm_M1 × (Rout_p ‖ Rout_n)，cascode 提 ro 两个数量级 |
| GBW | 30-100 MHz | gm_M1 / (2π·CL) |
| Phase margin | 50-70° | 第二极点在 fold 节点，距 GBW 距离决定 |
| Power | 200-800 µW | 2 × Itail × VDD（左右两 branch + bias tree）|
| **Output swing** ⭐ | **≈ 0.6-0.8V** | 4 段 cascode 占 0.5V headroom |
| ICMR | 0.3-1.6V | fold 解耦 input 与输出堆叠（较 5T 宽）|
| Input-referred noise | 低 | cascode 抑制 mirror flicker（FC 优势）|

## 4D Trade-off vs 其他 OTA

| 维度 | 5T | **FC** | Tele | 2-stage |
|---|---|---|---|---|
| Gain | 40-55 dB | **60-80 dB** | 60-80 dB | 80-100 dB |
| GBW | 1-50 MHz | **30-100 MHz** | 30-120 MHz | 10-50 MHz |
| Power | 低 | **中-高** | 中 | 较高 |
| **Swing** | ≈ 1.0V | **≈ 0.6-0.8V** | 0.4-0.6V | ≈ 1.6V |
| ICMR | 中 | **宽** | 紧 | 宽 |

详细对比见 `architecture.md`。

## When to load this knowledge

- 用户 spec 含 "folded cascode" / "FC-OTA" / "fc_ota" / "折叠共源共栅"
- gain 60-80 dB 单级 OTA（不愿用双级 / 不愿摆幅紧张的 telescopic）
- LDO EA 设计在 5T 不够时（loop gain 60-80 dB）
- ADC 子模块 / 高 ICMR 需求 OTA

## When NOT to load

- gain 要求 < 50 dB → 用 `blocks/5t-ota`（更简单）
- gain 要求 > 90 dB → 用 `blocks/two-stage-ota`（双级 EA）
- ICMR 紧 + headroom 充足 → telescopic 更高效
- VDD < 1.0V → 低压专用拓扑（不在本章范围）

## Related

- `blocks/base-cells/cascode` cascode 物理 + bias 决定下管 Vds
- `blocks/base-cells/current-mirror/wide-swing` wide-swing bias scheme（vbc_p / vbc_n 生成）
- `blocks/5t-ota` baseline 对比（gain 不够时升级到 FC）
- `blocks/telescopic-ota` 相邻拓扑（FC 与 Telescopic 的 swing/ICMR/power 取舍）
- `skills/ac_feedback_loop_method` AC Method C 测 PM/GBW
- `skills/device_sizing` 通用 sizing 流程 + R1-R4 铁律
