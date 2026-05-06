---
chapter: architecture
parent: bandgap
summary: |
  4 拓扑变体对比（PNP first-order Brokaw / CMOS sub-1V Banba/DRO /
  curvature-corrected / chopper-stabilized）+ zero-TC 条件 R2/R1 ≈ 12 for N=8
  因果推导 + 7 sizing pitfalls（PMOS mirror L / R2/R1 比例 / R2a-R2b matching /
  OTA polarity / OTA oversize / 外环 compensation / OTA input pair 共模）。
  startup 相关 pitfall 见 chapter=startup。物理推导（β-multiplier 双稳态）
  见 base-cell。
tokens: ~1700
prerequisite_chapters: []
related_skills:
  - architecture_decomposition
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/bias-generator
  - blocks/base-cells/differential-pair
  - blocks/base-cells/differential-pair/cm-range
  - blocks/base-cells/current-mirror
  - blocks/5t-ota
---

# Bandgap 架构

## 拓扑选择两轴

Bandgap 拓扑由两个**独立**决策组合：

| 轴 | 选项 | 关键决策依据 |
|---|---|---|
| 温度参考源 | BJT (vertical PNP/NPN) / CMOS-only (Vth-based) | 工艺是否提供低成本 BJT；Vref 目标值（≈1.2V vs <1V）|
| 补偿阶数 | first-order / curvature-corrected / chopper | TC budget（80 / 20 / 5 ppm/°C）|

**典型组合**：

| 组合 | 落地拓扑 | 应用 |
|---|---|---|
| BJT + first-order | **PNP Brokaw**（默认）| 教学 + 工业主流 LDO/PMIC/ADC reference |
| CMOS + first-order | **Banba / DRO**（sub-1V）| VDD < 1.6V 或工艺无低成本 BJT |
| BJT + second-order | **Curvature-corrected** | 高精度 ADC（< 20 ppm/°C） |
| BJT + chopper | **Chopper-stabilized** | 低噪 / < 10 ppm/°C / DC offset 校准 |

## 4 拓扑变体对比

| 拓扑 | Vref @ 27°C | VDD min | TC | PSRR @ DC | Iq | PNP 依赖 | 复杂度 |
|---|---|---|---|---|---|---|---|
| **PNP Brokaw**（first-order）| 1.19 V | 1.5 V | 30–80 ppm/°C（需 resistor TC / curvature 受控）| 35–45 dB（V3 non-cascoded）/ 60–70+ dB（cascoded variant）| 25–40 µA | ✅ vertical PNP | 中 |
| **CMOS Banba/DRO**（sub-1V）| 0.6 – 0.8 V | 1.0 V | 50–150 ppm/°C | 40–60 dB | 5–30 µA | ❌ | 中 |
| **Curvature-corrected** | 1.20 V | 1.8 V | < 20 ppm/°C | 60–70 dB | 30–60 µA | ✅ | 高（二阶电路 + trim）|
| **Chopper-stabilized** | 1.20 V | 1.8 V | < 10 ppm/°C | 70–80 dB | 50–100 µA | ✅ | 高（chopper 时钟 + 滤波）|

> **物理推导出处**：β-multiplier 双稳态 / startup-helper 拓扑物理推导见 `blocks/base-cells/bias-generator/{beta-multiplier, startup-helper}`。本表是应用层数值范围摘要，不重复推导。

## zero-TC 条件（PNP first-order 核心因果）

本 reference netlist 的输出由 mirrored current 生成：

```
Vref(T) = R_OUT · [Vbe(T)/R2 + ln(N)·VT(T)/R1]
```

若 `R_OUT` 的 TC 可忽略，zero-TC 比例与经典 Brokaw `Vbe + K·ΔVbe` 等效：

```
Vbe TC ≈ -2 mV/°C        (CTAT，Vbe 随温度下降)
ΔVbe TC = ln(N)·k/q ≈ 2.079 × 86.17 µV/°C
                    ≈ +179 µV/°C @ N=8  (PTAT，VT 随温度上升)

zero-TC 条件:  ∂Vref/∂T = 0
            ⇒  (1/R2)·∂Vbe/∂T + (1/R1)·ln(N)·k/q = 0
            ⇒  R2/R1 = |∂Vbe/∂T| / (ln(N)·k/q)
                     ≈ 2 mV/°C / 179 µV/°C
                     ≈ 11.2  (工程起点取 12) for N=8
```

**结果**：N=8 时 R2/R1 ≈ 11.2–12。N=4 → R2/R1 ≈ 16.8；N=16 → R2/R1 ≈ 8.4。

**实战提示**：先选 N（受 area 约束），再选 R1（受 I_PTAT 约束 = VT·ln(N)/I_PTAT），最后按 zero-TC 比例选 R2。Vref 中心由 R_OUT × (I_PTAT + I_CTAT) 调。27°C 通常是 nominal trim point，不是物理必然——Vbe slope / resistor TC / PNP curvature 会移动零斜率温度，**必须用 tb_tc_sweep 验证**。

## 拓扑选择决策（按 spec 反推）

| Spec 关键字 | 推荐拓扑 |
|---|---|
| VDD ≥ 1.8V / TC 30–80 ppm/°C / 工艺有 PNP | **PNP Brokaw** |
| VDD = 1.0–1.6V / Vref 0.6–0.8V OK | **CMOS Banba/DRO** |
| TC < 20 ppm/°C / VDD ≥ 1.8V | **Curvature-corrected**（first-order 不够）|
| TC < 10 ppm/°C / 高精度 ADC | **Chopper-stabilized** |
| VDD < 1.0V | charge-pump sub-bandgap（超本章范围）|
| 工艺无 BJT 且 VDD ≥ 1.8V / Vref 必须 ≈ 1.2V | Vth-based first-order CMOS（精度有限，typical TC 100+ ppm/°C）|

**Iron Law**：选错家族（如用 first-order 追 < 20 ppm/°C） = TC 差 4×，sizing 救不回——必须 challenge 拓扑（[L0 Iron Law 6](../../../src/agent_engine/prompt_compiler.py#_IRON_LAWS_DEFAULT)）。

## ⚠️ Common sizing pitfalls

> 这一节是 PNP first-order Brokaw bandgap 的 sizing 决策避坑提示。完整 closed-form 4-step recipe（I_PTAT → R1 → R2 → R_OUT → mirror）见 `chapter=reference-design` § Sizing 起点。startup 相关 pitfall（W_KICK / R_START）见 `chapter=startup`。

### Pitfall 1: PMOS mirror L < 1 µm → ro 不够 → PSRR / Vref 漂

**症状**：PSRR @ DC < 50 dB；VDD 从 1.5→1.9V 扫描时 Vref 漂 > 5 mV/V

**因果**：bandgap loop gain 由 OTA gain × mirror ro 决定。3-leg PMOS mirror 是 V_DD ripple 的主路径：`PSRR ≈ 1 + gm_OTA · ro_MP · (...)`。L_MP=0.18 µm（Lmin）时 ro ≈ 30 kΩ；L_MP=1 µm 时 ro ≈ 200 kΩ → 6× 改善。

**修复**：MP1/MP2/MP3 全部 L ≥ 1 µm（vpdk180nm，Lmin × 5–6）。PSRR > 70 dB 需求 → 升级到 cascoded mirror（变体，超出 first-order 默认）。

### Pitfall 2: R2/R1 比例不在 zero-TC 点 → TC 漂大

**症状**：tb_tc_sweep 三点 (−40 / 27 / 125 °C) 输出 TC > 100 ppm/°C；Vref 单调随温度升或降

**因果**：zero-TC 条件 R2/R1 ≈ 12 for N=8（见 § zero-TC 条件）。比例偏 ±20% 已让 TC 漂 50+ ppm/°C。**这是 bandgap 设计的核心 zero-TC 平衡点**，不是 random sizing。

**修复**：先固定 N（默认 8），按 `R2/R1 = |∂Vbe/∂T| / (ln(N)·k/q)` 算比例（N=8 → 11.2–12，N=16 → 8.4）；R1 由 I_PTAT 约束确定后，R2 用比例反推。tb_tc_sweep 验证 TC 形状与零斜率温度；27°C 只是 nominal trim point，不是物理必然。

### Pitfall 3: R2a / R2b mismatch → CTAT 两路不平衡 → na ≠ nb

**症状**：DC op 中 `|V(na) − V(nb)| > 1 mV`（OTA lock error）；Vref shifted 但不知所以然

**因果**：bandgap 双 CTAT 支路（na 和 nb branch）必须严格匹配——R2a (na branch) 与 R2b (nb branch) 阻值差 1% 让 CTAT 电流差 1%，na/nb 漂移 ≈ I_CTAT × ΔR ≈ µA × kΩ → mV 级。

**修复**：R2a / R2b 用同一段 layout（common-centroid 或 interdigitated 对称对）。Schematic 用同 unit cell × N 拷贝（不要写 R2a=180k / R2b=180k 两条独立 R）。

### Pitfall 4: OTA polarity 接反 → DC latch 错误分支但**不报错**

**症状**：DC op 显示 Vref ≈ 1.79V（≈ VDD），不是 1.19V；或 Vref = 0V startup 失败但 DC op "成功"。**关键**：`.op` 不报错，只能看 Vref 绝对值

**因果**：bandgap 是闭环正反馈拓扑——OTA 强制 V(na) = V(nb)，正负输入接错 → loop 反向 → DC latch 到错误的稳态分支（Vref=VDD 或 Vref=0）。Razavi 单级 5-T OTA 用 `vp=nb / vn=na`；2-stage OTA（5T 非反相 + NMOS-CS 反相）整体反相 → 必须用 `vp=na / vn=nb`。

**V3 实战教训**（commit efb0fa3）：抄 Razavi 单级 5-T 写法到 2-stage OTA bandgap，DC latch 到 Vref=1.79V，没报错只能看 FOM 才发现。

**修复**：写 OTA 接 bandgap 前画小信号 loop sign。对 V3 2-stage PMOS-input OTA：

```
na ↑ (vp ↑) → 5T first stage d2 ↑ (非反相)
            → NMOS-CS stage yg ↓ (反相)
            → PMOS mirror current ↑
            → nb branch (含 R1，等效电阻更高) 上升快于 na
            → (na − nb) 被拉回 → 负反馈关环
```

→ 2-stage 用 `vp=na / vn=nb`。Razavi 单级 5T 没有 NMOS-CS 第二级，整体非反相，bandgap 连接相反：`vp=nb / vn=na`。**bandgap review 第一步**：DC op Vref 接近 rail（如 1.79V）是 polarity / rail-latch 强嫌疑——但仍需同时检查 startup helper 与 `na − nb` lock error 才能定论。

### Pitfall 5: OTA oversize → Iq 过预算

**症状**：Iq 测得 300+ µA（典型 bandgap 应 25–40 µA），主要源于 OTA 过大

**因果**：bandgap loop 内 OTA **要 gain 不要 BW**——闭环带宽由 mirror parasitics 限制（kHz 级），OTA 不需要 BW 大。但 LLM 常抄宽带 amp 模板（`W=20u/L=0.5u` typical for high-BW OTA）→ Itail 200+ µA。

**V3 实战教训**（efb0fa3）：抄宽带 amp 模板让 OTA Iq=378 µA（12× 预算）；改 `W=4u/L=4u` 后 Iq 降到 10 µA。

**修复**：bandgap OTA 用 small-W long-L（典型 `W=4 µm / L=4 µm` for 5T input pair）。`gm/Id ≈ 15–20`、`Itail ≈ 5–10 µA` 起步。BW 100 kHz 已够。

### Pitfall 6: 外环 oscillation（多极点缺 compensation）

**症状**：tb_startup tran 后 Vref 持续振荡（mid-MHz 频率，不收敛）；或 PSRR 在 1 MHz 附近有 peaking

**因果**：bandgap loop 至少有两个高阻 / 大电容候选节点：(a) `yg` 节点（OTA 输出阻抗 × PMOS mirror gate capacitance）/ (b) core sense nodes `na/nb/ny`（R2/R1 × PNP diffusion / junction capacitance）/ 另有 `vref` load pole。哪两个成为慢极点取决于 OTA sizing、PNP model 和 load。

**V3 实战教训**（efb0fa3）：2-stage OTA + mirror + core 出现 ringing → 加 OTA 内 Miller (Cm=3 pF + Rz=20 kΩ) + yg 上 2 pF cap 后稳定。

**修复**：OTA 内加 Miller 补偿（Cm 跨 stage2；**Rz 约等于第二级 `M_OUT` 的 `1/gm`**，用于 null / move RHP zero）+ 视 mirror 极点位置给 yg 节点加小 Ccomp（1–5 pF）。具体值必须用 loop AC / tb_startup tran 验证，**不能只复制 3pF/20k/2pF**。

### Pitfall 7: NMOS-input OTA 在 Vbe ≈ 0.65V 共模没 headroom

**症状**：DC op 中 OTA 输入对 region 显示 triode 或 cutoff；na/nb 不锁；或 Vref latch 到错误分支

**因果**：PNP bandgap 中 na/nb ≈ Vbe ≈ 0.65V。NMOS-input diff pair 的 tail 节点为
`Vtail = Vcm − Vgs_diff ≈ 0.65 − (Vth_n + Vov_diff)`。在 vpdk180nm 若 `Vth_n ≈ 0.45–0.50V`、`Vov_diff ≈ 0.12–0.18V`，则 `Vtail ≈ 0–80 mV`，通常小于 `Vdsat_tail ≈ 0.15–0.25V`，**tail 进入 triode**。这个 headroom 限制来自**低输入共模**，不是来自 1.8V VDD 顶端余量。

**修复**：PNP first-order bandgap 默认用 **PMOS-input OTA**（na/nb 0.65V 距 VDD=1.8V 有 1.15V，PMOS tail Vds_sat 充裕）。如果工艺要求用 NMOS input，必须升级到 sub-1V 拓扑或抬升 OTA 输入共模（折叠 cascode + level-shifter）。

**跨 PDK 注意**：上述数据是 vpdk180nm instance（VDD=1.8V，\|Vth_p\|=0.45V，PMOS ceiling=1.25V，远 > 0.65V 有 60cm 余量）。跨 PDK（vpdk55nm VDD=1.2V, ceiling=0.75V → 0.65V 已紧）/ vpdk7nm（VDD=0.8V, ceiling=0.45V → 0.65V 违 ceiling）必须**用实测 \|Vth_p\| / VDD 重算 PMOS ceiling**。详见横切章 `blocks/base-cells/differential-pair/cm-range`。

## 验证清单（架构选好后）

- [ ] 拓扑与 spec 匹配（VDD / TC budget / PNP 可用性，参考 § 拓扑选择决策表）
- [ ] zero-TC 条件 R2/R1 比例符合 N（避 Pitfall 2）
- [ ] PMOS mirror L ≥ 1 µm（避 Pitfall 1）
- [ ] R2a / R2b 用 common-centroid layout（避 Pitfall 3）
- [ ] OTA polarity 按级数定（vp = na 还是 vp = nb；避 Pitfall 4）
- [ ] OTA sizing small-W long-L（W/L ≈ 4/4 µm，避 Pitfall 5）
- [ ] OTA 内 Miller + Rz nulling（避 Pitfall 6）
- [ ] PMOS-input OTA（避 Pitfall 7）
- [ ] 加载 `chapter=reference-design` 复制 standard cir / tb 起步
- [ ] 加载 `chapter=startup` 验 startup 行为 + tb_startup .ic/uic

## 常见架构误区

| 心里想 | 现实 |
|---|---|
| "bandgap 就是 PTAT - CTAT 比例对了就行" | zero-TC 在 27°C 处条件是 ∂Vref/∂T=0，不是 Vref 绝对值；TC 形状是 parabolic |
| "DC op 显示 Vref ≈ 1.2V 就 OK" | DC op 不报 polarity 错；可能 latch 到错误分支或缺 startup（Pitfall 4 + chapter=startup） |
| "OTA gain 越大越好" | bandgap OTA 过大 → Iq 过预算（Pitfall 5）；30–40 dB gain 已足够锁 na = nb |
| "NMOS-input OTA 普适" | bandgap 中 na/nb=0.65V，NMOS tail 没 headroom → 必须 PMOS-input（Pitfall 7）|
| "first-order 加 trim 能达 < 20 ppm/°C" | first-order 物理上限 30 ppm/°C 左右；< 20 ppm/°C 必须 curvature 二阶补偿 |
| "PSRR 不够就加 cap" | PSRR 主要由 mirror ro × OTA gain 决定；cap 只改频率特性不改 DC（Pitfall 1）|
| "R2a / R2b 写 180k 就匹配" | schematic 等值 ≠ 实际 matching；layout 必须 common-centroid（Pitfall 3）|

## 不在本章范围

- **PNP first-order Brokaw 标准 cir / 4 testbench / sizing 起点** → `chapter=reference-design`
- **startup 行为 + helper sizing + .ic/uic + 5 类 startup-related failure modes** → `chapter=startup`
- **β-multiplier 双稳态物理推导** → `blocks/base-cells/bias-generator/beta-multiplier`
- **startup-helper 拓扑物理（M_kick / detector / 自禁用机制）** → `blocks/base-cells/bias-generator/startup-helper`
- **5T-OTA 详细 sizing**（diff pair / mirror / tail）→ `blocks/5t-ota`
- **cascoded PMOS mirror 详细电路**（PSRR > 70 dB variant）→ `blocks/base-cells/cascode` + `blocks/base-cells/current-mirror` § cascoded
- **CMOS Banba / DRO sub-1V 详细电路实现** → 不在本 first-order knowledge 范围（标顶层选型决策即可）
- **chopper-stabilized / curvature-corrected 详细补偿电路** → 高精度 reference 专门 knowledge
