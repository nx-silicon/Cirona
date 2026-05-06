---
chapter: reference-design
parent: comparator
summary: |
  Production-grade StrongARM comparator reference (9-MOSFET, PMOS-regen
  + NMOS input pair + clocked tail) + standard cir/tb 路径 + sizing 起点
  + clock 时序约束 + regen 时序 / kickback / metastability 验证清单。
  Iron Law: 写 comparator 必先复用 reference cir，不要从零造拓扑（StrongARM
  9 设备 connectivity 多个 trap 点，从零写易接错）。
tokens: ~900
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/comparator-latch
  - blocks/base-cells/differential-pair
  - blocks/base-cells/switch
  - simulators/ngspice
  - pdks/vpdk180nm
---

# StrongARM Comparator Reference Design

## Iron Law

**Reference design 优先**：写 StrongARM comparator 时**必须**先复用本章 § Core topology 的 inline `.subckt`（9 MOSFET self-contained）。当前 comparator 包还没有 `assets/reference_designs/` 资产，本章 inline subckt 即 canonical reference；后续若补 asset 文件，可通过 `load_knowledge(name='comparator', asset='reference_designs/<file>')` 拿到，并应与本章 subckt 逐行一致。**从零造 StrongARM 几乎必踩 connectivity trap**（9 设备分 5 组：reset PMOS / cross-coupled regen / discharge bridge / input pair / tail switch；任一组 source/drain 接错就锁死或单边放电）。

**物理推导出处**：StrongARM 三相工作流（reset / evaluate / regen）+ offset σ / τ_reg / metastability / kickback 公式见 `blocks/base-cells/comparator-latch/strongarm.md`（W3 已有完整推导，本章不重复）。

## Quick reference

```
Canonical subckt       : 本章 § Core topology（inline, 9 MOSFET）
DC OP testbench        : 本章 § tb_dc_op.sp 模板
Tran 时序 testbench    : 本章 § tb_tran_clock.sp 模板
Metastability MC tb    : blocks/base-cells/comparator-latch/strongarm § Metastability
Kickback testbench     : blocks/base-cells/comparator-latch/strongarm § Kickback Noise
```

> 后续可往 comparator 包下补 `assets/reference_designs/` 文件，让 `load_knowledge(name='comparator', asset='reference_designs/<file>')` 直接复用；当前阶段 agent 应直接复制本章 inline subckt + tb 模板为起点。

## Standard subckt port order

```spice
.subckt strongarm_comparator vinp vinn voutp voutn clk vdd vss
```

> ⚠️ `clk` 是单相 input；本 subckt 没有独立 `phi_pre / phi_eval` 端口，因此 non-overlap 概念不直接适用——CK=0 reset / CK=VDD evaluate 物理互斥。外部 clock generator 只控制 edge-rate / duty / jitter。`voutp / voutn` 在 reset phase（CK=0）pre-充到 VDD；在 evaluate 末段 regen 后 rail-to-rail。若系统需要显式 non-overlap，应包一层 two-phase wrapper 或使用 two-phase variant。

## Core topology — 9-MOSFET StrongARM (PMOS regen + NMOS input pair)

ASCII 拓扑见 `blocks/base-cells/comparator-latch/strongarm.md` § 拓扑（三相工作流）。本章给完整 .subckt 网表骨架：

```spice
.subckt strongarm_comparator vinp vinn voutp voutn clk vdd vss

* Group 1: Reset PMOS (CK=0 precharge voutp/voutn → VDD)
M_RP  voutp  clk  vdd  vdd  pch  W=4u   L=0.18u  m=1
M_RN  voutn  clk  vdd  vdd  pch  W=4u   L=0.18u  m=1

* Group 2: Cross-coupled regen pair (PMOS, positive feedback)
M_LP  voutp  voutn  vdd  vdd  pch  W=4u  L=0.18u  m=1
M_LN  voutn  voutp  vdd  vdd  pch  W=4u  L=0.18u  m=1

* Group 3: Discharge bridge (NMOS, CK=1 connect voutp/voutn ↔ sp/sn)
M_DP  voutp  clk  sp  vss  nch  W=4u  L=0.18u  m=1
M_DN  voutn  clk  sn  vss  nch  W=4u  L=0.18u  m=1

* Group 4: NMOS input pair (offset / aperture-defining)
M_INP  sp  vinp  tail  vss  nch  W=4u  L=0.36u  m=1
M_INN  sn  vinn  tail  vss  nch  W=4u  L=0.36u  m=1

* Group 5: Tail switch (NMOS, CK=1 enable evaluate current)
M_TAIL  tail  clk  vss  vss  nch  W=8u  L=0.18u  m=1

.ends strongarm_comparator
```

**关键 connectivity rules**（违反必锁死或单边放电）：

| Group | Device | gate 接 | drain 接 | source 接 | 关键正确性 |
|---|---|---|---|---|---|
| 1 Reset | M_RP / M_RN | clk | voutp / voutn | vdd | CK=0 → Vgs=-VDD < Vtp ⇒ ON ⇒ precharge VDD；CK=VDD ⇒ OFF |
| 2 Regen | M_LP | **voutn**（cross）| **voutp** | vdd | cross-coupled — gate 接对侧 drain；接同侧 = diode 没正反馈 |
| 2 Regen | M_LN | **voutp**（cross）| **voutn** | vdd | 同上 |
| 3 Bridge | M_DP / M_DN | clk | voutp / voutn | **sp / sn**（内部 fly-node）| ⚠️ S/D 不要反——drain 必须在高电压侧（voutp 在 reset 后 VDD），source 在 sp（evaluate 中放电中节点）|
| 4 Input | M_INP / M_INN | vinp / vinn | sp / sn | **tail**（共 source）| 共 source 接 tail；drain 接 sp/sn 内部节点（不是 voutp/voutn 直接）|
| 5 Tail | M_TAIL | clk | tail | vss | NMOS source 接 vss；drain 接 tail（input pair 共 source 节点）|

> **常见错（实战 trap）**：把 M_DP/M_DN（discharge bridge）的 source 直接接 vss 而非 sp/sn——结果输入差分被旁路、永远 voutp=voutn 同步放电、无 regen。**bridge 的 source 必须接 sp/sn，让 input pair 的 drain 通过 bridge 与 voutp/voutn 串联**。

## Clock generation（single-clock reference）

StrongARM 单相 clk 输入要求外部 clock generator 满足：

```
edge rate (90% of swing rise/fall):  ≤ 30 ps         避 Pitfall 2 (architecture.md，jitter 主导 SNR)
                                                     同时压缩 Pitfall 7 short-through 边沿窗口
duty cycle:                            evaluate phase ≥ 20× τ_reg @ 1e-9 metastability target
```

**two-phase wrapper 场景**（不属于本 single-clock subckt 的 port order）：若上层 ADC FSM 要求显式 phi_pre / phi_eval non-overlap，需另起 two-phase variant subckt（端口 `... phi_pre phi_eval ...`），由 wrapper 的 clock generator 保 ≥ 100 ps non-overlap。本 single-clock reference 不直接适用。

## Sizing 起点 (vpdk180nm, fclk ≤ 500 MHz, 10-bit ADC σ_OS ≤ 10 mV)

| 设备 | role | W | L | m | 备注 |
|---|---|---|---|---|---|
| `M_INP` / `M_INN` | NMOS input pair | 4 µm | 0.36 µm | 1 | **L = 2× Lmin** 减 Pelgrom σ_Vth；σ_OS 主要源 |
| `M_TAIL` | NMOS tail switch | 8 µm | 0.18 µm | 1 | rail-driven switch；看 `R_on` / `V(tail)` / 放电斜率（避 Pitfall 4），不是 current-source Vov |
| `M_DP` / `M_DN` | NMOS bridge | 4 µm | 0.18 µm | 1 | 短沟道速度优先 |
| `M_RP` / `M_RN` | PMOS reset | 4 µm | 0.18 µm | 1 | 充 voutp/voutn 到 VDD 速度 |
| `M_LP` / `M_LN` | PMOS regen | 4 µm | 0.18 µm | 1 | regen W·L 0.5–1 µm² 范围（避 Pitfall 3）|

**详细 sizing 范例**（含 σ_OS / τ_reg / T_decide 数值反推）见 `blocks/base-cells/comparator-latch/strongarm.md` § sizing 范例（10-bit / 100 MSPS SAR ADC，W=10µ/L=1µ input pair，σ_OS ≈ 5–8 mV，τ_reg ≈ 60 ps，T_evaluate 600 ps–1.2 ns）。本表起点 W=4µ/L=0.36µ 是更紧凑版本（适合面积敏感场合）。

## Standard testbench 关键内容

### `tb_dc_op.sp`（DC OP，CK 静态 high / low 验 region）

```spice
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include '../design/strongarm_comparator.cir'
.param VCM = 0.9
.param VDIFF = 1m
Vdd  vdd  0  DC 1.8
Vinp vinp 0  DC 'VCM + VDIFF/2'
Vinn vinn 0  DC 'VCM - VDIFF/2'
Vclk clk  0  DC 1.8     $ static evaluate phase 看 region
* port: vinp vinn voutp voutn clk vdd vss
X1 vinp vinn voutp voutn clk vdd 0 strongarm_comparator
.op
.control
  set units = degrees
  run
.endc
.end
```

→ 用 `dc_snapshot` 看 CK=high 静态 evaluate bias 下的 `V(tail)`、M_INP / M_INN region（避 Pitfall 4）；本单 tail switch 不用 current-source saturation margin 判定。`sp / sn` 放电斜率必须在 tran 中测量（见下方 `tb_tran_clock.sp`）。

### `tb_tran_clock.sp`（Tran 时序：reset → evaluate → regen）

```spice
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include '../design/strongarm_comparator.cir'
.param VCM = 0.9
.param VDIFF = 5m
Vdd  vdd  0  DC 1.8
Vinp vinp 0  DC 'VCM + VDIFF/2'
Vinn vinn 0  DC 'VCM - VDIFF/2'
* Single-phase clock, 500 MHz, 30 ps edges
Vclk clk 0 PULSE(0 1.8  5n  30p  30p  1n  2n)
X1 vinp vinn voutp voutn clk vdd 0 strongarm_comparator
.tran 1p 20n
.control
  set units = degrees
  run
  meas tran t_decide TRIG v(clk) VAL=0.9 RISE=1
+                     TARG v(voutp) VAL=1.6 RISE=1
  meas tran v_diff_final FIND v(voutp)-v(voutn) AT=15n
.endc
.end
```

### `tb_metastab_mc.sp`（MC σ_OS + metastability 错误率）

详细 MC sweep 设置见 `blocks/base-cells/comparator-latch/strongarm.md` § Metastability。基本流程：input slow ramp + clock 周期采样 + 统计输出方向是否正确 → 错误率 = 错误次数 / 总次数。

## 已知设计陷阱（V3 archived StrongARM 实战 + W3 base-cell 教训）

| 陷阱 | 表现 | 修复 |
|---|---|---|
| **Bridge S/D 接反**（M_DP source 接 vss）| evaluate 阶段 voutp/voutn 同步放电，无差分 regen | M_DP source = sp（fly-node）；drain = voutp |
| **Cross-coupled regen 接错**（M_LP gate 接 voutp 自身）| 变 diode-connected，无正反馈 | M_LP gate = voutn（对侧 drain）|
| **Tail switch 太弱**（W 太小 / clock 慢） | `V(tail)` 抬高、`sp/sn` 放电慢 → 初始差分小 / metastability 概率上升 | 增大 tail W（本 reference 起点 8µ）+ 改善 clock edge；检查 `V(tail)` 与 input pair region |
| **clock 边沿 100 ps+** | aperture jitter > 1 ps，ADC SNDR 受限；同时 CK 边沿期 reset PMOS 与 tail NMOS 同时导通的 short-through 窗口宽 | clock buffer 链最末级 W 大；测 dCK/dt ≥ 60 V/ns @ 1.8V |
| **误把 single-clock 与 two-phase non-overlap 混淆** | 在 single-clock subckt 上要求 100 ps non-overlap，testbench 注入失败 | single-clock 只控 edge-rate；要 non-overlap 必须 two-phase variant subckt |
| **Input pair L=Lmin** | σ_Vth 大、σ_OS 不达标 | L = 2× Lmin（W=4µ/L=0.36µ 起步）|
| **MC sweep 没 cover 全 input range** | metastability 错误率漏估 | input slow ramp 覆盖 ±3σ_OS 区间 + 统计方向错误 |
| **kickback 测得大但找不到源** | preamp 不存在 / Cgd 反耦合 | 加 preamp（架构升级）；或加 small-cap 隔离（架构 trade-off）|

## When to use this reference

- 任何 StrongARM 风格 clocked dynamic comparator 设计
- ADC 主比较器（SAR / pipeline / flash 都可起步用本 reference）
- SerDes RX slicer
- 与 preamp 串联做高精度 comparator（preamp 在前，本 reference 当 latch 后端）

## When NOT to use

- Continuous-time / hysteresis comparator（不同家族 → 见 `chapter=architecture` § continuous-time）
- preamp 内部增益级（preamp 是 OTA → 见 `blocks/5t-ota` 或 `blocks/folded-cascode-ota`）
- 双相 master-slave latch（数字 flip-flop 风格）→ 数字 IC 标准库
- 极致面积优化的 dynamic comparator（无 cross-coupled regen）→ 见 `chapter=architecture` § dynamic-comparator

## 不在本章范围

- **拓扑 4 变体对比 + 选择决策树** → `chapter=architecture`
- **offset σ / τ_reg / metastability / kickback 物理推导** → `blocks/base-cells/comparator-latch/strongarm`
- **5 类故障 debug**（offset / metastability / kickback / clock race / 电源耦合）→ `blocks/base-cells/comparator-latch/troubleshooting`
- **clock generator / non-overlap circuit 详细电路** → `blocks/base-cells/switch` + clock distribution knowledge
- **Preamp + StrongARM 复合架构 sizing** → `chapter=architecture` § Pitfall 5 + `blocks/5t-ota`
- **MC sweep / metastability 完整 testbench** → `blocks/base-cells/comparator-latch/strongarm` § Metastability + `simulators/ngspice/analyses` § MC
- **完整 ADC 时序 / SAR FSM** → `systems/sar-adc`（W8+）

## 下一步 Required Action

1. 本章 § Core topology 含完整 9-MOSFET inline subckt 骨架，**就地复用**抄拓扑（device 连接 / 5 组 connectivity，不复制数值）。当前无独立 asset cir；若后续 comparator 包补 `assets/reference_designs/`，则用 `load_knowledge(name='comparator', asset='reference_designs/<file>')` 拿 asset 文件为准。
2. 推导自己 spec 的 W/L/m（R0 铁律：M_INP/M_INN input pair L ≥ 2×Lmin 满足 Pelgrom offset / M_TAIL sizing 按 V(tail) 放电需求重推，不可复制参考数值）
3. `write_file` → `design/strongarm_comparator.cir` + `design/sizing.yaml`
4. `simulate` `testbench/tb_tran_clock.sp` → 验证 voutp/voutn regen rail-to-rail / t_decide in spec
