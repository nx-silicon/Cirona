---
chapter: regulated-common-gate
parent: common-gate-stage
summary: |
  Regulated common-gate（RCG）—— 内嵌反馈 OTA 把 source 节点钉住 /
  Rin 降到 1/(gm·A_OTA) / Rout 升到 gm·ro·A_OTA·ro / 稳定性约束
tokens: ~700
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/ac-feedback-loop-method
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/cascode
---

# Regulated Common-Gate（RCG）

## 拓扑结构（内嵌反馈 OTA）

```
                     VDD
                      │
                  ┌───┴───┐
                  │ Rload │
                  └───┬───┘
                      ●─── V_out ────────┐
                  ┌───┴───┐               │
                  │  Mn   │               │
        Vbias ────│       │               │ A_OTA
        ───┌──────┤  CG   │               │ (高增益反馈 OTA)
        |  │      └───┬───┘               │
        |  │          ●─── V_s ───────────┤  ← 反馈输入
        |  │          │                   │
        |  └──────────●  ← OTA 输出钉住 V_s
        |             │
       V_REF →OTA+    │  (V_REF 是 V_s 的目标值，典型 0.5-1V)
                      ●  ← 信号 I_in 进入
                      │
                   sensor
                      │
                     VSS
```

**核心机制**：内嵌反馈 OTA（增益 A_OTA）"看着" V_s，比较 V_REF，反馈调节 CG 管的 Vbias_g（gate 电压），目的是**把 V_s 钉在 V_REF**。

**等价模型**：
- 反馈环把 V_s 节点的"看进去"等效阻抗压低 A_OTA 倍
- 同时把 drain 端 Rout 提升 A_OTA 倍

## 小信号公式（事实 + 因果）

### Rin（关键改进）

```
Rin_RCG ≈ 1 / (gm × A_OTA)         # 比基础 CG 的 1/gm 小 A_OTA 倍

例：gm = 10 mS, A_OTA = 100 → Rin = 1 Ω
```

**因果**：
- 反馈环检测到 V_s 偏离 V_REF → A_OTA 放大误差 → 调 Vbias_g → CG 管补偿电流 → V_s 拉回
- 等效 Rin 被反馈"虚拟接地" A_OTA 倍

### Rout（关键改进）

```
Rout_RCG ≈ ro × (gm × A_OTA × ro)   # 比基础 CG 的 ro 大 (gm·A_OTA·ro) 倍

例：ro = 100 kΩ, gm = 10 mS, A_OTA = 100 → Rout = 100k × 100k = 10 GΩ
```

**与 cascode 对比**：
- 普通 cascode：Rout = gm·ro·ro ≈ ro × gm·ro = 数 MΩ-GΩ
- RCG：Rout = gm·ro·ro × A_OTA ≈ 数十 GΩ +

### 跨阻 / 电压增益（注意区分 Z_T vs Av_v）

```
跨阻（电流输入 → 电压输出，TIA 应用）:
Z_T_RCG = V_out / I_in ≈ Rload   (Rload 通常远小于 RCG Rout)

电压增益（V_s → V_out 视角，仅当 V_s 不被钉住时）:
Av_v_source = V_out / V_s ≈ (gm × A_OTA) × Rload
（实际 RCG 中 V_s 被反馈钉住 ≈ V_REF，"V_s 视角"不常用；
 用于断环测 PM 时是有意义的 small-signal gain）
```

## 应用场景（vs 普通 CG / cascode）

| 场景 | 选 |
|---|---|
| 输入是高阻抗 sensor + 需要极低 Rin（< 100 Ω）| **RCG**（Rin = 1/gm·A 显著好）|
| 高精度 ADC 输入级（ro > 1 GΩ 需求）| **RCG** |
| 一般 LNA / TIA（NF 优先）| 普通 CG / cascode（RCG 反馈 OTA 引入额外 noise）|
| OTA 输出级增益增强 | cascode（更简单，足够）|

## 稳定性约束（关键，反馈环 PM）

RCG 内的反馈 OTA 是闭环 → 必须保证 PM ≥ 60°。

**主极点位置**：
- A_OTA 输出节点（即 CG 管 gate）
- 由 A_OTA 的 Rout 与 Cgate_CG 决定
- 典型 fp_main = 1/(2π·Rout_OTA·Cgate_CG)

**次极点**：
- V_s 节点（CG 的 source）：fp_s = 1/(2π·Rin_eff·C_s)
- 由 V_s 节点的 Cload 与等效电阻决定

**因果**（不稳定常见原因）：
- A_OTA 太快（GBW > V_s 节点极点）→ 双极点接近 → PM 退化
- 修：减 A_OTA bias / 加 Cc 在 OTA 输出 → 主极点拉低

## Sizing 范例（高精度 sensor 前端）

> 📌 **@ vpdk180nm**（μn/p·Cox / Vth 数值参考 `pdks/vpdk180nm/index.md`）。换工艺需重算 Itail / Vov；regulated common-gate 拓扑（内嵌 OTA 钉 V_s）跨工艺通用。

设计目标：
- Sensor 输出电流 1-100 µA
- 要求 Rin < 10 Ω（避免 sensor V 摆幅）
- BW = 10 MHz
- VDD = 1.8 V

**derivation**：
```
CG 管 sizing:
  - 选 Id = 200 µA, gm/Id = 10 → gm = 2 mS
  - Vov = 200 mV, L = 0.36 µm, W ≈ 30 µm

A_OTA 目标:
  - Rin_target = 10 Ω → A_OTA × gm = 1/10 = 0.1 → A_OTA = 0.1 / 2m = 50 (= 34 dB)
  - 选 simple OTA（5T 或 fc）即可

Rout_RCG = ro × A_OTA × gm·ro
  - ro_M ≈ 200 kΩ @ Id=200µA / L=0.36µm
  - Rout_RCG = 200k × 50 × 2m·200k = 200k × 50 × 400 = 4 GΩ

主极点（OTA Cc + Rout_OTA）:
  - 选 Cc = 1 pF, Rout_OTA = 1 MΩ → fp_main = 1/(2π·1M·1p) = 159 kHz
  - GBW_OTA = A_OTA × fp_main = 50 × 159k = 8 MHz

次极点（V_s 节点）:
  - C_s = sensor C + Cgs_CG ≈ 200 fF
  - Rin_eff = 1/(gm·A_OTA) = 10 Ω
  - fp_s = 1/(2π·10·200f) = 80 GHz （远高于 GBW，PM 安全）

PM:
  - GBW = 8 MHz, 次极点 80 GHz → PM ≈ 90° ✓
```

## 验证清单

- [ ] dc_snapshot：V_s ≈ V_REF（误差 < 5 mV）
- [ ] dc_snapshot：CG 管 + OTA 管全部 saturation
- [ ] AC 仿真：测 Rin（应 ≈ 1/(gm·A_OTA)）
- [ ] AC 仿真：断反馈环测 PM ≥ 60°（用 skill `circuit-method/ac-feedback-loop-method`）
- [ ] PVT corner：A_OTA 漂 < 30%，Rin 仍 < spec
- [ ] tran：阶跃输入电流 → V_s 应稳定，OTA 不振铃

## 常见误区

| 心里想 | 现实 |
|---|---|
| "RCG = 普通 CG + 大 OTA 增益就行" | OTA 必须稳定；A_OTA × Rin × C_s 决定主次极点距离 |
| "A_OTA 越大越好" | 越大 → 主极点低 → 闭环 BW 受限；A=20-100 是常用范围 |
| "RCG 不需考虑 PM" | RCG **是** 反馈环，必须断环测 PM；OTA 不稳 → 整个 RCG 振铃 |
| "RCG 比 cascode NF 更低" | 错，RCG 的 OTA 引入 **额外** noise（OTA input pair）；NF 通常 > 普通 cascode |
| "RCG 适合所有低 Rin 应用" | 复杂 + 多 5-10× 功耗（OTA bias）；普通应用 cascode 已够 |

## 不在本章范围

- 反馈环 PM 通用断环方法 → skill `circuit-method/ac-feedback-loop-method`
- 普通 CG / cascode → chapter `basic` 和 `blocks/base-cells/cascode`
- TIA / LNA 应用 → chapters `tia-application` / `lna-application`
- OTA 内部设计（A_OTA 的 5T-OTA 拓扑）→ `blocks/5t-ota/`
