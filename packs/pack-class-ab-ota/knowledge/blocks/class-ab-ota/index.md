---
type: knowledge
domain: circuit
name: class-ab-ota
version: 1.0
summary: |
  Class-AB Output Stage 2-stage Opamp 设计参考：Stage1 5T NMOS-input + Stage2
  class-AB push-pull (floating bias + 22 MOSFET total) + Miller compensation。
  事实+因果格式，**Iron Law: 设计 class-AB 必先 load reference-design 章节**，
  floating bias 接错必造成 quiescent 失控 + crossover distortion（class-AB
  特有 silent failure）。Class-A 2-stage 升级到 class-AB 的核心：动态 push-pull
  电流 → 大 drive + 高 SR + rail-to-rail，代价是复杂度 + IQ control。

chapters:
  - name: architecture
    summary: Stage1 5T + Stage2 class-AB push-pull + floating bias + Miller 拓扑 + 4 variants（Monticelli / current-mirror class-AB / FVF / source-follower）+ 5 OTA 4D 对比（含 max output current 维度）
    tokens: ~1300
  - name: sizing-typical
    summary: spec → 子模块约束（含 IQ + max drive）+ ⭐ 5 阶段严格推进顺序（Stage1 → Floating bias 链 → Output W·m → Miller cap → Tran 验证）+ 跨子模块强耦合表 + 起点表
    tokens: ~1600
  - name: bias-headroom
    summary: ⭐ 灵魂章 — Quiescent-current control 物理（floating bias 链锁 VGP-VGN）+ R1 KVL + R2 floating bias 同步铁律 + 4 个 R1-R4 范例（IQ 失控 / crossover distortion / output triode / Stage1 跨级耦合）
    tokens: ~2200
  - name: ac-stability
    summary: Miller pole splitting + RHP zero + nulling Rz（同 class-A）+ class-AB 特有 dynamic gm 变化 + load-dependent stability + Cc/CL ≈ 1 设计起点 + 3 失稳调整范例
    tokens: ~1500
  - name: troubleshooting
    summary: 10 类失败模式（IQ 失控 / crossover / max drive / quiescent PM / dynamic PM / cross-corner / Stage1 跨级 / load-dependent / output triode / SR 不对称）+ 推荐诊断顺序
    tokens: ~1700
  - name: reference-design
    summary: production-grade 22 MOSFET class-AB OTA 网表（Stage1 5T + floating bias + push-pull output + Miller）+ standard cir/tb 路径 + sizing 起点 + 22 connectivity 陷阱
    tokens: ~1500

trigger:
  explicit:
    user_selected_pack: class_ab_opamp
  implicit:
    keywords:
      - class-AB
      - class AB
      - class_ab_opamp
      - class-AB output
      - class-AB OTA
      - class-AB opamp
      - 推挽输出
      - push-pull output
      - rail-to-rail output
      - 大电流驱动 OTA
      - large-drive opamp
      - high slew rate opamp
      - floating bias
      - 浮动偏置
      - audio driver opamp
      - headphone driver
      - LDO output stage
      - Monticelli

related:
  knowledge:
    - blocks/base-cells/output-stage         # class-A vs class-AB vs class-B 物理
    - blocks/base-cells/miller-compensation  # Miller comp 数学
    - blocks/base-cells/differential-pair    # Stage1 input pair
    - blocks/base-cells/current-mirror       # mirror match
    - blocks/5t-ota                          # Stage1 5T 内部约束
    - blocks/two-stage-ota                   # class-A 2-stage 对照（最相关）
    - blocks/folded-cascode-ota              # Stage1 升级 FC 选项
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

# Class-AB OTA 设计参考

## Quick Facts

- Class-AB OTA = Stage1 5T 差分放大 + Stage2 push-pull 输出（动态 IQ）+ Miller 补偿
- 典型 gain **65-80 dB** / GBW 10-30 MHz / SR ≥ 7 V/µs / output current ≥ mA
- ⭐ **唯一 大 drive + 大 SR + rail-to-rail 同时实现** 的拓扑（class-A 2-stage 不行）
- 核心物理：Floating bias 链锁 VGP - VGN 之差 → 决定 quiescent IQ
- 适用：headphone driver / audio output / LDO output stage / 大 CL driver

## Cheatsheet (vpdk180nm, VDD=1.8V, ibias=20µA, CL=5pF)

| Spec | 典型值 | 关键决定因子 |
|---|---|---|
| DC gain | 65-80 dB | gm1·ro1 × g_m_AB·ro_AB |
| GBW | 10-30 MHz | gm1 / (2π·Cc)；Cc/CL ≈ 1（class-AB 大）|
| Phase margin | 45-60° | gm_AB / CL > 3 × GBW；dynamic 时变 |
| Power（quiescent）| 200-400 µW | I_stage1 + 2·IQ_AB（典型 IQ ≈ 100 µA per device）|
| **Output swing** ⭐ | **≈ 1.6V (rail-rail - 0.2V)** | output 单管 ≤ 100mV margin |
| **Max output current** ⭐ | **5-10 mA** | output W·m ≥ 200µm·m=10 |
| **Slew rate** ⭐ | **7-15 V/µs**（push-pull 动态）| dynamic >> IQ_AB / CL |
| THD-3 (Nyquist) | -50 ~ -60 dB | crossover distortion 主导 |
| Quiescent current | 50-150 µA per output | floating bias 锁定 |

## 4D Trade-off vs 其他 OTA

| 维度 | 5T | FC | Tele | 2-stage class-A | **Class-AB** |
|---|---|---|---|---|---|
| Gain | 40-55 | 60-80 | 60-80 | 80-100 dB | **65-80 dB** |
| GBW | 1-50 MHz | 30-100 | 30-120 | 10-50 MHz | **10-30 MHz** |
| Power | 低 | 中-高 | 中 | 较高 | **中** |
| **Swing** | ≈1V | 0.6-0.8V | 0.4-0.6V | ≈1.6V | **≈1.6V (rail-rail)** |
| **Max output I** ⭐ | µA-100µA | µA | µA | mA（class-A 限）| **mA-10mA** ⭐ |
| **SR**（dynamic）| gm/CL | I_branch/CL | I_branch/CL | I_stage2/CL | **dynamic >> IQ/CL** ⭐ |
| 复杂度 | 最简单 | 中-高 | 中 | 复杂 | **最复杂**（22 MOSFET）|

详细对比见 `architecture.md`。

## 设计 Iron Law（**class-AB 特有**）

```
1. Floating bias 同步铁律 ⭐:
   - 整链 W/L/m 比例必须严格按比例 sizing；改任一 device 必须按比例同步整链
   - 单调"优化"链上一管 → IQ 失控（V3 实战 silent failure 第一名）

2. 5 阶段严格设计顺序:
   Stage1 → Floating bias 链 → Output W·m → Miller cap → Tran 验证
   - 跨子模块强耦合让乱序必反复推翻

3. PM > 60° quiescent + dynamic 双满足:
   - quiescent PM 留 margin（70°+）让 dynamic 不退化到 50° 以下
   - Cc / CL ≈ 0.5-1（比 class-A 2-stage 大）

4. Output PMOS / NMOS 比例 ≈ μn/μp:
   - vpdk180nm: W_p / W_n ≈ 2-3 → SR+ ≈ SR-（push-pull 对称）
   - 比例错 → SR 不对称 + crossover 偏

5. IQ_quiescent ≥ 50 µA per output device:
   - 物理下限避免 crossover dead zone
   - spec THD < -60 dB 时 IQ ≥ 100 µA per device
```

## When to load this knowledge

- 用户 spec 含 "class-AB" / "rail-to-rail output" / "headphone driver" / "audio output"
- 大输出电流需求（≥ 1 mA 不能用 class-A 2-stage）
- 大 CL（≥ 5 pF）+ slew rate spec
- Battery-powered 应用（低静态 + 大动态 drive）
- LDO output stage（高 PSRR + 大 load step）

## When NOT to load

- gain < 60 dB → 5T-OTA 简单
- gain > 90 dB + 不需大 drive → 2-stage class-A
- 高速 GBW > 50 MHz → output cap 限速
- 低噪 input-referred noise < 5 nV/√Hz → output thermal 大
- Power-tight < 50 µW → IQ_AB 有下限（crossover）
- 高线性度 THD < -80 dB → AB-class crossover 引入小非线性

## Related

- `blocks/two-stage-ota` ⭐ class-A 2-stage 最相关对照（替换 stage2 即得 class-AB）
- `blocks/5t-ota` Stage1 5T 内部约束
- `blocks/base-cells/output-stage` class-A / class-AB / class-B 输出级物理对比
- `blocks/base-cells/miller-compensation` Miller comp + RHP zero + Rz nulling
- `blocks/base-cells/differential-pair` Stage1 input pair Pelgrom matching
- `skills/ac_feedback_loop_method` AC Method C 测 PM/GBW
- `skills/device_sizing` 通用 sizing 流程 + R1-R4 铁律
