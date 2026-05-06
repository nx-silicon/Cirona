---
chapter: architecture
parent: ldo
summary: |
  LDO 架构层级化决策（L1 instance）+ PMOS / NMOS pass 选择 + EA 拓扑 + EA 输入对
  极性 IRON LAW（NMOS floor + PMOS ceiling）+ pass FET sizing 反推。
  Iron Law: Step 0 必须做 EA 输入对极性 self-check（Vref vs PMOS ceiling /
  NMOS floor），违反 = sub-threshold 工作 = gm 损 50-100×（Demo 04 实证）。
tokens: ~900
prerequisite_chapters: []
related_skills:
  - architecture_decomposition
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/differential-pair
  - blocks/base-cells/differential-pair/cm-range
  - blocks/base-cells/cascode
---

# LDO 架构

## 架构层级化决策（L1 instance）

> **方法论入口**：见 L1 skill `architecture_decomposition`。本章是该方法论在 **LDO 电路族**上的具体 instance。Step 0 必须**逐层** self-check，**任一层违反物理约束** → 必须换该层选择 OR declare hypothesis。**严禁**只敲定 L1 大类（"PMOS-pass + 双级 EA"）就直接进 sizing。

LDO 用层级（顺序自上而下决策）：

| 层 | LDO 决策内容 | spec 物理约束 | 详见 |
|---|---|---|---|
| **L1** Pass FET 极性 + EA 拓扑 | PMOS / NMOS-pass × 5T / cascode / 双级 EA | dropout / DC loop gain | 本章 § Pass FET / EA 拓扑 |
| **L2 EA 输入对极性** ⭐ | **NMOS / PMOS / FC EA** | **Vref vs PMOS ceiling 与 NMOS floor**（vs VDD-\|Vth_p\|-Vdsat 与 Vth_n+Vdsat）| 本章 § EA 输入对极性 + `base-cells/differential-pair/cm-range` |
| **L3** EA 镜像类型 | simple / cascoded mirror | PSRR ceiling | `index.md` § Spec Ceiling Table |
| **L4** EA bias 方式 | NMOS-diode + PMOS-diode 链 / cascoded / replica | PSRR / area | 本章 § Iron Law 2 mirror |
| **L5** Pass FET sizing | W 反推 from dropout × Iload | dropout × Iload | 本章 § Pass FET sizing |
| **L6** 补偿 | Miller / Ahuja / Cload-only | PM @ all Iload | `ac-stability.md` |

**Demo 04 实证（L2 漏检的代价）**：vpdk55nm，Vref=0.9V，VDD=1.2V，agent 选 PMOS-input pair（误，没自检 ceiling）。PMOS ceiling = 1.2 − 0.35 (\|Vth_p\|) − 0.1 (Vdsat) = 0.75V。Vref 0.9V > 0.75V，违 150mV → M1/M2 sub-threshold → ID 60nA vs 设计 5µA → gm ×1/83 → PSRR 25dB vs 50dB target → AC 全垮，反复调 sizing 救不了（拓扑外冲突）。

## 拓扑两轴

LDO 拓扑选择是两个**独立**决策：

| 轴 | 选项 | 关键决策依据 |
|---|---|---|
| Pass FET 极性 | PMOS / NMOS | dropout 要求 / Iquiescent / driving capability |
| EA 拓扑 | 单级 5T / 单级 cascode / 双级（5T+CS）| DC loop gain 目标（→ PSRR / load reg） |

两个轴独立组合：PMOS-pass + 双级-EA / NMOS-pass + cascode-EA / 等等。

## Pass FET：PMOS vs NMOS

| 特性 | PMOS-pass | NMOS-pass |
|---|---|---|
| **dropout（Iload=10mA）** | **100-500 mV** | 100-500 mV（typical）但需要 Vboost > Vin |
| 控制电压 | EA 输出**降低** → pass 开 | EA 输出**升高** → pass 开 |
| Vgs 来源 | Vin-EA_out（内部） | EA_out-Vout，**需要 EA 高于 Vin** → 需 charge pump 或 boost |
| **常用场景** | 标准 LDO，不需要外置升压 | 高效 / 无 dropout 限制 / 已有内部 Vboost |
| 主极点 | 输出节点（Cload）| 同 |
| Vsg / Vgs swing | 全摆 = Vin-Vss | 受 EA 输出范围限制 |

**典型选择**：教学 / 通用集成 LDO 用 **PMOS-pass**（不需要额外 boost 电路）；高效 LDO（如 capless / SoC 内部 LDO）有时用 NMOS-pass + charge pump。

## EA 拓扑（DC loop gain 决定）

**核心因果**：LDO 的 PSRR / line regulation / load regulation 都正比 DC loop gain T₀：

- PSRR_DC ≈ T₀ + 1/β（β = 反馈分压系数）
- ΔVout/ΔVin ≈ 1/T₀（line reg）
- ΔVout/ΔIload ≈ 1/(gm_pass × T₀)（load reg）

→ **EA 必须给 50-70 dB DC gain** 才能达 LDO 典型 spec。

| EA 拓扑 | DC gain | 适用 |
|---|---|---|
| ❌ 单级 5T（教学）| **25-35 dB** | **不够 LDO**——5T 跑不到任何 gain-dependent spec（PSRR ≥ 40 dB / load reg ≤ 10 mV 等）|
| ⚠️ 单级 cascode | 50-70 dB | **足够**——常见选择 |
| ✅ 双级 5T + CS | 50-70 dB（30 + 25 dB 叠加）| **足够 + 易补偿**（Miller Cc 跨 2nd stage 自然分裂极点）|
| 折叠 cascode | 50-70 dB + 大 ICMR | 需要 rail-to-rail 输入时 |

**实战提示**：双级 EA 是 LDO 默认。单级 cascode 在面积 / 功耗紧的项目用。**5T-EA 永远不够**——如测出 DC loop gain < 40 dB 就是 EA 拓扑选错了，不是补偿能修的。

## EA 输入对极性 — IRON LAW（NMOS floor + PMOS ceiling）

> **L2 self-check（必做，写 EA 前）**：用 PDK 实测的 \|Vth_p\| / Vth_n + Vdsat_tail（典型 0.1V）数值代入下面公式，对照 Vref 位置。详细公式 + 跨 PDK 数据见 `base-cells/differential-pair/cm-range.md`。

### 双向公式

```
PMOS-input pair (tail at top)：
    Vcm_max (ceiling) = VDD − |Vth_p| − Vdsat_tail
    [若违反 → M1/M2 sub-threshold → gm 损 50-100×]

NMOS-input pair (tail at bottom)：
    Vcm_min (floor)   = Vth_n + Vdsat_tail
    [若违反 → tail M5 进 triode → DC OP 漂]
```

### 跨 PDK 数据（vpdk 系列）

| PDK | VDD | \|Vth_p\| | Vth_n | PMOS pair Vref ceiling | NMOS pair Vref floor |
|---|---|---|---|---|---|
| vpdk180nm | 1.8 V | 0.45 V | 0.40 V | **1.25 V** | 0.50 V |
| vpdk55nm  | 1.2 V | 0.35 V | 0.30 V | **0.75 V** | 0.40 V |
| vpdk7nm   | 0.8 V | 0.25 V | 0.25 V | **0.45 V** | 0.35 V |

注：Vdsat_tail 取典型 0.1V；EA load PMOS 加 Vds_load ≈ 0.1V 保守值。

### 决策规则（IRON LAW）

| Vref 位置 | 必选 EA 输入对 | 备注 |
|---|---|---|
| Vref ≥ Vref_ceiling_PMOS（PMOS ceiling 违）| **NMOS diff-pair** | PMOS pair sub-threshold，gm 灾难 |
| Vref ≤ Vref_floor_NMOS（NMOS floor 违）| **PMOS diff-pair** | NMOS tail triode，DC OP 漂 |
| Vref 落两个上限之间（健康区间）| 看 noise / 1/f 取舍（PMOS 噪声低）| 双向都 OK，按 noise spec 取舍 |
| Vref 同时违两个上限 | **折叠 cascode EA** | 单极性 pair 都不能用，FC 两侧从 rail 取 bias 路径 |

### Demo 04 实证（PMOS ceiling 漏检 → 调参救不了）

```
spec: vpdk55nm, VDD=1.2V, Vref=Vfb=0.9V (unity-gain)
agent (Kimi K2): 选 Topology B (PMOS-input 5T + SF + Miller)
  PMOS ceiling check: 1.2 − 0.35 − 0.1 = 0.75V
  Vref 0.9V > 0.75V，违 150mV
  → M1/M2 sub-threshold (Vgs < |Vth|)
  → ID 60nA vs 设计 5µA (×1/83)
  → gm ×1/83 → 闭环 gain ↓35dB
  → PSRR 25dB (vs target 50dB), undershoot 179mV (vs <50mV), 30mA 不规制
  → agent 反复调 sizing 想救 → 救不了（拓扑外冲突）
  → Turn 13+ 才发现 root cause，浪费 15+ turn

正解：
(a) 换 NMOS-input pair（Vref 0.9V > NMOS floor 0.40V，满足）
(b) 或加分压器降 Vfb（R1=300kΩ + R2=600kΩ 让 Vfb=0.6V）
```

### 老 LDO 默认陷阱（v3 历史教训）

bandgap 给 0.6V Vref 但 Pack 默认 NMOS diff-pair → NMOS floor 0.50V (vpdk180nm) → 0.6V 边缘但勉强满足 → tail 紧张 → 仿真"成功"但 vout 错。

### 判别（仿真后）

- dc_snapshot 看 EA tail device M5 的 Vds_sat：Vds < Vdsat → tail triode → **NMOS pair floor 违**
- inspect_device 看 M1/M2 input pair 的 gm 实测 vs 设计期望：gm < 1/10 期望 → **PMOS pair ceiling 违**（M1/M2 sub-threshold）

### Step 0 写 EA 前必做

```
1. 查 PDK constants: |Vth_p|, Vth_n, VDD
2. 计算 PMOS ceiling = VDD − |Vth_p| − 0.1
3. 计算 NMOS floor   = Vth_n + 0.1
4. 对照 Vref：决定 EA 输入极性
5. 在 Step 0 报告里写明「Vref=?V, PMOS ceiling=?V, NMOS floor=?V, 选 ?-pair, 理由 ?」
6. **任一极性都不安全（Vref 同时违两个）→ 必选 FC EA**
```

## Pass FET sizing（关键约束）

> ⚠️ **核心方法**：Pass FET sizing **从 dropout spec 反推**，不是从 Iload 正向 sizing。  
> 跳过反推 → W 只够 Iload 平均值 → 接近 dropout 边缘时 m_pass 进 triode → DC OP 漂或 fail。

### 步骤 1：从 spec 反推 R_DS(on) target

```
Spec:   dropout < V_drop_max @ Iload_max
公式:   R_DS(on) ≤ V_drop_max / Iload_max
```

**Worked example**（V4 LDO Case A 实测对应数据）：

| Spec | 值 |
|---|---|
| Vin | 1.8 V |
| Vout | 1.2 V |
| Iload_max | 100 mA |
| dropout 目标 | < 200 mV |
| → R_DS(on) target | **< 2.0 Ω** |

### 步骤 2：从 R_DS(on) 反推 W（PMOS 在 triode 区）

```
R_DS(on) = 1 / (μp · Cox · (W/L) · Vov_pass)
```

| 参数（vpdk180nm 典型）| 值 |
|---|---|
| μp · Cox | ~ 60 µA/V² |
| L (Lmin × 1.5-2) | 0.36 µm |
| Vov_pass = Vsg - \|Vtp\| = (Vin - vg_pass_min) - \|Vtp\| | 1.2-1.5V（pass FET 全开时）|

**反推 W**（用上面 worked example）：

```
W/L = 1 / (R_DS(on) × μp·Cox × Vov)
    = 1 / (2.0 Ω × 60µA/V² × 1.3 V)
    = 6,400
W   = 6,400 × 0.36 µm = 2,300 µm
```

→ **W ≈ 2,000-3,000 µm 才能保证 100mA + dropout 200mV**。  
W=1,200 µm 只够 ~50mA + 200mV dropout 或 100mA + 400mV dropout。

### 步骤 3：sizing 不收敛 → 升级拓扑（不是无限加大 W）

**rule**：同轴 sizing 改动 ≥ 3 次仍不收敛 = 拓扑达不到 spec，**必须 challenge 拓扑而非继续改 W**（[L0 Iron Law 6](../../../src/agent_engine/prompt_compiler.py#_IRON_LAWS_DEFAULT)）。

| sizing 卡住的症状 | 拓扑升级方向 |
|---|---|
| **W 加到 4000+ µm 仍 dropout 边缘** | 加 cascoded pass FET（M_pass 串 cascode 提升等效 R_out 摆幅）|
| Pass FET Cgs 太大让 EA 推不动（fp_EA 太低）| 加 buffer between EA → pass FET（典型 source follower 或 class-AB push-pull）|
| Iload 范围太宽（µA 到 100mA）| Pass FET 拆 N 个并联 finger，按 Iload 自适应启用（adaptive Iq biasing）|
| dropout < 50mV @ 100mA spec | 超出 PMOS-pass 标准范围，必须用 NMOS-pass + charge pump |
| 单级 EA 推不动 + dropout spec 严苛 | 双级 EA + cascoded pass FET 联合升级 |

### 其他关键约束

- **Cgs_pass 是大寄生**：W_pass ~ 1400 µm 时 Cgs ~ pF 级，**主导 EA 输出节点的 RC**——这给 LDO 一个**慢极点**（fp_EA），是补偿的关键参考点
- **L 用 minimum 还是 longer？** 短 L → gm_pass 大 / Vov 小 / dropout 好；长 L → matching 好 / 1/f noise 低 / mismatching offset 好。**教学项目用 Lmin；生产项目 1.5-2× Lmin**
- **m（finger / multiplier）**：Iload 大时分多个 finger 让单管 Id 适中

### 验证（必做，不要漏 worst case）

- [ ] DC OP @ Iload_min（典型 1mA 或更低）：m_pass 应在 saturation 边缘
- [ ] **DC OP @ Iload_max（worst case stress）**：m_pass 必须 saturation，margin > 50mV
- [ ] dropout 实测：vin 从标称下扫到 vout+200mV 看 vout 是否仍稳
- [ ] `chapter=troubleshooting` § 症状 2 看 pass FET in triode 修复指引

## ⚠️ Common sizing pitfalls (LDO E2E v3-v5 实战卡点 codify — patch knowledge)

> 这一节是 LDO Case A E2E 多次实测（v3 95 turn / v4 / v5 53 turn）暴露的 sizing 数值反推 LLM 短板。先读这里避免重复踩坑；完整 sizing 数值反推方法论留 W6+ 专门 skill 解决。

### Pitfall 1: `M_xxx` .param 名跟 ngspice MOSFET `m` 关键字冲突

**症状**：ngspice 报 `Undefined parameter [m_cs_n]` / `Cannot evaluate parameter`

**原因**：ngspice MOSFET device 行 `M1 ... W=W_diff L=L_diff M=M_diff` 中的 `M=` 是内置 finger multiplier 关键字。如果 `.param M_diff = 1` 用同前缀 `M_`，ngspice 解析冲突。

**修复**：所有 multiplier `.param` 命名用 `NF_xxx` (number-of-fingers) 或 `MULT_xxx`，**不要用 `M_xxx`**：

```spice
.param NF_diff = 1     $ ✅ 正确（替代 M_diff）
.param NF_tail = 2     $ ✅
M5 ntail vbn vss vss nch W=W_tail L=L_tail M=NF_tail   $ device 行用 NF_xxx
```

### Pitfall 2: EA 输入对极性 CM range 自检漏检（floor 与 ceiling **双向**）

**两侧症状（绝大多数 agent 漏掉一侧）**：

| 误选 | 现象 | 物理 |
|---|---|---|
| NMOS-input + Vref 太低（floor 违）| DC OP fail，M5 tail Vds < Vdsat（margin 负 100mV+）| ntail = Vref − Vgs_n，Vref 低 → ntail 撞地 |
| **PMOS-input + Vref 太高（ceiling 违）⭐ Demo 04** | DC OP "通过"但 M1/M2 sub-threshold，**gm ×1/50-100**，AC 全垮 | Vsg_p = VDD − Vref，Vref 高 → Vsg < \|Vth\| |

**LDO v5 实战**（NMOS floor 边缘）：vpdk180nm 用 Vref=0.9V → ntail=0.4V → M5 Vds margin 紧（边缘）。

**Demo 04 实战**（PMOS ceiling 违）：vpdk55nm Vref=0.9V，VDD=1.2V，PMOS ceiling=VDD−\|Vth_p\|−Vdsat=0.75V → Vref 0.9V > 0.75V 违 150mV → M1/M2 sub-threshold → gm ×1/83 → PSRR 25dB vs target 50dB → AC 全垮，调参救不了。

**修复**：见上 § "EA 输入对极性 — IRON LAW" 章节。**用 PDK 实测的 \|Vth\| + VDD 数值代入算 ceiling/floor**，不能凭 Vref 绝对值（如旧规则的 0.8V / 1.0V 阈值）。

**Iron Law**：跨 PDK（vpdk180nm → 55nm → 7nm）\|Vth\| 和 VDD 都变，绝对 Vref 阈值失效，必须**每个 PDK 重算 ceiling/floor**。判别工具：dc_snapshot（NMOS floor 违）/ inspect_device gm（PMOS ceiling 违）。

### Pitfall 3: Itail mirror ratio = (W × m) ratio 不只是 m ratio

**症状**：agent 写 `Mbias W=2u m=1` + `M5 W=2u m=2` 期望 Itail = 2 × Ibias，但实测 Itail = ibias × (W_5×m_5)/(W_bias×m_bias) = (2×2)/(2×1) = 2 ✓ —— 但 agent 反推时算错把 W 当无关。

**原因**：mirror current ratio 是 (W·m)_out / (W·m)_in 的乘积，不是单 W 或单 m。

**修复**：mirror sizing 必须三件事同步声明：
```yaml
- name: Mbias
  W: 2u
  L: 1u
  m: 1
  derivation: "ibias=10µA reference"
- name: M5_tail
  W: 2u           # = W_bias 保持镜像精度
  L: 1u           # = L_bias 保持匹配
  m: 2            # NF=2 → Itail = ibias × (2×2)/(2×1) = 2 × 10µA = 20µA
  derivation: "mirror ratio = (W·m)_M5 / (W·m)_bias = 2 → Itail=20µA"
```

### Pitfall 4: Pass FET sizing 必须**反推**from dropout，不能正向 sizing

参考 skill `dropout_sizing_method` Step 1-5 完整流程。

**LDO v1/v3 实战**：v1 W=1200u 不够 → 试错到 4000u。v3 一次到位 W=2400u（因 P0-2 加了反推 worked example）。

### Pitfall 5: Stage2 NMOS-CS 的 G 必须接 stage1 真高增益输出（M2.D），不是 diode 端 (M1.D)

参考 reference-design.md "Connectivity rules" 表 + LDO v3 H-005 实战。

**症状**：DC OP PASS 但 AC loop gain 低 30 dB+

**修复**：M6.G = `v1` (M2 漏极，mirror 输出，high-Z) 而非 `vea_left` (M1 漏极，diode 端，low-Z)

### Pitfall 6: 同 device W 改 ≥ 3 次仍 triode → Iron Law 6 触发，**升级拓扑**而非继续改 W

参考 L0 Mental Core Iron Law 6 + skill `dropout_sizing_method` Step 5。

升级方向（按问题类型）：
- W=4000+ µm 仍 dropout 边缘 → 加 cascoded pass FET
- Pass FET Cgs 太大让 EA 推不动 → 加 source follower buffer between EA → pass FET
- Iload 范围太宽（µA 到 100mA）→ Pass FET 拆 N 个并联 finger + adaptive Iq biasing

### Pitfall 7: AC Method C 断环 testbench 实现细节（5 处易错）

详见 `chapter=ac-stability` "已知卡过的细节" 表 — Cfb 接哪 / 浮动 Vinj / Vinj DC=0 / 测量点 / PM 公式 / set units=degrees。

> ⚠️ **完整 sizing 数值反推方法论欠债**：上面 7 条都是"避坑提示"性质，不是手把手反推 W 数值。完整 LDO EA bias chain 反推（gm/Id 选 → Id 算 → W 算 → mirror ratio 反算 → headroom 验证）的 worked example 留 W6+ 专门 sizing skill 解决。当前阶段 agent 应优先用 V3 reference cir 当起点（见 `chapter=reference-design`），sizing 数值小幅微调 OK，大改 W 则触发 Iron Law 6 升级拓扑。

## 反馈分压器

```
vfb = vout × R2 / (R1 + R2)
```

| 配置 | 应用 |
|---|---|
| Unity feedback (vfb = vout) | Vout = Vref（适用 Vref 高于工艺常用范围）|
| Resistor divider | Vout = Vref × (R1+R2)/R2（任意 Vout > Vref）|

**关键约束**：
- R1+R2 不能太小（避免分流 Iload）—— 典型总和 > 100 kΩ
- R1+R2 不能太大（噪声 / matching 问题）—— 典型 < 10 MΩ
- 中间节点 vfb 是 EA 反相输入 → AC 断点位置（见 `chapter=ac-stability`）

## 设计入口（从 spec 反推架构）

按下表从 spec 反推（Vref 阈值是 **vpdk180nm instance**，跨 PDK 必须用上文 § "EA 输入对极性 — IRON LAW" 的 ceiling/floor 公式重算）：

| spec 关键字 | 推荐拓扑 |
|---|---|
| 标准 LDO（PSRR ≥ 50dB / Vref 1V+ @ vpdk180nm）| PMOS-pass + 双级 EA + NMOS diff-pair |
| Vref 0.6V @ vpdk180nm（bandgap） | PMOS-pass + 双级 EA + **PMOS diff-pair** |
| Iq 严苛（< 5µA）| PMOS-pass + 单级 cascode EA |
| capless（内部 cap < 100pF）| 需要专门补偿（Ahuja / FVF），超出本 knowledge 范围 |
| Vref 0.8-1.0V 灰色 @ vpdk180nm | PMOS-pass + 折叠 cascode EA |
| **vpdk55nm Vref 0.5-0.75V**（PMOS pair 健康区）| PMOS-pass + 双级 EA + PMOS diff-pair |
| **vpdk55nm Vref 0.75V+**（PMOS ceiling 违）| PMOS-pass + 双级 EA + **NMOS diff-pair**（Demo 04 教训）|
| 高效率（dropout < 50mV @ 100mA）| 需 NMOS-pass + boost，超出本 knowledge 范围 |

## 验证清单（架构选好后）

- [ ] **L2 EA 输入对极性 self-check（Iron Law）**：用 PDK 的 \|Vth\| + VDD 算 PMOS ceiling 与 NMOS floor，对照 Vref，写明决策理由
- [ ] EA topology 给 ≥ 50 dB DC gain（5T 永远不够）
- [ ] Pass FET R_DS(on) 满足 dropout × Iload_max
- [ ] dc_snapshot 显示 EA tail 在 saturation（**floor 违 → tail triode**）
- [ ] inspect_device 看 M1/M2 gm 实测 vs 设计期望（**ceiling 违 → gm < 1/10 期望**）
- [ ] 反馈分压器 R 总和 100k-10M
- [ ] 加载 `blocks/base-cells/differential-pair/cm-range` 做 CM range 数值代入
- [ ] 加载 `blocks/base-cells/miller-compensation` 知识做 Cc 选型（双级 EA 必需）
- [ ] 跑 `chapter=ac-stability` 验证 PM

## 常见架构误区

| 心里想 | 现实 |
|---|---|
| "用 5T-EA 设计 LDO" | 5T gain 30 dB，LDO 需要 50-70 dB，差 20+ dB——补偿救不了 |
| "Vref 多少都用 NMOS diff-pair" | Vref=0.6V @ vpdk180nm → NMOS tail 撞地（floor 违），DC OP 漂 |
| "PMOS 噪声低 → 默认选 PMOS diff-pair" | **Demo 04 实证**：vpdk55nm Vref=0.9V > PMOS ceiling 0.75V → M1/M2 sub-threshold → gm ×1/83 → AC 全垮 |
| "用 vpdk180nm 那一套 0.8/1.0V Vref 阈值跨 PDK" | \|Vth\| 和 VDD 跨 PDK 都变，绝对阈值失效，**每个 PDK 重算 ceiling/floor** |
| "Step 0 选了"PMOS-pass + 双级 EA"就开干" | 只敲定 L1 大类没下钻 L2 输入极性 → 拓扑外冲突，参 L1 skill `architecture-decomposition` |
| "pass FET 跟其他 PMOS 用同 W/L" | pass FET 是 mA 级 Iload，需要 W ~ 1000+ µm 量级 |
| "ESR 越小越好" | 纯陶瓷 cap (ESR ~10mΩ) 让 Cload 极点 / 零点重合，PM 崩——需要专门补偿 |
| "反馈分压 R 用 1k 高精度" | 1k × 0.5×Vout = 0.5mA 漏掉一半 Iload，R 总和应 > 100kΩ |

## 不在本章范围

- **AC 测稳定性具体方法**（断点 / Rfb / Cfb / meas）→ `chapter=ac-stability`
- **PSRR 提升手段**（cascode EA / 双级 EA noise gain）→ `chapter=psrr`
- **EA 输入对 / mirror / cascode 各自 sizing 细节** → `blocks/base-cells/<>`
- **Miller 补偿原理 / RHP zero / nulling resistor** → `blocks/base-cells/miller-compensation`
- **capless LDO / FVF 拓扑** → 不在本 knowledge 范围（先验证标准 LDO 后扩）
