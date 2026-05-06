---
chapter: troubleshooting
parent: telescopic-ota
summary: |
  Telescopic OTA 系统级失败模式 + 物理因果链 + 根因可能性表（不写流程，
  诊断顺序由通用 systematic-debugging skill 提供）。涵盖 gain 极低（V3 sizing
  case）/ 4 处 cascode triode / ICMR 不够 / GBW / PM / wide-swing 密度失配。
tokens: ~1700
prerequisite_chapters:
  - architecture
  - bias-headroom
related_skills:
  - systematic_debugging
  - signal_tracing
  - device_sizing
---

# Telescopic OTA Troubleshooting

> 通用诊断顺序见 `skill: systematic-debugging`（4-phase）+ `skill: signal-tracing`
> （信号反推）。本章节给的是 **Telescopic 拓扑特有**的失败模式 + 物理因果链 +
> 根因可能性表。**device 不 saturation 触发的失败**（如 MM1 triode）见
> `bias-headroom.md` —— 本章不重复 R1/R2 推理细节，只列根因表 + 链接回去。

## 失败模式 1：DC gain 极低（< 30 dB）—— **wide-swing bias 密度失配**

> ⭐ **Telescopic 最危险的"deceptive failure"**——agent 容易诊断为 sizing 起点不对，
> 但根因在 bias 支路与主支路**电流密度失配**。V3 实战 sizing 修复案例（2026-04-22）。

### 症状

```
inspect_device(MM1): triode, Vds_MM1 = 0.05V
inspect_device(MMcasc1): triode, Vds_MMcasc = 0.10V
gain_dc: 3.2 dB     ← 远低于 telescopic 典型 60-80 dB
```

注意：**多个 device 同时 triode**（不是单一 bias 节点失败）—— 这是 bias 树
本身坏掉的标志。

### 物理因果链
```
bias 支路（MMbp_nc 支路） m 倍数 × ibias / m_bias = bias 支路电流
主支路（MMtail 支路）    m_tail × ibias / m_bias / 2 = 主支路单边电流

如果 bias 支路 m 没匹配主支路：
  bias 支路 I_per_finger ≠ 主支路 I_per_finger
  → MMbnc_top.Vgs ≠ MMcasc.Vgs    (bias diode 与主 cascode Vgs 不同)
  → vbnc = Vgs_MMbnc_top + Vds_pad ≠ 设计目标
  → V(ncasc) = vbnc - Vgs_MMcasc 漂到错的位置
  → MM1 / MMcasc1 同时 triode
```

### 修复（V3 sizing 修复 case 的核心）

```
强制 bias 支路 m 倍数 = m_load × m_tail / (2 × m_bias)

例：m_bias=1, m_tail=8, m_load=8
   MMbp_nc.m = 8 × 8 / (2 × 1) = 32       ← V4 reference 默认
   MMbn_pc.m = m_tail / 2 = 4              ← V4 reference 默认
```

### Anti-pattern

- ❌ **诊断为 input pair sizing 错**：W_diff / L_diff 不是根因，bias tree 才是
- ❌ **加大 ibias 想"提升 bias 支路电流"**：会牵动所有 mirror，主支路电流也变，
  fold-free 比例错
- ❌ **改 W_pad 想"调 vbnc"**：padding 是次要抓手，先修同密度

### 验证

修复后 `inspect_node('vbnc')` 应在 0.9-1.0V 区间（典型）；所有 4 处 cascode
device sat margin > +50mV。

---

## 失败模式 2：DC gain 低（< 60 dB）—— 单 device 物理或 sizing

**症状**：DC OP 全过（无 device triode），但 AC 测 gain < 60 dB。

### 物理因果链
```
gain = gm_MM1 × Rout
Rout = Rout_p ‖ Rout_n
Rout_n = gm_ncasc × ro_MM1 × ro_ncasc      ← Telescopic 特点：包含 ro_MM1
Rout_p = gm_pcasp × ro_MM3 × ro_pcasp
```

任一项弱 → gain 弱。**Telescopic gain ceiling**：cascode 把 ro 提到
gm·ro × ro 量级，物理上 80-90 dB。

### 根因可能性表

| 可能根因 | 验证 | 物理原因 | 修复方向 |
|---|---|---|---|
| **L_diff 短**（Telescopic 特有路径 ⭐）| `op_point_check` 看 ro_MM1 | ro ∝ L，**直接进 Rout_n** | L_diff 0.5 → 1-2 µm（**Telescopic 提 gain 首选**）|
| L_load 短 | `op_point_check` 看 ro_MM3 | ro ∝ L | L_load 1 → 2 µm |
| L_cascode 短 | `op_point_check` 看 ro_MMcasc / ro_MMcasp | ro ∝ L | L_cascode 0.36 → 0.5 µm |
| gm_MM1 不足 | `op_point_check` 看 gm_MM1 vs target | gm ∝ √(W/L · Id) | W_diff ↑ 或 m_diff ↑ |
| **wide-swing 密度失配（隐性）**| 看 vbnc / vbpc 落点是否对 | bias tree 失效 | 见失败模式 1 |
| **某 cascode triode**（致命）| `dc_snapshot` region | triode → ro ≈ 0 | 见 `bias-headroom.md` 4 处范例 |

> **Telescopic 增 L_diff 比 FC 更直接提 gain**——Rout_n 包含 ro_MM1。

### Anti-pattern

- ❌ **增 ibias 想提 gain**：gm × ro 在 strong inversion 几乎不变；
  且改 ibias 会牵动所有 mirror（fold-free 主支路电流密度全变）
- ❌ **W_load 盲增**：增 gm_load 但 ro_load 几乎不变（短 L 主导）；mirror node cap ↑
- ❌ **加 second stage 想救 gain**：变成两级了，要重新 layout + Miller 补偿，
  不能算"Telescopic 救活"

### 边界判断（spec 不可达时）

gain target > 90 dB → Telescopic **物理不行**。直接换：
- `blocks/two-stage-ota`（gain 80-100 dB）
- gain-boosted Telescopic variant（独立章节）

---

## 失败模式 3：GBW 远低于 target（gain / PM 看似正常）

**症状**：测得 GBW << gm_target / (2π · CL)，但 gain / PM 看似合理。

### 物理因果链
```
GBW = gm_MM1 / (2π · CL)

GBW 低 ⇐ {gm_MM1 低, CL 大}
gm_MM1 低 ⇐ {Itail 小, gm/Id 太高（weak inversion）}
Itail 低 ⇐ {m_tail 没同步 sizing 结果, ibias 错}
```

### 根因可能性表

| 可能根因 | 验证 | 修复 |
|---|---|---|
| **m_tail 与 sizing 没同步**（最常见！）| `op_point_check` 看 Itail vs sizing 计算 | 同步 .cir 的 m_tail，并按密度铁律同步 bias 支路 m |
| CL 写错（spec 1pF 但 testbench 10pF）| 看 testbench `.param CL` | 校 testbench |
| gm/Id 选太高（> 18，weak inversion）| `op_point_check` 看 gm/Id | gm/Id 12-15（更深 strong inversion）|
| input pair Vov 过小 | dc_snapshot Vov_MM1 < 0.05V | 减 W_diff（让 Vov 升）|

### Anti-pattern

- ❌ **加 compensation cap 想救 GBW**：Telescopic 是单极点主导不需要补偿
- ❌ **盲 ibias ↑**：要重 check 所有 device operating point + bias 支路密度也要重算
- ❌ **只增 m_tail 不同步 bias 支路 m**：密度失配（见失败模式 1）

---

## 失败模式 4：ICMR 不够（输入共模范围窗口太小）

> **Telescopic 特有失败**（FC 有宽 ICMR，5T / 2-stage 通常 ICMR 也宽）。

**症状**：spec 要求 VCM 0.4V swing，但 telescopic 只能容 0.4-0.7V。

### 物理因果链

详见 `bias-headroom.md` 的 ICMR 紧物理约束节。简短：

```
VCM_window = VCM_max - VCM_min
           = (vbnc - 50mV) - (Vov_tail + Vth_n + Vov_diff + 50mV)
```

### 根因可能性表

| 根因 | 修复 |
|---|---|
| Vov_diff 太大 → VCM_min 高 | W_diff ↑（让 Vov_MM1 ↓）|
| Vov_tail 太大 → VCM_min 高 | W_tail ↑（让 Vov_tail ↓）|
| vbnc 太低 → VCM_max 低 | L_pad_n ↑ 或 W_pad_n ↓（让 vbnc ↑）|

### 边界判断

如果 spec ICMR 窗口 > 0.6V → **Telescopic 物理不行**。直接换 FC（fold 解耦 ICMR）。

---

## 失败模式 5：PM < 50°

**症状**：tran 仿真 ringing，AC PM 测得 < 50°。

### 物理因果链

见 `ac-stability.md` 模式 1（GBW 接近 cascode source 节点极点）。本章只列根因表 + 修复路径。

### 根因可能性表

| 可能根因 | 验证 | 修复 |
|---|---|---|
| GBW 太接近 f_p2（cascode source 节点）| 算 GBW / f_p2 ≈ ? | CL ↑ 或 W_diff ↓（trade-off：Vov_diff ↑）|
| W_cascode 过大 → cascode source cap 大 | C_cascode_source 估算 | m_cascode ↑ + W_cascode ↓（保 ro，减 cap）|
| **wide-swing 密度失配（隐性）**| 看 vbnc / vbpc 落点 | 见失败模式 1 |
| **device 不 sat**（PM 数字假象）| `dc_snapshot` region | 见 `bias-headroom.md` |
| testbench `set units = degrees` 漏 | 看 PM 数值是否在 -180 ~ 180 度 | 加 `set units = degrees` |
| Miller 补偿误加（Telescopic 不需要！）| 看是否有 Cc / Rz | 删除 |

### Anti-pattern

- ❌ **Telescopic 加 Miller 补偿**：单级不需要，且会引入 RHP zero + 主极点下移
- ❌ **dc_op 不通过时讨论 PM**：device 不 sat 时 PM 数值无意义

---

## 失败模式 6：MM1（input pair）triode

> **Telescopic 最常见 cascode bias 失败**。

详见 `bias-headroom.md` 范例 1。简短根因表：

| 根因 | 修复 |
|---|---|
| Vds(MMbnc_bot)（padding）过小 → vbnc 偏低 → V(ncasc) 偏低 → MM1 Vds 不足 | L_pad_n ↑ 或 W_pad_n ↓（**首选，单选不混用**）|
| Vdsat_MM1 自身过大（L_diff 太短）| L_diff ↑ |
| VDD 过低（< 1.5V）| 拓扑不可行 → 换 FC |

⚠️ **不要混用** L_pad_n ↑ + W_pad_n ↓，两个方向相同会过度调（一步内 ≤ 50% 改动）。

---

## 失败模式 7：MMcasc1 / MMcasc2（NMOS cascode）triode

> 与 MM1 triode **镜像症状**（vbnc 太高的副作用）。

详见 `bias-headroom.md` 范例 2。简短根因表：

| 根因 | 修复 |
|---|---|
| vbnc 推太高 → V(ncasc) 太高 → MM1 拿走太多 Vds 预算 → MMcasc 没空间 | L_pad_n ↓ 或 W_pad_n ↑（与 MM1 fix 相反方向）|

> **硬约束**：Vds(MM1) + Vds(MMcasc1) = V(vout) − V(ntail) ≈ const。padding
> 调整是在 MM1 / MMcasc1 之间**重新分配**，不能增总预算。

---

## 失败模式 8：MMcasp3 / MMcasp4（PMOS cascode）triode

详见 `bias-headroom.md` 范例 3。简短根因表：

| 根因 | 修复 |
|---|---|
| vbpc 偏低 → V(nload) 太接近 V(vout) → \|Vds_pcasp\| 不足 | L_pad_p ↓ 或 W_pad_p ↑（**与 NMOS 侧 vbnc 调整方向相反**）|

> ⚠️ **PMOS 侧 vbpc 调整方向**：
> - 想提升 |Vds_MMcasp| 或 |Vds_MM3|: vbpc ↓: L_pad_p ↑ 或 W_pad_p ↓
> - 想提升 |Vds_pcasp|（cascode 自身）: vbpc ↑: L_pad_p ↓ 或 W_pad_p ↑

---

## 失败模式 9：MM3 / MM4（PMOS mirror）triode

详见 `bias-headroom.md` 范例 4。

| 根因 | 修复 |
|---|---|
| vbpc 太高 → V(nload) 接近 VDD → \|Vds_MM3\| 不足 | vbpc ↓：L_pad_p ↑ 或 W_pad_p ↓ |

---

## 失败模式 10：MMtail 进 triode

同 5T-OTA / FC，**tail 节点电压由 input pair 决定**。详见 `blocks/5t-ota/bias-headroom`
范例 1。

修复路径：
- 增 W_diff → 减 Vov_MM1 → V(ntail) ↑（路径 A）
- 增 L_bias → 减 Vov_tail（**注意**：MMbias / MMtail / MMbn_pc 共 W/L，**同步全部改**！）

---

## 失败模式 11：output swing 不够

**症状**：tran 大信号 clipping；spec 要求 swing > 0.6V。

### 物理因果链
```
Vout_max ≈ VDD - |Vov_load| - |Vov_pcasp| - margin
Vout_min ≈ Vov_diff + Vov_ncasc + Vov_tail + margin       ← 比 FC 多一段（input pair 在 stack）
total_swing ≈ VDD - 1.0V = 0.8V @ VDD=1.8V                 ← 仅理论上限
实际典型 0.4-0.6V
```

### 修复路径

| 路径 | 怎么做 | 副作用 |
|---|---|---|
| 上行 swing | W_load ↑ + W_pcasp ↑ | mirror node cap ↑ → PM ↓ |
| 下行 swing | W_diff ↑ + W_ncasc ↑ + W_tail ↑（3 段都缩 Vov）| ro 全降 → gain ↓ |
| 接受限制 | 标 spec swing = 0.5V | 不能做更严苛 spec |
| 换拓扑 | FC（少一段 NMOS Vov）或 2-stage（rail-to-rail）| 更复杂 |

---

## 失败模式 12：cascode S/D 接反 → DC 锁死

**症状**：DC OP 完全失败，vout 卡 rail，nvg=0V。

### 修复

```
NMOS cascode (MMcasc1/2)：S=ncasc（input pair drain），D=vout（cascode high-Z）
                          → NMOS source 在低电压侧，drain 在高电压侧（电流 D→S）

PMOS cascode (MMcasp3/4)：S=nload（mirror drain），D=vout（cascode high-Z）
                          → PMOS source 在高电压侧（电流 S→D）

颠倒接法 → 反向导通 → 锁死
```

详见 `reference-design.md` connectivity rules 表。

---

## When to load this chapter

- AC / DC 仿真后 spec 不达标（任一项）
- 看到 dc_snapshot 异常（多个 device triode）→ 先看失败模式 1（密度失配）
- agent 在调 sizing 撞壁（多次试都没收敛）
- ICMR 不够 → 看失败模式 4

## Related

- **device 不 saturation**（4 处 bias 节点）→ `bias-headroom.md`（KVL/R2 推理）
- **AC 极点分析** → `ac-stability.md`
- **sizing trade-off + 同密度铁律** → `sizing-typical.md`
- **拓扑选型（Telescopic vs FC）** → `architecture.md`
- **通用诊断方法** → `skill: systematic-debugging` / `signal-tracing`
