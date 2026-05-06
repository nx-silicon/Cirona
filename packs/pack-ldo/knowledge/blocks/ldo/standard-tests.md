---
chapter: standard-tests
parent: ldo
summary: |
  LDO 标准测试套件 — 任何 LDO 设计必须跑完整测试集才算"验证"：
  Line-regulation / Load-regulation / AC loop gain（多 Iload）/ PSRR / Transient。
  含 testbench 配置硬约束（AC log-spaced sweep、Line ±10%、@0mA 最小负载、
  vp() 度数、Tran reference 用 V_pre_step）+ 每项的 pass criterion。
  Iron Law: LDO 验证缺这其中任一项都属于"未完成"。
tokens: ~1100
prerequisite_chapters:
  - reference-design
  - architecture
related_skills:
  - ac_feedback_loop_method
  - signal-tracing
related_knowledge:
  - simulators/ngspice
  - pdks/vpdk180nm
---

# LDO 标准测试套件（Standard Test Suite）

## Iron Law

任何 LDO 设计**必须**跑完下列 P0 全集才算"验证完成"。**缺任一项 = 未验证**：

1. DC OP（多个 Iload 工作点 + **必含 @0mA**）
2. AC loop gain（**必须 log-spaced Iload sweep 覆盖 light → heavy**）
3. Line regulation（**±10% Vin 范围**）
4. Load regulation（**必含 @0mA 验证最小负载支路**）
5. PSRR（多频点）
6. Tran load step（多 slew rate）

LDO 设计常见的"看起来 work" 假象（如 @10mA nominal PASS）通常掩盖了边界缺陷（@0mA 漂、@light-load 失稳、Vin 边沿失调）。**只测一个工作点 = 没测**。

---

## P0 必测项（不通过不得发布）

| 测试 ID | 测试名 | 关键测量量 | Pass Criterion |
|---|---|---|---|
| **LDO-T1a** | DC OP @nominal Iload | 所有器件 V_ds_margin | 全部 SAT，margin > 50mV |
| **LDO-T1b** | DC OP **@Iload=0** | Vout，Vg_pass | Vout ∈ [Vnom ± 1%]（**输出级必须有最小负载支路**——见 §设计规则）|
| **LDO-T1c** | DC OP @Iload=Imax | MP V_ds_margin | MP margin > 0；否则 W_pass 不足或 dropout 不够 |
| **LDO-T2a** | AC Loop Gain @ light load（≤ Iq）| dc_gain，UGF，PM，fp1 | dc_gain ≥ 60 dB；PM > 45° |
| **LDO-T2b** | AC Loop Gain @ Iload sweep（**log-spaced**） | PM、UGF 趋势 | 全 Iload 点 PM > 45°（除明确越界点）|
| **LDO-T2c** | AC Loop Gain @ Imax | PM | PM > 45° |
| **LDO-T3** | Line Regulation（**Vin ±10%**） | ΔVout/ΔVin (mV/V) | < 5 mV/V（典型） |
| **LDO-T4** | Load Regulation（**0 → Imax**，含 @0mA）| ΔVout，**Vout @0mA**| @0mA Vout ≠ Vdd（关键 bug 检查）；< 1% Vnom |
| **LDO-T5a** | Tran 加载阶跃（slow + fast 边） | undershoot，settle time | 依 spec |
| **LDO-T5b** | Tran 卸载阶跃（slow + fast 边） | overshoot，settle time | 依 spec |

### 关键 sweep 范围约定

| 测试 | 错的范围 | 对的范围 | 原因 |
|---|---|---|---|
| **LDO-T2 AC sweep** | `[10mA, 20mA, 30mA]`（都集中在大电流）| **`[0µA, 10µA, 100µA, 1mA, 10mA, Imax]`**（log-spaced）| 大电流不暴露 light-load 失稳；很多 LDO 在 quiescent 点 PM 边界，必查 |
| **LDO-T3 Line reg** | `Vin = 1.6V → 2.0V`（1.6V 接近 dropout，失真）| **`Vin = 0.9·Vnom → 1.1·Vnom`**（如 1.62V → 1.98V）| 进入 dropout 边界后 Vout 已脱调，line reg 数据无意义 |
| **LDO-T4 Load reg** | `[10mA, 30mA]`（漏掉 @0mA）| **`[0, 10µA, 100µA, 1mA, ..., Imax]`**（必含 @0mA）| @0mA 是经典 bug 工况：缺最小负载支路时 Vout 会漂到 Vdd |

---

## P1 推荐测试（产品级）

| 测试 ID | 测试名 | 关键测量量 |
|---|---|---|
| LDO-T6 | PSRR @ multiple frequencies | PSRR(dB) @ DC / 1kHz / 10kHz / 100kHz / 1MHz |
| LDO-T7 | 温度扫描 -40 / 27 / 125°C | Vout 漂移、PM、Iq |
| LDO-T8 | Process corners（TT/SS/FF/FS/SF）| 全 corner DC OP PASS、PM > 45° |
| LDO-T9 | Monte Carlo（mismatch + process） | Vout σ、PM 分布（3σ 不破 spec）|
| LDO-T10 | Dropout 边界（Vin = Vout + Vdrop_min）| MP V_ds_margin、loop 是否仍在调节 |
| LDO-T11 | 启动仿真（Vin 0 → Vnom ramp） | 启动时间、无 latch-up、无振荡 |
| LDO-T12 | 负载越界压力测试（Iload = 1.5–2× Imax）| 失效模式（MP triode? loop 断?） |

---

## Testbench 配置硬约束（Hard Conventions）

下列约定不是"建议"，是**任何 LDO testbench 必须遵守**的硬约束。违反任一项 → 数据不可信。

### Conv-1: AC 断环用 Method C（Rfb=1G + Cfb=1F + Vac）

```spice
* DC closed via Rfb（让环路 DC 解算正常）
Rfb  vfb_inj  vfb  1G
* AC opened via Cfb 接地（高频信号被旁路）
Cfb  vfb  0  1
* AC injection
Vac  vfb_inj  0  AC 1
```

> 数学上 1G+1F 让 fc = 1/(2π·Rfb·Cfb) ≈ 0.16 nHz，远低于任何 LDO band → DC 闭环 / AC 全开。详细推导见 skill `ac_feedback_loop_method`。

### Conv-2: vp() 单位明示为度数

```spice
.control
  set units = degrees    ← 必须！否则 vp() 返回弧度，PM 计算错 57×
  ac dec 50 1 1G
  ...
.endc
```

> ngspice 默认 vp() 返回弧度，没显式声明 → PM 数值乘 180/π，看起来 178° 实际 3°。**LDO v3 实测踩过这个坑**。

### Conv-3: PM 公式用锚点差值法

```spice
let phase_deg = vp(vfb) - vp(vfb_inj)
meas ac phase_dc      find phase_deg at=1
meas ac phase_at_ugf  find phase_deg when gain_db=0 cross=1
let pm_deg = 180 - (phase_dc - phase_at_ugf)
```

或等价的：`pm_deg = 180 + phase_at_ugf`（前提 phase_dc ≈ 0°）。**锚点差值法对 phase 符号约定无关**，更稳健。

### Conv-4: Tran reference 用 V_pre_step（不用 nominal）

```spice
* 错的：reference 用 spec target（如 1.2V）
.meas tran undershoot trig v(vout) val=1.2 cross=1 targ ...

* 对的：reference 用 pre-step DC 稳态值
.meas tran v_pre find v(vout) at=4u    ← step 之前的稳态采样
.meas tran v_min  min v(vout) from=5u to=10u
.meas tran undershoot param='v_pre - v_min'
```

> Vout 在 nominal 工况下不会精确等于 Vref（loop 解算到稳态有 mV 级 offset），用 nominal 1.2V 作 reference 会引入伪偏移。

### Conv-5: @0mA 测试 testbench 直接置 Iload=0（subckt 内部 R-divider 自带 Ibleed）

```spice
* 标准 LDO subckt 内置 R1+R2 divider → divider 自带 Ibleed = Vout/(R1+R2)
* testbench @0mA 测试只需置零外部 Iload，验证 LDO 在仅 Ibleed 工况下能否调节
Iload  vout  0  DC 0
* 如果 Vout 漂到 Vdd → LDO subckt 缺 R-divider（违反 Rule 1）
* 如果 Vout = Vnom → divider Ibleed 充当最小负载，LDO 正常调节 ✓
```

> 这是典型 LDO 设计 bug 的"金丝雀"——`@0mA Vout = Vdd` 暴露 LDO subckt **缺 R-divider**（违反 Rule 1）。**Ibleed 必须由 subckt 内部 R1+R2 提供**，而不是依赖外部测试条件或独立 M_bleed 管子（详见 §设计规则 Rule 1）。

### Conv-6: Dropout 边界 sweep 方向

```spice
* 错的：从 Vin_nominal 向下 sweep
.dc Vvdd 1.8 1.4 -0.05  ← 反向 sweep 起点已饱和，找不到边界

* 对的：从 Vout 上方向上 sweep
.dc Vvdd 1.25 1.8 0.01  ← 正向 sweep 找出 Vout 开始脱调的 Vin
```

### Conv-7: 越界压力测试用 challenge_dv_verdict 旁路 DV RED

某些测试明确是越界压力（如 Iload = 2× Imax 看失效模式），simulate 后 DV verdict 会标 RED（pass FET triode）。这是**预期失败**，用 V4 物理审查工具 `challenge_dv_verdict(reason='deliberate over-range stress test')` 旁路 latch，继续后续测试。

---

## 设计规则（Design Rules，必须满足）

### Rule 1 (LDO IRON LAW): R-divider 必须在 LDO subckt 内部 + Ibleed 由 divider 提供

PMOS-pass LDO 在 Iload → 0 时 pass FET 关断，Vout 节点失去下拉路径 → Vout 漂到 Vdd（loop 失调）。**所有 LDO 必须在输出级有静态最小负载**。

#### 标准做法（默认实现）：subckt 内部 R1+R2 divider 自带 Ibleed

```spice
.subckt my_ldo  vdd vss vout ibias vref     $ NOTE: vfb 不在 port list，是内部节点
+ params: R_R1=6k R_R2=18k ...
*   ... EA + pass + comp ...
*   Feedback divider INSIDE subckt (Iron Law)
R1  vout  vfb  {R_R1}
R2  vfb   vss  {R_R2}
.ends my_ldo
```

R1+R2 同时实现两个功能：
1. **Vout 比例**：Vout = Vref × (R1+R2)/R2（loop 调节使 vfb=vref）
2. **Ibleed**：Vout/(R1+R2) 作为静态最小负载，pass FET 至少要驱动这个电流，不会进 cutoff

**有 R-divider 时不需要独立 M_bleed**——divider 自带的 Ibleed 已经满足 Rule 1。

#### 设计流程（必须按此顺序，不能反推）

```
Step 1: 选 Ibleed
  - 由 (a) 整体 Iq budget（如 total Iq < 100µA），(b) 光载 gm_pass 要求决定
  - 典型范围 Ibleed ∈ [10µA, 100µA]

Step 2: 算 R_total
  R_total = R1 + R2 = Vout / Ibleed

Step 3: 分 R1/R2 比例
  R2 / (R1+R2) = Vfb / Vout = Vref / Vout
  → R1 = R_total × (1 − Vref/Vout)
  → R2 = R_total × (Vref/Vout)
```

#### ❌ 反过来的错误流程（不要这样做）

```
拍脑袋选 R1=10kΩ, R2=30kΩ → 得到 Ibleed = Vout/(R1+R2) = 1.2V/40kΩ = 30µA
```

这样做的问题：Ibleed 是被 R1/R2 拍脑袋值决定，可能不符合 power budget 或 light-load gm_pass 要求。**Ibleed 是设计输入，R1+R2 是设计输出**。

#### 例外情况：M_bleed 用于 unity-feedback / divider-less LDO

只有当 LDO **没有 R-divider**（少数 capless LDO 或 unity-feedback 拓扑，Vout = Vref 直连），才需要独立 M_bleed 管子提供下拉电流。这时 M_bleed 接法用 mirror Mbias：

```spice
* fallback only when no divider exists
M_bleed  vout  ibias  vss  vss  nch  W=W_bias  L=L_bias  m=m_bleed
* I_bleed = I_Mbias × m_bleed (精确可控)
```

**核心原则**：任何支路电流必须**可控**——divider 由 R1+R2 决定（精确电阻分压），M_bleed 由镜像 Mbias 决定（精确电流镜像）。**绝不能用 Vref/Vdd 直接接 gate**（电流随工艺/温度大幅漂移，不可控）。

### Rule 2: Bleeder 电流预算（Ibleed 选型指南）

| Iload_nominal | I_bleed 推荐范围 | 占比 |
|---|---|---|
| 1 mA | 50–100 µA | 5–10% |
| 10 mA | 100–500 µA | 1–5% |
| 100 mA | 200–1000 µA | 0.2–1% |

> Bleeder 太小 → light-load 调节失效；bleeder 太大 → Iq 严重超 spec。**典型平衡点：bleeder ≈ Imax 的 1–5%**。

### Rule 3: AC sweep 必须覆盖 light + heavy 两端

很多 LDO 在 light-load（≤ 100µA）极限稳定（PM 60–80°），在 heavy-load 边界（接近 Imax）PM 退化。**只测中间点会漏失 light-load 失稳风险**——某些拓扑（特别是 capless / FVF）light-load 反而不稳。

### Rule 4: Line reg 范围必须在 LDO 工作范围内

Line reg sweep 起点必须 > Vout + Vdrop_min + safety margin（典型 +100mV）。否则进入 dropout 边界 Vout 已脱调，line reg 数据失真。**标准选择：±10% Vin_nominal**。

---

## When to load this knowledge

- 任何 LDO 设计跑测试前（**强烈推荐 simulate 之前 load**）
- 调试 LDO 数据看起来"正常但有 bug"（如 nominal PASS 但边界 FAIL）
- 评估 LDO testbench 是否完整（缺哪些测试 / 哪些 sweep 范围错了）
- 写新 LDO testbench 时（用作模板）

## When NOT to load

- 不是 LDO（开关电源 / charge-pump）
- 已经跑完所有 P0 + P1 测试，只在调具体某项细节时（直接用对应 chapter，如 `psrr` / `overshoot`）

## Related

- **`reference-design`** — 标准 LDO 网表（PMOS-pass + 多 EA 拓扑）+ 标准 testbench 复用路径
- **`ac-stability`** — AC PM/GBW 详细分析、Miller 补偿原理
- **`psrr`** — PSRR 频段特性、shape sanity check、根因诊断
- **`overshoot`** — 负载瞬态过冲、EA slew 计算、Cload trade-off
- **Skill `ac_feedback_loop_method`** — Method A/B/C 断环对比、断点选择
- **Knowledge `simulators/ngspice/analyses`** — `.ac` / `.tran` / `.meas` 卡片细节、vp() 弧度坑

## 不属于本章范围

- 具体 LDO 拓扑选型（PMOS / NMOS pass、5T / cascode / 双级 EA、FVF）→ `architecture`
- 具体网表实现（subckt 端口、bias chain）→ `reference-design`
- 具体 PSRR/overshoot 物理因果链 → `psrr` / `overshoot`
- ngspice 语法细节 → `simulators/ngspice/*`
- 通用 AC 断环理论 → skill `ac_feedback_loop_method`

---

## 测试套件 checklist（写报告时复制）

```markdown
## LDO 验证完成度（P0 必测）

- [ ] LDO-T1a DC OP @nominal — 所有器件 SAT，margin > 50mV
- [ ] LDO-T1b DC OP **@0mA** — Vout 在 Vnom ± 1%（非 Vdd！验证最小负载支路）
- [ ] LDO-T1c DC OP @Imax — MP margin > 0
- [ ] LDO-T2 AC Loop Gain — Iload = [0µA, 10µA, 100µA, 1mA, 10mA, Imax]，全部 PM > 45°
- [ ] LDO-T3 Line Reg — Vin ±10% 范围，< 5 mV/V
- [ ] LDO-T4 Load Reg — 0 → Imax，**包含 @0mA**，< 1% Vnom
- [ ] LDO-T5 Tran — 加载 + 卸载 step，slow + fast 边
- [ ] LDO-T6 PSRR — 多频点（DC / 1kHz / 10kHz / 100kHz / 1MHz）
```
