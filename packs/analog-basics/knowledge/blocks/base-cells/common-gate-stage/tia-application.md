---
chapter: tia-application
parent: common-gate-stage
summary: |
  共栅级在 TIA（跨阻放大器）前端的应用 —— 跨阻增益 / Rf 反馈 /
  噪声贡献 / BW 与 Rf·C_PD 极点 trade-off
tokens: ~700
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/ac-feedback-loop-method
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/resistive-load
---

# CG 在 TIA 中的应用

## TIA 架构（CG 作为输入级）

```
                     VDD
                      │
                  ┌───┴───┐
                  │ Rload │  (or active load)
                  └───┬───┘
                      ●─── V_out
                  ┌───┴───┐
        Vbias ───→│  Mn   │  (CG 接收光电流)
                  │ NMOS  │
                  └───┬───┘
                      ●─── source 节点 V_s
                      │
                ┌─────┴─────┐  ← Rf 反馈电阻（从 V_out 接回 V_s）
                │           │
                ▼           │
     I_PD（光电流）         │
                │           │
            photodiode ─────┘ (反馈电阻 Rf 跨 V_out 与 V_s 之间)
            (Cathode)
                │
               VSS
```

**核心机制**（与 CS-TIA 区别）：
- **CG-TIA**：电流从 source 进入 → CG 把 V_s 钉在 1/gm 的低阻 → drain 端 R_load 转为电压
- **CS-TIA（更常见）**：电流灌入 V_in 节点 + Rf 反馈（shunt-shunt）→ 跨阻 ≈ -Rf
- **CG-TIA 的优势**：低 Rin（≈ 1/gm）天然 ≪ photodiode 寄生 → V_s 摆幅小 → 不易被 C_PD（pF-nF）吃掉 BW
- **CG-TIA 的劣势**：跨阻不直接由 Rf 决定（需仔细推导），噪声 vs CS-TIA 通常更高

## 跨阻增益（small-signal 分析）

```
Z_T = V_out / I_in
```

简化（无 Rf 时，纯 CG）：
```
Z_T_open = R_load   (输入电流全部流过 CG → 流经 R_load)
```

加 Rf 反馈（shunt-shunt 反馈结构）：完整 Z_T 表达式依赖反馈环具体接法（feedback factor / loop gain），**不在本 base-cell 范围**。本章只保留 CG 前端简化事实：

- **简单 CG-TIA（无 Rf）**：Z_T ≈ R_load（输入电流全过 CG → R_load 转电压）；典型应用 1k - 数十 kΩ 跨阻
- **加 Rf 改善 BW + noise**：完整 TIA 设计（含 Rf loop / PM 验证 / 噪声整形）见未来 `blocks/tia/`

## sizing 决策（事实 + 因果）

| spec | sizing 决策 | 因果 |
|---|---|---|
| 目标 Rin（钉住 photodiode 节点）| gm = 1/Rin_target | typical Rin = 100Ω-1kΩ → gm = 1-10 mS → Id = 100µA-1mA |
| 目标 Z_T（跨阻）| R_load = Z_T_target | Z_T ≈ R_load 简化情况；@ 1V_pp out / 100µA in → R_load = 10 kΩ |
| 目标 BW | C_drain × R_load < 1/(2π·BW)| C_drain 含 Cgd_CG + C_load_metal + 下级 Cgs；典型 100 fF - 1 pF |
| 噪声目标（NF）| 增 gm（减 thermal noise / gm × Rs²）| gm 大 → 功耗大；找 NF vs power 最佳点 |

## 噪声分析（关键）

CG-TIA 输入参考噪声主要源：
1. **CG 管 thermal**：i²_n_CG = 4kT·γ·gm（电流谱密度 A²/Hz）
2. **R_load thermal**：i²_n_RL = 4kT/R_load
3. **Rf thermal**（如有）：i²_n_Rf = 4kT/Rf

输入参考（电流谱密度，A²/Hz；R_load 已经是 Norton 电流形式，**不**再除 Z_T²）：
```
i²_in_total ≈ 4kT·γ·gm + 4kT/R_load + 4kT/Rf
              ↑           ↑               ↑
            CG channel   Rload Norton     Rf Norton
```

**因果**：
- gm 大 → CG thermal 大（i²_n_CG ∝ gm），但同时 Rin 小 / 增益高 → SNR 关系复杂
- typical NF 优化点：gm/Id ≈ 8-12（中等反型）+ R_load 取大（noise i²/R 反而小）

## Sizing 范例（光电二极管 TIA）

> 📌 **@ vpdk180nm**（μn·Cox / Vth / fT 数值参考 `pdks/vpdk180nm/index.md`）。换工艺需重算 R_load 与 gm；TIA noise 公式（i²_n / Z_in）跨工艺通用。

设计目标：
- I_PD = 10 µA - 100 µA（光强变化）
- C_PD = 1 pF（photodiode 寄生）
- Z_T_target = 10 kΩ → V_out = 100 mV - 1 V
- BW_target = 100 MHz
- VDD = 1.8 V

**derivation**：
```
Rin_target: 让 V_s 摆幅 < 50 mV @ I_PD = 100 µA
  → Rin ≤ 50mV / 100µA = 500 Ω → gm = 2 mS

CG sizing（NMOS）:
  - gm = 2 mS, gm/Id = 10 → Id = 200 µA
  - Vov = 2 / 10 = 200 mV
  - L = 0.36 µm（2× Lmin）, W 按 gm/Id 表查 ≈ 30 µm
  - 验证 Rin = 1/(gm+gmb) ≈ 1/(2m × 1.2) ≈ 420 Ω ✓

R_load:
  - Z_T = R_load → R_load = 10 kΩ
  - V_out_max = R_load × I_PD_max = 10k × 100µ = 1 V ✓（不撞 VDD）
  - 检查 V_drain DC ≈ VDD - I_DC × R_load = 1.8 - 200µ × 10k = -200 mV ✗
  - **修正**：Id = 200 µA × R_load 静态压降 = 2V > VDD → 必须降 Id 或 R_load
  - 改 R_load = 5 kΩ + Id = 200 µA → V_drain = 0.8V，OK；R_load 降一半 → Z_T = 5k

BW:
  - C_drain 估 200 fF（含下级 Cgs 100fF + metal 100fF）
  - drain 极点 = 1/(2π·5kΩ·200fF) = 159 MHz > 100 MHz ✓

Iq = 200 µA / VDD = 1.8V → 静态功耗 = 360 µW
```

## 验证清单

- [ ] dc_snapshot：V_s 静态在 Vbias_g - Vgs_n（典型 0.6 V）；与 PD bias 兼容
- [ ] dc_snapshot：CG 管 saturation
- [ ] AC 仿真：实测 Z_T = V_out/I_in @ DC + 中频
- [ ] AC 仿真：实测 BW（-3 dB 带宽）≥ spec
- [ ] noise 仿真：input-referred i²_n_total 与公式预测对照
- [ ] tran 仿真：阶跃 I_PD 0 → 100 µA → V_out 建立时间 ok

## 常见误区

| 心里想 | 现实 |
|---|---|
| "CG-TIA 跨阻 = Rf"（混了 CS-TIA）| CS-TIA 跨阻 ≈ -Rf；CG-TIA 跨阻 ≈ R_load（电流 → R_load 直接转电压） |
| "增大 gm 任意降 Rin" | gm 大 → Id 大 → R_load 上压降大 → V_drain headroom 不够，**先看静态点再 sizing** |
| "C_PD 不影响 BW（CG 不像 CS）"| C_PD 仍在 source 节点，Rin × C_PD 仍是次极点（虽然 Rin 小，但 C_PD pF 级时 ≈ 1 GHz） |
| "Rf 越大跨阻越大" | 是，但 Rf 增大 → noise（4kT/Rf）减但 BW 降；trade-off |

## 不在本章范围

- 完整 TIA 系统（含输出 buffer + 反馈环 PM）→ 未来 `blocks/tia/`
- 光电二极管 / 雪崩二极管模型 → `devices/`
- LNA 与 TIA 的拓扑共性 → 见 chapter `lna-application`
- regulated CG（钉源节点更硬）→ chapter `regulated-common-gate`
