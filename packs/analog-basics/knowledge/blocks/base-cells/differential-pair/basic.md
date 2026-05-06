---
chapter: basic
parent: differential-pair
summary: |
  基础 differential pair 物理 + sizing + Pelgrom Vos + CMRR / 输入 CM 范围
  + 极性选择决策（NMOS vs PMOS）+ tail saturation 因果
tokens: ~800
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
  - circuit-method/region-inspection
related_knowledge:
  - blocks/base-cells/current-mirror
  - blocks/base-cells/bias-generator
---

# 基础差分对

## 拓扑结构（事实）

```
          (active load / mirror load 通常在上方)
              │       │
            voutp   voutn
              │       │
            ┌─┴─┐  ┌─┴─┐
   vinp ────│M1│  │M2│──── vinn
            └─┬─┘  └─┬─┘
              │      │
              ▼      ▼
              └──┬──┘  ntail（M1 / M2 共 source）
                 │
              ┌──┴──┐
              │M_tail│ Vgs_tail = Vbias_tail
              └──┬──┘
                 │
                vss
```

**核心机制**：
- M1 / M2 是**匹配** 输入对（共 W/L/L/m + 同 layout common-centroid）
- 两路输入 vinp / vinn 相对 vcm 摆 ±vid/2 → 输出 ±gm·vid/2 电流
- tail device M_tail 决定 total Itail，平衡时 Id_M1 = Id_M2 = Itail/2
- 差分输出 = vout_p - vout_n（差分模式）

## 关键物理（事实 + 因果）

### 极性选择（NMOS vs PMOS input pair）

> ⭐ **完整公式 + 跨 PDK 数据 + Step 0 self-check protocol** 见横切章 [`cm-range.md`](./cm-range.md)。本节是简介，**做架构决策时必读 cm-range.md** 拿数值代入证据。

**核心约束**：tail device 必须 saturation + input pair 必须在饱和区（不能 sub-threshold）。

**双向公式**：
```
PMOS-input (tail at top): Vcm_max = VDD − |Vth_p| − Vdsat_tail
NMOS-input (tail at bot): Vcm_min = Vth_n + Vdsat_tail
```

PMOS ceiling 违 → MP1/MP2 sub-threshold → gm 损 50-100×（**Demo 04 实证**：vpdk55nm Vcm=0.9V > 0.75V → gm ×1/83）
NMOS floor 违 → tail triode → CMRR 崩 / DC OP 漂

**详细决策表 + 跨 PDK 数据见 `cm-range.md`**。本节只列两个常见场景：

| 场景 | Vcm 状态 | 选 |
|---|---|---|
| LDO bandgap Vref=0.6V @ vpdk180nm | 接近 NMOS floor 0.50V | PMOS pair（NMOS 边缘）|
| LDO Vfb=0.9V @ vpdk55nm | PMOS ceiling 0.75V 违 | NMOS pair |

**判别**：dc_snapshot 看 M_tail Vds < Vdsat = NMOS floor 违 / inspect_device 看 input pair gm < 1/10 期望 = PMOS ceiling 违（sub-threshold）。

### Pelgrom Vos（input-referred offset）

```
σ_1sigma(Vos) = Avt / √(W·L)
σ_3sigma(Vos) = 3 × σ_1sigma
```

**典型工艺常数**：
- NMOS Avt ≈ 5 mV·µm（180nm bulk）
- PMOS Avt ≈ 7 mV·µm（PMOS Vt 不均更敏感）

**因果链**：
- W·L ↑ → σ ↓ ∝ 1/√(WL)（随机 Pelgrom 失配只看总 W·L）
- 同面积下 L↑ vs W↑：随机 Vth 失配大致**相同**；L↑ 的额外好处是 1/f noise 降、ro/gds 升、systematic 匹配改善（系统性偏差消）
- 典型 LDO/OTA spec σ_3sigma 1-10 mV → W·L 1-100 µm²

### CMRR（Common-Mode Rejection Ratio）

```
CMRR ≈ gm_diff / gm_cm = gm × (2 × ro_tail × ...)
```

Tail current source 的 ro_tail **越大 CMRR 越好**——这是用 cascoded tail / regulated tail 的物理动机。

**典型 CMRR**：
- single-device tail（ro_tail ≈ 1 MΩ）：60-70 dB
- cascoded tail（gm·ro² ≈ 100 MΩ）：80-90 dB
- regulated cascode tail（GΩ）：> 100 dB

## Sizing Guideline

按 spec 反推因果链（典型 LDO EA 输入级范例）：

```
Spec: gain_db=60 (loop level), itail = 20 µA, vdd=1.8V, vos_3sigma < 5 mV

→ gm/Id = 12（中等反型，noise-speed 平衡，typical for EA input）
  gm = (gm/Id) × Id_branch = 12 × 10µ = 120 µS per device

→ Pelgrom 反推 W·L:
  σ_3sigma < 5 mV → σ_1sigma < 1.67 mV
  W·L > (Avt / σ_1sigma)² = (5/1.67)² = 9 µm²

→ L 选取（matching 优先）:
  L = 1 µm（2x Lmin，matching + 1/f noise）
  或 L = 2 µm 如要更好 matching（W·L 更大 / ro 更大）

→ W 反推:
  matching 约束：W·L = 9 µm² → W = 9 µm at L = 1 µm（或 W=4.5µm at L=2µm 更安全）
  gm/Id 约束验证（W/L = 2·Id/(μn·Cox·Vov²)）：
    Vov = 2/(gm/Id) = 2/12 = 0.167 V，μn·Cox = 270 µA/V²
    所需 W/L ≈ 2·10/(270·0.028) ≈ 2.6
  取较大者 W=9µm/L=1µm（matching 主导）后，**实际 W/L = 9 → 大于 2.6**：
    实际 Vov = √(2·Id / (μn·Cox·(W/L))) = √(2·10/(270·9)) ≈ 0.091 V（**比 0.167 V 小**）
    实际 gm/Id ≈ 2/0.091 ≈ 22 V⁻¹（**比初始 12 大**，更弱反型）
    实际 gm = 22 × 10µ = 220 µS（**比初始 120 µS 大**）
  → 取 matching 约束的 W 后必须**回算 Vov / gm/Id / gm**，原 spec 的 gm/Id=12 已不再成立

→ m（multiplicity）:
  m = 1（single finger 足够；如要更好 matching 用 m=4 共心 layout）

→ input CM range 验证（NMOS input pair）:
  Vov_diff = 0.167V, Vth_n = 0.45V, Vov_tail = 0.2V (typical)
  Vcm_min = Vov_tail + Vth_n + Vov_diff = 0.82 V
  spec Vcm 在 0.6-1.2V → vcm_min spec 0.6V < 0.82V → polarity 错（要 PMOS）
```

完整 sizing 范例 + tool 输出对照：见 skill `circuit-method/device-sizing` §Pattern 段。

## 验证清单

- [ ] dc_snapshot 显示 M1 / M2 在 saturation（Vds > Vdsat 50mV margin）
- [ ] dc_snapshot 显示 M_tail 在 saturation（关键！tail triode → CMRR 崩）
- [ ] dc_snapshot 显示 M1 / M2 同 Vov（应一致 ±5%）
- [ ] AC sweep（differential mode）：gain ≈ gm × (ro_diff ‖ ro_load)
- [ ] AC sweep（common mode）：CMRR > spec
- [ ] DC sweep Vcm：Itail（tail current）在 spec Vcm 范围内不变 < 5%
- [ ] MC mismatch 仿（100 次）：σ_1sigma(Vos) < spec/3

## 常见误区（self-check）

| 心里想 | 现实 |
|---|---|
| "tail triode 是 tail W 太小，加大 W" | tail Vds = vcm - Vgs_diff，由上层 vcm 决定，不是 tail 自决（应改 polarity 或调 Vbias_tail）|
| "Vos 大就重新 sizing input pair" | **Vos 由 W·L 决定**（Pelgrom）—— 必须算 W·L 不能拍脑袋 |
| "Vov_diff 越小越好（gm 大）" | Vov 太小（< 80mV）→ subthreshold，gds 增 / matching 差 |
| "PMOS load 的 L 跟 input pair 同 L" | **PMOS load L 必须长**（noise / matching / gds 三重）—— 见 OTA 设计经典误区 |
| "CMRR 不够就加 cascode tail" | 对，但**先验证 ro_tail 真的是瓶颈**（不是 layout 失配 / 输入对 mismatch）|
| "input pair 越大 Vos 越小所以越好" | 大 W → Cgs 增 → BW 降 / 大 L → ro 增但 gm 降 → trade-off |

## 不在本章范围

- **active load（PMOS mirror）配套 sizing**——见 `chapter=active-load` + `blocks/base-cells/current-mirror`
- **tail current source 自身 sizing**——见 `blocks/base-cells/current-mirror`（tail 是 mirror 镜像）
- **cascoded tail / regulated tail**——见 `blocks/base-cells/cascode`
- **source-degenerated 线性化**——见 `chapter=source-degenerated`
- **大信号 current-steering 模式**（DAC / CML）——见 `chapter=current-steering`
- **完整 OTA 拓扑**（5T / fc / telescopic）——见 `blocks/ota-*`
