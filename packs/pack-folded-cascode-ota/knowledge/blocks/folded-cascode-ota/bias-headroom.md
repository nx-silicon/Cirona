---
chapter: bias-headroom
parent: folded-cascode-ota
summary: |
  ⭐ FC-OTA 拓扑特有的 Vds/Vdsat 物理约束 + R1 KVL 反推 + R2 镜像约束 +
  失稳器件调整顺序。核心范例：MN5_bottom（cascode 底部管）triode →
  Vds_M5 = vbc_n − Vgs_cascode → 调 padding device（不调 M5 自身）。
  配 W6+ inspect_device / inspect_node / propose_knob 三件套使用。
tokens: ~2000
prerequisite_chapters:
  - reference-design
related_skills:
  - device_sizing
  - signal_tracing
related_knowledge:
  - blocks/base-cells/cascode
  - blocks/base-cells/current-mirror/wide-swing
---

# FC-OTA Bias & Headroom Reasoning

> 通用 vds-vdsat 推理范式见 `skill: device-sizing`（W6+ R1-R4 铁律）。
> 本章节给的是 **FC-OTA 拓扑特有的器件 Vds / Vdsat 物理约束**与失稳调整顺序。
> 工具：`inspect_device(<device>)` 看 Vds/Vdsat margin；`inspect_node(<node>)`
> 看节点电压由谁决定；`propose_knob(<target>, <direction>)` 给可调旋钮排序。

## Headroom Budget（VDD = 1.8V 典型）

FC-OTA 信号通路两侧堆叠：
- **VDD → vout 路径**：2 个 PMOS（MP1_bottom fold + MP2_top cascode）= 2 段 Vov
- **vout → VSS 路径**：2 个 NMOS（MN6_top cascode + MN5_bottom mirror）= 2 段 Vov

每段必须 Vov + 50mV 裕度才 saturation。

| 路径 | 器件堆栈 | 最小 Vds 占用 | swing 占比 |
|---|---|---|---|
| Vout 上限 | VDD − \|Vds_pfold\| − \|Vds_pcasc\| | (\|Vov_pfold\|+50) + (\|Vov_pcasc\|+50) ≈ 0.5V | Vout_max ≈ 1.30V |
| Vout 下限 | Vds_nmirror + Vds_ncasc | (Vov_nmirror+50) + (Vov_ncasc+50) ≈ 0.45V | Vout_min ≈ 0.45V |
| **总 swing** | — | — | **≈ 0.85V**（@VDD=1.8V）|

⚠️ **降 VDD 时 FC 第二个撞墙（5T 第一个）**：VDD ≤ 1.2V 时 4 段 cascode 占满
0.7-0.8V，剩余 swing < 0.4V，应换 wide-swing 极限优化或 2-stage。

⚠️ **wide-swing bias tree 强制 vbc_n / vbc_p 落点**：FC 不像 5T 直接堆叠
（vbc 由 padding 线性区 Vds 决定），所以**改 padding device sizing 直接
影响 cascode 底部管的 Vds 预算**——这是 FC 修 triode 的核心抓手。

## 每个器件的 Vds 物理因果（KVL 反推）

| 器件 | Vds 公式（KVL）| 调节路径 |
|---|---|---|
| **MN1, MN2**（NMOS input pair）| Vds_M1 = V(vmid_left1) − V(ntail) | 由 fold junction 电压 + tail 决定 |
| **MNtail**（NMOS tail）| Vds_tail = V(ntail) = Vinp − Vgs_M1 | tail 节点电压由 input pair 决定（同 5T 范式）|
| **MP1_b, MP3_b**（PMOS fold） | \|Vds_pfold\| = VDD − V(vmid_left1) | fold junction 电压由 cascode source 拉 |
| **MP2_t, MP4_t**（PMOS cascode）| \|Vds_pcasc\| = V(vmid_left1) − V(vd_left or vout) | cascode source follower：V(vmid_left1) ≈ vbc_p + \|Vgs_pcasc\| |
| **MN6_t, MN8_t**（NMOS cascode）| Vds_ncasc = V(vd_left or vout) − V(vmid_left2) | cascode source follower：V(vmid_left2) ≈ vbc_n − Vgs_ncasc |
| **MN5_b, MN7_b**（NMOS mirror bottom）⭐ | **Vds_M5 = V(vmid_left2) = vbc_n − Vgs_M6** | **不是 M5 自己决定，由 vbc_n + cascode 决定**（见范例 1）|

## ⭐ 范例 1：MN5_bottom（cascode 底部管）进 triode 怎么办？

**这是 FC-OTA 最常见的 bias 失稳，也是 FC 版的 R1-R4 推理经典案例**
（FC-OTA E2E v3 + ACP 4.3 Phase 0 实测踩点）。

### 症状

```
inspect_device(MN5_bottom):
  region: triode
  Vds_M5 = 0.08 V
  Vdsat_M5 = 0.20 V
  margin = -120 mV  ← 负值，已进 triode
```

`dc_snapshot` 通常同时报：vmid_left2 ≈ 0.08V（应该 ≥ Vdsat_M5 ≈ 0.18-0.20V）。

### R1 KVL 反推 — Vds_M5 由什么决定？

```
Vds_M5 = V(vmid_left2) − V(vss) = V(vmid_left2)

V(vmid_left2) 由 cascode source follower 决定：
  V(vmid_left2) = V(MN6.G) − Vgs_MN6 = vbc_n − Vgs_MN6

vbc_n 由 wide-swing bias tree 决定：
  vbc_n = Vgs(MMN_vbcn_2_diode) + Vds(MMN_vbcn_1_padding)
                ↑ 几乎固定（diode）        ↑ ⭐ 这里是抓手（线性区，可调）
```

**MN5 的 Vds 不是 MN5 自己决定的，是 padding device `MMN_vbcn_1` 的 Vds 决定的**——
两层间接：padding Vds → vbc_n → vmid_left2 → MN5 Vds。

调用 `inspect_node('vmid_left2')` 验证：vmid_left2 节点的 driver 是 MN6.S
（cascode source follower），不是 MN5.D。再 `inspect_node('vbc_n')`：
driver 是 MMN_vbcn_2.D + MMN_vbcn_1.D（padding）。

### 三条调节路径

**路径 A — 提升 V(vbc_n) → 提升 V(vmid_left2)**（首选）：
- `MMN_vbcn_1` 工作在 **线性区**，`Rds ∝ L / W`
- 在固定电流下 `Vds = I × Rds ∝ L / W`
- → **L_pad_n ↑（推荐）** 或 **W_pad_n ↓（备选）**
- 一步 ≤ 50% 改动（避免 MN6 反过来 triode）

**路径 B — 降低 Vdsat_M5**（让 M5 在低 Vds 下仍 saturate）：
- 需要 **L_nmirror ↑**（Vov ↓ → Vdsat ↓）或 m_nmirror ↑（电流密度 ↓）
- ⚠️ 不要直接调 W_nmirror —— 镜像比例会乱（R2 铁律）

**路径 C — 拓扑不可行**（VDD < 1.2V 时）：
- 单级 FC 物理上需要 ~600-700 mV NMOS 堆叠 headroom
- 修不了 → 换 telescopic-low-voltage 或 2-stage

### R2 镜像约束铁律 ⭐⭐⭐

MN5_bottom / MN7_bottom 是 **cascode self-biased mirror**：
`MN5: D=vmid_left2, G=vd_left, S=vss`；`MN7.G=vd_left`（slave）。
**G≠D 不是普通 diode**——通过 MN6_top cascode 形成 self-biased loop（vd_left=MN6.D
master gate；MN5.D=MN6.S=vmid_left2 由 cascode bias 间接锁）。MN5/MN7 匹配决定 mirror。

**直接调 MN5.W/L 的后果**：
- mirror ratio 与 fold branch 不再匹配 → I_M5 ≠ I_fold − I_diff/2
- → vd_left 偏移 → MN6 Vgs 偏移 → 整个左 branch DC 工作点漂
- → AC gain / PM 一起崩

**正确做法**（FC 的 R2 铁律）：
1. **先调 padding device**（MMN_vbcn_1）改 vbc_n 落点 → 改变 Vds 在 MN5 / MN6
   之间的分配（**总 Vds 预算 = vd_left ≈ 常量**——这是硬约束）
2. 如果 padding 调到极限仍不够 → 调 L_nmirror（同时改 MN5 + MN7，保持
   mirror 对称）
3. 不到万不得已不调 m_nmirror（会改 mirror ratio）

> **CMOS 设计本质**：在 cascode 拓扑中，cascode 底部管的 Vds 由**上方 cascode
> 的 gate bias** 决定，不是它自己——所以调它的 Vds 要从 bias tree 入手，
> 不是从底部管 sizing 入手。**这是 LLM 最常忽略的物理约束**。

### R3 推理路径（agent 应该走的完整链）

```
看到 MN5_bottom triode
  ↓
inspect_device(MN5_bottom)
  → Vds / Vdsat / region / margin
  ↓
inspect_node('vmid_left2')
  → driver = MN6.S（cascode source follower），不是 MN5.D！
  ↓
inspect_node('vbc_n')
  → driver = MMN_vbcn_2.D + MMN_vbcn_1.D（padding linear）
  ↓
KVL: V(vmid_left2) = vbc_n − Vgs_MN6
     vbc_n = Vgs_diode + Vds_pad_n
  ↓
问 1: Vds_pad_n 可调？= 改 W_pad_n / L_pad_n（**首选，路径 A**）
问 2: Vdsat_M5 可降？= 改 L_nmirror（路径 B）
问 3: VDD 可加？= 物理决定（路径 C）
  ↓
propose_knob([
  ('L_pad_n', 'increase'),    # 增 L → Rds ↑ → Vds_pad ↑ → vbc_n ↑ → V(vmid_left2) ↑（对，路径 A1）
  ('W_pad_n', 'decrease'),    # 减 W → 同上（对，路径 A2）
  ('L_nmirror', 'increase'),  # 增 L → Vdsat ↓（对，路径 B）
  ('W_nmirror', '...')        # 别动！破镜像（R2 违反）
  ('m_tail', '...')           # 别动！会改 fold_ratio
])
```

> ⚠️ **W6+ 实测显示 LLM 常忽略 R2 镜像约束**——直接调 MN5_bottom 的 W/L。
> chapter 写作必须强调"调 vbc_n 通过 padding，调 Vdsat 通过 L_nmirror 同步双侧"。

### R4 testbench 验证

调好 padding 之前先搭最小 testbench 验证 vbc_n 落点：

```spice
* tb_check_vbcn.sp — vbc_n 落点扫描（W_pad_n / L_pad_n）
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include '../design/fc_ota.cir'
.param IBIAS = 10u
.param L_pad_n = 0.5u  $ sweep variable

Vdd vdd 0 DC 1.8
Vinp vinp 0 DC 0.9
Rfb vout vinn 1G
Cfb vinn 0 1
Ibias vdd ibias IBIAS
X1 vinp vinn vout ibias vdd 0 folded_cascode_ota

.dc L_pad_n 0.36u 1.5u 0.1u
.meas dc vbc_n_target find v(x1.vbc_n) when v(x1.vmid_left2)='Vdsat_target'
.end
```

确定 L_pad_n 让 V(vmid_left2) 落到 ≥ Vdsat_M5 + 50mV margin。

### 不要做（anti-pattern）

- ❌ **直接增大 W_nmirror / L_nmirror 不同步双侧**：mirror ratio 错乱
- ❌ **同时 W_pad_n ↑ + L_pad_n ↑**：两个方向相反 → 互相抵消（不要混用！）
- ❌ **加理想电压源压 vbc_n**：违反 self-bias 设计原则，且不能反映 corner 漂移
- ❌ **直接增大 W_diff 想让 input pair 让出 Vds**：W_diff 改大会增 I_diff，
  fold junction 拥堵 → 副作用更大
- ❌ **接受 MN5 在 triode**："反正 V(vmid_left2) 还在变"——triode 的 mirror master
  ro 几乎为 0，gain / CMRR / PSRR 全垮

### 镜像症状：MN6_top triode（vbc_n 推太高）

如果反过来——vbc_n 推太高（padding 过度调整后）→ V(vmid_left2) 太高 →
MN5_bottom margin 充足但 MN6_top 没空间：

```
inspect_device(MN6_top): triode, Vds = 0.10V
inspect_device(MN5_bottom): sat, margin = +200 mV  ← 余量太大
```

**修复方向相反**：L_pad_n ↓ 或 W_pad_n ↑（让 vbc_n ↓）。

> **硬约束**：Vds(MN5) + Vds(MN6) = V(vd_left) ≈ Vgs(MN5 master) ≈ const。
> padding 调整只是在 MN5 / MN6 之间**重新分配** Vds 预算，不会增加总预算。
> 任何一侧调过头另一侧必坏——所以 **保守步长 ≤ 50% per step + 双侧 margin 都看**。

## ⭐ 范例 2：PMOS cascode 镜像 (MP2_top / MP4_top) Vds 不足

### 症状
```
inspect_device(MP2_top): triode, |Vds| = 0.12V, |Vdsat| = 0.18V
```

通常发生在 vbc_p 偏高（PMOS cascode 把 vmid_left1 拱得太靠近 vd_left）。

### R1 KVL 反推
```
|Vds_MP2| = V(vmid_left1) − V(vd_left)
V(vmid_left1) = vbc_p + |Vgs_MP2|
vbc_p = VDD − |Vds_MP_pad| − |Vgs_MP_diode|
```

PMOS 侧的 padding device `MMP_vbcp_1` 同样在线性区，**L_pad_p ↑ → |Vds_pad_p| ↑
→ vbc_p ↓**（PMOS 是反向的，注意符号）。

### 调节路径

| 路径 | 怎么做 | 副作用 |
|---|---|---|
| 降 vbc_p（提 \|Vds_MP2\|）| L_pad_p ↑ 或 W_pad_p ↓ | 反过来可能让 MP_fold triode |
| 降 \|Vdsat_MP2\| | L_pcasc ↑ | gain ↑（趋势相同），无副作用 |
| 接受 swing 限制 | 标 Vout_max = VDD − \|Vov_pfold\| − \|Vov_pcasc\| − 50mV | 缩小 spec |

### R2 镜像约束（PMOS cascode）

MP2_top 与 MP4_top **必须同 W / L / m**（镜像对称）。调 W_pcasc 时双侧
一起改。`m_pcasc` 是常用调 ro 的旋钮（FC reference 默认 m=6 提 ro_pcasc）。

## ⭐ 范例 3：MNtail (tail current source) 进 triode

同 5T-OTA，**tail 节点电压由 input pair 决定**：
```
V(ntail) = Vinp − Vgs_M1 = Vinp − (Vth_n + Vov_M1)
Vds_MNtail = V(ntail)
```

修复路径与 5T-OTA 相同（见 `blocks/5t-ota/bias-headroom`）：
- 增 W_diff → 减 Vov_M1 → V(ntail) ↑（路径 A）
- 增 L_bias → 减 Vov_tail（注意：MNtail / MMNbias 共 W/L，要同步双侧改）

> **R2 同步铁律**：FC 中 MNtail 镜像 MMNbias，**改 L_bias 双侧同步**——
> 不要只改 MNtail（破坏 mirror）。

---

## Headroom 设计原则（FC-OTA 特定）

| # | 原则 | 理由 |
|---|---|---|
| 1 | **VCM = 0.6-0.9V**（@VDD=1.8V，NMOS-input）| Vds_tail ≥ Vdsat + 50mV，Vds_M1 ≥ Vdsat + 50mV |
| 2 | **Vov ≤ 0.20V**（每段 cascode）| 4 段堆叠 0.8V，剩余 swing > 0.6V |
| 3 | **Vov ≥ 0.10V**（除 input pair）| weak inversion gm/Id > 18 → gm/W 小，gm 不够 |
| 4 | **input pair Vov 0.12-0.18V**（gm/Id 12-15）| 噪声主导，倾向 weak inversion |
| 5 | **fold + cascode + mirror Vov 0.18-0.22V**（gm/Id 8-12）| matching + headroom |
| 6 | **PMOS load L > input pair L**（典型 2µm vs 1µm）| gain ceiling + 噪声衰减 |
| 7 | **padding device 工作在 triode** | wide-swing bias 设计目标，不是错误 |
| 8 | **L_cascode ≥ 2× Lmin**（典型 0.5µm）| cascode ro 主导，但不必过长（fold node cap）|
| 9 | **fold_ratio = 2**（默认对称）| I_cascode = I_diff，避免大信号 cutoff |

## 配套工具（W6+ inspect 三件套）

| 工具 | 用途 | 何时调 |
|---|---|---|
| `inspect_device(<device>)` | Vds / Vdsat / region / margin | dc_snapshot 显示某 device 不 sat 时 |
| `inspect_node(<node>)` | 节点电压由谁决定（driver 反推）| 想"提升 V(vmid_left2)"时先查谁决定 |
| `propose_knob(<target>, <direction>)` | 给可调旋钮排序 | 推理完 R1/R2 后挑修复路径 |

## When to load this chapter

- `dc_snapshot` 显示某 device 不在 saturation 或 margin < 50mV
- 设计推进到 sizing 阶段，需要分配 Vov budget 给 4 段 cascode
- 调 sizing 撞 R2 镜像约束（多次试 W/L 没收敛——典型信号）
- 看到 cascode 底部管 triode 但不知道改哪个 padding

## Related

- **W6+ R1-R4 推理铁律**：`skill: device-sizing` 通用 sizing 流程（pre-sim / post-sim）
- **信号路径反推**：`skill: signal-tracing`
- **cascode 物理 + bias 决定下管 Vds 因果链**：`blocks/base-cells/cascode`
- **wide-swing bias scheme padding 推导**：`blocks/base-cells/current-mirror/wide-swing`
- **fold_ratio 耦合规则 + sizing 步骤**：`sizing-typical.md`
- W6+ sizing 范例（W6+ sizing-2 P0-D-H 5 cell sizing-reasoning chapter）
