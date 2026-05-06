---
chapter: bias-headroom
parent: telescopic-ota
summary: |
  ⭐ Telescopic OTA 拓扑特有的 Vds/Vdsat 物理约束 + R1 KVL 反推 + R2 镜像约束 +
  失稳器件调整顺序。核心范例：4 处 cascode bias 节点 triode（双 cascode 4 个
  Vds budget 都靠 padding device 调）+ MM1 triode（ICMR 紧的物理来源）。
  配 W6+ inspect_device / inspect_node / propose_knob 三件套使用。
tokens: ~2200
prerequisite_chapters:
  - reference-design
related_skills:
  - device_sizing
  - signal_tracing
related_knowledge:
  - blocks/base-cells/cascode
  - blocks/base-cells/current-mirror/wide-swing
---

# Telescopic OTA Bias & Headroom Reasoning

> 通用 vds-vdsat 推理范式见 `skill: device-sizing`（W6+ R1-R4 铁律）。
> 本章节给的是 **Telescopic 拓扑特有的器件 Vds / Vdsat 物理约束**与失稳调整顺序。
> Telescopic 的特点：**4-stack + 双 cascode + ICMR 紧**——4 处 bias 节点都
> 可能 triode，**所有都通过 wide-swing padding 调**，不直接调主管 W/L。
> 工具：`inspect_device(<device>)` 看 Vds/Vdsat margin；`inspect_node(<node>)`
> 看节点电压由谁决定；`propose_knob(<target>, <direction>)` 给可调旋钮排序。

## Headroom Budget（VDD = 1.8V 典型）

Telescopic OTA 信号通路 4-stack 堆叠：
- **VDD → vout 路径**：2 个 PMOS（MM3 mirror + MMcasp3 cascode）= 2 段 Vov
- **vout → VSS 路径**：3 个 NMOS（MMcasc1 cascode + MM1 diff pair + MMtail）= 3 段 Vov

**与 FC 的关键差异**：FC 的 input pair 在独立 branch（不计 cascode 堆叠），
Telescopic 的 input pair **直接在主 cascode 路径中** → NMOS 侧多一段 Vov。

| 路径 | 器件堆栈 | 最小 Vds 占用 | swing 占比 |
|---|---|---|---|
| Vout 上限 | VDD − \|Vds_load\| − \|Vds_pcasp\| | (\|Vov_load\|+50) + (\|Vov_pcasp\|+50) ≈ 0.5V | Vout_max ≈ 1.30V |
| Vout 下限 | Vds_ncasc + Vds_diff + Vds_tail | (Vov_ncasc+50)×3 ≈ 0.75V | Vout_min ≈ 0.75V |
| **总 swing** | — | — | **≈ 0.55V**（@VDD=1.8V）|

⚠️ **Telescopic 比 FC swing 更紧**（FC 0.6-0.8V vs Tele 0.4-0.6V）的物理来源：
NMOS 侧多一段 Vov（input pair 在 stack 中）。**降 VDD 时 Telescopic 第一个
撞墙**：VDD ≤ 1.5V 时 4-stack 占满 0.7-0.8V，剩余 swing < 0.4V → 拓扑不行。

## ICMR 紧的物理约束（**Telescopic 关键差异**）

```
VCM_max ≈ vbnc - 50mV                                 (MM1 saturate 约束: V(ncasc) > V(ntail) + Vov_diff + 50mV)
VCM_min ≈ Vth_n + Vov_diff + Vov_tail + 50mV          (tail 不进 triode: V(ntail) > Vov_tail + 50mV)
```

**ICMR 窗口**：典型仅 0.4-0.5V（vs FC 1.3V）。Telescopic 输入共模严格依赖
vbnc 落点 → padding device 同时影响 ICMR + cascode bias。

## 每个器件的 Vds 物理因果（KVL 反推）

| 器件 | Vds 公式（KVL）| 调节路径 |
|---|---|---|
| **MMtail**（NMOS tail）| Vds_tail = V(ntail) = VCM − Vgs_MM1 | tail 节点电压由 input pair Vgs 决定 |
| **MM1, MM2**（NMOS diff pair）⭐ | Vds_MM1 = V(ncasc) − V(ntail)<br>= (vbnc − Vgs_MMcasc) − (VCM − Vgs_MM1)<br>= vbnc − Vgs_MMcasc − VCM + Vgs_MM1 | **由 vbnc 间接决定**——见范例 1 |
| **MMcasc1, MMcasc2**（NMOS cascode）⭐ | Vds_ncasc = V(vout) − V(ncasc)<br>= V(vout) − (vbnc − Vgs_MMcasc) | 由 vbnc + 输出 vout 决定 |
| **MMcasp3, MMcasp4**（PMOS cascode）⭐ | \|Vds_pcasp\| = V(nload) − V(vout)<br>= (vbpc + \|Vgs_MMcasp\|) − V(vout) | 由 vbpc + 输出 vout 决定 |
| **MM3, MM4**（PMOS mirror）⭐ | \|Vds_load\| = VDD − V(nload)<br>= VDD − (vbpc + \|Vgs_MMcasp\|) | 由 vbpc + load Vgs 决定 |

**关键事实**：**所有 4 处 bias 节点（MM1 / MMcasc / MMcasp / MM3）的 Vds
都由 wide-swing bias tree 的 vbnc / vbpc 间接决定**。这是 Telescopic 比 FC
更"难"的原因——FC 只有 cascode 底部管由 padding 决定（mirror master 自己
diode-connect），Telescopic 是 4 处。

## ⭐ 范例 1：MM1（input pair）进 triode → 调 padding 提 vbnc

**Telescopic 最常见 + 最难诊断的 bias 失稳**——agent 容易诊断为 input pair
sizing 错，但根因在 padding。

### 症状

```
inspect_device(MM1):
  region: triode
  Vds_MM1 = 0.10V
  Vdsat_MM1 = 0.20V
  margin = -100 mV
```

`dc_snapshot` 通常同时报：V(ncasc) ≈ 0.4V（应该 ≥ V(ntail) + Vdsat_MM1 ≈ 0.5V）。

### R1 KVL 反推 — Vds_MM1 由什么决定？

```
Vds_MM1 = V(ncasc) − V(ntail)

V(ncasc) 由 cascode source follower 决定：
  V(ncasc) = vbnc − Vgs_MMcasc

vbnc 由 wide-swing bias tree 决定：
  vbnc = Vgs(MMbnc_top_diode) + Vds(MMbnc_bot_pad)
              ↑ 几乎固定（diode）        ↑ ⭐ 抓手（线性区，可调）

V(ntail) 由 input pair 决定：
  V(ntail) = VCM − Vgs_MM1   (VCM 是 spec)
```

**MM1 的 Vds 不是 MM1 自己决定的**——是 padding device `MMbnc_bot` 的 Vds 决定的：

```
Vds_MM1 = vbnc − Vgs_MMcasc − VCM + Vgs_MM1
        = [Vgs_diode + Vds_pad] − Vgs_MMcasc − VCM + Vgs_MM1

注意 Vgs_MMcasc ≈ Vgs_diode（wide-swing 同密度铁律），所以：
        ≈ Vds_pad + Vgs_MM1 − VCM    ← Vds_pad 是抓手
```

**调用 `inspect_node('ncasc')` 验证**：ncasc 节点的 driver 是 MMcasc1.S
（cascode source follower），不是 MM1.D。再 `inspect_node('vbnc')`：
driver 是 MMbnc_top.D + MMbnc_bot.D（padding linear）。

### 三条调节路径

**路径 A — 提升 Vds_pad → 提升 vbnc → 提升 V(ncasc) → 提升 Vds_MM1**（首选）：
- `MMbnc_bot` 工作在 **线性区**，`Rds ∝ L / W`
- 在固定电流下 `Vds = I × Rds ∝ L / W`
- → **L_pad_n ↑（推荐）** 或 **W_pad_n ↓（备选）**
- 一步 ≤ 50% 改动（避免 MMcasc1 反过来 triode）

**路径 B — 降低 Vdsat_MM1**（让 MM1 在低 Vds 下仍 saturate）：
- `L_diff ↑`（Vov ↓ → Vdsat ↓）或 `m_diff ↑`（电流密度 ↓）
- 副作用：gm_MM1 微变（影响 GBW）+ 噪声 ↑

**路径 C — 改 VCM**（如果 spec 允许）：
- VCM ↑ → V(ntail) ↑ → 但 V(ncasc) 也跟（VCM 进 vbnc 关系）—— 实际**不会改善**
- VCM ↓ → 仅在 ICMR 下限附近改善 Vds_tail，不直接救 MM1
- **多数情况 VCM 不是抓手**（ICMR 紧让 VCM 自由度小）

### R2 镜像约束铁律 ⭐⭐⭐（**Telescopic 多重 mirror**）

Telescopic 中 **5 个 mirror 关系** 必须保持（W/L 严格相同，m 可不同）：

| # | mirror | 用途 |
|---|---|---|
| 1 | MMbias ↔ MMtail ↔ MMbn_pc（NMOS）| tail + bias 支路 sink |
| 2 | MMbn2p ↔ MMbp_ref（N-to-P）| 转 NMOS bias 到 PMOS |
| 3 | MMbp_ref ↔ MMbp_nc（PMOS）| bias 支路 source |
| 4 | MMbnc_top ↔ MMcasc1/MMcasc2（NMOS cascode self-bias）| 密度同 → Vgs 同 → vbnc 落点对 |
| 5 | MMbpc_bot ↔ MMcasp3/MMcasp4（PMOS cascode self-bias）| 同上 |

**直接调主管 W/L（如 MMcasc1.W）的后果**：与 mirror 4 的 MMbnc_top 不再匹配
→ Vgs 漂 → vbnc 落点错 → MM1 / MMcasc 一起出问题。

**正确做法**：先调 padding（MMbnc_bot / MMbpc_top）改 vbnc / vbpc 落点；
如要改 cascode 主管 sizing → **同步改 MMbnc_top / MMbpc_bot 保持密度**；
不到万不得已不调单管 W/L。

> **CMOS 设计本质**（Telescopic 强化版）：cascode 拓扑中所有 cascode 节点的
> Vds 都由 cascode bias 决定。padding device 是修 4 处 bias 节点的统一抓手。

### R3 推理路径 + R4 testbench

agent 应走的完整链：
```
inspect_device(MM1) → triode? Vds / Vdsat
  → inspect_node('ncasc') → driver = MMcasc1.S (cascode source follower)
    → inspect_node('vbnc') → driver = MMbnc_top + MMbnc_bot (padding linear)
       → propose_knob: L_pad_n ↑ (A1) / W_pad_n ↓ (A2) / L_diff ↑ (B)
         不动: W_diff（破 sizing）/ m_tail（改主密度）
```

调 padding 前先搭最小 testbench 扫 `L_pad_n` 在 0.5-2.5µm 区间：在 `op` 下读
`v(x1.vbnc)` / `v(x1.ncasc)` / `@m.x1.mm1[vds]`，确定 L_pad_n 让
V(ncasc) ≥ V(ntail) + Vdsat_MM1 + 50mV。详见 `simulators/ngspice/measurements`。

### 不要做（anti-pattern）

- ❌ **直接增大 W_diff / 减 L_diff 想让 input pair 让出 Vds**：副作用太多
  （gm 漂 + 噪声 ↑ + cascode cap ↑），不解决根因
- ❌ **同时 W_pad_n ↓ + L_pad_n ↑**：两个方向相同 → 互相叠加可能过度调到
  MMcasc1 triode（不要混用！）
- ❌ **加理想电压源压 vbnc**：违反 self-bias 设计原则；corner 漂移不能 track
- ❌ **接受 MM1 在 triode**："Vinp 还在 swing"——triode 的 input pair gm 急
  剧降低，gain 直接掉 30-40 dB

## ⭐ 范例 2：MMcasc1（NMOS cascode）进 triode

**通常发生在 vbnc 推太高（padding 过度调整后），与范例 1 是镜像症状**。

### 症状
```
inspect_device(MMcasc1): triode, Vds = 0.10V
inspect_device(MM1): sat, margin = +200 mV  ← 余量太大
```

### R1 KVL 反推
```
Vds_MMcasc = V(vout) − V(ncasc)
V(ncasc) = vbnc − Vgs_MMcasc
```

vbnc 太高 → V(ncasc) 太高 → 在固定 V(vout) 下 Vds_MMcasc 变小 → triode。

### 修复方向相反（与范例 1 镜像）
```
L_pad_n ↓ 或 W_pad_n ↑   →   Vds_pad ↓ → vbnc ↓ → V(ncasc) ↓
                              → MM1 失去 Vds margin（要权衡！）
                              → MMcasc1 拿到 margin
```

> **硬约束**：Vds(MM1) + Vds(MMcasc1) = V(vout) − V(ntail) ≈ const（在 V(vout)
> 工作点固定时）。padding 调整是在 MM1 / MMcasc1 之间**重新分配**，不增加总预算。
> **保守步长 ≤ 50% per step + 双侧 margin 都看**。

## ⭐ 范例 3：PMOS 侧 triode（MMcasp / MM3）—— vbpc 调整

**MMcasp3 进 triode**：vbpc 偏低 → V(nload) 偏低 → \|Vds_MMcasp\| 不足。
**MM3 进 triode**：vbpc 偏高 → V(nload) 接近 VDD → \|Vds_MM3\| 不足。

### R1 KVL（PMOS 侧）
```
|Vds_MM3|    = VDD − V(nload)            ← V(nload) 高 → MM3 紧
|Vds_MMcasp| = V(nload) − V(vout)         ← V(nload) 低 → MMcasp 紧

V(nload) = vbpc + |Vgs_MMcasp|
vbpc = VDD − |Vds_pad_p_linear| − |Vgs_diode|
```

### 修复方向（PMOS 侧 padding 调整）
```
PMOS 侧 vbpc 与 NMOS 侧 vbnc 调整方向相反（极性翻）：
  L_pad_p ↑ → |Vds_pad_p| ↑ → vbpc ↓ → V(nload) ↓ → |Vds_MM3| ↑ + |Vds_MMcasp| ↓
  L_pad_p ↓ → |Vds_pad_p| ↓ → vbpc ↑ → V(nload) ↑ → |Vds_MM3| ↓ + |Vds_MMcasp| ↑
```

| 失败 | 修复方向 |
|---|---|
| MM3 triode（V(nload) 太高）| L_pad_p ↑ 或 W_pad_p ↓（让 vbpc ↓）|
| MMcasp triode（V(nload) 太低）| L_pad_p ↓ 或 W_pad_p ↑（让 vbpc ↑）|

> **Telescopic 4 处 bias 节点的修复方向总结**：
> - **NMOS 侧**：MM1 triode → vbnc ↑（L_pad_n ↑）；MMcasc triode → vbnc ↓（L_pad_n ↓）
> - **PMOS 侧**：MM3 triode → vbpc ↓（L_pad_p ↑）；MMcasp triode → vbpc ↑（L_pad_p ↓）
> - **同侧硬约束**：Vds(MM3) + Vds(MMcasp) = VDD - V(vout) ≈ const；padding 在两者间重新分配

> ⚠️ **PMOS 侧公式符号容易出错**——画一个简化 KVL 图核对再调。

## ⭐ 范例 4：MMtail 进 triode

同 5T-OTA：**tail 节点电压由 input pair Vgs 决定**。
- `V(ntail) = VCM − Vgs_MM1`，`Vds_MMtail = V(ntail)`
- 修复：增 W_diff（减 Vov_MM1）或 增 L_bias（**同步 MMbias / MMtail / MMbn_pc 全部改**！）

详见 `blocks/5t-ota/bias-headroom` 范例 1（NMOS-input 同范式）。

---

## Headroom 设计原则（Telescopic 特定）

- VCM 严格落 ICMR 中点 ≈ **0.7-0.9V**（@VDD=1.8V）；ICMR 仅 0.4-0.5V 窗口
- 每段 cascode **Vov ≤ 0.20V**，input pair Vov 0.15-0.20V，cascode + load Vov 0.18-0.22V
- Vov ≥ 0.10V（避免 weak inversion，gm/W 不够）
- PMOS load L > input pair L（典型 1µm，m 不同）；L_cascode = 0.5 µm（≥ 2.5× Lmin）
- **padding device 工作在 triode 是设计目标**，不是错误
- **bias 支路电流密度 = 主支路**（wide-swing 同密度铁律，V3 sizing 修复 case）
- VDD < 1.5V → 4-stack 撑不开，换 FC

## 配套工具（W6+ inspect 三件套）

`inspect_device(<device>)` → Vds/Vdsat/region；`inspect_node(<node>)` → driver 反推；
`propose_knob(<target>, <direction>)` → 推理完 R1/R2 后排可调旋钮。详见
`skill: device-sizing` W6+ 通用 sizing 流程。

## When to load this chapter

- `dc_snapshot` 显示某 device 不在 saturation 或 margin < 50mV
- 看到 4-stack 任一段 triode 但不知道改哪个 padding
- 设计推进到 sizing 阶段，需要分配 4-stack Vov budget
- 调 sizing 撞 R2 多重 mirror 约束（5 个 mirror，多次试都没收敛）
- ICMR 不够 → 看 VCM 是否落 ICMR 窗口（vbnc 决定 ICMR_max）

## Related

- **W6+ R1-R4 推理铁律**：`skill: device-sizing` 通用 sizing 流程（pre-sim / post-sim）
- **信号路径反推**：`skill: signal-tracing`
- **cascode 物理 + bias 决定下管 Vds**：`blocks/base-cells/cascode`
- **wide-swing bias scheme padding 推导**：`blocks/base-cells/current-mirror/wide-swing`
- **同密度 wide-swing 铁律 + sizing 步骤**：`sizing-typical.md`
- **FC 对照（fold 解耦 ICMR）**：`blocks/folded-cascode-ota/bias-headroom`
- W6+ sizing 范例（W6+ sizing-2 P0-D-H 5 cell sizing-reasoning chapter）
