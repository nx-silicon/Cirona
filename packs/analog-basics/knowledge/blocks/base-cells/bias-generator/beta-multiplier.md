---
chapter: beta-multiplier
parent: bias-generator
summary: |
  β-multiplier 自偏置 —— supply-independent / PTAT 输出 / 双稳态分析 /
  必须配 startup helper / 常用作 bandgap 的电流源
tokens: ~700
prerequisite_chapters:
  - basic-mirror-tree
related_skills:
  - circuit-method/device-sizing
  - circuit-method/bias-tree-reasoning
related_knowledge:
  - blocks/bandgap
---

# β-Multiplier 自偏置（Supply-Independent Bias）

## 拓扑

```
       VDD
        │
    ┌───┴───┐ ┌───┴───┐
    │ Mp1   │ │ Mp2   │ ← PMOS mirror (m=1:1)
    │ diode │ │ mirror│
    └───┬───┘ └───┬───┘
        ●─── vb_p     ●─── vb_p
        │             │
    ┌───┴───┐     ┌───┴───┐
    │ Mn1   │     │ Mn2   │ ← NMOS pair (m=1:K, 典型 K=4)
    │ (W,L) │     │(K·W,L)│
    └───┬───┘     └───┬───┘
        │             │
       VSS         R_set
                     │
                    VSS
```

**核心机制**：
- Mp1 / Mp2 mirror 强制 I_Mn1 = I_Mn2
- Mn2 比 Mn1 大 K 倍 → 同 Id 下 Vov_Mn2 < Vov_Mn1
- ΔVgs = Vov_Mn1 - Vov_Mn2 = I·R_set
- 自洽稳态：**I_bias 由 R_set + (W/L) + K 决定，与 VDD 几乎无关**（"supply-independent"）

## PTAT 特性

```
I_bias = (2/(μn·Cox·(W/L))) × ((1 - 1/√K) / R_set)²
```

- μn 随温度下降 → I 升 → **PTAT 趋势**
- 与 bandgap CTAT 项形成天然搭档（β-mult PTAT × bandgap CTAT 互补补偿）

## 双稳态问题（必须配 startup）

求解 I_bias 自洽方程有 **两个解**：
1. 正常工作点：I = nominal（µA 级）
2. **零电流点**：I = 0（所有管 cutoff 但稳定）

**stuck-at-zero 风险**：上电后若运气不好 stuck 在零点 → 主电路死。

→ **必须配 startup helper**（见 chapter `startup-helper`）。

## sizing 关系

| 量 | 推荐 | 因果 |
|---|---|---|
| K（Mn2/Mn1 W ratio）| 4 - 16（典型 4）| K 大 → ΔVov 大 → I_bias 大；K 太大 layout 难 |
| (W/L)_Mn1 | 由目标 I_bias 反推 | gm/Id 表 + Vov 选择 |
| L | 4 - 8 × Lmin | matching + ro |
| R_set | k Ω 量级（看 I_target）| 由 I_bias_target 反推 |

## 典型范例（5 µA Iref @ 180nm）

```
目标: I_bias = 5 µA
选 K = 4 → (1 - 1/√K) = 0.5
选 (W/L)_Mn1 = 5 → μn·Cox·(W/L) = 1000 µA/V²

I = (2/1000µ) × (0.5/R)² = 5e-6
→ R² = (0.5)² × 2/(1000µ × 5e-6) = 100k
→ R ≈ 316 Ω（理想），实际取 ~10 kΩ + 重新平衡 K 或 (W/L)
```

## PVT 漂

由 R + μ + V_th 都漂 → I_bias spread typical ±20-30%。修复方法：
- 数字 trim
- 后端 ADC 校准
- 与 bandgap 联合补偿

## 验证清单

- [ ] tran：电源 ramp-up 启动正确（必须加 startup helper 后）
- [ ] dc_snapshot：I_bias = nominal ± 5%
- [ ] PVT corner：I 漂 < ±30%
- [ ] tran：VDD 阶跃 1.6→1.8→2.0V → I_bias 几乎不变
- [ ] tran：温度 -40°C → 125°C → PTAT 斜率与公式对照

## 常见误区

| 心里想 | 现实 |
|---|---|
| "β-multiplier 自启动不需 startup" | **错** — 双稳态 stuck-at-zero 必须 startup |
| "I 与 VDD 无关" | 一阶是；实际有 channel-length modulation 弱依赖 |
| "K 越大 I 越大" | 是，但 layout 大 + matching 难；K=4 甜点 |
| "R_set 用 well resistor 节省面积" | TCR ±5000 ppm/°C → I 漂；用 poly |
| "β-multiplier = bandgap" | bandgap 是电压基准，β-mult 是电流源（PTAT only） |

## 不在本章范围

- 基础镜像树 → chapter `basic-mirror-tree`
- replica 偏置 → chapter `replica`
- startup helper 详细 → chapter `startup-helper`
- bandgap → `blocks/bandgap/`
- R_set 工艺选择 → `blocks/base-cells/resistive-load/basic.md`
