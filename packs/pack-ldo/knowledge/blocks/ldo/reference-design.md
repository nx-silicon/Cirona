---
chapter: reference-design
parent: ldo
summary: |
  LDO 多模板 PACK：4 种 EA 拓扑 reference cir（A 5T+PMOS-CS / B PMOS-in 5T+PMOS-SF
  / C FC-direct+Ahuja / D FVF-dual-loop TBD）+ 通用 LDO 设计铁律（divider 必须 in
  subckt、mirror 用 W_bias 只 m 变、Ibleed 反推 R1+R2、EA polarity 必须 case-by-case
  推导）+ 各拓扑选型决策树 + 通用 testbench 模板（5 ports 无 vfb）。
  Iron Law: 写 LDO 必先按 spec 选拓扑 → 复用对应 reference cir，不从零写。
tokens: ~1500
prerequisite_chapters:
  - architecture
  - standard-tests
related_skills:
  - architecture_decomposition
  - device_sizing
  - ac_feedback_loop_method
related_knowledge:
  - blocks/base-cells/differential-pair
  - blocks/base-cells/differential-pair/cm-range
  - blocks/base-cells/current-mirror
  - blocks/base-cells/source-follower
  - blocks/base-cells/cascode
  - blocks/base-cells/miller-compensation
  - blocks/folded-cascode-ota
  - simulators/ngspice
  - pdks/vpdk180nm
---

# LDO Reference Design — Multi-Topology PACK

## Iron Law

**LDO 是系统级电路，提供多模板**。任何 LDO 设计必须：

1. 按 spec 选拓扑（4 种，决策树见下）
2. `read_file` 对应 reference cir
3. 工作区 `cp + 调 sizing`（不修改主 reference）
4. 用 `standard-tests` chapter 跑 P0 测试套件

**NEVER** 从零写 LDO 网表。多次实战验证：从零写易犯拓扑级错误（如 EA 第二级 stage current source 接错、缺 NMOS 下拉、divider 写在 testbench 等），调试代价极大。

---

## 通用 LDO 设计铁律（多拓扑共有）

### Iron Law 1: R-divider 必须在 LDO subckt 内部

```spice
.subckt my_ldo  vdd vss vout ibias vref         $ NOTE: vfb 不在 port list
+ params: R_R1=10k R_R2=30k ...
* ... EA + pass + comp ...
R1  vout  vfb  {R_R1}                            $ vfb 是 subckt 内部节点
R2  vfb   vss  {R_R2}
.ends
```

R1+R2 同时实现：
- **Vout 比例**：Vout = Vref × (R1+R2)/R2
- **Ibleed = Vout/(R1+R2)**（自带最小负载）

有 R-divider → 不需要独立 M_bleed。详细设计流程见 `standard-tests` chapter Rule 1。

### Iron Law 2: Mirror 原则（current source/sink 设计）

```spice
* NMOS sink mirror Mbias: W/L 与 Mbias 相同，只 m 变
M_sink  drain  ibias  vss  vss  nch  W={W_bias}  L={L_bias}  m={m_sink}
* I_sink = I_Mbias × m_sink (精确可控)

* PMOS source mirror M_pbias_p: W/L 与 M_pbias_p 相同，只 m 变
M_source  drain  vbias_p  vdd  vdd  pch  W={W_pbias}  L={L_pbias}  m={m_source}
```

**绝不能用 vref/vdd 直接接 gate**（电流随工艺/温度大幅漂移，不可控）。

### Iron Law 3: EA polarity 必须 case-by-case 推导

| EA 拓扑 | vfb 接哪 | vfb→vea 是否 inverting | 后级 inverter 数 |
|---|---|---|---|
| NMOS-input 5T (A) | M2 mirror side | inverting | 2 (PMOS-CS + pass) → 总 3 inv |
| PMOS-input 5T (B) | M1 diode side | non-inverting | 2 (SF + pass) → 总 1 inv |
| FC OTA (C) | MN1 left | non-inverting | 1 (pass) → 总 1 inv |

**规则**：vfb→vout 的总反相数必须**奇数**（negative feedback）。换拓扑必须重画 polarity，不能复制 vfb/vref 接法。

### Iron Law 4: Pass FET 用 PMOS（系统层默认）

NMOS pass 需要 charge pump（vg > vdd），复杂度太高。本 PACK 仅含 PMOS-pass 拓扑。

---

## 4 种 EA 拓扑选型决策树

```
START: 选 LDO 拓扑

├─ 需要超高精度 (line/load reg < 0.5 mV/V) 或宽 Vref 范围？
│   └─ → C (Folded-cascode EA, direct drive, Ahuja dual-cap)
│       Loop gain ~90-100dB / Iq ~100µA / Vref 0.4-1.4V
│
├─ Vref 较低 (≤ 1.0V) 且 Vdd ≤ 1.8V？
│   └─ → B (PMOS-input 5T + PMOS Source-Follower)
│       Loop gain ~50-60dB / Iq ~70µA / Vref ≤ 1.1V (ICMR upper)
│
├─ Standard SoC LDO, Vref ≥ 1.0V, 中等精度？
│   └─ → A (NMOS-input 5T-OTA + PMOS-CS Second Stage)
│       Loop gain ~60-70dB / Iq ~50µA / Vref ≥ 0.7V (ICMR lower)
│
└─ Capless / fast (<1µs) transient?
    └─ → D (FVF Dual-Loop), 暂未实现 reference cir
        参考 analog-design-system: assets/architectures/analog_ldo_dual_loop_fvf.yaml
```

---

## 各拓扑 Reference Cir 路径与特点

### Topology A: NMOS 5T-OTA + PMOS-CS Second Stage

- **asset**: `reference_designs/ldo_5t_pmos_cs.cir` （`load_knowledge(name='ldo', asset='reference_designs/ldo_5t_pmos_cs.cir')`）
- **subckt**: `ldo_5t_pmos_cs`
- **EA polarity**: vref→M1 (diode), vfb→M2 (mirror, output v1)
- **Stage 2**: PMOS-CS gate=v1（signal in），NMOS sink gate=ibias（mirror Mbias）
- **关键 sizing**:
  - `W_load1=2u L_load1=1u` 让 v1 nominal ~ 1.0V，给 PMOS-CS 足够 |Vsg|
  - `m_cs_n=8` → I_stage2 = 40µA
  - Cc=10pF Miller across stage 2

适用：标准 SoC LDO，Vref≥1V，中等精度。Loop gain ~60-70dB 由 5T (~30dB) × PMOS-CS (~30dB) × pass FET 组成。

### Topology B: PMOS-input 5T + PMOS Source-Follower

- **asset**: `reference_designs/ldo_5t_pmos_in_sf.cir` （`load_knowledge(name='ldo', asset='reference_designs/ldo_5t_pmos_in_sf.cir')`）
- **subckt**: `ldo_5t_pmos_in_sf`
- **EA polarity**: vfb→M1 (diode), vref→M2 (mirror, output vea)
- **Buffer**: PMOS SF — `Mbuf vg_pass vea vss vg_pass pch m={m_buf_p}`
  - bulk 接 source（消除 body effect）
  - vg_pass = vea + |Vsg_p| → vg_pass 偏高，匹配 PMOS pass driving range
- **Bias chain**: NMOS Mbias → M_pbias_n (NMOS) + M_pbias_p (PMOS diode) → vbias_p
  - PMOS sources (M_ptail, M_buf_source) 都 mirror M_pbias_p

适用：低 Vref / 低 Vdd 场景。**ICMR 上限 ≈ 1.1V**（PMOS-input 限制），Vout=1.2V 时 vfb=0.9V（divider 1:3）。

### Topology C: Folded-Cascode EA + PMOS SF Buffer + Ahuja

- **asset**: `reference_designs/ldo_fc_buffer.cir` （`load_knowledge(name='ldo', asset='reference_designs/ldo_fc_buffer.cir')`）
- **subckt**: `ldo_fc_buffer`
- **EA polarity**: vfb→MN1 (non-inv), vref→MN2 (inv)
- **Buffer (5 devices)**: PMOS SF + NMOS sink (mirror Mbias) + NMOS adaptive
  pull-down + PMOS diode pull-up + ideal current source (per
  analog-design-system `wide_range_stable.cir` pattern):
  - `Mbuf` PMOS SF: D=nadapt, G=vea, S=vg_pass, body=vdd
  - `Mbuf_sink` NMOS sink at nadapt: gate=ibias, mirror Mbias
  - `Mbuf_adapt` NMOS adaptive pull-down at vg_pass (heavy load → vea ↓ →
    Mbuf I ↑ → nadapt ↑ → Mbuf_adapt sinks more from vg_pass)
  - `Madapt_p` PMOS diode at vg_pass (sources current at very light load)
  - `Ibuf` ideal current source vdd→vg_pass (sets static buffer current)
- **Compensation**: Ahuja `Cc vout vcas_n` (NMOS cascode source tap) — no
  RHP zero, since buffer separates EA output from pass FET gate.

**Why buffer is required** (实证教训): FC EA's super-high R_vea × pass FET's
Cgd Miller creates a low-freq pole at vea that cannot be compensated by
external Cc alone. Empirical: FC + direct drive achieved only PM ≈ 13°
even with aggressive Cc tuning (5pF→100pF). Adding the SF buffer separates
vea from MP_pass.gate (vg_pass), restoring stable PM ≈ 73°.

适用：宽 ICMR (Vref 0.4-1.4V) / 高 PSRR 目标 / 中等精度。Loop gain ~70-90dB
(FC × buffer attenuation × pass)。Iq 较大 (cascode + buffer ~100µA)。

### Topology D: FVF Dual-Loop (TBD)

- **cir**: 暂未实现（仅 architecture 草图）
- **参考**: `analog-design-system/.../analog_ldo_dual_loop_fvf.yaml`
- 适用：capless / sub-µs 瞬态 / 中等电流（1-100mA）
- 待补充模板。

---

## 通用 Testbench 模板（5 ports，无 vfb）

```spice
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './ldo_<topology>.cir'        $ A: ldo_5t_pmos_cs / B / C

Vdd   vdd 0  DC 1.8
Vref  vref 0 DC 0.9                    $ Vref < min(Vout, ICMR upper)
Ibias vdd ibias 5u                     $ external 5µA bias

Iload vout 0 DC 10m                    $ test condition

* Output cap (typical 1µF + ESR 0.1Ω — MLCC 类电容 ESR ~10mΩ-100mΩ；
*                                       钽 / POS-cap ~100mΩ；电解 ~Ω 级)
Cload vout vout_cap 1u
Resr  vout vout_cap 0.1

* X1 instance: 5 ports (no vfb!) — vfb is internal divider node
X1 vdd 0 vout ibias vref ldo_<topology>

.op
* ... or .ac, .tran, etc.
```

**关键**：testbench 实例 X1 只有 **5 ports**（vdd, vss, vout, ibias, vref），**没有 vfb**。
- vfb 在 subckt 内部由 R1+R2 生成
- testbench 控制 Vref 和 Iload，subckt 自身负责 Vout = Vref × (R1+R2)/R2 的稳压

### 7 项 P0 测试套件

按 `standard-tests` chapter 跑：
- LDO-T1a/b/c: DC OP 三点（含 @0mA 验证 R-divider 提供 Ibleed）
- LDO-T2: AC Loop Gain log-spaced Iload sweep
- LDO-T3: Line Reg ±10% Vin
- LDO-T4: Load Reg 0→Imax
- LDO-T5: Tran load step 多 slew rate
- LDO-T6: PSRR 多频点

每个 testbench 共用上面 5-ports X1 实例，仅改变 Iload, Vvdd, Vref 等外部条件。

---

## When to use this knowledge

- 写新 LDO 之前**必读**（按 spec 选拓扑 + 复用 reference cir）
- 调试 LDO 拓扑级问题（loop polarity 错、Iq 超 spec、@0mA 漂等）
- 评估 LDO 拓扑选型决策

## When NOT to load

- 已选定拓扑且只调具体某项细节 → 用对应 chapter（`psrr` / `overshoot` / `ac-stability`）
- 不是 LDO（开关电源、bandgap、charge-pump）

## Related

- **`architecture`** — LDO 架构选择决策详细推导
- **`standard-tests`** — P0/P1 测试套件 + testbench 配置约定 + 4 条设计规则
- **`ac-stability`** — AC PM/GBW 详细分析、补偿原理（Miller / Ahuja）
- **`psrr`** — PSRR 频段特性 + 物理根因
- **`overshoot`** — 负载瞬态分析 + EA slew rate
- **`troubleshooting`** — debug 5 类症状对照
- **Skill `device_sizing`** — pass FET / EA input pair / mirror sizing 推导
- **Skill `ac_feedback_loop_method`** — Method C 断环法

## 不在本章范围

- 详细拓扑选型决策推导 → `architecture`
- 测试套件实施 → `standard-tests`
- AC 稳定性公式与详细补偿设计 → `ac-stability`
- ngspice 语法 → `simulators/ngspice/*`
- 通用 sizing methodology → skill `device_sizing`

---

## 历史教训（v3 PACK 重写动机）

旧 reference-design.md（v2 之前）建立在错电路上：
- 旧 `ldo.cir` EA 第二级 M7 gate=vea_left 共享 stage-1 mirror，违反"2nd stage current source 应固定"原则
- 旧 cir 缺最小负载支路（@0mA Vout 漂到 Vdd）
- 旧 cir 把 R1/R2 divider 写在 testbench（违反 Iron Law 1）

v3 重写后：
- 拓扑分 4 种（A/B/C/D），按 spec 各自有 reference cir
- 每个 cir 都把 R1+R2 放进 subckt + 移除独立 M_bleed
- 每个 cir 都贯彻 mirror 原则（W=W_bias L=L_bias 只 m 变）
- 每个 cir EA polarity 都重新推导（含 KCL 分析），写在 cir 顶部注释

## 下一步 Required Action

> ⭐ **Step 0 必须先做（v6 + Demo 04 双重教训）**：
> - 跳过 Step 0 直接进 Step 1 = Demo 01 v6 浪费 50+ turn 追逐拓扑外 spec 的根因
> - 只敲定 L1 大类没下钻 L2 输入极性 = Demo 04 浪费 15+ turn（vpdk55nm Vref=0.9V > PMOS ceiling 0.75V，AC 全垮调参救不了）
>
> 方法论入口：L1 skill `architecture_decomposition`（架构层级化决策 IRON LAW）

### Step 0 — Spec 可行性 + 架构层级化 self-check（必做，~5 分钟）

#### Step 0.1 — Spec → 拓扑大类（L1）

把当前 spec 与 `index.md` § Spec Ceiling Table 逐项对账：

```
[ ] PSRR @ DC 目标 = ? dB → 落在 [5T 35 / cascode 60 / 双级 70 / 双级+cascode 80 / post-LDO >80] 哪一档？
[ ] PSRR @ 1MHz 目标 = ? dB → 双级 ≤ 40 dB / 多级 ≤ 60 dB；若 > 50 dB 必须 active filter / 大 Cload
[ ] PM at 0-Iload_max + corner 全 ≥ 45° → 必选 B 拓扑（PMOS-input + SF + Miller）
[ ] dropout @ Iload_max = ? mV → PMOS-pass < 200mV 可达；< 50mV @ 100mA 必 NMOS-pass + boost
[ ] Iq budget = ? µA → 双级 EA 20-50µA 典型
```

#### Step 0.2 — EA 输入对极性 self-check（L2 IRON LAW，**不能跳**）⭐

```
[ ] PDK constants（查 PDK reference）：
    - VDD = ? V
    - |Vth_p| = ? V
    - Vth_n = ? V
[ ] PMOS-input pair Vref ceiling = VDD − |Vth_p| − 0.1 = ? V
[ ] NMOS-input pair Vref floor   = Vth_n + 0.1                 = ? V
[ ] Vref / Vfb = ? V，对照 ceiling 与 floor：
    - Vref < floor                  → PMOS pair（floor 违是 NMOS pair 的不行）
    - Vref > ceiling                → NMOS pair（ceiling 违是 PMOS pair 的不行）
    - floor < Vref < ceiling 健康   → 双向都 OK，按 noise / 1/f 取舍（PMOS 噪声低）
    - 同时违（Vref > ceiling 且 Vref < floor）→ 必选 FC EA
[ ] 选定的 EA 输入对极性 = ?，写明理由（数值代入 + 决策结果）
```

**典型陷阱（必避）**：
- vpdk55nm Vref=0.9V → PMOS ceiling=0.75V 违 → **不能用 PMOS pair**（Demo 04 实证：M1/M2 sub-threshold，gm ×1/83，AC 全垮）
- vpdk180nm Vref=0.6V → NMOS floor=0.50V 边缘 → 不建议 NMOS pair（tail headroom 紧）

详见 `architecture.md` § "EA 输入对极性 — IRON LAW" + `base-cells/differential-pair/cm-range`。

#### Step 0.3 — 结论

```
- 选 Topology = ?（A / B / C）（必须显式宣告）
- 选 EA 拓扑 = ?（5T / cascode / 双级 / 双级+cascode）
- 选 EA 输入对极性 = ?（NMOS / PMOS / FC EA）
- 数值代入证据 = ?
```

**任一项超 ceiling**：
- 不能靠 trim/sizing 救 → 必须升级拓扑（按 `index.md` § Spec → 必选拓扑路径）
- 或 declare hypothesis：「我假设 spec PSRR=80dB 可改为 70dB，理由是 ...」（用 `hypothesis_declare` tool）
- **禁止**：跳过 Step 0 直接 Step 1 / 在拓扑上限外 sizing / 漏 L2 EA 输入对极性 self-check

### Step 1 — 抄 reference cir 拓扑

按 Step 0 决策树选拓扑后用 `load_knowledge(name='ldo', asset=...)` 拿对应 reference cir（抄拓扑：EA 连接 / pass FET / divider R 网络，不复制数值）：
- Topology A: `reference_designs/ldo_5t_pmos_cs.cir`
- Topology B: `reference_designs/ldo_5t_pmos_in_sf.cir`
- Topology C: `reference_designs/ldo_fc_buffer.cir`

### Step 2 — 推导 W/L/m（R0 铁律）

按 `architecture.md` § Pass FET sizing 反推 + `ac-stability.md` § 补偿策略：
- R1/R2 divider 按 Vout/Vref 目标重推
- Pass FET W 按 dropout @ Iload_max 反推（典型 W=2000-3000µm @ 100mA + 200mV）
- EA 各 device sizing 按 Step 0 declared loop gain 目标重推
- **不可复制参考数值**

### Step 3 — 写网表

`write_file` → `design/ldo_<topology>.cir` + `design/sizing.yaml`

### Step 4 — 仿真验证

`simulate` `testbench/tb_dc_op.sp` → 验证 Vout 稳压 / Iq in spec

**然后**必须连续验：
- DC OP 多负载点（**含 Iload=0mA**，按 standard-tests § DC OP）
- AC log-spaced sweep（PM 全 Iload）
- PSRR @ DC/1k/100k/1MHz（vs Step 0 declared 拓扑上限对账）
- Tran load step（undershoot）
- Line/Load reg

### 改 PSRR / 改 Cload / 加补偿前必须读

**改 PSRR 路径** → `psrr.md` 全章 + Spec Ceiling Table（各 EA 上限）
**改 Cload / ESR** → `ac-stability.md` § ESR + Cload trade-off
**改电容 / 加 Miller / Cload** → 电容尺寸约束见 `blocks/bandgap/physical-constraints.md` § 1（横切，> 50pF 片内不可行）
