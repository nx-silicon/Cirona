---
type: knowledge
domain: circuit
name: 5t-ota
version: 1.0
summary: |
  5T-OTA (Five-Transistor OTA) 设计参考：standard 拓扑 + sizing 起点 +
  reference cir/tb 路径。事实+因果格式，**Iron Law: 设计 5T-OTA 必先 load
  reference-design 章节，不要从零造拓扑**。

chapters:
  - name: architecture
    summary: 拓扑细节 + variants 文字描述 + 与其他 OTA 4D 对比 + 适用场景
    tokens: ~900
  - name: sizing-typical
    summary: spec → device 约束因果 + 拓扑特定设计推进顺序 + @vpdk180nm 起点表
    tokens: ~1300
  - name: bias-headroom
    summary: ⭐ Vds/Vdsat 物理约束 + R1 KVL 反推 + R2 镜像约束铁律 + M5/M4 triode 调整范例
    tokens: ~1500
  - name: ac-stability
    summary: 极点分布 + 单级 OTA 不需 Miller 补偿 + PM/GBW/CL 因果
    tokens: ~900
  - name: troubleshooting
    summary: 6 类失败模式（gain 低 / GBW 低 / PM 紧 / swing 紧 / mismatch / weak inversion）+ 根因表
    tokens: ~1400
  - name: reference-design
    summary: production-grade 拓扑 ASCII + DC paths + AC signal flow + 标准 cir/tb 路径 + sizing 起点
    tokens: ~800

trigger:
  explicit:
    user_selected_pack: ota_5t
  implicit:
    keywords:
      - 5T OTA
      - 5T-OTA
      - five-transistor OTA
      - five transistor OTA
      - single-stage OTA
      - 单级 OTA
      - 简单 OTA

related:
  knowledge:
    - blocks/base-cells/differential-pair
    - blocks/base-cells/current-mirror
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

hierarchy: block
applicable_pdks: any
applicable_simulators: [ngspice]
authors: ["cirona team"]
---

# 5T-OTA 设计参考

## Quick Facts

- 5T-OTA 是单级 OTA：NMOS 差分对 + PMOS 镜像负载 + NMOS tail
- 典型 gain **40-55 dB**（无 cascode 增益），GBW = gm_M1 / (2π·CL)
- 主要用途：低 gain 缓冲器 / 数字接口 / 简单 unity-gain follower
- gain 要求 > 60dB 不要选 5T，用 cascode / FC-OTA / two-stage

## Cheatsheet (vpdk180nm, VDD=1.8V, ibias=10µA → Itail=20µA)

| Spec | 典型值 | 影响因素 |
|---|---|---|
| DC gain | 37-55 dB ⚠️ | gm_M1 × (ro_M2 ‖ ro_M4) — V3 reference cir 用 L_LOAD=0.5µm 给 **37.4 dB**（实测）；要达 50+ dB 必须 L_LOAD ↑ 到 1.0 µm（见 sizing-typical 起点表）|
| GBW | 1-50 MHz | gm_M1 / (2π·CL) |
| Phase margin (unity feedback) | 60-70° | M2/M4 极点距离 |
| Power | 30-50 µW | Itail × VDD |
| Iquiescent | ≈ Itail | 主要 EA tail |
| **Output swing** ⭐ | **≈ 1.0V**（VDD - 0.5V）| Vov_M4 + Vov_M2 + Vov_M5 占用 |
| Input-referred noise | 中（5T 单级噪声主导）| gm_M1 + (gm_M3/gm_M1)² 衰减 |

## 4D Trade-off vs 其他 OTA

| 维度 | 5T | FC | Tele | 2-stage |
|---|---|---|---|---|
| Gain | 40-55 dB | 60-80 dB | 60-80 dB | 60-90 dB |
| GBW | 1-50 MHz | 1-100 MHz | 1-100 MHz | 1-50 MHz（Miller 限）|
| Power | 低 | 中 | 中 | 较高 |
| **Swing** | **≈ 1.0V** | 0.6-0.8V | 0.4-0.6V | ≈ 1.2V |

详细对比见 `architecture.md`。

## When to load this knowledge

- 用户 spec 含 "5T OTA" / "five-transistor OTA" / 单级 OTA gain 30-55dB
- 设计 LDO EA 时**评估**单级是否够（多数情况不够，但要先 load 了解 baseline）
- 任何 OTA 类设计的入门参考（同时要 load FC-OTA / two-stage 章节做拓扑对比）

## When NOT to load

- gain > 60dB 要求 → 直接 load `blocks/folded-cascode-ota` 或 `blocks/two-stage-ota`
- 高 PSRR / 严苛 line/load reg → 5T 永远不够

## Related

- `blocks/base-cells/differential-pair` 输入对 sizing 细节
- `blocks/base-cells/current-mirror` PMOS load mirror sizing
- `skills/device_sizing` 通用 sizing derivation 方法
- `skills/ac_feedback_loop_method` AC 测 PM/GBW 的 Method C 断环
