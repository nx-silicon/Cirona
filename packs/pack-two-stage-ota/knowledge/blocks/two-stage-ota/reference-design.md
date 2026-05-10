---
chapter: reference-design
parent: two-stage-ota
summary: |
  Production-grade two-stage Miller OTA reference (PMOS input + NMOS mirror + NMOS-CS stage2 + Miller Cc+Rz)
  + standard cir/tb 路径 + Cc/Rz 起点 + 第二级输出节点接对（LDO v3 H-006 实战卡点）
  Iron Law: 写 two-stage OTA 必先复用 reference cir。
tokens: ~800
prerequisite_chapters: []
related_skills:
  - architecture_decomposition
  - device_sizing
  - ac_feedback_loop_method
related_knowledge:
  - blocks/base-cells/miller-compensation
  - blocks/base-cells/common-source
  - blocks/base-cells/differential-pair
  - blocks/base-cells/differential-pair/cm-range
  - blocks/base-cells/current-mirror
  - simulators/ngspice
  - pdks/vpdk180nm
---

# Two-Stage OTA Reference Design

## Iron Law

**Reference design 优先**：写 two-stage OTA 时**必须**先用 `load_knowledge(name='two-stage-ota', asset='reference_designs/two_stage_ota.cir')` 拿网表复制为起点。**LDO v3 H-005 教训**：agent 自己造 stage2 时把 M_cs gate 接 vea1 (M1 drain，diode-load 端) 而不是 nvea1b (M2 drain，真高增益输出节点) → 增益失效，浪费 5+ turn 修。

## Quick reference (assets)

| Asset | 用途 |
|---|---|
| `reference_designs/two_stage_ota.cir` | 完整网表 |
| `reference_designs/tb_dc_closed.sp` | ⭐ DC OP testbench（**主推**，与 AC 共用激励）|
| `reference_designs/tb_dc_op.sp` | DC OP sanity 备用（open-loop，仅作 mismatch=0 对照）|
| `reference_designs/tb_ac_gain_bw.sp` | AC gain/BW/PM testbench |

通过 `load_knowledge(name='two-stage-ota', asset='<上表 Asset 列>')` 拿原文。**禁止用 `read_file` 读知识库内容** — knowledge tool 是唯一合规入口。

## Standard subckt port order

```spice
.subckt two_stage_ota_se vinp vinn vout ibias vdd vss
```

## Core topology — Stage1 (5T) + Stage2 (NMOS CS) + Miller

```
                       VDD
              +----+----+----+
              |    |         |
        [MPBIAS]  [MPTAIL]  [MP6]      Stage 2: PMOS load (mirror from MPBIAS)
        diode      |         |          gate = vbp
        G=D=vbp   ntail     vout
              |    |         |
            [MP1] [MP2]      |          Stage 1: PMOS input pair
            G=vinp G=vinn    |          (PMOS input → tail at top)
            S=ntail S=ntail  |
            D=vx_l  D=vx     |
              |     |        |
             vx_l  vx        |
              |     |        |
            [MN3] [MN4]    [MN6]      Stage1 NMOS mirror load + Stage2 NMOS CS
            diode mirror     |          MN6 gate = vx (Stage1 真输出，不是 vx_l)
            G=D=vx_l G=vx_l G=vx       MN3 diode-connected
            S=vss  S=vss   S=vss
              |     |        |
              +-----+--------+
                     vss

       Miller compensation: Cc between vx (Stage1 output) and vout (Stage2 output)
                           + nulling Rz in series

         Cc=1.5pF        Rz=2k
       vx ────||────────/\/\/\─── vout
```

**Bias chain**：
- `MNBIAS` (NMOS diode @ ibias) sets vgs for MNSINKP
- `MNSINKP` sinks current through MPBIAS (PMOS diode at top)
- `MPBIAS` (G=D=vbp) sets vbp for MPTAIL (Stage1 tail) + MP6 (Stage2 PMOS load)

**关键 connectivity rules**：

| Device | role | gate 接 | 关键正确性 |
|---|---|---|---|
| MN3 | NMOS diode (Stage1 mirror master) | **G=D=vx_l**（diode）| diode-connected 必须 |
| MN4 | NMOS mirror (Stage1 output side) | **G=vx_l** | gate 接 master 节点 vx_l |
| **MN6** | **Stage2 NMOS CS** | **G=vx**（不是 vx_l！）| ⚠️ vx 是 MP2 漏极 = stage1 真高增益输出；vx_l 是 diode 端低增益。**LDO v3 H-005 卡点**：误接 vx_l 让 stage2 不放大，loop gain 大幅下降 |
| MP6 | Stage2 PMOS load | G=vbp（mirror MPBIAS）| 与 MPTAIL 共 gate ref |
| Cc | Miller cap | between **vx ↔ vout** | 跨 stage2，不要接 vx_l ↔ vout |
| Rz | nulling resistor | series with Cc | 调零点位置抵消 RHP zero |

## Sizing 起点 (vpdk180nm, ibias=20µA)

| 参数 | role | W | L | m | 备注 |
|---|---|---|---|---|---|
| `W_DIFF` | PMOS input pair (MP1/MP2) | 20 µm | 0.5 µm | 1 | gm/Id ≈ 12 |
| `W_LOAD` | NMOS mirror load (MN3/MN4) | 10 µm | 1 µm | 1 | 长 L 减 1/f noise + matching |
| `W_TAIL` | PMOS tail (MPTAIL) | 20 µm | 0.5 µm | 1 | Itail = ibias × 1 = 20µA |
| `W_BIAS_N` / `W_BIAS_P` | bias diode (MNBIAS/MPBIAS) | 5/10 µm | 1 µm | 1 | bias chain ref |
| **`W_STAGE2_N`** | **Stage2 NMOS CS (MN6)** | 50 µm | 0.5 µm | 1 | I_stage2 = 50-200 µA（远 > Stage1 Itail，slew rate 关键）|
| **`W_STAGE2_P`** | **Stage2 PMOS load (MP6)** | 100 µm | 0.5 µm | 1 | μp/μn ≈ 1/4 → W_p ≈ 4 × W_n |
| `CCOMP` | Miller Cc | 1.5 pF | — | — | 起点 0.25 × CL |
| `RZ` | nulling Rz | 2 kΩ | — | — | 起点 1/gm_stage2 |

**spec 调整方向**：
- gain 不够 → 加 `L_LOAD` / `L_STAGE2_*` 提 ro
- PM 不够 → 加大 Cc（30% step）or 调 Rz
- slew rate 不够 → 加 `m_stage2_n` 提 I_stage2（典型 4:1 ~ 10:1 vs Stage1 Itail）

## Standard testbench 模板（DC OP 与 AC 共用激励）

> ⭐ **IRON LAW（DC 与 AC 必须用同一激励）**：
> - **DC OP 默认 closed-loop**（Rfb=1G/10Meg + Cfb=1F），与 AC testbench 同一组
>   Vinp/Ibias/Rfb/Cfb 激励，仅切换 `.op` ↔ `.ac`
> - **DC 工作点决定 small-signal 参数**（gm, gds, ro），AC 测出来的 gain/PM 必须基于
>   "AC 部署时实际收敛到的 OP"。如果 DC 用 open-loop（VINP=VINN 强制）、AC 用
>   closed-loop（Rfb shunt），两者 OP 不同 → AC 结果与实际部署状态无关，**毫无意义**
> - **High-gain (≥60dB) two-stage open-loop DC 不可靠**：stage1/stage2 mismatch 被
>   开环增益放大，即使 VINP=VINN 数学相等，数值精度 + device 参数 mismatch 让 vout
>   常飘 rail。这是物理规律不是 sizing bug。closed-loop 把 OP 拉回 Vcm 附近
>   (Rfb=1G 时 fc≈0.16nHz → DC 等效短路；high-gain 时可降至 10Meg/100Meg 让 DC
>   loop 更紧)
> - **Open-loop DC（VINP=VINN 强制）仅作 sanity 备用**：用于 mismatch=0 理想拓扑下的
>   device region 验证；与 closed-loop 对比可定位"vout 飘 rail"是 Rfb 量级问题还是
>   sizing 真问题
> - 详细模式对比见横切章 `simulators/ngspice/testbench-patterns`

实际 reference testbench 在 `assets/reference_designs/`：
- `tb_dc_closed.sp` ← ⭐ **DC OP closed-loop**（主推，与 AC 共用激励）
- `tb_dc_op.sp`     ← DC OP sanity 备用（open-loop，mismatch=0 对照）
- `tb_ac_gain_bw.sp` ← Method C closed-loop（AC 测 PM 用）

下面是模板最小骨架，**抄拓扑不抄数值**，Vdd/Vcm/ibias/Rfb 按 spec 重定。

### Template 1: DC OP（closed-loop，主推）

```spice
* DC Operating Point — closed-loop（与 AC testbench 同一激励，仅切 .op）
* 用途: 验 device region (sat/triode), V_ds_margin, bias chain
.lib '../../pdk/<pdk>/<pdk>_corners.lib' TT
.include './two_stage_ota.cir'

VDD vdd 0 DC <VDD>
VSS vss 0 0
IBIAS vdd ibias DC <iref>

* ⭐ 与 AC testbench 共用激励（DC closed via Rfb + Cfb）
*    high-gain 时 Rfb 可降至 10Meg / 100Meg 让 DC loop 收得更紧
Vcm  vcm  0   DC <Vcm_in>
Vinp vinp vcm DC 0 AC 1            $ AC 1 仅 .ac 用，.op 模式下不影响
Rfb  vout vinn 1G                  $ DC 闭环 (fc≈0.16nHz)
Cfb  vinn 0   1                    $ Cfb=1F：AC 路径上 vinn 接地

X1 vinp vinn vout ibias vdd vss two_stage_ota_se
CL vout 0 5p

.control
  set noaskquit
  op
  print all
  echo "=== vinn vs Vcm（验 closed-loop 收敛）==="
  print v(vinp) v(vinn) v(vout) v(vx)
  echo "=== Stage1 input pair ==="
  print @m.x1.mp1[id] @m.x1.mp1[vgs] @m.x1.mp1[vds] @m.x1.mp1[vdsat]
  print @m.x1.mp2[id] @m.x1.mp2[vgs] @m.x1.mp2[vds] @m.x1.mp2[vdsat]
  echo "=== Stage1 mirror load ==="
  print @m.x1.mn3[id] @m.x1.mn3[vgs] @m.x1.mn3[vds] @m.x1.mn3[vdsat]
  print @m.x1.mn4[id] @m.x1.mn4[vgs] @m.x1.mn4[vds] @m.x1.mn4[vdsat]
  echo "=== Stage2 ==="
  print @m.x1.mn6[id] @m.x1.mn6[vgs] @m.x1.mn6[vds] @m.x1.mn6[vdsat]
  print @m.x1.mp6[id] @m.x1.mp6[vgs] @m.x1.mp6[vds] @m.x1.mp6[vdsat]
.endc
.end
```

**Pass criterion**：所有 device region=SAT，Vds_margin = Vds − Vdsat > 50mV，
vx 不在 rail（应 ≈ Vth_n + Vov，对 PMOS-input + NMOS-mirror 拓扑约 0.4-0.6V），
**vinn 应与 Vcm 收敛在 50mV 以内**（偏离过大 → Rfb 太大 / stage1 imbalance）。

### Template 1b: DC OP sanity（open-loop，仅作诊断对照）

仅当 Template 1 closed-loop 下 vout 飘 rail 时用本模板做对照，定位是 sizing 问题
还是 Rfb 量级 / mirror match 问题。**不作主测**：

```spice
* DC OP sanity — open-loop（mismatch=0 理想拓扑下 region 验证）
VINP vinp 0 DC <Vcm_in>            $ 直接 DC 强制
VINN vinn 0 DC <Vcm_in>
* NO Rfb, NO Cfb
.op
```

诊断对照逻辑：
- T1 fail / T1b pass → Rfb 量级或 stage1 mirror imbalance
- T1 fail / T1b fail → 真 sizing 问题
- T1 pass / T1b 飘 rail → **预期常态**（high-gain open-loop 物理本不可靠）

### Template 2: AC gain / GBW / PM（Method C closed-loop）

```spice
* AC PM/GBW — Method C: DC closed via Rfb=1G+Cfb=1F (fc≈0.16nHz),
*                       AC open at all freq of interest
* 用途: 测 dc_gain, GBW (UGF), PM
.lib '../../pdk/<pdk>/<pdk>_corners.lib' TT
.include './two_stage_ota.cir'

VDD vdd 0 DC <VDD>
VSS vss 0 0
IBIAS vdd ibias DC <iref>

* ⭐ DC closed-loop（让 OP 收敛到 Vcm），AC 全开（freq > 0.16nHz）
Vcm vcm 0 DC <Vcm_in>
Vinp vinp vcm AC 1            $ AC 注入在 vinp ↔ vcm
Rfb  vout vinn 1G             $ Rfb 1G 让 fc≈0.16nHz，DC 等效短路
Cfb  vinn 0 1                 $ Cfb=1F 让 vinn DC 跟住 vcm

X1 vinp vinn vout ibias vdd vss two_stage_ota_se
CL vout 0 5p

.ac dec 50 1 1G
.control
  set units = degrees           $ ⭐ 让 vp() 返回度数（不是弧度）
  run
  setplot ac1
  let gain_db   = db(abs(v(vout)/v(vinp)))
  let phase_deg = vp(vout) - vp(vinp)
  meas ac dc_gain      find gain_db    at=1
  meas ac gbw_hz       when gain_db=0  cross=1
  meas ac phase_at_ugf find phase_deg  when gain_db=0 cross=1
  meas ac phase_dc     find phase_deg  at=1
  * Anchor-difference PM 公式（universal，不依赖拓扑反相数）:
  meas ac pm_deg       param='180 - (phase_dc - phase_at_ugf)'
.endc
.end
```

**Pass criterion**：dc_gain ≥ spec target；GBW ≥ spec target；PM ≥ 60°（默认）。

**注意 vp() 度数**：必须 `set units = degrees`（不加默认弧度，PM 算出 178°
实际 3°，错 57×）。详见 `architecture.md` 已知陷阱表。

## 已知设计陷阱（LDO v3 + V3 历史教训）

| 陷阱 | 表现 | 修复 |
|---|---|---|
| **Stage2 MN6.G 接 vx_l 而不是 vx**（LDO v3 H-005）| Stage2 不放大 → loop gain ↓ 30dB | MN6.G=vx（MP2 漏极，真高增益节点）|
| Cc 接 vx_l ↔ vout 而非 vx ↔ vout | 极点分裂失效 → PM 崩 | Cc 跨 Stage2: vx ↔ vout |
| Cc 太小 → PM 不够 | PM < 45° | Cc ≥ 0.25 × CL，过低 PM 必崩 |
| Rz 太大 → RHP zero 反向 → 不稳 | PM 数字看似好但 tran 振荡 | Rz ≈ 1/gm_stage2，不要随便加 |
| Stage2 I 与 Stage1 同量级（slew rate 不够）| Tran 阶跃响应慢 / 振荡 | I_stage2 = 4-10 × I_stage1 |
| AC vp() 当度数 → PM 错 57× | PM 178° 实际 3° | testbench `set units = degrees` |

## When to use this reference

- LDO EA（双级是 LDO EA 标准）
- 任何 gain 80-100 dB 要求
- ADC 子模块（采样保持放大器 SHA）
- 需要 rail-rail 输出摆幅

## When NOT to use

- gain < 60 dB → 5T-OTA
- gain 60-80 dB + 单级 → FC-OTA
- 高速 / 超低噪声 → 多级 OTA 或 chopper-stabilized OTA（不在本章）

## 不在本章范围

- Miller 补偿原理 / RHP zero / nulling resistor 详细推导 → `blocks/base-cells/miller-compensation`
- Stage2 CS sizing 细节（Vdsat / 噪声 / matching）→ `blocks/base-cells/common-source`
- gm/ID sizing 通用方法 → skill `device_sizing`
- AC Method C 通用断环 → skill `ac_feedback_loop_method`
- LDO 用 two-stage OTA 做 EA 的整体设计 → `blocks/ldo/architecture` + `blocks/ldo/reference-design`

## 下一步 Required Action

> ⭐ **Step 0 必须先做（v6 + Demo 04 双重教训）**：
> - 跳过 Step 0 直接进 Step 1 = Demo 01 v6 浪费 50+ turn 追逐拓扑外 spec 的根因
> - 只敲定 L1 拓扑大类没下钻 L2 input pair 极性 = Demo 04 浪费 15+ turn（PMOS-input + Vcm_in=0.9V > ceiling 0.75V → AC 全垮）
>
> 方法论入口：L1 skill `architecture_decomposition`（架构层级化决策 IRON LAW）

### Step 0 — Spec 可行性 + 架构层级化 self-check（必做，~5 分钟）

#### Step 0.1 — Spec → 拓扑大类（L1）

把当前 spec 与 `index.md` § Spec Ceiling Table 逐项对账：

```
[ ] DC gain 目标 = ? dB → 落在 [5T 55 / FC 80 / Tele 80 / 2-stage 100 / +cascoded 115] 哪一档？
[ ] GBW 目标 = ? MHz → 2-stage Miller 上限 ~50 MHz；若 > 50 MHz 换 FC 或 telescopic
[ ] PM 目标 = ?° → 60° default；> 70° + 大 GBW 是 trade-off
[ ] Output swing 需求 → rail-to-rail 必选 2-stage（FC/Tele swing 不够）
[ ] Slew rate = ? V/µs → I_stage2 ≥ Cload × SR；> 50 V/µs 需大 power
[ ] Power budget = ? µW → 2-stage @ vpdk180nm 典型 300-1000 µW
```

#### Step 0.2 — Stage1 Input Pair 极性 self-check（L2 IRON LAW，**不能跳**）⭐

```
[ ] PDK constants（查 PDK reference）：
    - VDD = ? V
    - |Vth_p| = ? V
    - Vth_n = ? V
[ ] PMOS-input pair Vcm ceiling = VDD − |Vth_p| − 0.1 = ? V
[ ] NMOS-input pair Vcm floor   = Vth_n + 0.1                  = ? V
[ ] Vcm_in = ? V（来源：LDO EA = Vfb / ADC SHA = Vref / 通用 = input source 工作点）
[ ] 对照 Vcm_in vs ceiling/floor：
    - Vcm_in > ceiling → **必选 NMOS-input pair**（→ Variant 1 拓扑）
    - Vcm_in < floor   → **必选 PMOS-input pair**（默认 reference）
    - floor < Vcm_in < ceiling 健康 → 双向都 OK，按 noise / 1/f 取舍（PMOS 噪声低）
    - 同时违 → rail-to-rail 或 folded-cascode tail
[ ] 选定的 Stage1 input pair 极性 = ?，写明数值代入证据
```

详见 `architecture.md` § "Stage1 Input Pair 极性 — IRON LAW" + `base-cells/differential-pair/cm-range`。

**典型陷阱（必避）**：vpdk55nm Vcm_in=0.9V → PMOS ceiling=0.75V 违 → **不能用默认 PMOS-input reference cir，必须切 Variant 1（NMOS-input）**（Demo 04 实证）。

#### Step 0.3 — 2-stage 内部 PM IRON LAW

```
[ ] gm6 ≥ 12 × gm1 (@ Cc=CL/4) → PM > 60° 物理必要条件
[ ] Cc ≥ 0.25 × CL → Miller 补偿基本
```

#### Step 0.4 — 结论

```
- 是否选 2-stage？（如果 gain ≤ 80dB 且不需要 rail-to-rail，应选 FC 而非 2-stage —— 简单 + PM 容易）
- 选定 Stage1 input pair 极性 = ?（PMOS / NMOS / rail-to-rail）
- 决定用 reference cir = ?（默认 PMOS-input or Variant 1 NMOS-input）
- I_stage1 / I_stage2 / Cc / Rz 起点估值
```

**任一项超 ceiling**：
- 不能靠 sizing 救 → 必须换拓扑（gain > 100 dB 加 cascoded stage1；GBW > 50 MHz 换 FC）
- 或 declare hypothesis：「我假设 spec gain=110dB 可改为 90dB，理由是 ...」（用 `hypothesis_declare` tool）
- **禁止**：跳过 Step 0 直接 Step 1 / 在拓扑上限外 sizing / 漏 L2 input pair 极性 self-check

### Step 1 — 抄 reference cir 拓扑

通过 `load_knowledge(name='two-stage-ota', asset=...)` 拿以下文件抄拓扑（Stage1 5T / Stage2 CS / Miller Cc+Rz 连接，**不复制数值**）：
- `reference_designs/two_stage_ota.cir`
- `reference_designs/tb_dc_closed.sp` ← ⭐ DC OP testbench 主推
- `reference_designs/tb_ac_gain_bw.sp`（与 tb_dc_closed.sp 共用激励）
- `reference_designs/tb_dc_op.sp` ← 仅作 open-loop sanity 对照（可选）

### Step 2 — 推导 W/L/m（R0 铁律）

按 `sizing-typical.md` Phase A → B → C **严格顺序**：
- Phase A: Stage1 sizing（5T input pair gm1 / Itail）
- Phase B: Stage2 sizing（NMOS-CS gm6 ≥ 12 × gm1 / Itail2 = 4-10× Itail1）
- Phase C: Miller Cc + Rz（Cc ≥ 0.25 × CL / Rz = 1/gm6）

**铁律**：
- I_stage2 = 4-10× Stage1 Itail
- Cc ≥ 0.25× CL（PM > 60° 物理必要）
- **MN6.G 必须接 vx（MP2 漏极）不是 vx_l**（LDO v3 H-005 教训，stage2 不放大就废了）
- 数值必须重推，不可复制参考数值

### Step 3 — 写网表

`write_file` → `design/two_stage_ota.cir` + `design/sizing.yaml`

### Step 4 — 仿真验证

`simulate` `testbench/tb_dc_closed.sp` → 验证 DC OP（closed-loop 主测）/
再跑 `tb_ac_gain_bw.sp` 验 gain/PM（与 DC 共用激励）。
仅当 vout 飘 rail 需诊断时再跑 `tb_dc_op.sp` 做 open-loop sanity 对照。

**ngspice 关键约定**：
- testbench `set units = degrees`（避免 vp() 弧度未转度，PM 178° 假象）
- AC 测 PM 用 anchor-difference 公式 `phase_margin = 180 - (phase_dc - phase_at_ugf)`

### 改电容 / 改补偿前必须读

**改 Cc / Cload** → 电容尺寸约束见 `blocks/bandgap/physical-constraints.md` § 1（横切，> 50pF 片内不可行）
**改 Rz** → `ac-stability.md` § nulling resistor（Rz = 1/gm6 起点）
**多变量同时改 Cc + Rz + gm** → ac-stability 模式 1-3，盲调易反复
