---
chapter: reference-design
parent: bandgap
summary: |
  Verified baseline PNP first-order Brokaw bandgap reference (3-leg PMOS mirror
  + PNP 1:8 + R2 CTAT shunt + R_OUT + 5T 2-stage PMOS-input OTA + Miller comp
  + startup branch) + standard cir/tb 路径（dc/startup/tc/psrr 4 testbench）+
  sizing 起点 + OTA polarity 实战教训（V3 efb0fa3 verified Vref=1.193V /
  Iq=34µA / TC=346 ppm/°C @ first-order）。Iron Law: 写 bandgap 必先复用
  reference cir。startup 详细行为见 chapter=startup。
tokens: ~1100
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/bias-generator
  - blocks/base-cells/differential-pair
  - blocks/base-cells/current-mirror
  - blocks/5t-ota
  - simulators/ngspice
  - pdks/vpdk180nm
---

# PNP Bandgap Reference Design

## Iron Law

**Reference design 优先**：写 bandgap 时**必须**先用 `load_knowledge(name='bandgap', asset='reference_designs/bandgap.cir')` 拿 107 行 self-contained 网表（含 PNP core + 2-stage PMOS-input OTA + Miller comp + startup）复制为起点。**从零造 bandgap 几乎必踩 OTA polarity 反转 trap**（V3 efb0fa3 实战：抄 Razavi 单级 5T `vp=nb` 写法到 2-stage OTA → DC latch 到 Vref=1.79V，**`.op` 不报错只能看 FOM 才发现**——见 `chapter=architecture` § Pitfall 4）。

V3 reference cir **已 verified**（commit efb0fa3 / 2026-04-22）：Vref=1.193V / Iq=34µA / OTA lock_err=0.5mV / TC=346 ppm/°C（3 点 sweep -40/27/125°C，**resistor TC / curvature 未补偿**）/ PSRR 36.8 dB DC（**non-cascoded mirror 限制**）。它是 topology / connectivity / startup baseline，**不是 TC / PSRR 已达生产规格的最终设计**。

## Quick reference (assets)

| Asset | 用途 |
|---|---|
| `reference_designs/bandgap.cir` | 完整网表（107 行 self-contained） |
| `reference_designs/tb_dc_op.sp` | DC OP testbench（含 OTA 内部节点 region 检查） |
| `reference_designs/tb_startup.sp` | Startup tran tb（VDD ramp 1µs + tran 200µs） |
| `reference_designs/tb_tc_sweep.sp` | TC 三点 sweep tb（-40/27/125°C） |
| `reference_designs/tb_psrr.sp` | PSRR AC tb（1Hz - 10MHz） |

通过 `load_knowledge(name='bandgap', asset='<上表 Asset 列>')` 拿原文。**禁止用 `read_file` 读知识库内容** — knowledge tool 是唯一合规入口。

## Standard subckt port order

```spice
.subckt bandgap vdd vss vref
```

> ⚠️ **Self-biased**——本 bandgap 没有外部 `ibias` pin。OTA bias 由 `R_BIAS` (2 MΩ) + `M_BIAS` (NMOS diode) 在 `bgr_ota` 内部生成。如需 port 到外部 ibias-driven 平台，替换 `bgr_ota` 内 R_BIAS + M_BIAS 那条 leg 为外部 ibias 驱动的 mirror。

## Core topology — PNP first-order Brokaw

```
                              VDD
              +----+----+----+----+----+
              |    |    |    |    |    |
            [MP1][MP2][MP3] R_START [bgr_ota
            G=yg G=yg G=yg     |     internal:
              |    |    |     v_sens R_BIAS+M_BIAS]
              na   nb  vref    |
              |    |    |   [MN_SENS]
            [R2a][R2b]  |   G=vref
              |   [R1]  R_OUT  D=v_sens
              |    |    |       S=vss
            [Q1]   ny  vss
            AREA=1 |
              |  [Q2]
             vss  AREA=8
                   |
                  vss

       OTA XAMP (2-stage PMOS-input, vp=na, vn=nb, vout=yg):
            ⚠️ vp=na / vn=nb is for 2-stage (overall inverting); 
            Razavi single-5T convention uses vp=nb (overall non-inverting)

       Outer compensation: Ccomp 2 pF on yg (avoids tran ringing)

       Startup: MN_KICK pulls yg low until Vref > Vth_n turns on MN_SENS,
                which then collapses v_sens, disengaging the kick.
```

**关键 connectivity rules**（V3 efb0fa3 实战 traps codify）：

| Branch | Device | gate / 关键端 | 关键正确性 |
|---|---|---|---|
| Mirror MP1 | PMOS, S=vdd, G=yg, D=na | yg shared with MP2/MP3 | 3 leg 必须 W/L/M 完全相同（Pitfall 3）|
| Mirror MP2 | PMOS, S=vdd, G=yg, D=nb | 同上 | 同上 |
| Mirror MP3 | PMOS, S=vdd, G=yg, D=vref | 同上 | 同上 |
| na branch | R2a (na↔vss) + Q1 (PNP, B=vss, E=na) | AREA=1 | Q1 emitter 接 na（PNP 极性反 → DC 漂）|
| nb branch | R2b (nb↔vss) + R1 (nb↔ny) + Q2 (PNP, B=vss, E=ny) | AREA=8 | R1 在 nb 与 Q2 emitter 之间，是 PTAT 生成元件 |
| Output | R_OUT (vref↔vss) | — | Vref = (I_PTAT + I_CTAT) × R_OUT |
| **OTA** | bgr_ota XAMP (na, nb, yg, vdd, vss) | **vp=na, vn=nb**（2-stage 反相）| ⭐ Pitfall 4 — 单级 OTA 用 vp=nb；2-stage 必须 vp=na |
| Startup | R_START (vdd→v_sens) + MN_SENS (G=vref, D=v_sens, S=vss) + MN_KICK (G=v_sens, D=yg, S=vss) | — | Vref<Vth_n 时 MN_SENS off → v_sens=VDD-µ → MN_KICK on → 拉 yg 低 → mirror 启动 |
| Comp | Ccomp 2 pF (yg↔vss) | — | 抑 outer loop 多极点 ringing |

> **OTA polarity 决策表**（避 Pitfall 4）：
> - 单级 5T OTA（5T 自身非反相）→ `vp=nb / vn=na` ← Razavi 经典约定
> - 2-stage OTA（5T 非反相 + NMOS-CS 反相 = 整体反相）→ **`vp=na / vn=nb`**（V3 PACK 默认）
> - 抄不同教材 OTA 拓扑前**必须自己画小信号 loop sign**

## Bias chain 标准（self-biased）

| 节点 | 由谁生成 | 用途 |
|---|---|---|
| `yg` | OTA 输出 | 3 PMOS mirror gate（共享）|
| `bp`（OTA 内）| `R_BIAS` (2 MΩ) → `M_BIAS` NMOS diode | OTA tail + load PMOS gate（self-biased Vsg ≈ 0.9V → 5 µA per leg）|
| `na` / `nb` | self-consistent 由 OTA 锁住 ≈ Vbe ≈ 0.65V | OTA 输入 + na/nb branch 反馈点 |
| `ny` | Q2 emitter（≈ na - ΔVbe ≈ 0.6V）| nb branch 内 PNP 端 |

## Sizing 起点 (vpdk180nm, VDD=1.8V, Vref ≈ 1.2V, Iq ≈ 25 µA target)

| 参数 | role | 值 | 备注 |
|---|---|---|---|
| `W_P` / `L_P` / `M_P` | PMOS mirror MP1/MP2/MP3 | 10 µm / 1 µm / 1 | L≥1µm（Pitfall 1）；3 leg 全等 |
| `R1_PTAT` | PTAT 生成 R | 15 kΩ | I_PTAT = VT·ln(8) / R1 ≈ 3.6 µA |
| `R2_CTAT` | CTAT shunt R（R2a / R2b 各一）| 180 kΩ | I_CTAT = Vbe / R2 ≈ 0.65/180k ≈ 3.6 µA；**R2a / R2b 必须 common-centroid layout**（Pitfall 3）|
| `R_OUT` | 输出 R | 165 – 171 kΩ | Vref = (I_PTAT + I_CTAT) × R_OUT ≈ 7.2µA × 165kΩ ≈ 1.19V |
| `AREA_Q1` / `AREA_Q2` | PNP emitter area ratio | 1 / 8 | ΔVbe = VT·ln(8) ≈ 54 mV @ 27°C |
| `R_START` | startup pull resistor | 500 kΩ | Pitfall: 太低 → MN_KICK 部分导通 → PSRR/Iq 退化（chapter=startup）|
| `W_SENS` / `L_SENS` | MN_SENS sizing | 5 µm / 1 µm | gate=Vref，detector |
| `W_KICK` / `L_KICK` | MN_KICK sizing | 5 µm / 1 µm | startup 太弱 → stuck-at-zero；太强 → startup oscillation（详见 chapter=startup）|
| **OTA**（bgr_ota 内）| 2-stage PMOS-input | input pair W=4µ/L=2µ；M_TAIL/M_LOAD W=4µ/L=4µ | gain ≥ 40 dB / Iq ≈ 5 µA per leg（Pitfall 5：避免抄宽带 amp 模板 W=20µ/L=0.5µ）|
| `Cmiller` / `Rz` | OTA Miller comp | 3 pF / 20 kΩ | nulling 消 RHP zero（Pitfall 6）|
| `Ccomp` | outer loop cap | 2 pF | yg 上抑 mid-MHz ringing（Pitfall 6）|

**Sizing derivation scope**：本表是 system-level 起点，不替代 device-level sizing。完整 PMOS mirror / OTA input pair / tail / load 的 Pelgrom、1/f noise、gm/Id lookup 见 `blocks/base-cells/current-mirror`、`blocks/base-cells/differential-pair`、`blocks/5t-ota`。

| 变量 | derivation chain | 起点 |
|---|---|---|
| `R1_PTAT` | `N=8` + `I_PTAT=2–5 µA` → `R1 = VT·ln(N) / I_PTAT` | 15 kΩ |
| `R2_CTAT` | zero-TC 比例 `R2/R1 ≈ 11.2–12`，且让 `I_CTAT ≈ Vbe / R2` 与 I_PTAT 同量级 | 180 kΩ |
| `R_OUT` | `Vref_target / (I_PTAT + I_CTAT)` | 165–171 kΩ |
| `L_P` | ro / line-reg / PSRR 优先，且 long-L 改善 matching；vpdk180nm 起点 ≥ 1 µm | 1 µm |
| `W_P` | 由目标 mirror current、gm/Id ≈ 15–20、Vsg headroom lookup；三腿保持同 W/L/m | 10 µm |
| OTA devices | 低 Iq + moderate gain；input pair `W=4µ/L=2µ`，tail / load PMOS `W=4µ/L=4µ`；详细 noise / matching 推导在 OTA / base-cell chapter | V3 baseline |
| startup FETs | `W_KICK` 满足 startup tran 中 `yg_min < VDD - \|Vsg_MP\|`；`MN_SENS` 满足正常 DC `V(v_sens) < 0.1V` | 5 µm / 1 µm |

## Standard testbench 摘要

完整 4 testbench 通过 `load_knowledge(name='bandgap', asset='reference_designs/tb_<...>.sp')` 获取（V3 已 verified，参见上方 Quick reference 表）。每 tb 关键点：

### `tb_dc_op.sp`（DC 静态验证）

```spice
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './bandgap.cir'
VDD vdd 0 DC 1.8
Xdut vdd 0 vref bandgap
.op
.control
  set units = degrees
  run
  let v_vref       = v(vref)
  let ota_lock_err = abs(v(xdut.na) - v(xdut.nb))
  let i_vdd        = i(VDD)
  print v_vref ota_lock_err i_vdd
.endc
.end
```

**期望**：Vref ≈ 1.19V / na ≈ nb / yg ≈ 1.05V / I(VDD) 25–40µA。Vref ≈ 1.79V → OTA polarity 反（Pitfall 4 silent failure）。

### `tb_startup.sp`（必做，详见 chapter=startup）

VDD `PULSE(0 1.8 0 1u 1u 10 20)` + `tran ... uic` + meas `vref_max / vref_settled / t_vref_90`。**DC `op` 不能证明 startup**。

### `tb_tc_sweep.sp`（TC 三点）

`.temp -40 / 27 / 125`，post-process `TC = (Vref_max − Vref_min) / (Vref_27 × ΔT)` ppm/°C。

### `tb_psrr.sp`（PSRR AC）

`VDD = DC 1.8 + AC 1`，`.ac dec 50 1 10Meg`，`PSRR(dB) = -vdb(vref)`。V3 non-cascoded baseline ~35–40 dB DC；spec 60–70 dB 需 cascoded mirror。

## 已知设计陷阱（V3 实战 + bandgap_pack_verified 教训 codify）

| 陷阱 | 表现 | 修复 |
|---|---|---|
| **OTA polarity 反**（V3 efb0fa3 stranger-domain review）| DC `op` Vref ≈ 1.79V（VDD-边缘）或 0V，**`.op` 不报错** | 2-stage OTA 用 `vp=na / vn=nb`（不是 Razavi 单级 5T 的 `vp=nb`）；写 OTA 前画小信号 loop sign |
| **OTA oversize**（W=20µ/L=0.5µ 抄宽带 amp 模板）| Iq=378 µA（12× 预算）| OTA 用 `W=4µ/L=2µ` input pair + `W=4µ/L=4µ` M_TAIL/M_LOAD（gain 不需 BW）|
| **外环 oscillation**（缺 Miller + Rz nulling）| tran Vref 持续振荡 mid-MHz；PSRR 1MHz peaking | OTA 内 Cmiller=3 pF + Rz=20 kΩ + yg 上 Ccomp=2 pF |
| **PMOS mirror L=Lmin**（0.18µm）| PSRR DC < 50 dB / Vref 漂 5+ mV/V | L_P ≥ 1 µm（W_P 也要相应增大保 Vsg 在 0.5-0.6V）|
| **R2a / R2b 各写独立** | DC \|na − nb\| > 1 mV / Vref shifted | 用同 unit cell × N 拷贝；layout common-centroid |
| **NMOS-input OTA**（na/nb=0.65V 共模没 headroom）| OTA tail triode / na/nb 不锁 | 必须 PMOS-input（V3 默认）|
| **`.op` 没证 startup**（DC solver 跳到非零解）| silicon stuck-at-zero | tb_startup tran + `.ic` + `tran ... uic`（详见 chapter=startup）|

## When to use / NOT use

✅ PNP first-order bandgap（VDD ≥ 1.5V / 工艺有 vertical PNP / TC 30–80 ppm/°C OK）；LDO/PMIC/ADC 子模块 Vref。

❌ VDD < 1.5V（用 CMOS Banba/DRO）；TC < 20 ppm/°C（curvature-corrected）；工艺无 PNP（CMOS Vth-based / chopper）；噪声 < 1 µV/√Hz（chopper）。

## 不在本章范围

- **拓扑对比 / zero-TC 因果 / 7 pitfalls** → `chapter=architecture`；**Startup 详细** → `chapter=startup`
- **β-multiplier 双稳态 / startup-helper 物理** → `blocks/base-cells/bias-generator/{beta-multiplier, startup-helper}`
- **5T-OTA sizing** → `blocks/5t-ota`；**Miller / RHP zero / Rz nulling** → `blocks/base-cells/miller-compensation`
- **cascoded PMOS mirror**（PSRR > 70 dB variant）→ `blocks/base-cells/{cascode, current-mirror}`
- **AC 通用断环** → skill `circuit-method/ac-feedback-loop-method`；**TC sweep 后处理** → 主机侧分析

## 下一步 Required Action

> ⭐ **Step 0 必须先做（v6 教训）**：跳过 Step 0 直接进 Step 1 = Demo 01 v6 浪费 50+ turn 追逐拓扑外 spec 的根因。

### Step 0 — Spec 可行性自检（必做，~5 分钟）

把当前 spec 与 `index.md` § Spec Ceiling Table 逐项对账：

```
对账清单（每条都要打钩或说明）：
[ ] PSRR @ DC 目标 = ? dB → 落在 [non-cascoded ≤ 45 / cascoded ≤ 55 / beta-multiplier ≤ 70 / chopper > 70] 哪一档？
[ ] TC 目标 = ? ppm/°C → first-order ≥ 30 / curvature < 20 / chopper < 10？
[ ] VDD min = ? V → PNP Brokaw ≥ 1.5V / Banba 1.0-1.6V？
[ ] Iq budget = ? µA → 25-40 (first-order) / 30-50 (cascoded) / 50-100 (chopper)？
[ ] PNP 可用？vpdk180nm/130nm 有，< 65nm 通常无 → 必切 CMOS Banba

结论：本 spec 选用拓扑 = ?（必须显式宣告）
```

**任一项超 ceiling**：
- 不能靠 trim/sizing 救 → 必须升级拓扑（按 `index.md` § spec → 必选拓扑路径）
- 或 declare hypothesis：「我假设 spec PSRR=60dB 可改为 50dB，理由是 ...」（用 `hypothesis_declare` tool）
- **禁止**：跳过 Step 0 直接 Step 1 / 在拓扑上限外 sizing

### Step 1 — 抄 reference cir 拓扑

通过 `load_knowledge(name='bandgap', asset=...)` 拿以下文件抄拓扑（device 连接 / mirror 结构 / R 网络，**不复制数值**）：
- `reference_designs/bandgap.cir`
- `reference_designs/tb_dc_op.sp`

### Step 2 — 推导 W/L/m（R0 铁律）

按 `sizing-typical.md` 4-step recipe：
- R1_PTAT / R2_CTAT / R_OUT / PMOS mirror sizing 必须按目标 Iq 和 Vref 重推，不可复制 V3 数值
- ⚠️ **dVbe/dT 必须 PDK 实测**（不抄教科书 -2.0 mV/°C；vpdk180nm 实测 -1.776 mV/°C）—— 见 `sizing-typical.md` Step 4

### Step 3 — 写网表

`write_file` → `design/bandgap.cir` + `design/sizing.yaml`

### Step 4 — 仿真验证

`simulate` `testbench/tb_dc_op.sp` → 验证 Vref ≈ target / OTA lock_err < 1mV / Iq in spec

**然后**必须连续验：
- `tb_startup.sp`（**必跑** uic + ramp，DC OP 不能证明 startup —— 见 `startup.md`）
- `tb_tc_sweep.sp`（TC 三点）
- `tb_psrr.sp`（PSRR vs Step 0 declared 拓扑上限对账）

### 改 PSRR / 加电容前必须读

**改电容**（任何 ≥ 1pF 改动）→ `physical-constraints.md` 全章 + `startup.md` Mode 6
**改 PSRR 路径** → `loop-stability.md` § R2 铁律（PSRR 上限随偏置拓扑变）+ `physical-constraints.md` § 6
**Cac 方向**（接 VDD 还是 VSS）→ `physical-constraints.md` § 3 + `troubleshooting.md` Mode 13
