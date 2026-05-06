---
chapter: bias-headroom
parent: class-ab-ota
summary: |
  ⭐ Class-AB OTA 拓扑特有的 quiescent-current control + Vds/Vdsat 物理约束 +
  R1 KVL 反推 + R2 floating bias 锁定铁律 + 失稳调整范例。核心范例：(1) IQ
  失控（floating bias 接错）；(2) Crossover distortion（IQ 太小 → dead zone）；
  (3) Output PMOS triode（rail 摆动时）；(4) Stage1 v1_out 跑 rail（跨级耦合）。
  这是 class-AB 灵魂章 — push-pull static bias 是设计核心。
tokens: ~2200
prerequisite_chapters:
  - reference-design
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/output-stage
  - blocks/5t-ota
---

# Class-AB OTA Bias & Headroom Reasoning

> 通用 vds-vdsat 推理范式见 `skill: device-sizing`（W6+ R1-R4 铁律）。
> Class-A 2-stage 对照见 `blocks/two-stage-ota/bias-headroom`。
> 本章节给的是 **class-AB 拓扑特有的 quiescent-current control 物理**与
> 失稳调整顺序。**这是 class-AB 设计灵魂**：output stage 的 IQ 不由单管 Id
> 直接决定，而是由 floating bias VGP - VGN 锁定，理解这个机制是修任何 IQ
> 失控 / crossover distortion 的前提。

## Quiescent Current Control（**class-AB 灵魂物理**）

```
Output stage push-pull static state（vinp = vinn = VCM）：
  V(vout) ≈ VCM (差分关闭，对称稳定)
  
  MP_ab_out (PMOS pull-up):
    Vsg_p = VDD - VGP                                  ← VGP 来自 floating bias
    Id_p = µp·Cox · W_p·m_p / L · (Vsg_p - |Vth_p|)² / 2
  
  MN_ab_out (NMOS pull-down):
    Vgs_n = VGN                                        ← VGN 来自 floating bias
    Id_n = µn·Cox · W_n·m_n / L · (VGN - Vth_n)² / 2
  
  KCL at vout: Id_p = Id_n + I_load
  无 load 时：Id_p = Id_n = IQ_quiescent
  
  → IQ = function(VGP, VGN)
       = µp·Cox·W_p·m/L · (VDD - VGP - |Vth_p|)² / 2
       = µn·Cox·W_n·m/L · (VGN - Vth_n)² / 2
```

**关键事实**：output W/L/m 固定时，IQ_quiescent 由 VGP / VGN 与 output sizing
共同决定；**VGP / VGN 是 floating bias 链锁定的工作点**，调试优先看它们。

### Floating bias 链如何锁 VGP / VGN

⚠️ MP_ab_src / MN_ab_src 的 **gate 决定电流**，**drain 是 floating node VGP/VGN**，
不能闭式 `VDD-(Vth+Vov)` 求。VGP/VGN 由 KCL 平衡（src 电流 = floating mid chain
电流）+ middle device Vgs 约束联立决定。Floating chain 强制 VGP-VGN 差值
≈ const over PVT（self-bias loop），典型 ≈ 0.4V at 27°C TT（仿真实测）。

### IQ_quiescent 数值估算

V4 baseline @ vpdk180nm 实测：V(VGP) ≈ 1.10-1.15V / V(VGN) ≈ 0.70-0.75V →
Vov ≈ 0.18-0.25V → IQ ≈ 50-100 µA per device。**用 dc_op 实测，不要闭式推算**。

> **R2 Floating Bias 锁定铁律**：**改 ibias / Stage1 / vbias_n 任一项 →
> VGP - VGN 之差变化 → IQ 大幅度漂**。**class-AB 设计的 R2 不是镜像约束**
> （5T 那种），而是 **floating bias 链同步铁律**：所有 floating bias 链上
> 的 device 必须按比例同步 sizing。

## 每个器件的 Vds 物理因果（KVL 反推）

| 器件 | Vds 公式（KVL）| 调节路径 |
|---|---|---|
| **MP_ab_out**（PMOS pull-up）| \|Vds_MP_out\| = VDD - V(vout) | quiescent: \|Vds\| ≈ VDD/2；信号 swing 时极端 |
| **MN_ab_out**（NMOS pull-down）| Vds_MN_out = V(vout) | quiescent: Vds ≈ VDD/2；信号 swing 时极端 |
| **MP_ab_src**（input PMOS, G=v1_out）| \|Vds\| = VDD - V(VGP) | 由 Stage1 v1_out 静态 + floating bias 决定 |
| **MN_ab_src**（input NMOS, G=vbias_n）| Vds = V(VGN) | 由 vbias_n + floating bias 决定 |
| **MP_ab_mid**（middle PMOS, floating）| \|Vds\| = V(VGP) - V(VGN) | floating bias 之差，~ 0.42V |
| **MN_ab_mid**（middle NMOS, floating）| Vds = V(VGP) - V(VGN) | 同上对侧 |
| **MP/N_ab_mid_top/bot**（vmid generators）| stacked diode | 永远 sat（diode）|
| **Stage1 各管** | 同 5T-OTA / 2-stage class-A | 见 `blocks/5t-ota/bias-headroom` |

## ⭐ 范例 1：IQ 失控（floating bias 链失配）

> ⭐ **class-AB OTA 最常见的 silent failure**——`.op` 不报错，IQ 数值偏几倍才暴露。

### 症状
spec：IQ_quiescent ≈ 100 µA per output device。
实测：IQ_p = 800 µA / IQ_n = 5 µA（极不对称）；或 IQ_p = IQ_n = 5 mA（极大）；
或 IQ_p = IQ_n = 1 µA（极小，crossover 风险）。

```
inspect_node('VGP', 'VGN'):
  V(VGP) = 1.05V  ← 偏 (设计 1.12V)
  V(VGN) = 0.85V  ← 偏 (设计 0.70V)
  → VGP - VGN = 0.20V (偏 0.42V 设计值)
  → Vov_p / Vov_n 漂 → IQ 不对
```

### R1 KVL 反推 — VGP / VGN 由什么决定？

MP_ab_src `Vsg = VDD - v1_out` 决定 `Id_MP_src`；MN_ab_src `Vgs = vbias_n` 决定
`Id_MN_src`。但 **VGP / VGN 是 floating drain 节点**，由 KCL 联立 floating chain
（`Id_MP_src = Id_MP_ab_mid = Id_MN_ab_mid = Id_MN_src`）+ middle device Vgs
约束求出，**不能闭式从 (Vth + Vov) 单步算出**。

**问题源头**：floating bias 链上任一 device 的 W/L 与设计 mismatch（在同电流密度
下 Vgs 偏移）→ VGP - VGN 之差变 → IQ 大幅漂。

### 三条调节路径

| 路径 | 修复 | 优先级 |
|---|---|---|
| A 修 floating bias 链 sizing | MN_ab_bias2/3 与 MN_bias 同 W/L；MP_ab_bias1/2 严格相同；vmid 4 管 stacked diode 接对；MP_ab_src vs MN_ab_src W 比例 ≈ μn/μp | ⭐ 首选 |
| B 修 Stage1 偏置 | Stage1 mirror imbalance（MP1/MP2/MN1/MN2 sizing typo）→ v1_out 偏 → VGP 偏。见 `blocks/two-stage-ota/bias-headroom` 范例 1 | 跨级耦合 |
| C 调 vmid 链 generator | 改 W_ab_mid_top/bot 比例（多变量耦合，不直接调）| 万不得已 |

### R2 Floating Bias 锁定铁律 ⭐⭐⭐

class-AB 的 R2 与 5T / cascode 的 R2（镜像不直接调本管 W/L）**不同**——
class-AB 的 R2 是 **floating bias 链同步铁律**：

```
floating bias 链上 N 个 device，每个 Vgs 由（Id, W/L）决定。
在同电流密度（同 Id/(W·m/L)）下 Vgs 近似不变 → VGP - VGN 之差稳定。

铁律：
  1. 改 ANY ONE device W/L 而其它不动 → 该 device Id/(W·m/L) 变 → Vgs 漂
     → VGP - VGN 改 → IQ 大幅漂
  2. 整链按比例缩放（同 m 倍数 + 同 W/L scaling）→ 同密度 Vgs 不变
     → VGP - VGN 不变 → IQ 保持
  3. 不能单独用 output device W 校 IQ；output W 进入 IQ square-law 但
     VGP/VGN 不变时改 IQ 的方向是次级
```

> **CMOS 设计本质**（class-AB 强化版）：output stage 的 IQ 主导因子是
> floating bias 链锁定的 VGP-VGN，output W/m 是次级 scaling。**调 IQ 优先
> 从 floating bias 链 sizing 同步入手**，不是单调 output device W。

### R3 推理路径（agent 应该走的完整链）

```
看到 IQ 失控
  ↓
inspect_device(MP_ab_out, MN_ab_out): 看 Id 偏方向
  ↓
inspect_node('VGP', 'VGN'): 看是否在设计点（1.12V / 0.70V）
  ↓
inspect_node('vmid_p_ab', 'vmid_n_ab'): 看 generator 输出
  ↓
inspect_node('v1_out'): 看 Stage1 静态点（应 ≈ VDD/2）
  ↓
判定根因：
  - v1_out 偏 → Stage1 mirror imbalance → 路径 B（修 Stage1）
  - v1_out 对，但 VGP / VGN 偏 → floating bias 链失配 → 路径 A
  - VGP / VGN 对，但 IQ 偏 → output device W·m 错或工艺漂 → 重 sizing
```

### 不要做（anti-pattern）

- ❌ **直接调 W_MP_ab_out 想"对准"IQ**：MP_ab_out 的 W 不锁 IQ；IQ 由 VGP 锁
- ❌ **加 ibias 想"提"IQ**：ibias 改变 vbias_n → MN_ab_src 和 vmid_*_ab 链
  整体偏 → VGP - VGN 漂 → 不一定 IQ ↑（可能反向）
- ❌ **跳过 Stage1 验证直接调 Stage2**：v1_out 偏是常见根因
- ❌ **加理想电压源压 VGP / VGN**：违反 self-bias 设计原则；PVT 不能 track

---

## ⭐ 范例 2：Crossover distortion（IQ 太小 → dead zone）

> **class-AB 与 class-B 的核心差异**——class-AB IQ > 0 避免 dead zone，
> class-B IQ = 0 引入 dead zone（信号过零附近 PMOS / NMOS 都 off）。

### 症状
tb_dynamic FFT 测 THD-3 偏大（> -50 dB）；tran 阶跃响应在 vout = VCM 附近
有明显非线性扭曲；IQ 实测 < 30 µA（设计 100 µA）。

### 物理因果链
```
crossover 物理：信号通过时 v1_out 摆动 → VGP / VGN 同步摆动（floating bias
锁差）→ 一边 PMOS overdrive ↑（推电流），另一边 NMOS overdrive ↓（cutoff）
→ push-pull 推挽输出。

注意：vout 摆动改变的是 output device 的 Vds（不是 Vgs/Vsg）。导通重叠由
VGP / VGN 的同步摆动决定，不是 vout 直接改变 output gate-source。

正常 class-AB：
  IQ_quiescent ≥ I_crossover_threshold（V4/vpdk180nm baseline 约 50 µA/device）
  → 在 crossover 区域（信号过零附近）PMOS / NMOS 都微导通
  → 输出 g_m = (gm_p + gm_n) 连续，无 dead zone
  
crossover 失败：
  IQ_quiescent 过低（< 30 µA in vpdk180nm baseline）→ crossover 区 gm_p + gm_n 极低
  → output stage 几乎 disconnected from input → THD-3 主导
```

### R1 KVL 反推
```
Crossover threshold IQ_critical：
  当 vout 信号过零附近时，MP 减小到 sub-threshold，MN 反向同理
  设计目标：IQ_quiescent ≥ 5 × IQ_critical（留 5× margin for PVT）

Crossover 物理：
  Vov_p_static = VDD - VGP - |Vth_p|
  Vov_n_static = VGN - Vth_n
  
  要 IQ_quiescent ≥ 50 µA / device → Vov_static ≈ 0.18-0.20V
  Vov < 0.10V → IQ < 30 µA → crossover 风险
```

### 修复路径
| 路径 | 怎么做 | 副作用 |
|---|---|---|
| 增 IQ（floating bias 调）| Vov_static ↑ → IQ ↑ | static power ↑ |
| 增 W·m_output | gm_AB ↑ → crossover 区域 transition 平滑 | parasitic cap ↑ → PM 紧 |
| Output devices L 选 short | gm/Cgs 高 → fT ↑ → crossover transit 快 | drive 不变（W·m 主导）|
| 减 spec THD 要求 | 接受 -50 dB THD | 不能做 high-fidelity audio |

> **R2 铁律**：crossover 不是 sizing typo —— 是 IQ_quiescent 设计起点过低。
> spec THD < -60 dB 时，**V4 baseline 约需 IQ ≥ 100 µA per device**；这不是
> vpdk180nm 普适物理下限，需随 output W/m + load + signal swing + THD spec
> 重新仿真验证。

---

## ⭐ 范例 3：Output PMOS triode（rail-to-rail swing 极限）

### 症状
tb_drive 测 vout swing 到 VDD - 0.1V（接近 rail）时 I_out_max 不够；MP_ab_out
进 triode：

```
inspect_device(MP_ab_out) at vout = 1.7V:
  region: triode
  |Vds_MP| = VDD - V(vout) = 0.10V
  |Vdsat_MP| ≈ 0.18V
  margin = -80 mV
```

### R1 KVL 反推
```
|Vds_MP_out| = VDD - V(vout)
当 vout → VDD → |Vds_MP| → 0 → triode

物理上：rail-to-rail output 极限就是 |Vov_MP_out| + 50 mV margin
  vout_max = VDD - |Vov_MP_out| - 50 mV ≈ VDD - 0.25V = 1.55V
```

### 调节路径
| 路径 | 怎么做 | 副作用 |
|---|---|---|
| 减 |Vov_MP_out|（增 W·m）| W·m ↑ → 同 Id 下 Vov ↓ | parasitic cap ↑ |
| 接受 swing 限制（vout_max = 1.55V）| 标 spec | 不能做 0V → VDD 极限 |
| 加 boost charge pump（特殊）| extreme rail-to-rail | 复杂度大 ↑ |

> **rail drive 物理边界**：common-source class-AB output stage **没有 cascode**，
> rail 极限不是 cascode bias 约束，而是 saturation 约束：
> 
> - 上摆极限：`vout_max ≈ VDD - |Vov_MP_out| - margin`（保 MP_ab_out saturation）
> - 下摆极限：`vout_min ≈ Vov_MN_out + margin`（保 MN_ab_out saturation）
> - 进入 triode 后 drive 仍存在但 gm/drive 下降；不是"完全不能 rail"。
> - 要更纯 rail（如 < 50 mV）需 boost charge pump（增 Vsg/Vgs over rail）。

---

## ⭐ 范例 4：Stage1 v1_out 跑 rail（跨级耦合）

V(v1_out) 偏 VDD/2 → VGP / VGN 全偏 → IQ 失控。修复：先验 Stage1 mirror
（MP1/MP2 / MN1/MN2 W/L typo；MP1 G=D=v1_n diode；MP2.G=v1_n mirror）。
详见 `blocks/two-stage-ota/bias-headroom` 范例 1。

---

## Headroom 设计原则（class-AB 特定）

- v1_out 静态 = VDD/2（Stage1 mirror feedback）→ 决定 Stage2 floating bias 起点
- VGP 静态 ≈ VDD - 0.7V；VGN 静态 ≈ 0.7V → VGP - VGN ≈ 0.4V → IQ 50-150µA
- vmid_p_ab ≈ VDD - 1.0V；vmid_n_ab ≈ 1.0V（stacked diode 起点）
- Vov_output 静态 ≈ 0.18-0.20V；Output L = Lmin 或 0.5µm（drive 优先）
- Output W_p / W_n ≈ μn / μp ≈ 2-3（IQ 对称 + SR± 对称）
- IQ ≥ 50 µA per output device（避 crossover）
- Cc / CL ≈ 0.5-1（class-AB 比 class-A 0.25-0.30 大）

## 配套工具

`inspect_device(MP_ab_out, MN_ab_out)` 看 IQ；`inspect_node('VGP', 'VGN',
'vmid_p_ab', 'vmid_n_ab', 'v1_out')` 验 floating bias 链；`propose_knob`
排旋钮。详见 `skill: device-sizing` W6+ 通用 sizing 流程。

## When to load this chapter

IQ 失控 / THD 大 / max drive 不达标 / Stage1 跨级耦合 / output triode 任一情况。

## Related

- `skill: device-sizing` W6+ 通用 sizing 流程 + R1-R4 铁律
- `blocks/two-stage-ota/bias-headroom` 2-stage class-A 跨级耦合对照
- `blocks/base-cells/output-stage` class-A vs AB vs B 物理
- `sizing-typical.md` Phase B floating bias 链 sizing
