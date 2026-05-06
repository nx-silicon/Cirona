---
chapter: current-steering
parent: differential-pair
summary: |
  差分对的大信号开关模式 —— 输入差分电压远超 ~5·Vov 让一管全开一管全关 /
  应用：DAC unit cell（电流舵）/ CML driver（高速链路）/ Mixer 切换器 /
  与小信号 diff pair 的 sizing 哲学完全不同
tokens: ~500
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/current-mirror
  - blocks/base-cells/bias-generator
---

# Current-Steering Differential Pair

## 与小信号 diff pair 的根本区别

```
                  vinp ──┬──    ──┬── vinn
                         │        │
                       ┌─┴─┐    ┌─┴─┐
                       │M1 │    │M2 │
                       └─┬─┘    └─┬─┘
                         ●────●────●  ← tail node V_t
                              │
                            ┌─┴─┐
                            │M_T│  tail current source（恒流 I_tail）
                            └─┬─┘
                              │
                            vss
```

| 模式 | 输入差分 ΔV = vinp - vinn | M1/M2 状态 | 输出电流 |
|---|---|---|---|
| **小信号**（basic chapter）| ≪ Vov（典型 < 0.2·Vov）| 都在 sat 一线性叠加 | I_d1 ≈ I_d2 ≈ I_tail/2 ± gm·ΔV/2 |
| **current-steering**（本章）| ≫ Vov（典型 > 5·Vov，几百 mV）| **一管全开 / 一管全关** | I_d1 = I_tail or 0；I_d2 = 0 or I_tail |

**根本区别**：small-signal 是 **modulation**（叠加微小扰动），current-steering 是 **switching**（一开一关，几乎数字逻辑）。Sizing 哲学不同 —— 小信号用 gm/Id 优化 noise/speed/Av；current-steering 优化**开关速度 + glitch + 电流精度**。

## 应用场景

| 应用 | 用途 | 关键 spec |
|---|---|---|
| **DAC unit cell（电流舵 DAC）** | 把单位电流"切到"输出 + 或 -（差分输出）| INL / DNL / glitch energy / settling time |
| **CML driver**（高速差分发射机）| 把数字信号 0/1 转成差分电流（驱动 50Ω 负载）| 数据率 / jitter / output amplitude / EMI |
| **Mixer switching pair**（如 Gilbert cell）| LO 信号大幅切换 RF 信号方向 | LO-IF feedthrough / mixer gain / linearity |
| **Comparator preamp 输入/输出 steering** | ΔVin 已足够大时把 tail current 近似全量导向一侧，驱动后级 latch | decision time / kickback / input capacitance |
| **SAR ADC dynamic comparator 前级** | 采样后 ΔVin 与低 Vov 输入对形成快速电流导向 | energy / delay / offset |
| **Class-AB output stage** | 大信号时把静态偏置电流导向 sourcing / sinking device | crossover distortion / slew rate / quiescent current |

**注意**：metastability 是 latch / regenerative 阶段的现象，不是 preamp 的；本章 current-steering 是把足够大的 ΔVin（≥5·Vov）转成电流导向来驱动后级 latch。comparator 主体（StrongARM / latch）见 `blocks/base-cells/comparator-latch`。

## 关键物理：tail node 动态

定义 balanced 模式（每管承载 I_tail/2）下的 Vov 为 **Vov_bal**；full-switching 时主导管承载 full I_tail，过驱抬升为 **Vov_full = √2·Vov_bal**。两个稳态：

- M1 全开 / M2 全关 时 V_t ≈ vinp - (Vth(VSB_t) + Vov_full)
- M2 全开 / M1 全关 时 V_t ≈ vinn - (Vth(VSB_t) + Vov_full)

**body effect 注**：bulk 接 VSS 时 V_t（=NMOS source 节点）抬升会改变 VSB，进而调制 Vth。低 Vov 场景（如 comparator 输入对 Vov ≈ 20-50 mV）body effect 与 Vov 同量级，不可忽略；高 Vov 场景（CML driver Vov ≈ 100-200 mV）body effect 是二阶项但仍影响 Vt 精度。

**关键**：**对固定 common-mode 的对称差分翻转**，两个 full-state 的主导管输入电压都是 V_cm + |ΔV|/2（共模不变），所以**稳态 V_t 在两个 state 几乎相同**——`V_t(full) = V_cm + |ΔV|/2 - Vth(VSB_t) - Vov_full`。

但**瞬态过程**会经过两管同时导通的 balanced 区（差分输入跨过 0 时主导管输入瞬时 = V_cm，承载 I_tail/2），此时 `V_t(balanced) = V_cm - Vth(VSB_t) - Vov_bal`。所以瞬态 V_t bounce 幅度：

```
ΔV_t(瞬态) ≈ V_t(full) - V_t(balanced)
          = |ΔV|/2 - (Vov_full - Vov_bal)
```

例：ΔV_in = 500 mV / Vov_full = 200 mV / Vov_bal = 140 mV → ΔV_t ≈ 250 - 60 = 190 mV（远大于 60 mV，与 ΔV_in/2 同量级，不能忽略）。

V_t 摆动实际综合来源：
1. **切换瞬间 overlap**（两管都活跃；瞬态 ΔV_t 主要部分，~ |ΔV_in|/2 - (Vov_full - Vov_bal)）
2. **驱动 common-mode 漂移**（vin_cm 变化直接传到 V_t）
3. **寄生电容耦合 + tail ro 调制**

所以**稳态** ΔV_t（两个 full-state 之间）不等于 ΔV_in；但**瞬态** ΔV_t 在 |ΔV_in|/2 量级，仍是 glitch 主源。

**因果**：切换瞬间的 V_t bounce → tail current source M_T 的 Vds 短时偏移 → ro_T 调制 → I_tail 短时偏离 → **glitch + 输出电流不精确**。这是 current-steering DAC 的精度核心损失源（瞬态主导，不是稳态主导）。

**应对**：
- M_T 用 cascoded current source（高 ro_T，对 V_t 摆动不敏感）
- **最小化** tail node 有效电容 C_tail_eff（不是加大！）—— τ_tail ≈ C_tail_eff/gm_on ≈ C_tail_eff·Vov_full/(2·I_tail)，电容会直接拖慢 switching 并引入 memory/ISI；常见误区"在 V_t 加 Cgs_filter 减摆"实际拖慢切换边沿
- 实际 high-speed DAC 用 latched switch driver 让 ΔV_in 边沿尽量陡 → tail glitch 时长缩短

## sizing 关系（大信号 + 速度优先）

| 量 | 推荐 | 因果 |
|---|---|---|
| Vov_M1/M2 | comparator 可到 20-50 mV；高速 DAC/CML 常取 100-200 mV | Vov 太大 → ΔV_in 要求大 + Cgs 大；Vov 太小 → W/Ctail 增大、body effect 和 mismatch 更敏感、切换瞬间 sub-threshold 行为 |
| ΔV_in（输入差分摆幅）| ≥ 5·Vov_full | 让 off 管 Vgs 低于 Vth（彻底 cut-off）；current-steering 是 switching，不是 small-signal modulation |
| L_M1/M2 | 1-2 × Lmin（**相对短**）| matching 不极致追求；速度优先（Cgs 小） |
| W (CML driver) | 由 Iload + Vov 反推 | 通常很大（10-100 µm 量级） |
| M_T sizing | cascoded + L 长（matching + 高 ro_T）| 抗 V_t glitch |
| Iout 精度（DAC unit cell）| 绝对电流误差 < 0.5 LSB（满量程 1/2^(N+1)）| 强反型近似 σI/I ≈ 2·σVth/Vov，σVth ≈ Avt/√WL → 决定 INL/DNL |

## sizing 范例（CML driver，1.25 Gb/s, 200 mV swing 单端到 50Ω, vpdk180nm）

> 📌 **@ vpdk180nm**（μn·Cox ≈ 270 µA/V²、Vth_n ≈ 0.35 V）。CML driver 在 GHz 级速率时 short-channel 工艺更常用（28nm/16nm），180nm 适合 1-2 Gb/s 区间；公式形式跨工艺通用。换工艺重新 sizing。

```
设计目标：data rate = 1.25 Gb/s（NRZ）, 单端 swing 200 mV @ 50Ω 单端负载,
          差分输出 400 mV pp differential

I_tail 计算:
  I_tail × R_load_eff = swing
  R_load_eff = 50Ω（每端 50Ω 单端 termination）
  swing = 200 mV → I_tail = 200m / 50 = 4 mA

M1/M2 sizing（按 balanced 口径选 Vov_bal）:
  Vov_bal = 0.15 V （balanced 模式下每管 I_tail/2，平衡 swing + speed）
  W/L = 2·(I_tail/2)/(μn·Cox·Vov_bal²) = 2×2m/(270µ × 0.0225) ≈ 660
  L = Lmin = 0.18 µm（速度优先；matching σ 用 Avt 估算后必要时增 L）
  W = 660 × 0.18 = 119 µm，m = 60 × W=2 µm 单 finger
  → full-switching 时主导管 Vov_full = √2·Vov_bal ≈ 0.21 V（自然抬升，W 不需翻倍）
  备选口径：若按 full-on 目标 Vov_full=0.15V 选，则 W/L≈1320 / W≈237µm（双倍面积）

ΔV_in 要求:
  让 M_off 进 cut-off：ΔV_in ≥ 5·Vov_full = 1.0 V → 实际用 0.7-1.0 V swing 来源（前级 latch）；
  若 swing 不够 5·Vov_full，driver 可能停在"半开半关"区，破坏切换精度

M_T sizing（cascoded current source）:
  I_tail = 4 mA, 选 Vov_T = 0.2V（headroom）
  W/L = 2·4m/(270µ × 0.04) ≈ 740
  L_T = 1 µm（matching + ro_T 高）
  W_T = 740 µm，m = 200 finger
  cascode 上叠 M_Tc 同 sizing，Vbias_Tc tracking

eye 估算:
  fT_M1 估算（Razavi 粗略公式 fT ≈ μn·Vov / (2π·L²)）:
    μn @ vpdk180nm ≈ 0.035 m²/(V·s)（注意 μn 与 μn·Cox 区分；μn·Cox=270µA/V² 是乘积）
    L² = (0.18 µm)² = 3.24×10⁻¹⁴ m²
    fT_bal ≈ 0.035 × 0.15 / (2π × 3.24×10⁻¹⁴) ≈ 25 GHz @ Vov_bal=0.15V
    fT_full ≈ 25 × √2 ≈ 35 GHz @ Vov_full=0.21V（实际切换瞬间主导）
    （vpdk180nm Lmin BSIM 实测在 30-50 GHz 量级）
  实测 driver 的有效 BW 受 Cgs + RC 限制；@ 1.25 Gb/s 这个 sizing 留 ~10-30× fT margin（充裕）

glitch energy（DAC 类应用关键）:
  V_t bounce 综合来源:
    - 稳态: 两个 full-state V_t 理想差 ≈ 0（共模相同时两边公式对称）
    - 瞬态（**glitch 主源**）: 经过 balanced 区，ΔV_t ≈ |ΔV_in|/2 - (Vov_full - Vov_bal)
      例: ΔV_in=500mV/Vov_full=200mV/Vov_bal=140mV → ΔV_t ≈ 190 mV（与 ΔV_in/2 同量级）
    - vin common-mode 漂移 + 寄生耦合 (二阶)
  
  tail node 加载电容（**不是** Cgs_M_T，是 drain/source 侧寄生总和；按拓扑分类）:
    无 cascoded tail source: C_tail_eff = C_sb_M1 + C_sb_M2 + C_db_M_T + C_routing
                            （tail node 直接是 M_T.drain）
    有 cascoded tail source: C_tail_eff = C_sb_M1 + C_sb_M2 + C_db_M_Tc + C_routing
                            （tail node 在 M_Tc.drain；M_T.drain 是内部节点经 cascode 隔离，
                             仅小信号下经 1/(gm_Tc·ro_Tc) 衰减贡献等效电容）
    典型 ~0.5-1 pF（远小于 Cgs_M_T，因结电容 ∝ 面积非 W·L）
    Cgs_M_T = (2/3)·Cox·W·L ≈ 4 pF 是 M_T 的 gate-source 电容（加载 bias 节点不是 tail node）
  
  charge_glitch ≈ C_tail_eff × ΔV_t(瞬态) ≈ 1p × 0.19 ≈ 200 fC（用 ΔV_in=500mV 时瞬态 bounce）
  → high-speed DAC 用 cascode M_Tc + latched switch 抑制 glitch
    （cascode 提升 ro_T 抗 V_t 调制；latched switch 让边沿陡峭缩短瞬态时长）
```

## 验证清单

- [ ] tran：单 bit 切换瞬态 → 测 t_rise / t_fall（从 10% 到 90% swing）≤ 1/(数据率 × 5) 量级
- [ ] tran：连续 PRBS 输入 → 看眼图 EH（eye height）/ EW（eye width）/ jitter
- [ ] tran：tail node V_t 摆动幅度 + 恢复时间（看 cascode M_T 是否压制 glitch）
- [ ] dc_sweep：扫 ΔV_in 看输出电流转移曲线（确认 ≥ 5·Vov 时彻底切换）
- [ ] PVT corner：FF / SS / 温度全角下数据率 spec PASS
- [ ] DAC 应用：跑 INL / DNL（unit cell matching driven）

## 常见误区

| 心里想 | 现实 |
|---|---|
| "current-steering sizing 用 gm/Id 反推" | gm/Id 是小信号方法；current-steering 是大信号开关，按 swing + I_tail + Vov 反推 W/L |
| "Vov 越大开关越快" | Vov 太大 → 切换前两管 sat 太深 → ΔV_in 要求更大 + Cgs 大；典型 100-200 mV 平衡 |
| "M_T 用基础 current mirror 即可" | V_t 稳态在两个 full-state 几乎相同（共模对称），但**瞬态**经过 balanced 区时 ΔV_t ≈ \|ΔV_in\|/2 - (Vov_full - Vov_bal)，与 ΔV_in/2 同量级（远大于 60 mV）。这个瞬态 V_t bounce 调制 M_T 的 Vds → ro_T 不够高时 I_tail 短时偏离严重 → 高精度/高速 DAC 必须用 cascoded tail source（高 ro_T）|
| "用 small-signal CMRR / Vos 公式评估" | current-steering 关心 INL / glitch / jitter，不是 CMRR / Vos；用错指标 |
| "L 用 Lmin 速度最快" | 看应用——CML driver 用 Lmin 速度最快；DAC unit cell matching 优先 → L = 2-4×Lmin |

## 不在本章范围

- 基础 small-signal diff pair 物理 → `chapter=basic`
- 配 active-load 的 5T-OTA 输入级 → `chapter=active-load`
- source-degenerated 线性化 → `chapter=source-degenerated`（pending）
- comparator latch / metastability → `blocks/base-cells/comparator-latch`
- cascoded current source（M_T 设计）→ `blocks/base-cells/current-mirror/cascoded.md` + `blocks/base-cells/cascode/basic.md`
- DAC 整体架构 / segmentation / R-2R / binary-weighted → 未来 DAC pack（不在 base_cells 范围）
- CML 链路设计（pre-emphasis / equalization / ESD）→ 未来 SerDes pack
