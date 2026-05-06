---
chapter: lna-application
parent: common-gate-stage
summary: |
  共栅级在宽带 LNA 的应用 —— 输入匹配（Rin = 1/gm 直接对应 Z_source）/
  噪声因子 NF / IIP3 / RF 频段考虑
tokens: ~700
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/active-load
---

# CG 在宽带 LNA 中的应用

## 为什么 CG 适合宽带 LNA

宽带 LNA（典型 100 MHz - 10 GHz）需要：
1. **输入匹配到 Z_source**（典型 50 Ω）
2. **低 NF**（噪声系数）
3. **足够 IIP3 / 线性度**
4. **宽带平坦增益**

CG 的天然优势：
- **Rin ≈ 1/gm**：选 gm = 1/(50 Ω) = 20 mS → 直接 50 Ω 匹配，**无需电感**（不像 cascode/CS LNA 需 Lg + Ls degeneration）
- **弱 Miller**：宽带 BW 不被 Cgd 拖累
- **简单拓扑**：单 NMOS + drain 负载

代价：
- **NF 偏高**（典型 ≥ 3 dB），主要来自 CG 管 thermal noise
- **gm 大 → Id 大**（50 Ω 匹配需 ~2 mA 电流，功耗显著）

## Rin = 1/gm 匹配方法

```
Rin_target = 50 Ω
→ gm = 1 / (Rin_target × (1+η))      # body effect 帮忙降低所需 gm
→ gm = 1/(50 × 1.2) ≈ 16.7 mS（含 η = 0.2）

@ gm/Id = 10 → Id = 1.67 mA
@ gm/Id = 5（强反型，更适合 RF）→ Id = 3.3 mA
```

**典型 sizing**：Id = 2-5 mA / Vov = 200-400 mV / W = 50-200 µm @ 180nm。

## 噪声分析（NF 推导）

CG-LNA 噪声主要源：
1. **CG 管 channel thermal**：i²_n_M = 4kT·γ·gm
2. **R_load thermal**（如有）
3. **gate 偏置网络 noise**（应足够低）
4. **source 端寄生 R**（layout）

### NF 公式（一阶，匹配条件下）

噪声因子 F（线性比，与 dB 不同）：
```
F ≈ 1 + γ·(gm·Rs)
   = 1 + γ                  (匹配条件 Rs·gm = 1)

→ F = 1 + 2/3 ≈ 1.67 → NF = 10·log₁₀(1.67) ≈ 2.2 dB（long-channel γ=2/3）
→ F = 1 + 1   = 2.0  → NF = 3.0 dB（short-channel γ≈1）
→ F = 1 + 2   = 3.0  → NF = 4.8 dB（short-channel γ≈2）
```

**关键**：
- CG-LNA F 不能 < 1+γ（一阶模型下的器件噪声下限）
- 短沟道 γ 偏大（1-2 vs long-channel 2/3）→ NF 比 long-channel 模型预测的高
- 实测典型 CG-LNA NF = 3-5 dB

### 与其他 LNA 拓扑 NF 对比

| 拓扑 | NF 典型 | 备注 |
|---|---|---|
| **CG-LNA** | 3-5 dB | 简单宽带；F ≈ 1+γ |
| Cascoded CS-LNA + Lg/Ls | 0.5-2 dB | 复杂，电感面积大；NF 更优 |
| Noise-cancelling CG | 1-2 dB | CG + parallel CS 抵消 CG 噪声 |

## 输出（drain 负载选择）

| 负载 | 增益 | BW | 适用 |
|---|---|---|---|
| Resistive R_L | gm·R_L (低) | 高 | 极宽带（10 GHz+）|
| Inductor L (RF)| gm·jωL (中等) | 窄带（ω₀=1/√(LC)）| 窄带 LNA |
| Active mirror | gm·ro/2 | 低 | 中频 LNA |

宽带 LNA 通常用 **Resistive load** 或 **shunt-peaking inductor**（兼顾增益 + BW）。

## IIP3 / 线性度

CG-LNA IIP3 主要受：
- gm 非线性（gm = f(Vgs - Vth)，强反型时近似线性）
- ro × Vds 曲率
- body effect 非线性

**典型 CG-LNA IIP3** = -10 dBm 到 +5 dBm（@ 50 Ω input），不如 cascoded CS-LNA。

提升方法：
- 增 Vov（强反型）→ gm 曲率减小
- 增 L（reduce ro 调制）

## Sizing 范例（2 GHz 宽带 LNA）

> 📌 **@ vpdk180nm**（μn·Cox / Vth / fT 数值参考 `pdks/vpdk180nm/index.md`）。LNA 性能与工艺 fT 强相关——RF 应用通常用 65nm 或更先进工艺，180nm 仅 sub-2 GHz 实用；公式形式（NF / Z_in = 1/gm）跨工艺通用，数值（gm / NF / Cgs）必须 BSIM 实测。

设计目标：
- Z_source = 50 Ω（匹配）
- NF < 4 dB
- Av_voltage ≥ 15 dB
- BW = 100 MHz - 5 GHz
- VDD = 1.8 V

**derivation**：
```
gm: 1/(50 × 1.2) = 16.7 mS（body effect 通过 gm+gmb 降低所需 gm）
Id: gm / (gm/Id) @ gm/Id=10 → Id = 1.67 mA
Vov: 200 mV
L: 0.18 µm（min L）—— RF 应用速度优先
W: 由 gm/Id 表 lookup → ~100 µm

R_load:
  Av_target = 15 dB = 5.6× → R_load = Av/(gm+gmb) = 5.6/(16.7m·1.2) = 280 Ω
  V_drain DC = VDD - Id × R_load = 1.8 - 1.67m × 280 = 1.33 V ✓
  C_drain ≈ 200 fF (Cgd_M + 下级 Cgs + metal)
  drain 极点 = 1/(2π·280·200f) = 2.84 GHz （边缘满足 5 GHz BW，加 shunt-peaking 可扩展）

F (理论): F = 1 + γ ≈ 1 + 1.5 = 2.5 → NF = 10·log₁₀(2.5) ≈ 4 dB
  - 实测可能 3.5-4 dB（含 R_load + bias 网络贡献）

匹配验证（S11）:
  - Z_in_actual ≈ 1/(gm+gmb) = 50 Ω ✓
  - S11 < -10 dB across BW （仿真验证）
```

## 验证清单

- [ ] DC OP：CG 管 saturation @ Vov = 200-400 mV
- [ ] S 参数仿真：S11 < -10 dB across BW（输入匹配）
- [ ] AC：voltage gain ≥ spec
- [ ] noise 仿真：NF < spec
- [ ] tran + .pss / .pnoise：IIP3 / 1 dB 压缩点
- [ ] PVT corner：S11 / NF 漂移 < 1 dB

## 常见误区

| 心里想 | 现实 |
|---|---|
| "CG-LNA NF 可以 < 1 dB" | 一阶模型 F ≥ 1+γ → NF ≥ 2.2 dB（long-channel γ=2/3）；短沟道实测常见 3.0-4.8 dB；要更低 NF 用 noise-cancelling 或 cascoded CS-LNA |
| "Rin = 1/gm 在所有频段都成立" | 高频 Cgs 等寄生让 Rin 偏离 1/gm；GHz 频段要 EM-aware 设计 |
| "增 gm 一直降 NF" | gm × Rs > 1（过匹配）→ NF 反升；最优在 gm·Rs = 1 |
| "用 PMOS CG 没 body effect 更好" | PMOS μ 低 → 同 gm 需更大 W → Cgs 大 → BW 反而差；典型 NMOS 仍优 |

## 不在本章范围

- 50 Ω 匹配电感设计（Lg / Ls） → RF passive knowledge
- noise-cancelling CG（CG + parallel CS）→ 未来 `blocks/lna-cmos/noise-cancelling-cg`
- LNA 整体设计（含 buffer / mixer 接口）→ `blocks/lna-cmos`
- TIA 应用 → chapter `tia-application`
- regulated CG → chapter `regulated-common-gate`
