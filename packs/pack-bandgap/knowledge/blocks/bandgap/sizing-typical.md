---
chapter: sizing-typical
parent: bandgap
summary: |
  PNP first-order Brokaw bandgap 顶层 spec → device 约束的因果链 + 拓扑特定
  推进顺序（**严格 4-step recipe**：N → I_PTAT → R1 → R2（zero-TC 比例）→
  R_OUT → mirror sizing；OTA + startup 平行做）+ 起点表（@vpdk180nm）+
  trade-off 表。引用 architecture zero-TC 推导 + base-cell 单 device 物理。
tokens: ~1500
prerequisite_chapters:
  - architecture
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/current-mirror
  - blocks/5t-ota
  - blocks/base-cells/miller-compensation
---

# Bandgap Sizing Typical Ranges

> 通用 sizing 方法见 `skill: device-sizing`。zero-TC 物理推导（`R2/R1 ≈ 12 for N=8`）见 `architecture.md` § zero-TC 条件。
> 本章节给的是 **PNP first-order Brokaw bandgap 拓扑特有**的：(1) spec → device 约束传递；(2) 4-step closed-form recipe；(3) OTA / startup 平行 sizing；(4) 起点表（@vpdk180nm）。

## 顶层 spec → device 约束（拓扑特定因果链）

| Bandgap spec | 决定的 device 量 | 关键公式 |
|---|---|---|
| Vref @ 27°C | (I_PTAT + I_CTAT) × R_OUT | I_PTAT = VT·ln(N) / R1；I_CTAT = Vbe / R2 |
| Iq budget | 3 mirror leg + OTA + startup | 3 × I_branch + Iq_OTA + Iq_startup |
| TC（first-order）| R2/R1 比例 + resistor TC | R2/R1 = \|∂Vbe/∂T\| / (ln(N)·k/q) ≈ 12 for N=8 |
| PSRR | OTA gain × mirror ro | mirror L 决定 ro；OTA gain 由 sizing |
| Line reg | OTA gain × mirror ro | 与 PSRR 同源 |
| Startup time | W_KICK + R_START + 主 loop ramp | tb_startup tran 验证 |
| PNP area ratio N | ΔVbe = VT·ln(N) | 默认 N=8（area + matching trade-off）|

## 拓扑特定的 4-step recipe ⭐（**Brokaw bandgap 标准设计流程**）

> 通用 sizing 流程见 device-sizing skill。本节给 **PNP first-order
> bandgap 拓扑特有**的 4-step closed-form recipe——**严格顺序**：N 是 area
> 约束先定，I_PTAT 是 power 约束次定，R1 / R2 / R_OUT 都从此推。OTA + startup
> 与主 4 步**平行**做。

### Step 1 — 选 N（PNP area ratio）

```
N 决定 ΔVbe = VT·ln(N) 大小：
  N=4  → ΔVbe = 36 mV @ 27°C → R2/R1 比例 16.8
  N=8  → ΔVbe = 54 mV @ 27°C → R2/R1 比例 11.2-12  ⭐ 默认
  N=16 → ΔVbe = 72 mV @ 27°C → R2/R1 比例 8.4

trade-off：
  - N ↑ → ΔVbe ↑ → R1 可减（同 I_PTAT），但 PNP 总 area ↑
  - N ↓ → R1 增大（占面积）+ matching 退化
```

**起点 N=8**（行业标准），N=4 / 16 仅在 area 极端约束时调整。

### Step 2 — 选 I_PTAT（power budget）

```
I_PTAT 起点：2-5 µA per leg
  Iq_total = 3 × I_PTAT (mirror) + 3 × I_CTAT (mirror leg) + Iq_OTA
  典型 25-40 µA → I_PTAT ≈ 3-4 µA per leg

起点 I_PTAT = 3.6 µA（@vpdk180nm V3 baseline，对应 Iq ≈ 25 µA）
```

> **注意**：bandgap 不需要大 I_PTAT。loop BW 限制在 kHz 级（mirror parasitic
> 主导），过大 I 浪费 power 且不改善 TC / PSRR。

### Step 3 — 计算 R1（PTAT 生成元件）

```
R1 = VT·ln(N) / I_PTAT
   = 26 mV × 2.08 / 3.6 µA
   = 15 kΩ                                  @ N=8, I_PTAT=3.6 µA, 27°C

约束：
  - R1 不要过小（< 1 kΩ）→ I_PTAT 过大 → power
  - R1 不要过大（> 100 kΩ）→ thermal noise 主导 + die area
  - 典型 5-50 kΩ
```

### Step 4 — 计算 R2（zero-TC 比例）

> ⚠️ **Iron Law（Demo 01 v6 实证）**：dVbe/dT **必须用 PDK 仿真实测**，**NEVER**
> 抄教科书 −2.0 mV/°C。@ vpdk180nm 实测 ≈ **−1.776 mV/°C**，差教科书值 **12%**
> —— 直接代教科书值 R2 会偏大 12% → **TC 从 20 ppm 膨胀到 198 ppm**（v6 v5 baseline 实测损失）。

```
zero-TC 公式：
R2/R1 = |∂Vbe/∂T| / (ln(N)·k/q)

教科书快算（仅做粗估，不可作为 final sizing）：
  ≈ 2.0 mV/°C / 179 µV/°C ≈ 11.2-12  for N=8 → R2 ≈ 180k

PDK 实测代入（@ vpdk180nm，N=8，R1=15kΩ，Demo 01 v6 实证）：
  ≈ 1.776 mV/°C / 179 µV/°C ≈ 9.93 → R2 = 9.93 × 15k ≈ 149kΩ ⭐ vpdk180nm 真实值
```

**实测验证**（@ vpdk180nm, N=8, R1=15k, R2=149k）：
- T=−40°C: Vref = 1.19959V
- T=27°C:  Vref = 1.20224V
- T=85°C:  Vref = 1.20263V
- TC = (Vref_max − Vref_min) / (Vref_27 × ΔT) = **20.2 ppm/°C** ✅

#### 如何实测 dVbe/dT（操作步骤）

```spice
* 在 tb 中跑两温度 DC OP，读 Q1 emitter 节点（na）
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './bandgap.cir'
VDD vdd 0 DC 1.8
Xdut vdd 0 vref bandgap

set temp = -40
op
echo "Vbe_m40=$&v(xdut.na)"   * Vbe ≈ V(na) - V(VSS) = V(na)

set temp = 85
op
echo "Vbe_85=$&v(xdut.na)"

* 计算 dVbe/dT = (Vbe_85 - Vbe_m40) / 125
```

**跨工艺 reminder**：vpdk180nm 实测 -1.776 mV/°C 不能照搬到其他 PDK；55nm /
130nm / 22nm 各自必须重新实测。完整工艺常数实测清单见 `physical-constraints.md` § 4。

**`R2_a / R2_b` matching critical**：bandgap 双 CTAT 支路必须严格匹配。
Schematic 用同 unit cell × N 拷贝（不要写 R2a=149k / R2b=149k 两条独立 R）；
layout common-centroid。

### Step 5 — 计算 R_OUT（输出阻抗）

```
Vref = (I_PTAT + I_CTAT) × R_OUT
I_PTAT + I_CTAT = (VT·ln(N) + Vbe) / R1 + Vbe / R2 ... 
≈ I_PTAT + I_PTAT × R1/R2_eff  (rough)
   typical I_PTAT ≈ I_CTAT ≈ 3.6 µA → I_total = 7.2 µA per leg
   I_mirror_to_vref = I_total = 7.2 µA

R_OUT = Vref_target / I_total
      = 1.19V / 7.2 µA
      = 165 kΩ                              @ Vref=1.19V, I_total=7.2 µA
```

### Step 6 — Mirror sizing（PMOS L 优先 + W 由 Vsg 反推）

```
L_P 优先：
  ro_P ∝ L_P → 直接进 PSRR + line reg
  L_P=Lmin (0.18µm) → ro 30 kΩ → PSRR < 50 dB
  L_P=1 µm → ro 200 kΩ → PSRR ≈ 35-45 dB DC
  L_P=2 µm → ro 400 kΩ → PSRR ≈ 50-55 dB DC
  
要 PSRR > 70 dB → cascoded mirror（不在 first-order baseline）

W_P 由 Vsg + I 反推：
  Vsg_target = 0.5-0.6V（headroom 留给 OTA + startup）
  W_P = I_branch / (µ_p · Cox · L_P · Vsg²/2)
  典型 W_P = 10 µm @ L_P=1 µm, I=7 µA → Vsg ≈ 0.55V

3 leg 严格 W/L/m 完全相同（matching critical，避 Pitfall 3）
```

### Step 7（平行）— OTA sizing：**small-W long-L**

```
bandgap OTA 要 gain 不要 BW（loop BW 限于 kHz）：
  - input pair PMOS：W=4µm / L=2µm (PMOS-input 因为 na/nb ≈ 0.65V 共模)
  - tail / load PMOS：W=4µm / L=4µm
  - gain ≥ 40 dB（30 dB 通常不够锁 na ≈ nb）
  - Iq_OTA ≈ 5 µA per leg

⚠️ 不要抄宽带 amp 模板（W=20µ/L=0.5µ 让 Iq=200µA+，12× 预算）—— V3 efb0fa3 教训
```

### Step 8（平行）— Startup helper sizing

```
W_KICK / L_KICK：5 µm / 1 µm 起点
  - 太小 → stuck-at-zero（拉 yg 不动）
  - 太大 → startup oscillation（kick 太强）

R_START：500 kΩ - 2 MΩ
  - 太小 → MN_KICK 部分导通 → PSRR 退化
  - 太大 → startup 慢

W_SENS：5 µm / 1 µm（detector）
```

详见 `startup.md`。

### Step 9（平行）— Loop compensation

```
OTA 内 Miller：
  Cmiller = 3 pF（跨 OTA stage2）
  Rz = 1/gm6 ≈ 20 kΩ（消 RHP zero）

外环 yg cap：
  Ccomp = 2 pF（yg ↔ vss，抑 mid-MHz ringing）
```

详见 `loop-stability.md`。

### 推荐建议（不强制）

> 这 9 步是 **bandgap 拓扑特有**的推进顺序，不是机械流程。**Step 1-6 是
> 主 loop sizing（必须先做）**，Step 7-9 是 OTA / startup / compensation
> 平行子模块（可与主 loop 并行做）。**关键耦合**：N 选定后 R1 / R2 / R_OUT
> 比例锁定，不能单独调一个；OTA polarity 必须按 architecture.md Pitfall 4
> 决定（2-stage 用 vp=na，单级 5T 用 vp=nb）。

## 起点表（@vpdk180nm，VDD=1.8V，N=8，I_PTAT=3.6 µA per leg）

| 参数 | role | 值 | derivation |
|---|---|---|---|
| `N` | PNP area ratio Q1:Q2 | 1:8 | 行业标准；ΔVbe = 54 mV |
| `I_PTAT` per leg | PTAT 电流 | 3.6 µA | power budget 25-40µA / 7 leg |
| `R1_PTAT` | PTAT 生成 R | 15 kΩ | VT·ln(8) / I_PTAT = 54mV/3.6µA |
| `R2_CTAT` (a / b) | CTAT shunt R | 180 kΩ | R2/R1 ≈ 12 (zero-TC) |
| `R_OUT` | 输出 R | 165-171 kΩ | Vref/(I_PTAT + I_CTAT) ≈ 1.19V/7.2µA |
| `W_P / L_P / m` | PMOS mirror | 10µ / 1µ / 1 | ro × OTA gain → PSRR；3 leg 严格相同 |
| `W_diff_OTA / L_diff_OTA` | OTA input pair (PMOS) | 4µ / 2µ | small-W long-L (gain 主导) |
| `W_tail_OTA / L_tail_OTA` | OTA tail | 4µ / 4µ | low Iq |
| `W_load_OTA / L_load_OTA` | OTA load (NMOS mirror) | 4µ / 4µ | matching + ro |
| `W_M2_OTA` (stage2 NMOS-CS) | 2-stage stage2 | 8µ / 1µ | gm6 ≥ 12× gm1 |
| `Cmiller` / `Rz` | OTA Miller comp | 3 pF / 20 kΩ | nulling 消 RHP zero |
| `Ccomp` | 外环 yg cap | 2 pF | mid-MHz ringing 抑 |
| `R_START` | startup pull-up | 500 kΩ | weak pull → MN_KICK detector |
| `W_KICK / L_KICK` | startup kick FET | 5µ / 1µ | 弱拉 yg |
| `W_SENS / L_SENS` | startup detect FET | 5µ / 1µ | gate=Vref → 自禁用 |

⚠️ **数值标 @vpdk180nm**：换工艺时 µ·Cox / Vth / Vbe 不同，要重新算。
跨工艺通用：4-step recipe 比例 + small-W long-L OTA 哲学 + 3 leg matching 铁律。

## Trade-off 表（按 bandgap FOM 维度）

| 调整 | Vref | TC | PSRR | Iq | area | 备注 |
|---|---|---|---|---|---|---|
| N ↑（4→8→16）| —（R 比例同步调）| —（zero-TC 比例不变）| — | — | ↑↑（PNP）| 8 是 sweet spot |
| L_P ↑（0.18 → 1 → 2µm）| —（DC 不变）| — | ↑↑ | — | ↑（gate cap ↑）| **PSRR 优先时首选** |
| W_P ↑（保 Vsg）| —（mirror 比例同）| — | ↑（gm 进 PSRR）| — | ↑ | trade-off 多 |
| I_PTAT ↑ | — | — | — | ↑↑ | — | 不必（loop BW 不需）|
| R_OUT ↑ | ↑ | — | — | — | ↑（die R）| 仅调 Vref nominal |
| OTA gain ↑ | — | — | ↑↑（loop gain ↑）| ↑ | ↑ | 30→40 dB sweet spot |
| Cmiller ↑ | — | — | —（DC 不变）| — | — | PM ↑（loop ringing 救）|
| Cascoded mirror | — | — | ↑↑↑（30 dB）| ↑（cascode bias）| ↑ | PSRR > 70 dB 必做 |
| Curvature-correction | — | ↑↑↑（< 20 ppm/°C）| — | ↑（多 device）| ↑ | 二阶 trim 必备 |

## 不在本章范围

- **gm/Id 通用 sizing 方法** → `skill: device-sizing`（通用 sizing 流程）
- **OTA 5T sizing 详细** → `blocks/5t-ota`（input pair / mirror / tail）
- **Miller 补偿原理 / RHP zero / Rz nulling** → `blocks/base-cells/miller-compensation`
- **cascoded PMOS mirror**（PSRR > 70 dB variant）→ `blocks/base-cells/{cascode, current-mirror}`
- **β-multiplier startup-helper 物理推导** → `blocks/base-cells/bias-generator/{beta-multiplier, startup-helper}`
- **zero-TC 物理推导**（Vbe slope vs k·ln(N)/q）→ `architecture.md` § zero-TC 条件
- **Loop AC stability + Miller / yg cap 选取** → `loop-stability.md`
- **Startup 详细行为 + 5 类 startup-related failure** → `startup.md`
- **架构选型决策（4 拓扑变体）** → `architecture.md`
- **Vds-Vdsat 失稳处理（OTA tail triode / mirror Vsg 不够）** → `architecture.md` Pitfall 7

## Related

- `architecture.md` zero-TC 条件 + 4 拓扑对比
- `loop-stability.md` Miller comp + yg cap + 多极点
- `startup.md` startup helper + tb_startup
- `troubleshooting.md` 失败模式 + 根因表
- `blocks/5t-ota` OTA 子模块 sizing
- `skill: device-sizing` 通用 sizing 流程 + R1-R4 铁律
