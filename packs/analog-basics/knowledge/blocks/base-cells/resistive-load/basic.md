---
chapter: basic
parent: resistive-load
summary: |
  基础电阻负载 —— Av/swing/noise/BW 公式 + 五变体 sizing 决策（poly / diffusion /
  well / triode-MOS / off-chip）+ Av-swing-noise-area 四角折衷
tokens: ~750
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/active-load
  - blocks/base-cells/common-source
---

# 基础电阻负载

## 拓扑（共源 + 电阻负载）

```
        VDD
         │
         R_load （poly / diffusion / well / triode-MOS）
         │
         ●─── V_out
    ┌────┴────┐
    │ M_drv   │ ← gain device（CS / diff pair）
    │  NMOS   │
    └────┬────┘
         │
        VSS
```

**核心机制**：电流变化 ΔI 通过 R 转换为电压变化 ΔV = -ΔI·R（负号是 NMOS CS 的反相）。**电阻是线性的**——R 不随 V_out 摆幅变化（除 well resistor 在高场下 VCR 显著）。

## 关键公式（事实）

### DC 增益

```
Av = -gm_drv × R_load          # 当 R << ro_drv 时近似成立
严格式：Av = -gm_drv × (R_load ‖ ro_drv)
```
通常 R << ro_drv → 上式 R 可忽略 ro_drv；当 R 接近或超过 ro_drv 时必须用严格式。

### 摆幅与功耗

```
V_out_quiescent = VDD - I_DC × R_load
V_out_max = VDD                              # signal off
V_out_min = V_DSat (M_drv)                   # signal max → M_drv 撞 triode
P_static = V_DD × I_DC

实用约束：V_out_quiescent 通常设在 (VDD + Vdsat_drv) / 2 → 对称 swing
```

### 噪声（线性 + 可预测）

```
S_v_R = 4kT × R                              # V²/Hz 谱密度
v_n_R_rms = √(4kT × R × BW)                  # 总 RMS

典型数值（@ 室温 4kT = 1.66e-20 J）：
  R = 1 kΩ  → √(4kT·R) ≈ 4 nV/√Hz
  R = 20 kΩ → √(4kT·R) ≈ 18 nV/√Hz
  R = 100 kΩ → √(4kT·R) ≈ 40 nV/√Hz
```

输入参考噪声（除以增益 gm·R）：
```
v_n_in_referred = √(4kT·R) / (gm·R) = √(4kT/(gm² · R))
                = √(4kT / gm) × 1/√(gm·R)
```
→ R 大 → 输入参考噪声**减**（因为增益增加更快）；但 R 自身的输出噪声变大。

### 带宽（受寄生限）

```
f_-3dB = 1 / (2π × R × C_par)

C_par 含：M_drv.Cgd（Miller 后） + 下级 Cgs + 电阻自身寄生（poly to substrate）+ metal wiring

典型 R = 10 kΩ / C_par = 200 fF → f_-3dB ≈ 80 MHz
```

## 五变体 sizing 决策

### A. Poly Resistor（首选）

**特征**：
- sheet R: 100-300 Ω/sq（工艺依赖）
- TCR: ±500 ppm/°C（@ 高电阻 poly）/ ±100 ppm/°C（@ 低电阻 silicide poly）
- VCR: 几乎为 0（< 50 ppm/V）
- matching: σ(ΔR/R) ≈ A_R / √(W·L)，A_R 工艺常数（典型 1-3 %·µm，依电阻类型与版图）；W·L 越大 σ 越小（1/√WL）
- linearity: 优（恒定 R 跨整个 swing）

**适用**：通用首选 / 差分对负载 / 反馈分压器 / TIA Rf。

**sizing**：
- R_target → 板数 N = R/sheet_R → 选 W（典型 1-2 µm）+ L = N × W → 蛇形布局
- 例 R = 20 kΩ @ poly 200 Ω/sq → N = 100 sq → W=1µm/L=100µm 或 W=2µm/L=200µm

### B. Diffusion Resistor（不推荐除非空间真紧）

**特征**：
- sheet R: 50-200 Ω/sq
- TCR: ±1500 ppm/°C（**比 poly 差 3×**）
- VCR: 中（junction 调制）
- linearity: 中

**陷阱**：junction capacitance 大 → BW 受限 + ESD 路径耦合。**几乎不推荐**。

### C. Well Resistor（极高 R 值）

**特征**：
- sheet R: 1-10 kΩ/sq（远高于 poly）
- TCR: ±2000-5000 ppm/°C
- VCR: 高（well 在不同 V 下耗尽层不同）
- linearity: 差

**适用**：仅用于 R > 1 MΩ 的场合（如 PTAT bias / Vref divider）+ 不在乎线性度。

### D. Triode-Region MOS Pseudo-R（可调）

**特征**：
- 用 NMOS / PMOS 在 triode 区做 R：R_eq ≈ 1/(μCox·(W/L)·(Vgs - Vth_eff(VSB) - Vds/2))（对小信号；含 body effect 一阶修正）
- **body effect 提醒**：若 bulk 不接 source（标准三阱中常见），VSB 随信号共模变化 → Vth_eff = Vth0 + γ(√(2ΦF + VSB) - √(2ΦF)) → R_eq 调阻曲线会额外漂移；高线性应用应明确说明 isolated well / back-gate 短接条件
- **可调**：通过 Vgs 改变 R_eq → 适合 replica bias / VGA / 自适应 load
- linearity: **差**（R 随 V_DS 变 → 非线性失真）
- 面积：极小（vs poly 节省 5-20×）

**典型 sizing**：
```
R_target = 10 kΩ
选 Vgs - Vth = 0.5 V，μCox·(W/L) = 1/(R·V_OV) = 1/(10k·0.5) = 200 µS
@ μCox = 200 µA/V² → W/L = 1（如 W=0.5µm, L=0.5µm）
```

**陷阱**：
- V_DS 摆幅 ≥ 50 mV 就开始非线（distortion > -40 dB）
- PVT 漂大（V_th + μ 都漂）
- 必须用 replica + 反馈 / digital trim 校正

### E. Off-Chip Resistor（仅原型）

精度好（0.1-1%）+ 高功率耐受 + 高 R 值任意；但不集成 → 仅用于测试板 / 调试。

## sizing 范例（CS gain stage with poly load）

> 📌 **@ vpdk180nm**（μn·Cox / Vth / R_poly 数值参考 `pdks/vpdk180nm/index.md`）。**poly resistor 模型不同工艺差异较大**（高阻/低阻 poly / TCR / VCR），必须查 PDK；公式形式（Av = -gm·R_load）跨工艺通用。

设计目标：Av = -10 / I_DC = 100 µA / VDD = 1.8 V / V_out_Q = 0.9V（中央）/ BW ≥ 50 MHz

```
R_load 推导:
  V_out_Q = VDD - I·R → R = (VDD - V_out_Q) / I = (1.8-0.9) / 100µ = 9 kΩ
  
gm_drv from Av:
  |Av| = gm·R → gm = 10 / 9k = 1.1 mS
  
NMOS sizing:
  gm/Id = 11 → Id = 100 µA OK
  Vov = 2/(gm/Id) = 0.18 V
  W/L 由 gm/Id 表 → W = 5 µm, L = 0.36 µm

R_load 实现（poly 200 Ω/sq）:
  N = 9k / 200 = 45 sq → W=1µm/L=45µm（蛇形）

噪声:
  v_n_R = √(4kT·9k) ≈ 12 nV/√Hz
  输入参考 = 12n / 10 = 1.2 nV/√Hz @ R 输出端

BW:
  C_par = 200 fF
  f_-3dB = 1/(2π·9k·200f) = 88 MHz ✓ spec
```

## 验证清单

- [ ] dc_snapshot：M_drv saturation（V_DS_drv > Vov）
- [ ] dc_snapshot：V_out_Q 在中央（avoid 撞 rail / saturation 边缘）
- [ ] AC：实测 Av = -gm·R（误差 < 10%，否则 R << ro 假设破坏）
- [ ] AC：BW = 1/(2π·R·C_par)
- [ ] noise 仿真：4kT·R 谱密度 vs 公式
- [ ] PVT corner（FF/SS, -40°C/125°C）：R 漂 ±10% （poly TCR ×温差 +工艺 sheet R 漂）

## 常见误区

| 心里想 | 现实 |
|---|---|
| "Av = -gm·R 只是近似" | 严格成立 @ R << ro；当 R 接近 ro 时改 Av = -gm·(R‖ro) |
| "增大 R 就增 Av" | 是，但 V_drop = I·R 也增 → 撞 rail；先看 swing |
| "diffusion resistor 便宜" | TCR 三倍差，PVT 漂死；几乎从来不推荐 |
| "triode-MOS 完美替代 poly"| 非线性、PVT 漂；只在调谐 / 特殊 bias 用 |
| "电阻噪声只看 4kTR" | 是；但 1/f noise 在某些工艺 / well resistor 中可能存在 |

## 不在本章范围

- TIA Rf 应用 → chapter `tia-feedback-resistor`
- 宽带 / RF 优化 → chapter `broadband-load`
- 故障诊断 → chapter `troubleshooting`
- 与 active load 选择决策 → 见 index 比较表 + `blocks/base-cells/active-load/`
- 电阻 layout 蛇形 / matching → layout knowledge（V4 不在范围）
