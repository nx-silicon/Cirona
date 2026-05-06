---
chapter: sizing-typical
parent: telescopic-ota
summary: |
  Telescopic OTA 顶层 spec → device 约束的因果链 + 拓扑特定推进顺序
  （4-stack headroom 紧 + ICMR 严格约束让 sizing 必先做 headroom budget）+
  起点表（@vpdk180nm）+ trade-off 表。引用 device-sizing skill 做单 device
  推导，不重复。
tokens: ~1500
prerequisite_chapters:
  - architecture
related_skills:
  - device_sizing
related_knowledge:
  - blocks/base-cells/differential-pair
  - blocks/base-cells/cascode
  - blocks/base-cells/current-mirror/wide-swing
---

# Telescopic OTA Sizing Typical Ranges

> 通用 sizing 方法见 `skill: device-sizing` 通用 sizing 流程 + Iron Law: NO PARAMETER WITHOUT EXPLICIT DERIVATION。
> 单 device 物理推导见对应 base-cell（`differential-pair` / `cascode` /
> `current-mirror/wide-swing`）。本章节给的是 **Telescopic 拓扑特有**的：
> (1) spec → device 约束传递；(2) 4-stack headroom 紧让 sizing 必先做
> headroom budget；(3) ICMR 紧的 VCM 约束；(4) 起点表（@vpdk180nm）。

## 顶层 spec → device 约束（拓扑特定因果链）

| OTA spec | 决定的 device 量 | 关键公式 |
|---|---|---|
| GBW | gm_MM1 (input pair) | gm_MM1 = 2π · GBW · CL |
| DC gain | Rout = Rout_p ‖ Rout_n | Rout_n = gm_casc · ro_MM1 · ro_MMcasc（包含 ro_diff）|
| PM | f_p2（cascode 节点）+ f_p3（mirror 节点）| f_p2 / GBW > 3 |
| Iq budget | I_tail（**单 branch！**）| I_total = I_tail = 2 × Id_per_side（FC 是 × 2）|
| Swing 上限 | \|Vov_load\| + \|Vov_pcasp\| | Vout_max ≈ VDD − \|Vov_load\| − \|Vov_pcasp\| − 50mV |
| Swing 下限 | Vov_diff + Vov_ncasc + Vov_tail | Vout_min ≈ Vov_diff + Vov_ncasc + Vov_tail + 50mV |
| ICMR 上限 | Vth_n + Vov_diff + Vov_ncasc | VCM_max ≈ vbnc − 50mV（input pair 不能让 cascode 进 triode）|
| ICMR 下限 | Vov_diff + Vov_tail + Vth_n | VCM_min ≈ Vov_tail + Vth_n + Vov_diff + 50mV |

> **Telescopic 与 FC 的 spec 公式差异**：
> - **Iq budget**：Telescopic = I_tail（**1 倍**），FC = 2 × I_tail（**2 倍**）
> - **Swing 上限**：Telescopic 与 FC 同（PMOS 双管堆叠）
> - **Swing 下限**：Telescopic 多一段（Vov_tail），FC 把 tail 偏置到 fold 之下少一段
> - **ICMR**：Telescopic 紧（input pair 在 cascode 路径中），FC 宽（fold 解耦）

## 4-stack headroom budget ⭐（**Telescopic 设计起点**）

```
VSS → ntail → ncasc → vout → nload → VDD
         |       |        |       |
       MMtail  MM1     MMcasc1   MMcasp3   MM3
       (Vov+50)(Vov+50)(Vov+50)  (|Vov|+50)(|Vov|+50)
```

**严格不等式**：
```
∑(Vov + 50mV) < VDD − Vout_swing_required

例（VDD=1.8V，要求 swing > 0.4V）：
4 × (Vov + 50) ≤ 1.4V → Vov ≤ 0.3V (每段)
更严格目标 swing 0.6V → Vov ≤ 0.2V (每段)
```

> **Telescopic Iron Law**：**先做 headroom budget，再算 W/L**。每段 Vov ≤
> 0.18-0.20V 是 vpdk180nm 下的物理硬约束，不是建议值。

## ICMR（输入共模范围）约束

```
VCM_max = vbnc − 50mV                    (input pair drain ncasc 不能拉太低)
VCM_min = Vov_tail + Vth_n + Vov_diff + 50mV
```

**Telescopic ICMR 极紧**（典型 0.4V，vs FC 1.3V）的物理来源：
- input pair drain（ncasc）由 cascode source follower 决定（vbnc - Vgs_MMcasc）
- VCM 太高 → MM1 Vgs 大 → V(ncasc) = VCM - Vgs > vbnc - Vgs_MMcasc → MMcasc 进 triode
- VCM 太低 → V(ntail) = VCM - Vgs_MM1 < Vov_tail → MMtail triode

**所以 Telescopic 必须 spec VCM 严格落在窗口内**（典型 VCM = 0.9V @ VDD=1.8V）。

## 拓扑特定的设计推进顺序（**4-stack + ICMR 双约束**）

> 通用 sizing 流程见 device-sizing skill。本节给 **Telescopic 拓扑特有**的
> 推进顺序——4-stack 紧 + ICMR 紧让 headroom budget 必须先于 W/L sizing。

### Step 1: 由 spec 反算 input pair gm（GBW + noise 双约束）

```
gm_MM1 = max(gm_GBW, gm_noise)
gm/Id = 12-15（noise 主导，倾向 weak inversion）
Id_per_side = gm_MM1 / (gm/Id)        ← 即 I_branch
I_tail = 2 × Id_per_side
```

### Step 2: 4-stack headroom budget（**先于 W/L sizing**）

```
swing target = spec
total_Vov_budget = VDD - swing - margin × 5
                 = 1.8 - 0.5 - 0.25 = 1.05V       (典型)
per_stage_Vov = total / 4 = 0.26V

每段 Vov：
  Vov_tail   = 0.20-0.25V    (matching + headroom)
  Vov_diff   = 0.15-0.20V    (gm + headroom)
  Vov_ncasc  = 0.18-0.22V    (matches diff density)
  Vov_pcasp  = 0.18-0.22V    (matches load density)
  |Vov_load| = 0.20-0.25V    (matching + ro)
```

> **优先级**：input pair Vov 0.15-0.20V（gm + noise），其他 0.20V 起步。
> 如果 swing target 仍不够 → 减小 4-stack Vov 到 0.12-0.15V → 接近 weak
> inversion → trade-off：gain ↓ + matching ↓。

### Step 3: ICMR 约束反推 VCM 窗口

```
VCM = (VCM_min + VCM_max) / 2   设计起点
VCM_min = Vov_tail + Vth_n + Vov_diff + 50mV ≈ 0.45V
VCM_max = vbnc - 50mV ≈ 1.0V    (典型 vbnc 1.0-1.1V)
VCM 窗口 ≈ 0.55V

→ VCM = 0.7-0.9V 设计起点（落 ICMR 中点）
```

如果 spec 要求 VCM 范围 > 0.55V → telescopic **物理不行**，换 FC。

### Step 4: 算 W / L（每个 group 用 gm/Id lookup）

```
gm_per_branch = gm/Id × Id_per_side
W = gm / (µ·Cox · gm/Id × Vov)
L 起点：
  input pair L = 1.0 µm（matching + ro_MM1 → Rout_n 关键）
  cascode L = 0.5 µm（≥ 2.5× Lmin，cascode ro 主导）
  load L = 1.0 µm（matching + ro_MM3）
m 起点：
  m_diff = ceil(Id_per_side / Id_per_finger)
  m_casc = m_diff / 2 typical（layout-friendly）
  m_load = m_diff
```

> **W_casc = W_diff（同 W）+ 用 m 调倍数**：layout-friendly + 镜像精度。
> V4 reference design `m_casc = m_diff / 2` 对应 cascode finger 是 diff finger 的 1/2。

### Step 5: 设计 wide-swing bias tree（vbnc / vbpc）⭐

bias tree 9 个 MOSFET 生成 `vbnc` / `vbpc` / `nbias_p`。**关键 1：padding device**
（`MMbnc_bot` / `MMbpc_top`）工作在 **线性区**（不是 sat）。

```
vbnc = Vgs(MMbnc_top_diode) + Vds(MMbnc_bot_pad)
vbpc = VDD − |Vds(MMbpc_top_pad)| − |Vgs(MMbpc_bot_diode)|
```

padding sizing：
- `W_pad_n / L_pad_n` 调到让 Vds(MMbnc_bot) ≈ Vov_diff + Vov_tail（典型 0.40-0.45V）
- `W_pad_p / L_pad_p` 调到让 |Vds(MMbpc_top)| ≈ |Vov_load|（典型 0.20V）

**关键 2：bias 支路电流密度 = 主支路电流密度**（V3 实战教训，2026-04-22 修复）：

```
bias 支路电流 = ibias × (m_factor / m_bias)
主支路电流   = ibias × (m_tail / m_bias) / 2

要求 bias 支路 / 主支路 单管电流密度相等（W_eff 同时缩放）
→ MMbp_nc.m = m_load × m_tail / (2 × m_bias)
→ MMbn_pc.m = m_tail / 2
```

> **wide-swing 同密度铁律**：**bias 支路 m 没匹配主支路 → vbnc / vbpc 落点错** →
> diff pair / cascode 进 triode → gain 仅 3-10 dB。这是 V3 实战 sizing 修复
> 案例的核心。

### Step 6: 验证 headroom + DC bias 落点

```
inspect_device(MM1..MMtail, MMcasc1..MMcasp4, MM3, MM4, MMbnc_top, MMbpc_bot)
  → 所有 gain-path device margin > 50 mV
  → padding device（MMbnc_bot / MMbpc_top）应在 triode（设计目标）

inspect_node('vbnc', 'vbpc', 'ncasc', 'nload', 'ntail')
  → vbnc ≈ Vth_n + 2 × Vov_n（典型 0.9-1.0V）
  → vbpc ≈ VDD − |Vth_p| − 2 × |Vov_p|（典型 0.8-0.9V）
  → ncasc ≈ vbnc − Vgs_MMcasc（典型 0.4-0.5V）
  → nload ≈ vbpc + |Vgs_MMcasp|（典型 1.3-1.4V）
```

如有任意 gain-path device 不 sat → 回 `bias-headroom.md` 范例（4 处 bias
节点）走 R1/R2 推理。

### Step 7: 验证 AC（gain / GBW / PM）

参见 `ac-stability.md` + `reference-design.md` 的 testbench 模板。
通用方法见 `skill: ac-feedback-loop-method`（Method C 断环）。

### 推荐建议（不强制）

> 这 7 步是**建议顺序**，不是机械流程。**Telescopic 的 Step 2（headroom budget）+
> Step 3（ICMR 反推）必须先于 Step 4（W/L）**——4-stack 紧 + ICMR 紧让乱序
> 必反复推翻。Step 5（bias tree wide-swing 同密度）是 V3 实战教训，**不可跳过**。

## 起点表（@vpdk180nm，VDD=1.8V，ibias=10µA，m_tail=8 → I_tail=80µA → I_branch=40µA）

| Device | role | W | L | m | gm/Id | Vov | 关键约束 |
|---|---|---|---|---|---|---|---|
| MM1, MM2 | NMOS diff pair | 10 µm | 1 µm | 8 | ~12 | 0.18 V | gm 主导 + 长 L 提 ro_MM1 |
| MM3, MM4 | PMOS mirror | 20 µm | 1 µm | 8 | ~10 | 0.20 V | μp/μn ≈ 1/4 → W_p ≈ 2 × W_n |
| MMcasc1, MMcasc2 | NMOS cascode | 10 µm | 0.5 µm | 4 | ~10 | 0.18 V | matches diff pair density |
| MMcasp3, MMcasp4 | PMOS cascode | 20 µm | 0.5 µm | 4 | ~10 | 0.20 V | matches load density |
| MMtail | NMOS tail | 5 µm | 1 µm | m_tail=8 | ~10 | 0.20 V | I_tail = 2 × Id_per_side = 80µA |
| MMbias | NMOS diode（bias ref）| 5 µm | 1 µm | 1 | — | — | mirror reference |
| MMbnc_bot（pad_n）| NMOS padding（vbnc gen）| 1.5 µm | 1.5 µm | 1 | — | — | linear region，调 Vds ≈ 0.55V |
| MMbpc_top（pad_p）| PMOS padding（vbpc gen）| 10 µm | 0.72 µm | 2 | — | — | linear region，调 \|Vds\| ≈ 0.20V |
| MMbp_nc | PMOS bias mirror | 20 µm | 1 µm | `m_load·m_tail/(2·m_bias)`=32 | — | — | wide-swing 同密度铁律 |
| MMbn_pc | NMOS bias mirror | 5 µm | 1 µm | m_tail/2=4 | — | — | wide-swing 同密度铁律 |

⚠️ **数值标 @vpdk180nm**：换工艺时 µ·Cox 不同，要重新算 W。4-stack /
wide-swing 同密度 / gm/Id / Vov 关系跨工艺通用。

## Trade-off 表（4D：gain / BW / power / swing）

| 调整 | gain | BW | power | swing | 备注 |
|---|---|---|---|---|---|
| L_load ↑（1→2µm）| ↑↑（ro_MM3 ↑）| ↓（mirror node cap ↑）| — | — | gain 优先时首选 |
| L_cascode ↑（0.5→1µm）| ↑（ro_cascode ↑）| ↓（cascode source 节点 cap ↑）| — | — | 适度提 gain |
| L_diff ↑（1→2µm）⭐ | ↑（ro_MM1 ↑ → Rout_n ↑）| —（gm 同）| — | — | **Telescopic 特有路径**：ro_MM1 进 Rout_n |
| W_diff ↑ | ↑（gm ↑）| ↑（gm ↑）| —（同 Id）| ↓（Vov 减但 cascode cap ↑）| trade-off 多 |
| m_tail ↑（同步 m_load + bias 支路 m）| —（gm·ro 不变）| ↑↑（gm ↑）| ↑↑ | ↓（Vov ↑）| BW 优先时首选 |
| L_pad_n ↑（调 vbnc ↑）| —（小信号不变）| —| —| —（重新分配 Vds budget）| 治 MM1 triode（见 bias-headroom）|

> **Telescopic vs FC 提 gain 的关键差异**：FC 的 input pair drain 直接接 fold
> junction（与 cascode 上方 high-Z 节点没共享），所以增 L_diff 不直接进 Rout_n；
> 而 Telescopic 的 input pair drain = cascode source = ro_MM1 进 Rout_n。
> **Telescopic 增 L_diff 提 gain 比 FC 更直接**。

## 不在本章范围

- **gm/Id 通用 sizing 方法** → `skill: device-sizing`（通用 sizing 流程）
- **input pair / cascode 各自单 device 物理推导** → `blocks/base-cells/differential-pair` + `cascode`
- **wide-swing bias scheme 详细推导** → `blocks/base-cells/current-mirror/wide-swing`
- **何时用 Telescopic 何时不用** → `architecture.md`（拓扑选择）
- **Vds-Vdsat 失稳处理（4 处 bias 节点 R1-R4）** → `bias-headroom.md`
- **cascode 极点 + PM 设计** → `ac-stability.md`

## Related

- `blocks/base-cells/differential-pair/sizing-reasoning` 输入对单 device sizing
- `blocks/base-cells/cascode/sizing-reasoning` cascode device sizing
- `blocks/base-cells/current-mirror/wide-swing` padding device + Vds budget 推导
- `blocks/folded-cascode-ota/sizing-typical` FC 对比（fold_ratio + ICMR 宽）
- `skill: device-sizing` 通用 sizing 流程 + R1-R4 铁律
- W6+ sizing-reasoning chapter（`current-mirror` / `cascode` / `differential-pair` / `bias-generator` 5 cell）
