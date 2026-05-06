---
type: knowledge
domain: circuit
name: two-stage-ota
version: 1.0
summary: |
  Two-stage Miller OTA 设计参考：5T 第一级 + CS 第二级 + Miller (Cc+Rz) 补偿。
  典型 80-100 dB gain，是 LDO EA / ADC 子模块标准选择。**Iron Law: 设计双级 OTA
  必先 load reference-design 章节**，注意第二级 stage2 输入节点位置（LDO v3 H-005 教训）。
  ⭐ 设计推进顺序：**stage1 → stage2 → Miller cap**（**严格顺序**，跨级耦合
  让乱序必反复推翻）。

chapters:
  - name: architecture
    summary: 5T+CS+Miller 拓扑细节 + variants（NMOS-input / cascode-stage1 / class-AB / fd_cmfb）+ 与其他 OTA 4D 对比
    tokens: ~1100
  - name: sizing-typical
    summary: ⭐ spec → device 因果（两级分配）+ 推进顺序（Phase A stage1 → Phase B stage2 → Phase C Miller）+ 跨级耦合表 + @vpdk180nm 起点表
    tokens: ~1500
  - name: bias-headroom
    summary: ⭐ Vds/Vdsat 物理约束 + R1 KVL 反推 + R2 镜像约束铁律（3 个 mirror）+ vx 跑 rail / MN6 triode / MPTAIL triode 范例（跨级耦合核心）
    tokens: ~1700
  - name: ac-stability
    summary: ⭐⭐ Miller 补偿核心章 - pole splitting + GBW=gm1/Cc + p2=gm6/CL + RHP zero + nulling Rz 完整推导
    tokens: ~1700
  - name: troubleshooting
    summary: 8 类失败模式（PM 紧 / gain 低 / vx rail / slew / 大 CL / Cc 接错 / units=degrees / mirror imbalance）+ 根因表
    tokens: ~1600
  - name: standard-tests
    summary: ⭐ OTA 标准测试套件（OTA-T1 DC OP open-loop / T2 AC PM Method C closed-loop / T3 PSRR / T4 Slew / T5 ICMR / T6 Settling）+ testbench 模式 IRON LAW（DC OP 必 open-loop，AC 必 closed-loop，Demo 02 实证）
    tokens: ~900
  - name: reference-design
    summary: production-grade two-stage OTA 网表（PMOS-input + NMOS mirror + NMOS-CS + Miller Cc/Rz）+ standard cir/tb 路径 + sizing 起点
    tokens: ~800

trigger:
  explicit:
    user_selected_pack: two_stage_ota
  implicit:
    keywords:
      - two-stage OTA
      - two stage OTA
      - 双级 OTA
      - Miller 补偿
      - Miller compensation
      - 双级 EA
      - LDO EA
      - 高 gain OTA

related:
  knowledge:
    - blocks/base-cells/differential-pair
    - blocks/base-cells/current-mirror
    - blocks/base-cells/miller-compensation
    - blocks/base-cells/common-source
    - blocks/5t-ota
    - blocks/folded-cascode-ota
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
    - inspect_device
    - inspect_node
    - propose_knob

hierarchy: block
applicable_pdks: any
applicable_simulators: [ngspice]
authors: ["cirona team"]
---

# Two-Stage OTA 设计参考

## Quick Facts

- 第一级：PMOS diff pair + NMOS mirror load（5T 结构）→ gain 30-40 dB
- 第二级：NMOS CS（gate=stage1 output vx）+ PMOS load（mirror from stage1 PMOS bias）→ gain 30-50 dB
- Miller 补偿：Cc 跨第二级（vx → vout）+ nulling Rz
- 总 gain **80-100 dB**，是 LDO EA / ADC 子模块标准选择
- ⭐ **唯一 rail-to-rail swing 拓扑**（4 OTA 中）

## ⭐ Spec Ceiling Table（拓扑能力上限 — 设计前必查）

> **Iron Law**：开始 sizing 前，**必须**对账目标 spec 与本表。任何 spec 超过对应拓扑的 ceiling →
> 不能靠 trim/sizing 救，必须换 OTA 拓扑（5T / FC / Telescopic / 2-stage）或换架构（多级 / cascoded stage1）。

### OTA 拓扑能力对比（4D）

| Spec | 5T | FC | Telescopic | **2-stage**（本 PACK）| + cascoded stage1 |
|---|---|---|---|---|---|
| **DC gain** | 40-55 dB | 60-80 dB | 60-80 dB | **80-100 dB** | 100-115 dB |
| **GBW @ CL=5pF** | 1-50 MHz | 30-100 MHz | 30-120 MHz | **10-50 MHz**（Miller 限）| 30-100 MHz |
| **Output swing** | ≈ 1.0 V | 0.6-0.8 V | 0.4-0.6 V | **≈ 1.6 V (rail-to-rail)** | ≈ 1.6 V |
| **PM** | 易（单极点）| 60-65°（中）| 60-65°（中）| **55-65°（难，Miller 三件套）** | 同 |
| **Power @ vpdk180nm** | 50-300 µW | 200-800 µW | 200-700 µW | **300-1000 µW** | 500-1500 µW |
| **Slew Rate** | I_tail / CL | I_tail / CL | I_tail / CL | **I_stage2 / CL**（class-A）| 同 |
| **设计复杂度** | 低 | 中 | 中 | **高（Miller + Cc + Rz + 顺序）** | 极高 |

### Spec → 必选拓扑路径

```
spec gain < 60 dB              → 5T-OTA（简单，PM 容易）
spec gain 60-80 dB             → FC-OTA（单级 cascode，无 Miller）
                                  或 telescopic（swing 紧但 PM 容易）
spec gain 80-100 dB            → 2-stage Miller（**本 PACK**）⭐
spec gain > 100 dB             → 2-stage + cascoded stage1
spec gain > 115 dB             → 多级（3-stage with nested Miller）— 不在本 PACK
spec GBW > 50 MHz              → 不能用 2-stage Miller（GBW 上限 ~50MHz），换 FC 或 telescopic
spec PM > 70° + 大 GBW         → 物理 trade-off，必须减 GBW 或加 power
spec output swing > 1.6V       → 受 VDD 约束（vpdk180nm VDD=1.8V，swing 上限 ~1.7V）
spec rail-to-rail swing 必需   → 必选 2-stage 或多级（FC/Tele swing 不够）
spec slew rate > 50 V/µs       → I_stage2 必须大 (≥ Cload×SR)，trade-off 增加 power
```

### 2-stage 内部 Iron Law（PM 物理约束）

```
PM > 60° ⇔ p2 / GBW > 3 ⇔ gm6 / gm1 ≥ 12 (@ Cc = CL/4)

→ Stage2 gm 至少 12 × Stage1 gm；这是 PM > 60° 的 IRON LAW
→ 违反则 PM 物理上不可能 > 60°（详见 ac-stability.md 模式 3）
```

详细推导：`ac-stability.md` § GBW=gm1/Cc + p2=gm6/CL + nulling Rz。

---

## Cheatsheet (vpdk180nm, VDD=1.8V, CL=5pF, ibias=20µA)

| Spec | 典型值 | 关键决定因子 |
|---|---|---|
| DC gain | 80-100 dB | gm1·ro1 × gm6·ro6（两级乘积）|
| GBW | 10-50 MHz | gm1 / (2π·Cc)（Miller 后 Cc 替代 CL）|
| Phase margin | 55-65° | gm6 / gm1 ≥ 12（@ Cc=CL/4）|
| Power | 300-1000 µW | I_stage2 = 4-10 × I_stage1 |
| **Output swing** ⭐ | **≈ 1.6V**（rail-to-rail）| stage2 单管堆叠 < 0.5V |
| Slew rate | I_stage2 / CL | 大电流第二级（class-A）|

## 4D Trade-off vs 其他 OTA

| 维度 | 5T | FC | Tele | **2-stage** |
|---|---|---|---|---|
| Gain | 40-55 dB | 60-80 dB | 60-80 dB | **80-100 dB** |
| GBW | 1-50 MHz | 30-100 MHz | 30-120 MHz | **10-50 MHz**（Miller 限）|
| Power | 低 | 中-高 | 中 | **较高** |
| **Swing** | ≈ 1.0V | 0.6-0.8V | 0.4-0.6V | **≈ 1.6V (rail-to-rail)** |
| **PM** | 易（单极点）| 中 | 中 | **难**（Miller 三件套）|

详细对比见 `architecture.md`。

## 设计 Iron Law（**2-stage 特有**）

```
1. 严格设计顺序: stage1 → stage2 → Miller cap
   - 跨级耦合让乱序必反复推翻
   - 详见 sizing-typical.md Phase A/B/C

2. PM > 60° 物理约束: gm6 ≥ 12 × gm1 (@ Cc = CL/4)
   - p2 = gm6/CL > 3 × GBW
   - stage2 gm 必须远大于 stage1

3. RHP zero 必须消: Rz = 1/gm6
   - Miller cap 引入 RHP zero 副作用
   - nulling Rz 把它推到无穷远（Rz=1/gm6）或 LHP（Rz>1/gm6）

4. Cc 一端必须 vx (高 gain 输出节点), 不是 vx_l (diode 端)
   - LDO v3 H-005 教训：误接 vx_l 让 Miller effect 几乎消失
```

## When to load this knowledge

- 用户 spec 含 "two-stage OTA" / "双级 OTA" / "Miller compensation" / "LDO EA"
- gain 80-100 dB 要求（FC 单级到顶）
- Rail-to-rail 输出 swing 需求
- Driving 大 CL（> 5 pF）—— stage2 大电流好驱动
- 任何 LDO 设计的 EA（双级是 LDO EA 默认选择）

## When NOT to load

- gain < 60 dB → 5T-OTA 简单
- gain 60-80 dB + 不需要 rail-rail swing → FC-OTA（更简单，PM 容易）
- 高速 BW > 100 MHz → cascode-OTA 或多级 OTA 不在本章范围
- Power-tight（< 200µW）→ 双级 OTA 至少 ~ 300µW

## Related

- `blocks/base-cells/miller-compensation` ⭐ Miller Cc + nulling Rz 原理推导
- `blocks/base-cells/common-source` stage2 CS 设计
- `blocks/5t-ota` stage1 5T 内部约束
- `blocks/folded-cascode-ota` 单级 cascode 对照（gain 60-80 dB 时备选）
- `blocks/ldo` 用 two-stage OTA 当 EA 时的 LDO 设计
- `skills/ac_feedback_loop_method` AC 测 PM/GBW Method C
- `skills/device_sizing` 通用 sizing 流程 + R1-R4 铁律
