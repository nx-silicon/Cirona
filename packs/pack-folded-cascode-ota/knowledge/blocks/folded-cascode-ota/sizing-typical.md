---
chapter: sizing-typical
parent: folded-cascode-ota
summary: |
  FC-OTA 顶层 spec → device 约束的因果链 + 拓扑特定推进顺序（fold_ratio
  耦合 + 5 group 同步 sizing）+ 起点表（@vpdk180nm）+ trade-off 表。
  引用 device-sizing skill 做单 device 推导，不重复。
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

# FC-OTA Sizing Typical Ranges

> 通用 sizing 方法见 `skill: device-sizing` 通用 sizing 流程 + Iron Law: NO PARAMETER WITHOUT EXPLICIT DERIVATION。
> 单 device 物理推导见对应 base-cell（`differential-pair` / `cascode` / `current-mirror/wide-swing`）。
> 本章节给的是 **FC-OTA 拓扑特有**的：(1) spec → device 约束传递；(2) fold_ratio 耦合规则；(3) 5 group 推进顺序；(4) 起点表（@vpdk180nm）。

## 顶层 spec → device 约束（拓扑特定因果链）

| OTA spec | 决定的 device 量 | 关键公式 |
|---|---|---|
| GBW | gm_M1 (input pair) | gm_M1 = 2π · GBW · CL |
| DC gain | Rout = Rout_p ‖ Rout_n | gain = gm_M1 · Rout；Rout_p = gm_pcasc · ro_pfold · ro_pcasc |
| PM | f_p2 ≈ gm_pcasc / (2π · C_fold_node) | f_p2 / GBW > 3 → PM > 60° |
| Iq budget | I_branch + I_bias_tree | I_branch = I_fold = I_tail × fold_ratio / 2 |
| Swing 上限 | \|Vov_pfold\| + \|Vov_pcasc\| | Vout_max ≈ VDD - \|Vov_pfold\| - \|Vov_pcasc\| - 50mV |
| Swing 下限 | Vov_nmirror + Vov_ncasc | Vout_min ≈ Vov_nmirror + Vov_ncasc + 50mV |
| ICMR 上限 | Vth_n + Vov_M1 + Vov_tail | VCM_max = VDD - 50mV（NMOS-input + fold 解耦）|
| ICMR 下限 | Vov_M1 + Vov_tail | VCM_min ≈ Vov_tail + Vth_n + Vov_M1 |
| Noise（input-referred）| gm_M1 + (gm_pfold/gm_M1)² | cascode 抑制 mirror flicker（FC 的噪声优势）|

## fold_ratio 耦合规则 ⭐（FC-OTA 专属硬约束）

```
I_fold = ibias × (m_fold / m_bias)         (PMOS fold branch 电流)
I_tail = ibias × (m_tail / m_bias)         (NMOS tail 电流)
fold_ratio = 2 × I_fold / I_tail = 2 × m_fold / m_tail
```

**物理意义**：每条 cascode branch 拿到的电流 = `I_fold − I_diff_branch`，
其中 I_diff_branch = I_tail / 2。

```
I_cascode = I_fold − I_tail / 2 = (m_fold − m_tail / 2) × ibias / m_bias
fold_ratio < 1  →  I_cascode < 0  →  cascode branch 缺电流  →  device cutoff
fold_ratio = 1  →  I_cascode = 0  →  cascode branch 空载（小信号 ro 也错乱）
fold_ratio = 2  →  I_cascode = I_diff_branch  →  对称稳定起点（典型默认）
```

**铁律**：**改 m_tail 必须同步改 m_fold**。
- `fold_ratio = 2.0` 起步：m_fold = m_tail（对称）
- 最小 `fold_ratio = 1.5`：m_fold ≥ 0.75 × m_tail（slew rate 已偏紧）
- 不要 fold_ratio < 1.5：cascode branch 在大信号下接近 cutoff

> ⚠️ V3 实战教训（FC-OTA E2E）：agent 把 m_tail 从 2 调到 16 但忘了同步
> m_fold（仍是 2）→ fold_ratio = 0.25 → cascode branch I_cascode 负值 →
> 整个 cascode 失效，gain 降到 < 30 dB，浪费 8+ turn。

## 拓扑特定的设计推进顺序（FC-OTA 5 Group 同步 sizing）

> 通用 sizing 流程见 device-sizing skill。本节给 **FC-OTA 拓扑特有**的——
> 5 group 之间的强耦合（fold_ratio + headroom 共享 + 4 bias 节点）让乱序
> sizing 必反复推翻，下面是建议推进顺序。

### Step 1: 由 spec 反算 input pair gm（GBW + noise 双约束）

```
gm_M1 = max(gm_GBW, gm_noise)
  - gm_GBW = 2π · GBW · CL
  - gm_noise = 8 · k · T · γ / V²_n,in,target
取较大者作为 gm_M1 design target。
gm/Id = 12-15（FC noise 主导，倾向 weak inversion）
Id_per_side = gm_M1 / (gm/Id)       ← 即 I_diff_branch
```

> **为什么这步先做**：input pair 决定 OTA 整体性能（gm + noise），下游
> 所有 device 跟着 Id_per_side 走。

### Step 2: 选 fold_ratio + 算 I_fold / I_tail

```
fold_ratio = 2.0（默认对称）
I_tail   = 2 × Id_per_side
I_fold   = fold_ratio × I_tail / 2 = Id_per_side × fold_ratio  
I_cascode = I_fold − I_tail / 2 = Id_per_side  (当 fold_ratio = 2)
```

设 `m_bias = 1`，`ibias = 5-10µA`：

```
m_tail = round(I_tail / ibias)      ← 取整！
m_fold = round(fold_ratio × m_tail / 2)
```

**KCL 自检**：m_fold ≥ m_tail / 2 + 安全裕度（典型 m_fold = m_tail，
对应 fold_ratio = 2）。

### Step 3: 用 headroom budget 反推每段 Vov（先于 W/L）

```
Vout_max = VDD - |Vov_pfold| - |Vov_pcasc| - 50mV  (设计目标)
Vout_min = Vov_nmirror + Vov_ncasc + 50mV          (设计目标)
swing = Vout_max - Vout_min  ≥ spec
```

把 swing budget 切给 4 段 cascode：

| 段 | Vov 起点 | gm/Id 起点 |
|---|---|---|
| PMOS fold（MP1_b/MP3_b）| 0.20 V | 8-10 |
| PMOS cascode（MP2_t/MP4_t）| 0.18 V | 9-11 |
| NMOS cascode（MN6_t/MN8_t）| 0.18 V | 9-11 |
| NMOS mirror（MN5_b/MN7_b）| 0.20 V | 8-10 |

> **5T-OTA 对照**：5T 只有 1 段 NMOS + 1 段 PMOS 占 headroom；FC 是 2 段 +
> 2 段，每段 Vov 必须更紧（~0.18-0.20V）才能保住 swing 0.6-0.8V。

### Step 4: 算 W / L（每个 group 用 gm/Id lookup）

```
gm_per_branch = gm/Id × Id_per_side (or I_fold for fold/cascode)
W = gm_per_branch / (µ·Cox · gm/Id × Vov)
L 起点：
  input pair L = 1.0 µm（matching + ro 双重）
  cascode L = 0.5 µm（≥ 2.5× Lmin，cascode ro 主导，不必过长）
  load L = 1.0 µm（matching + 噪声 + ro）
m 起点（按支路电流 KCL 算，cascode 串联同一支路必然 m 相同）：
  m_diff = ceil(Id_per_side / Id_per_finger)
  m_fold = m_tail（fold_ratio = 2 → I_fold = I_tail）
  m_pcasc = m_ncasc = m_fold − m_diff
              （cascode 支路电流 I_pcasc = I_ncasc = I_fold − I_in_per_side；
                fold_ratio = 2 → I_fold = 2·I_in → m_pcasc = m_ncasc = m_diff）
  m_nmirror = m_diff
```

> **注意**：cascode 串联在同一支路，按 KCL 必然 `m_pcasc = m_ncasc`。
> 不存在 `m_pcasc / m_ncasc = m_fold` 这种公式（量纲不对、物理也不成立）。
> 起点 m 由 fold_ratio + I_in_per_side 共同决定，不是 cascode 之间的 ratio。

> **W_pcasc = W_fold（同 W）+ 用 m 调倍数**：layout-friendly + 镜像精度。
> V4 reference design `m_pcasc = 6` 而不是 `W_pcasc × 6` 就是这个原则。

### Step 5: 设计 wide-swing bias tree（vbc_n / vbc_p）

bias tree 9 个 MOSFET 生成 4 个 bias 节点。**关键：padding device**
`MMN_vbcn_1` / `MMP_vbcp_1` 工作在 **线性区**（不是 sat）。

```
vbc_n = Vgs(MMN_vbcn_2) + Vds(MMN_vbcn_1)   ← linear padding decides Vds
vbc_p = VDD − |Vds(MMP_vbcp_1)| − |Vgs(MMP_vbcp_2)|
```

padding sizing：
- `W_pad_n / L_pad_n` 调到让 Vds(MMN_vbcn_1) ≈ Vov_nmirror（典型 0.18-0.20V）
- `W_pad_p / L_pad_p` 同理

> 物理：padding 在 triode 时 `Rds ≈ L / (µ·Cox · W · Vov_eff)`，
> 在固定电流下 `Vds = I × Rds ∝ L / W`。**L ↑ 或 W ↓ → Vds ↑**。
> 详见 `bias-headroom.md` 范例 1（MN5 triode 修复因果链）。

### Step 6: 验证 headroom + DC bias 落点

```
inspect_device(MN1..MN8, MP1..MP4, MNtail, MMN_vbcn_*, MMP_vbcp_*)
  → 所有 gain-path device margin > 50 mV（Vds - Vdsat）
  → padding device（MMN_vbcn_1 / MMP_vbcp_1）应该在 triode（设计目标）
inspect_node('vbc_n', 'vbc_p', 'vmid_left1/2', 'vmid_right1/2')
  → vbc_n ≈ Vth_n + 2 × Vov_n（典型 0.6V）
  → vbc_p ≈ VDD − |Vth_p| − 2 × |Vov_p|（典型 1.2V）
```

如有任意 gain-path device 不 sat → 回 `bias-headroom.md` 范例（M5/M7
triode）走 R1/R2 推理。

### Step 7: 验证 AC（gain / GBW / PM）

参见 `ac-stability.md` + `reference-design.md` 的 testbench 模板。
通用方法见 `skill: ac-feedback-loop-method`（Method C 断环）。

### 推荐建议（不强制）

> 这 7 步是**建议顺序**，不是机械流程。**FC 的 Step 2（fold_ratio）+ Step 3
> （headroom budget）必须先于 Step 4（W/L）**——否则反复推翻 sizing。Step 5
> （bias tree）可以在 Step 4 之后做，但**改 padding sizing 一定要重跑 Step 6**
> 验证 vbc_n / vbc_p 落点。

## 起点表（@vpdk180nm，VDD=1.8V，ibias=10µA → I_tail=20µA → I_fold=20µA）

| Device | role | W | L | m | gm/Id | Vov | 关键约束 |
|---|---|---|---|---|---|---|---|
| MN1, MN2 | NMOS input pair | 4.4 µm | 1 µm | 1 | ~12 | 0.15 V | gm 主导，weak inversion 倾向 |
| MP1_b, MP3_b | PMOS fold | 24.7 µm | 2 µm | 2 | ~8 | 0.20 V | I_fold = 20µA × m_fold/m_bias |
| MP2_t, MP4_t | PMOS cascode top | 8.9 µm | 2 µm | 6 | ~10 | 0.18 V | ⚠️ m=6 偏离 KCL（见下注）|
| MN6_t, MN8_t | NMOS cascode top | 9.1 µm | 1 µm | 1 | ~10 | 0.18 V | matches mirror W |
| MN5_b, MN7_b | NMOS mirror bottom | 4.4 µm | 1 µm | 1 | ~8 | 0.20 V | mirror reference |
| MNtail | NMOS tail | 3.3 µm | 1 µm | 2 | ~10 | 0.20 V | I_tail = 2 × Id_per_side |
| MMNbias | NMOS bias diode | 3.3 µm | 1 µm | 1 | — | — | mirror reference |
| MMP_vbcn_1（pad_n）| PMOS padding（vbc_n gen）| 1 µm | 2 µm | 1 | — | — | linear region，调 Vds ≈ Vov_nmirror |
| MMN_vbcp_1（pad_p）| NMOS padding（vbc_p gen）| 1 µm | 2 µm | 1 | — | — | linear region，调 Vds ≈ \|Vov_pfold\| |

⚠️ **数值标 @vpdk180nm**：换工艺时 µ·Cox 不同，要重新算 W。fold_ratio /
gm/Id / Vov 跨工艺通用。

> **关于起点表 `m_pcasc = 6` / `m_ncasc = 1`** — 这是 reference design 实证
> 的工程数值，**不是 KCL 起点**。教科书起点应是 `m_pcasc = m_ncasc = m_fold
> − m_diff`（cascode 串同支路、电流必相等、Vov 也一致）。当前 reference
> design 通过让 PMOS cascode 多 finger（m=6）+ 同 W/L 让 cascode 工作在
> 较小 Vov（更深饱和、ro 更大）来提 gain，代价是 fold node DC 电压偏移、
> NMOS cascode 那侧 Vov 变大；spec 5/5 PASS 是**实证可跑**而非"sizing 公式
> 推导出 m=6"。新拓扑 sizing 时不用照抄这个比例，按 `m_pcasc = m_ncasc`
> 起步即可。

## Trade-off 表（4D：gain / BW / power / swing）

| 调整 | gain | BW | power | swing | 备注 |
|---|---|---|---|---|---|
| L_load ↑（1→2µm）| ↑↑（ro_pfold ↑）| ↓（fold node cap ↑）| — | — | gain 优先时首选 |
| L_cascode ↑（0.5→1µm）| ↑（ro_cascode ↑）| ↓（cascode source 节点 cap ↑）| — | — | 适度提 gain，不破 PM |
| W_diff ↑ | ↑（gm ↑）| ↑（gm ↑）| —（同 Id）| ↓（Vov 减但 fold cap ↑）| trade-off 多 |
| m_tail ↑ + m_fold ↑（同步）| —（gm·ro 不变）| ↑↑（gm ↑）| ↑↑ | ↓（Vov ↑）| BW 优先时首选 |
| m_pcasc ↑（提 m，不改 W）| ↑↑（ro_pcasc 倍数 ↑）| —（fold node cap 同）| —（同 Id）| —（Vov 微变）| ⭐ FC 提 gain 最佳路径 |
| L_pad_n ↑（调 vbc_n ↑）| —（小信号不变）| —| —| —（重新分配 Vds budget）| 治 MN5 triode（见 bias-headroom）|

## 不在本章范围

- **gm/Id 通用 sizing 方法** → `skill: device-sizing`（通用 sizing 流程）
- **input pair / cascode 各自单 device 物理推导** → `blocks/base-cells/differential-pair` + `cascode`
- **wide-swing bias scheme 详细推导** → `blocks/base-cells/current-mirror/wide-swing`
- **何时用 FC 何时不用** → `architecture.md`（拓扑选择）
- **Vds-Vdsat 失稳处理（MN5 triode / MN6 triode）** → `bias-headroom.md`
- **fold node 极点 / PM 设计** → `ac-stability.md`

## Related

- `blocks/base-cells/differential-pair/sizing-reasoning` 输入对单 device sizing
- `blocks/base-cells/cascode/sizing-reasoning` cascode device sizing
- `blocks/base-cells/current-mirror/wide-swing` padding device + Vds budget 推导
- `skill: device-sizing` 通用 sizing 流程 + R1-R4 铁律
- W6+ sizing-reasoning chapter（`current-mirror` / `cascode` / `differential-pair` / `bias-generator` / `output-stage` 5 cell）
