---
chapter: broadband-load
parent: resistive-load
summary: |
  电阻在宽带 / RF 应用 —— 寄生 cap vs BW / shunt-peaking inductor 补偿 /
  GHz 频段考虑 / 集成 vs 离散
tokens: ~500
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/common-source
  - blocks/base-cells/common-gate-stage
---

# 电阻作宽带 / RF 负载

## 为什么宽带应用首选电阻负载

宽带 / RF 应用（典型 100 MHz - 10 GHz）需要：
- **平坦频响**（<1 dB ripple across BW）
- **可预测增益**（process-independent）
- **稳定线性度**

active load 的劣势在宽带：
- 高阻输出节点 RC 极点低（fp = 1/(2π·ro·Cload)，ro 大 → fp 低）
- ro 随工作点变化 → 增益随信号摆幅漂
- mirror load 的 Vds 调制让差分对失配

电阻负载的优势：
- 极点高：fp = 1/(2π·R·C_par)，R 通常远小于 ro → fp 高 5-50×
- R 不随信号摆变化 → 线性度好
- noise：理想 poly resistor 仅热噪 4kTR（不带 1/f flicker）；well/diffusion 电阻或强偏置（高电场）下可能有 excess 1/f 与 current noise，需查 PDK noise model

## 寄生电容 vs BW 的关键 trade-off

```
fp = 1/(2π × R × C_par)

C_par 来源：
  - M_drv.Cgd（Miller × (1+|Av|)，CS 拓扑这是大头）
  - 下级 Cgs / 输入端
  - 电阻自身（poly to substrate / metal to substrate）
  - 走线 metal stack
  
典型 @ 180nm：
  R = 1 kΩ, C_par = 100 fF → fp = 1.6 GHz
  R = 1 kΩ, C_par = 500 fF → fp = 320 MHz
  R = 5 kΩ, C_par = 100 fF → fp = 320 MHz
```

→ 宽带应用通常用**小 R**（1-5 kΩ）+ 接受 gain 损失（gm·R = 5-15）。

## Shunt-Peaking Inductor 补偿（RF 经典）

```
        VDD
         │
    ┌────┴────┐
    │   L     │  shunt-peaking inductor
    │ (chip   │  典型 1-10 nH
    │  ind)   │
    └────┬────┘
         │
         R_load (small, 100 Ω - 1 kΩ)
         │
         ●─── V_out
         │
       (drv)
```

**机制**：L 与 C_par 在某频段形成串联谐振 → 提升高频增益 → BW 扩展 1.5-2×。

**设计公式**（典型 m-derived）：
```
L = m × R² × C_par,  m ≈ 0.3-0.4（最大平坦度）
ω_resonance = 1/√(L·C_par)

例：R=200Ω, C_par=200fF → L = 0.3 × 200² × 200f = 2.4 nH
    BW 扩展从 4 GHz → 6-7 GHz
```

**代价**：
- chip inductor 占用大面积（5-10 nH 需 100×100 µm² 螺旋）
- 增加 layout 复杂度 + EM coupling 风险
- 仅在 GHz 频段值得用（< 1 GHz 直接增 R 减 C 更经济）

## RF 频段（>1 GHz）特别考虑

| 现象 | 原因 | 修复 |
|---|---|---|
| 寄生 inductance 自激 | 长 metal 走线 + bypass cap 不足 | layout 短 + 多 via + 邻近 bypass |
| Skin effect on metal | 高频 metal 实际 R 升 | 选 thicker metal 或多层并联 |
| Substrate coupling | poly resistor 寄生 → substrate noise | guard ring + 大 poly W 减电流密度 |
| Self-resonance | 大值电阻 + 寄生 cap 谐振 | 蛇形布局有 "蜿蜒" 寄生；用 metal 走线穿插 |

## 宽带 LNA 范例（5 GHz 应用）

设计目标：
- BW = 1 - 5 GHz
- Av_voltage = 10 dB (3.16×)
- VDD = 1.8 V

```
R_load 选小（保 BW）:
  R = 200 Ω (gm·R = 3.16 → gm = 15.8 mS)
  
gain 级（NMOS CS）:
  gm = 15.8 mS → 选 gm/Id = 8 → Id = 2 mA
  V_drop = 2m × 200 = 0.4 V → V_out_Q = 1.4 V ✓
  
寄生估算:
  C_par ≈ 200 fF (Cgd Miller + 下级 + metal)
  无补偿 fp = 1/(2π·200·200f) = 4 GHz ✗ (低于 5 GHz spec)
  
加 shunt-peaking:
  L = 0.3 × 200² × 200f = 2.4 nH
  → BW 扩展 ~1.7× → 6.8 GHz ✓
  
布局：
  螺旋 inductor 5 圈 / 直径 80 µm / 金属层 top metal
  bypass cap = 10 pF MOM 紧邻 R 顶端
```

## 验证清单（RF 特别项）

- [ ] dc_snapshot：M_drv saturation @ V_out_Q
- [ ] AC：BW 与公式对照（含 shunt-peaking 后的 BW 扩展）
- [ ] S 参数：S11 / S22 / S21 across BW
- [ ] EM 仿真（含 inductor）：Q / SRF / 耦合
- [ ] PVT corner：BW 漂 < 10%

## 常见误区

| 心里想 | 现实 |
|---|---|
| "电阻负载 GHz 应用一定要 inductor" | 不一定——R = 100-300 Ω + 小 W M_drv 可达 5-10 GHz BW；inductor 值得用是 BW > 5 GHz 或要求最大平坦度 |
| "L 越大 BW 扩展越多" | m = 0.3-0.4 是最大平坦度；m 太大引起 ripple（peaking）|
| "metal R 在 GHz 可忽略" | skin effect + 走线 inductance 会让有效 R 升；layout 必须短 + 宽 |
| "Rf 也用 shunt-peaking" | TIA Rf 的极点是反馈环 PM 关键，加 L 会破坏稳定性；不推荐 |

## 不在本章范围

- 基础公式 + 五变体选择 → chapter `basic`
- TIA 反馈电阻 → chapter `tia-feedback-resistor`
- 故障 debug → chapter `troubleshooting`
- inductor 设计 / Q 优化 → RF passive knowledge（V4 不在范围）
- 完整 LNA（含匹配网络）→ 未来 `blocks/lna-cmos/`
- CG-LNA（CG 拓扑配 R load 是另一种宽带）→ `blocks/base-cells/common-gate-stage/lna-application.md`
