---
chapter: tia-feedback-resistor
parent: resistive-load
summary: |
  电阻作 TIA Rf 反馈 —— 跨阻 Z_T = Rf / 噪声 4kT/Rf / Rf·C_PD 主极点 /
  Rf 选择的 gain-BW-noise 三角折衷（承接弃用的 shunt_feedback_stage）
tokens: ~600
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/common-source
  - blocks/base-cells/common-gate-stage
---

# 电阻作 TIA 反馈电阻 Rf

## 拓扑（CS-TIA shunt-shunt 反馈）

```
                              VDD
                               │
                          ┌────┴────┐
                          │  Mp_load│  (active load 或 R_load)
                          └────┬────┘
                               ●─── V_out
              ┌────────────────┤
              │                │
           Rf │       (反馈电阻)
              │            ┌───┴───┐
              ●─── V_in ───│  Mn   │
              │            │ NMOS  │  (gain device, gm)
              ●            │  CS   │
         ┌────┴────┐       └───┬───┘
         │  C_PD   │           │
         │ photodiode│         VSS
         └────┬────┘
              │
             VSS

I_PD（光电流）通过 Rf 转换为 V_out 的电压响应
```

**核心机制**（CS-TIA shunt-shunt）：
- 信号电流 I_PD 从 V_in 节点注入
- gain 级（NMOS CS）放大 → V_out
- Rf 把 V_out 反馈到 V_in → 形成 shunt-shunt 反馈
- **跨阻 Z_T ≈ -Rf**（高 loop gain 时）

> 注：这是 **CS-TIA**（V_in 节点输入）。**CG-TIA** 拓扑见 `blocks/base-cells/common-gate-stage/tia-application.md`，物理机制完全不同。

## 跨阻公式（事实）

**理想（loop gain → ∞）**：
```
Z_T = -Rf
```

**实际（含 loop gain A 有限）**：
```
Z_T = -Rf × A / (1 + A) ≈ -Rf × (1 - 1/A)

A = gm × R_load_eff（CS gain 级开环增益）
A 典型 20-100 → Z_T ≈ Rf × 0.95-0.99（小误差）
```

## 关键 trade-off：Rf 选择的三角折衷

| spec | Rf 选大 | Rf 选小 |
|---|---|---|
| 跨阻 Z_T = Rf | 大跨阻（mV/µA 级 → V/µA 级）| 小跨阻（适合大电流输入）|
| 噪声（输入参考电流） | 4kT/Rf 小 ✓ | 4kT/Rf 大 ✗ |
| 主极点 1/(2π·Rf·C_PD) | 低（BW 损） | 高（宽 BW）|
| 稳定性 | loop 极点 ↓，PM 易满足 | loop 极点 ↑，可能 PM 紧张 |

→ **没有最优 Rf**——必须在 spec 表里 lock 三选二。

## Rf·C_PD 极点（关键）

```
fp_main = 1 / (2π × Rf × C_PD)

典型数值：
  C_PD = 1 pF, Rf = 100 kΩ → fp = 1.6 MHz （窄带高跨阻）
  C_PD = 1 pF, Rf = 10 kΩ  → fp = 16 MHz  （中速中跨阻）
  C_PD = 1 pF, Rf = 1 kΩ   → fp = 160 MHz （宽带低跨阻）
  C_PD = 100 fF, Rf = 10 kΩ → fp = 160 MHz
```

**PSpice 直觉**：Rf·C_PD 是 V_in 节点的 RC 时间常数（V_in 是 high-impedance summing junction）。这是 **CS-TIA 主 BW 限制**。

## 噪声分析（输入参考电流谱密度）

主要噪声源：
1. **Rf thermal**：i²_n_Rf = 4kT/Rf（电流 Norton）
2. **gain 级 (M_n) thermal**：i²_n_M_referred = 4kT·γ·gm × (1/Rf)²（除 |Z_T|² = Rf²，但 V→I 回到电流）
3. **active load** thermal（如有）

总输入参考电流噪声：
```
i²_in_total ≈ 4kT/Rf + 4kT·γ·gm/Rf²
            = (4kT/Rf) × (1 + γ·gm·1/Rf × Rf)
            = (4kT/Rf) × (1 + γ × gm·Rf · 1/A_loop)
```

**关键**：Rf 大 → 自身 4kT/Rf 项小 + gain 高让 M_n 项也减小（除 Rf²）→ **大 Rf 同时减两路噪声**。这是为何高灵敏度 TIA（光通信 / sensor）用大 Rf。

## sizing 范例（CS-TIA 光电接收）

> 📌 **@ vpdk180nm**（μn·Cox / Vth / R_poly 数值参考 `pdks/vpdk180nm/index.md`）。换工艺重算所有数值；TIA noise 公式（4kT/Rf + i²_M / gm² × Rf²）跨工艺通用。

设计目标：
- I_PD = 1 µA - 100 µA
- C_PD = 1 pF
- Z_T_target = 10 kΩ → V_out = 10 mV - 1 V
- BW_target = 50 MHz
- VDD = 1.8 V

```
Rf 选 10 kΩ: 跨阻直接 10 kΩ ✓
fp_main: 1/(2π·10k·1p) = 16 MHz ✗ (低于 50 MHz spec)

→ Rf 减小到 3 kΩ: 跨阻 3 kΩ → V_out 0.3-30 mV (太小？看 ADC dynamic range 是否 ok)
   fp_main: 1/(2π·3k·1p) = 53 MHz ✓
   噪声: i_n_Rf = √(4kT/3k) = 2.4 pA/√Hz × √BW = 17 nA RMS @ 50 MHz BW
   → SNR @ 100µA: 100µ/17n = 75 dB ✓

OR 增 gain 级 gain（A_loop 升）:
   - gain 级用 active load mirror（A_open = gm·ro/2 ≈ 50）
   - 增 A_loop → 实际 fp_main 推高 ~A_loop 倍 ≈ A_open × 1/(2π·Rf·C_PD)
   - 但实际看 GBW 限制：50 × 16 MHz = 800 MHz GBW 要求；通常 gain 级带宽 < 这值
   - → 实际 BW 由 gain 级 BW 决定

trade-off 策略:
  - 高 SNR 优先：Rf = 10-50 kΩ + 接受 BW 1-3 MHz；用 cascode 或 nested feedback
  - 高 BW 优先：Rf = 1-3 kΩ + 大 gain 级 BW；噪声会差
  - 平衡：Rf = 5-10 kΩ + active load gain 级
```

## 验证清单

- [ ] dc_snapshot：V_in / V_out 静态 OK（高环路增益时 V_in ≈ -V_out/A，**逼近虚地**而不是与 V_out 共点；shunt-shunt 反相 TIA 的输入节点是低阻虚地节点）
- [ ] dc_snapshot：M_n saturation
- [ ] AC：实测 Z_T = V_out / I_in @ DC 中频 ≈ Rf（误差 < 5%）
- [ ] AC：实测 fp_main 与 1/(2π·Rf·C_PD) 对照
- [ ] AC：闭环 loop PM ≥ 60°（断环测）
- [ ] noise：输入参考 i²_n_total 与公式对照
- [ ] tran：阶跃 I_PD 0→100µA → V_out 建立时间 < spec

## 常见误区

| 心里想 | 现实 |
|---|---|
| "增 Rf 总是好（跨阻 + 减噪声）" | 是，但 BW 损 + 大 R 面积大 + 可能 PM 紧；没有 free lunch |
| "TIA Rf 等同于 mirror-load 的 R_load" | 角色完全不同：Rf 是反馈元件不是 load；同样 R 值噪声贡献和稳定性影响差很多 |
| "CG-TIA 跨阻也是 Rf" | 错——CG-TIA 跨阻 ≈ R_load（不是 Rf）；见 `common-gate-stage/tia-application.md` |
| "Rf·C_PD 极点不影响（loop gain 推高）" | 推高有限（受 gain 级 GBW 限制）；C_PD pF 级时仍是 fundamental BW 上限 |
| "用 well resistor 减面积" | TCR ±5000 ppm/°C → spec 不能 lock；用 poly + 蛇形布局或 triode-MOS pseudo-R |

## 不在本章范围

- 完整 TIA 系统（含 buffer / 反馈环 PM 详细 / Vos）→ 未来 `blocks/tia/`
- CG-TIA（不同拓扑）→ `blocks/base-cells/common-gate-stage/tia-application.md`
- 光电二极管模型 → `devices/`
- 基础电阻 sizing → chapter `basic`
- 宽带 / RF 应用 → chapter `broadband-load`
