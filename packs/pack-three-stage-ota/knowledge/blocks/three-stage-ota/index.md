---
type: knowledge
domain: circuit
name: three-stage-ota
version: 1.0
summary: |
  Three-stage Miller Compensated Opamp 设计参考：Stage1 5T NMOS-input + Stage2
  NMOS-CS + Stage3 PMOS-CS output + Nested Miller Compensation (NMC: 2 Cc/Rz
  pairs)。事实+因果格式，**Iron Law: 设计 3-stage 必先 load reference-design**，
  NMC 补偿网络复杂（2 cap + 2 nulling Rc 互锁），从零造几乎必踩 Cc/Rc 接错或
  反相极性叠加错。突破 100 dB gain ceiling 的 OPAMP 拓扑（2-stage 物理上限）。

chapters:
  - name: architecture
    summary: 3 stage 拓扑细节 + variants（NMC / MNMC / NGCC / Active feedback / cascode-stage1）+ 6 OTA 4D 对比（gain ceiling 突破 100 dB 但 GBW 受限）
    tokens: ~1300
  - name: sizing-typical
    summary: spec → 子模块约束 + ⭐ 4 阶段严格推进顺序（Stage1 → Stage2 → Stage3 → NMC compensation；3 stage 互锁 + 2 Cc/Rz 互相耦合）+ 跨级耦合 + 起点表
    tokens: ~1500
  - name: bias-headroom
    summary: 3 stage 跨级耦合（v1_out → v2_out → vout 链式决定）+ R1 KVL + R2 6 mirror 同步铁律 + 3 反相极性叠加（+−− = +）+ 4 R1-R4 范例（v1_out / v2_out / vout / output triode）
    tokens: ~1700
  - name: ac-stability
    summary: ⭐ 灵魂章 — Nested Miller Compensation 完整推导 + 双 pole splitting + 2 RHP zero + Rc1 / Rc2 nulling 双消（Rc1 用 stage_combined gm，Rc2 用 stage3 gm）+ 4 失稳调整范例
    tokens: ~2000
  - name: troubleshooting
    summary: 9 类失败模式（v1_out / v2_out / vout 跑 rail / total gain 不达 / NMC PM / cross-corner / 大 CL 失稳 / DC latch loop sign 反 / NMC Rc 接错）+ 推荐诊断顺序
    tokens: ~1500
  - name: reference-design
    summary: production-grade 13 MOSFET 3-stage opamp 网表（Stage1 5T + Stage2 NMOS-CS + Stage3 PMOS-CS + NMC 2 Cc/Rz pairs）+ standard cir/tb 路径 + 起点表 + connectivity rules + 9 已知陷阱
    tokens: ~1500

trigger:
  explicit:
    user_selected_pack: three_stage_opamp
  implicit:
    keywords:
      - three-stage
      - 3-stage
      - three stage opamp
      - 三级运放
      - 三级 OTA
      - nested Miller
      - NMC
      - nested compensation
      - 嵌套米勒补偿
      - 三级 LDO EA
      - high-gain opamp
      - 100dB opamp
      - precision opamp
      - instrumentation opamp
      - 仪表运放

related:
  knowledge:
    - blocks/base-cells/miller-compensation  # Miller comp 单级数学
    - blocks/base-cells/common-source        # Stage2/3 CS
    - blocks/base-cells/differential-pair    # Stage1 input
    - blocks/base-cells/current-mirror       # mirror match
    - blocks/5t-ota                          # Stage1 5T 内部
    - blocks/two-stage-ota                   # 2-stage Miller 对照（最相关）
    - blocks/class-ab-ota                    # output stage 升级备选
    - simulators/ngspice
    - pdks/vpdk180nm
  skills:
    - circuit-method/device-sizing
    - circuit-method/ac-feedback-loop-method
    - circuit-method/signal-tracing
  tools:
    - simulate
    - generate_testbench
    - dc_snapshot
    - op_point_check
    - inspect_device
    - inspect_node
    - propose_knob

hierarchy: block
applicable_pdks: any
applicable_simulators: [ngspice, hspice, spectre]
authors: ["cirona team"]
---

# Three-Stage Opamp 设计参考

## Quick Facts

- 3 stage opamp = Stage1 5T diff + Stage2 NMOS-CS + Stage3 PMOS-CS + NMC 双 Miller 补偿
- 典型 gain **100-130 dB** ⭐（突破 2-stage 物理上限的 OPAMP 拓扑）
- NMC = Nested Miller Compensation：2 个 Cc + 2 个 nulling Rc（不是 2-stage 的 1 套）
- 每 stage gain 30-40 dB；总 100+ dB 是 cascade 乘积
- 适用：严苛 LDO EA / precision instrumentation / ≥ 14-bit ADC reference buffer

## Cheatsheet (vpdk180nm, VDD=1.8V, ibias=20µA, CL=5pF)

| Spec | 典型值 | 关键决定因子 |
|---|---|---|
| DC gain | **100-130 dB** | 3 stage 乘积 (gm·ro)³ |
| GBW | 5-30 MHz | gm_stage1 / Cc1（NMC 限）|
| Phase margin | 50-65° | NMC pole splitting × 2 |
| Power | 300-1000+ µW | I_stage1 + I_stage2 + I_stage3 |
| Output swing | ≈ 1.6V (rail-rail) | stage3 单管 |
| Max output current | 1-5 mA | output W·m 决定 |
| Slew rate | 5-20 V/µs | I_stage3 / CL |
| THD（Nyquist）| -60 ~ -80 dB | 3 stage 累加 |

## 4D Trade-off vs 其他 OTA

| 维度 | 5T | FC | Tele | 2-stage | Class-AB | **3-Stage** |
|---|---|---|---|---|---|---|
| Gain | 40-55 | 60-80 | 60-80 | 80-100 | 65-80 | **100-130 dB** ⭐ |
| GBW | 1-50 MHz | 30-100 | 30-120 | 10-50 | 10-30 | **5-30 MHz** |
| PM | 易 | 中 | 中 | 难 | 难 | **最难**（3 极点 + 2 Cc/Rz NMC）|
| Power | 低 | 中-高 | 中 | 较高 | 中 | **高**（300-1000+ µW）|
| Swing | ≈1V | 0.6-0.8V | 0.4-0.6V | ≈1.6V | rail-rail | **≈1.6V** |
| 复杂度 | 最简单 | 中-高 | 中 | 复杂 | 最复杂 | **最复杂**（13 MOSFET + NMC）|

## 设计 Iron Law（**3-stage 特有**）

```
1. NMC 双重补偿铁律 ⭐:
   - 必须配 Cc1（outer，跨 stage 2+3）+ Cc2（inner，跨 stage3）
   - 必须配 Rc1（用 gm_combined）+ Rc2（用 gm_stage3）
   - 单 Cc 不够 splitting 3 极点 → 必振荡

2. NMC nulling resistor 端口铁律:
   - Rc1 一端必须接 vout（不是 v1_out）
   - Rc2 一端必须接 vout（不是 v2_out）
   - 接错 → RHP zero 不消 → PM 崩

3. 反相极性叠加：3 stage 总极性 = + − − = +:
   - feedback 接 vinn（不是 vinp）
   - 写 3-stage 前画 loop sign 验证

4. 4 阶段严格设计顺序:
   Stage1 → Stage2 → Stage3 → NMC compensation
   - 跨级 cascade + NMC 多变量耦合让乱序必反复推翻

5. 6 mirror 同步铁律:
   - 6 个 mirror 关系必须严格 W/L 同步（m 不同 OK）
   - 任一 mirror 失配 → 某 stage 偏 → cascade 全错
```

## When to load this knowledge

- 用户 spec gain ≥ 100 dB（2-stage 不够）
- 严苛 LDO EA（loop gain > 100 dB / line reg < 0.1%）
- Precision instrumentation amp（CMRR > 100 dB）
- ≥ 14-bit ADC reference buffer
- 用户 spec 含 "nested Miller" / "三级运放" / "100 dB opamp"

## When NOT to load

- gain < 80 dB → 2-stage 简单
- 高速 GBW > 50 MHz → NMC 限速；用 active feedback variant
- Power-tight (< 200 µW) → 3-stage 至少 300 µW
- 低噪声 → 3 stage thermal 累加
- 简单应用（buffer / 数字接口）→ 5T-OTA

## Related

- `blocks/two-stage-ota` ⭐ 2-stage Miller 最相关对照（升级到 3-stage 物理增量）
- `blocks/5t-ota` Stage1 5T 内部约束
- `blocks/class-ab-ota` output stage 升级备选（class-AB 3-stage variant）
- `blocks/base-cells/miller-compensation` Miller 单级数学（pole splitting + RHP zero + Rz）
- `blocks/base-cells/common-source` Stage2 / Stage3 CS 物理
- `blocks/base-cells/differential-pair` Stage1 input pair
- `skills/ac_feedback_loop_method` AC Method C
- `skills/device_sizing` 通用 sizing 流程 + R1-R4 铁律
