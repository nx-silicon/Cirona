---
chapter: reference-design
parent: 5t-ota
summary: |
  Production-grade 5T-OTA reference: 拓扑 ASCII + DC paths + AC signal flow
  + standard subckt port order + sizing 起点 + 标准 testbench 模板。
  Iron Law: 写 5T-OTA 时先 load 此章节并采纳 reference cir，不要从零造拓扑。
tokens: ~800
prerequisite_chapters: []
related_skills:
  - device_sizing
  - ac_feedback_loop_method
related_knowledge:
  - blocks/base-cells/differential-pair
  - blocks/base-cells/current-mirror
  - simulators/ngspice
  - pdks/vpdk180nm
---

# 5T-OTA Reference Design

## Iron Law

**Reference design 优先**：写 5T-OTA 时先用 `load_knowledge(name='5t-ota', asset='reference_designs/5t_ota.cir')` 拿网表复制为起点，**不要从零造 .cir**。Reference 已经过物理审查 + 标准 bias chain + sizing 起点，复用它跳过整个"造拓扑 + 调 bias bug"的 debug iteration（v3 LDO 实战教训：H-006 才修对 PMOS load diode-connect 拓扑，浪费 20+ turn）。

## Quick reference (assets)

| Asset | 用途 |
|---|---|
| `reference_designs/5t_ota.cir` | 完整网表（147 行 self-contained） |
| `reference_designs/tb_dc_op.sp` | DC OP testbench |
| `reference_designs/tb_ac_gain_bw.sp` | AC gain/BW/PM testbench（Method C 断环） |

通过 `load_knowledge(name='5t-ota', asset='<上表 Asset 列>')` 拿原文，做最小 sizing 调整后 `write_file` 写到自己的 `<project>/<cell>/design/` 目录。**禁止用 `read_file` 读知识库内容** — knowledge tool 是唯一合规入口。

## Core topology (NMOS-input + PMOS-mirror + NMOS-tail)

```
        VDD
         |
    +----+----+
    |         |
  [M3]------[M4]   PMOS mirror (M3 diode, M4 mirror)
   D=vd_l    G=vd_l
   G=vd_l    D=out
   S=vdd     S=vdd
    |         |
   vd_l      out
    |         |
  [M1]      [M2]   NMOS input pair
  G=inp     G=inn
  D=vd_l    D=out
  S=tail    S=tail
    |         |
    +----+----+
         |
        tail
         |
       [M5]        NMOS tail current source
       G=ibias
       D=tail
       S=vss
        VSS
```

**关键 connectivity rules（标准做法，违反必 fail）**：

| Device | role | 关键连接 | 常犯错 |
|---|---|---|---|
| M3 | PMOS diode（mirror master）| **G=D=vd_l**（diode-connected）| 把 M3.G 接 ibias 或 vbp 共享节点 → mirror 失效 |
| M4 | PMOS mirror output | **G=vd_l**（不是 vbp）；D=out | 把 M4.G 接外部 vbp → mirror 没追踪 M3 |
| M1, M2 | NMOS diff pair | S=tail（共 source）；D=vd_l/out | 一边 S 接 vss → 不是 diff pair |
| M5 | NMOS tail | G=ibias（mirror Mbias）；D=tail | tail 要 sink Itail 不能进 triode |

## Standard subckt port order

```spice
.subckt five_transistor_ota inp inn ibias out vdd vss
```

> ⚠️ 注意 `ibias` 在 `out` 之前 — 这是 V3 时代约定的 OTA 标准 port order（与 `vinp vinn ibias out vdd vss` 一致），改 port 顺序会让 testbench 接错 X-instance。

## DC current paths

- **Path 1** (mirror master): VDD → M3(diode) → vd_l → M1 → tail → M5 → VSS
- **Path 2** (output): VDD → M4(mirror) → out → M2 → tail → M5 → VSS
- **Path 3** (bias ref): ibias → Mbias(diode) → VSS
- KCL: I_M3 = I_M1 = Itail/2; I_M4 = I_M2 = Itail/2

## AC signal flow (vinp > vinn)

1. M1.gm ↑ → I_M1 ↑ → vd_l 下降
2. M3 (diode) Vgs 减小 → I_M3 = I_M1（自动追踪）
3. M4 G=vd_l 下降 → M4.|Vgs| 增 → I_M4 ↑（mirror 翻倍）
4. 输出端 M2 sink 减少 + M4 push 增加 → vout 上升

**Gain**: Av = gm_M1 × (ro_M2 ‖ ro_M4)（典型 40-55 dB）  
**GBW**: gm_M1 / (2π·CL)

## Sizing 起点 (vpdk180nm, ibias=10µA, Itail=20µA)

| Device | role | W | L | m | gm/Id | Vov | 备注 |
|---|---|---|---|---|---|---|---|
| M1, M2 | NMOS input pair | 10 µm | 0.5 µm | 1 | ~12 | 0.15 V | gain × noise 平衡 |
| M3, M4 | PMOS mirror load | 10 µm | 1µm    | 1 | ~8 | 0.30 V | 大 Vov 减 noise；gm3 << gm1 让 PMOS noise 衰减 |
| M5 | NMOS tail | 20 µm | 0.5 µm | 2 | ~10 | 0.20 V | Itail = 2 × Id_per_side |
| Mbias | NMOS bias diode | 10 µm | 0.5 µm | 1 | — | — | mirror reference for M5 |

**spec 调整方向**：

- gain 不够 → 加大 L_LOAD (M3/M4 L → 1µm) 提 ro_M4
- power 严苛 → 减 m_tail (Itail 降到 10-15µA)
- noise 紧 → 加大 W_DIFF (gm_M1 ↑) + 加大 L_LOAD（gm_M3 ↓）

## Standard testbench 关键内容

### `tb_dc_op.sp`（DC closed-loop self-bias）

```spice
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include '../design/5t_ota.cir'
.param VCM = 0.9
Vdd  vdd 0  DC 1.8
Vinp vinp 0 DC VCM
Rfb  out vinn 1G    $ DC 闭环 vout->vinn 自校正 vout≈VCM
Cfb  vinn 0 1
Ibias vdd ibias 10u
X1   vinp vinn ibias out vdd 0 five_transistor_ota
.op
.control
  set units = degrees
  run
.endc
.end
```

### `tb_ac_gain_bw.sp`（Method C 断环 AC）

```spice
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include '../design/5t_ota.cir'
.param VCM = 0.9
Vdd  vdd 0  DC 1.8
Vinp vinp 0 DC VCM AC 1   $ AC 注入 + DC bias
Rfb  out vinn 1G          $ DC 闭环
Cfb  vinn 0 1             $ AC 接地（vinn → AC short）
Ibias vdd ibias 10u
X1   vinp vinn ibias out vdd 0 five_transistor_ota
.ac dec 50 1 1G
.control
  set units = degrees
  run
  let gain_db   = db(abs(v(out)/v(vinp)))
  let phase_deg = vp(out) - vp(vinp)
  meas ac dc_gain      find gain_db    at=1
  meas ac gbw_hz       when gain_db=0  cross=1
  meas ac phase_dc     find phase_deg  at=1
  meas ac phase_at_ugf find phase_deg  when gain_db=0 cross=1
  * Anchor-difference PM (universal，对 vinp/vinn 注入 + 内部反相数都对):
  *   PM = 180° - (phase_dc - phase_at_ugf) — phase 走过的距离与 -180° 的余量
  * 适用：5T-OTA 主极点远高于 1Hz，phase_dc=at(1Hz) 取到干净 DC phase
  meas ac pm_deg       param='180 - (phase_dc - phase_at_ugf)'
.endc
.end
```

## 已知设计陷阱（实战教训）

| 陷阱 | 表现 | 修复 |
|---|---|---|
| M3 G ≠ D（不 diode-connected）| mirror 完全失效，I_M4 ≠ I_M3 | M3.G=D=vd_l 必须保证 |
| M4.G 接外部 vbp 而不是 vd_l | mirror 不追 M3 → DC offset 大 | M4.G=vd_l |
| PMOS load 用 input pair 同 L (0.5µm) | noise / matching 差 | PMOS L = 1-1.5 µm（生产风格）|
| Itail 不够大 → gm 不够 → gain 低 | DC OP PASS 但 AC gain < 30dB | Itail ≥ 2 × 期望 gm/12 |
| AC 仿真 vp() 当度数 → PM 数值 57× | PM 报 178° 看似稳实际 3° | testbench 必含 `set units = degrees` |
| 没用 Rfb=1G+Cfb=1F → 闭环测 PM | PM 数字无意义（不是 loop gain）| Method C 断环（见 skill `ac_feedback_loop_method`）|

## When to use this reference

- 设计简单 unity-gain buffer / 数字接口 OTA / 不需要 cascode 的 OTA
- gain 30-50 dB / GBW < 50 MHz / single-stage 足够

## When NOT to use

- gain > 60 dB → 用 `blocks/folded-cascode-ota/reference-design`
- 严苛 PSRR / line reg → 用 `blocks/two-stage-ota/reference-design`
- LDO EA（loop gain 60-80 dB）→ 用双级 EA，5T 永远不够

## 不在本章范围

- gm/ID sizing 通用方法 → skill `device_sizing`
- AC Method C 通用断环原理 → skill `ac_feedback_loop_method`
- input pair / mirror 各自 sizing 细节 → `blocks/base-cells/differential-pair` + `current-mirror`
- ngspice .meas / setplot / 弧度 → `simulators/ngspice/analyses`

## 下一步 Required Action

1. 通过 `load_knowledge(name='5t-ota', asset=...)` 拿以下文件抄拓扑（device 连接 / mirror 结构，不复制数值）：
   - `reference_designs/5t_ota.cir`
   - `reference_designs/tb_dc_op.sp`
2. 推导自己 spec 的 W/L/m（R0 铁律：M1/M2 input pair / M3/M4 mirror load / M5 tail 必须按目标 GBW 和 Itail 重推，不可复制起点数值）
3. `write_file` → `design/5t_ota.cir` + `design/sizing.yaml`
4. `simulate` `testbench/tb_dc_op.sp` → 验证 DC OP 正确 / 再跑 `tb_ac_gain_bw.sp` 验 gain/PM
