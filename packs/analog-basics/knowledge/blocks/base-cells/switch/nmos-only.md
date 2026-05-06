---
chapter: nmos-only
parent: switch
summary: |
  单 NMOS 开关 —— Ron 公式 / Vth 限制 / 摆幅约束 / charge injection 估算 /
  典型应用（小摆幅 SC / 数字辅助）
tokens: ~600
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
related_knowledge: []
---

# 单 NMOS 开关

## 拓扑（最简）

```
              CK（时钟）
               │
               ▼ gate
    V_in ────│┤────  V_out → C_sample
                  M_sw （NMOS）
              source/drain 对称
              (signal flow either way)
```

**核心机制**：
- CK = VDD（high）→ M_sw 导通 → V_out 跟踪 V_in
- CK = 0（low）→ M_sw 关断 → V_out 保持采样值
- **NMOS 的 source 是较低电压端**——若 V_in 高，drain=V_in / source=V_out；若 V_out 高反过来

## Ron 公式

完整：
```
Ron = 1 / (μn·Cox·(W/L)·(Vgs - Vth))   # 三极管区，忽略 Vds 项
    = 1 / (μn·Cox·(W/L)·Vov)
```

V_in 在范围内变化时：
```
Vgs = V_clk - V_signal                            # NMOS 的 source 是低端
Vov_eff = V_clk - V_signal - Vth_eff(VSB)         # body effect: 高电平时 VSB 大 → Vth_eff 升
其中 Vth_eff = Vth0 + γ(√(2ΦF + VSB) - √(2ΦF))
Ron 随 V_signal 上升而升高（Vth_eff 同向恶化让 Ron 比常 Vth 估算更差）
```

**关键限制**：当 `V_signal > V_clk - Vth_eff(VSB)` → Vov_eff ≤ 0 → **NMOS 关断**。
（body effect 让这个上限比 V_clk - Vth0 还更低 100-200mV @ 180nm γ ≈ 0.4 V^0.5）

例 @ 180nm vpdk：
- V_clk = 1.8 V，Vth_n ≈ 0.5 V → V_signal_max ≈ 1.3 V
- V_signal = 0 V → Vov = 1.3 V，Ron ≈ small（典型 1-10 kΩ）
- V_signal = 1.3 V → Vov ≈ 0，Ron 暴涨（→ ∞）

→ **Ron 跨摆幅变化 5-10× 是 nmos-only 的根本线性度问题**。

## 摆幅约束 vs 信号 V_in

| V_signal 范围 | Ron 行为 | 失真度 |
|---|---|---|
| 0 - VDD/3 | Ron 几乎恒定（~1 kΩ）| 优 |
| VDD/3 - 2·VDD/3 | Ron 缓升（1-2 kΩ）| 良 |
| 2·VDD/3 - (V_clk - Vth) | Ron 急升（2-10 kΩ）| 差 |
| V_signal > V_clk - Vth | NMOS 关断 | 不能用 |

→ NMOS-only 适合 V_signal 在 0 - VDD/2 范围（对地参考的小信号）。

## charge injection 估算（关键误差源）

开关关断时，channel 中的电荷被注入到 source 和 drain 两端。

通道电荷总量：
```
Q_ch = W·L·Cox · (Vgs - Vth) = W·L·Cox · Vov
```

注入到采样节点（C_sample）的部分：
```
Q_inj = α × Q_ch          α ∈ [0.4, 0.6]（取决于 source/drain 阻抗，对称时 0.5）

ΔV_sample = Q_inj / C_sample
```

例：W = 5 µm / L = 0.18 µm / Cox = 8.6 fF/µm² / Vov = 1 V → Q_ch = 7.7 fC
- C_sample = 1 pF → ΔV = 3.85 mV（**误差大**）
- C_sample = 10 pF → ΔV = 0.39 mV

**因果**：
- 减 W·L → 减 charge inj，但 Ron 升 → 建立慢；trade-off
- 减 Vov → 减 charge inj，但 Ron 升；同样 trade-off
- 增 C_sample → 减 ΔV，但面积大 + kT/C noise 改善有限（√C 关系）

## clock feedthrough（次级误差源）

clock 边沿通过 Cgd_overlap 耦合到采样节点：
```
ΔV_feedthrough = (Cov / (Cov + C_sample)) × ΔV_clk

Cov ≈ Cox × W × L_overlap ≈ 0.1 × W × L × Cox
```

@ W=5µm / L=0.18µm / V_clk swing 1.8V → Cov ≈ 1 fF → ΔV_feedthrough ≈ 1.8 mV @ C_sample=1pF。

**关键**：charge injection 与 V_signal 相关（非线性），clock feedthrough 与 V_signal **几乎无关**（仅 offset）→ 后者可校准，前者不易。

## sizing trade-off 矩阵

| 目标 | sizing 选择 |
|---|---|
| 快速建立（小 Ron） | W ↑ |
| 小 charge inj | W·L ↓ + Vov ↓ |
| 减 clock feedthrough | W ↓ + L_overlap ↓（layout） |
| 大 V_in 范围 | 改用 transmission-gate（chapter）或 bootstrap |
| 高线性度 | 改用 bootstrap（chapter） |

→ nmos-only 几乎所有 spec 同时优化都不成立 → 适用面窄。

## 典型应用（适用边界）

✅ **适合**：
- 数字 / 数模混合的逻辑控制（V_signal 是数字电平 0/VDD）
- 小摆幅 SC 电路（V_signal 在 Vcm ± 100 mV）
- bottom-plate switch（接到 ground，V_signal ≈ 0 → Ron 恒定）

❌ **不适合**：
- ADC 主采样开关（输入摆幅大 + 高线性度需求）
- rail-to-rail 模拟连接

## 验证清单

- [ ] DC OP：M_sw 在 ON 阶段 V_in / V_out 几乎相等（误差 = I_load × Ron）
- [ ] tran：track 阶段建立 7τ 内（τ = Ron × C_sample）
- [ ] tran：hold 阶段 V_out drift（leakage / sub-Vth）< spec
- [ ] tran：关断瞬间 ΔV_sample = charge inj + clock feedthrough，与公式对照
- [ ] AC：测 Ron vs V_in（应符合 1/(μ·Cox·W/L·Vov) 曲线）
- [ ] PVT corner（FF/SS）：V_th 漂 → Ron 漂 / V_in_max 漂

## 常见误区

| 心里想 | 现实 |
|---|---|
| "NMOS 开关线性度还行" | Ron 跨摆幅变 5-10× → 失真显著；rail-to-rail 必须 transmission-gate / bootstrap |
| "增 W 就能减 Ron" | 是，但 W 增 → charge inj 增 → 采样误差更大；trade-off |
| "用 PMOS 就解决了 Vth 限制" | PMOS 在 V_signal 接近 0 时关断；同样有 Vth 限，方向相反 |
| "charge inj 加 dummy switch 全消" | dummy 部分抵消 50-70%，不是全消；底板优先关断更有效 |
| "clock feedthrough 与 charge inj 一回事" | 两个完全不同的物理：通道电荷 vs Cov 耦合；它们叠加但分别建模 |

## 不在本章范围

- 传输门（双向 rail-to-rail）→ chapter `transmission-gate`
- bootstrap（线性 Ron）→ chapter `bootstrapped`
- 故障 debug → chapter `troubleshooting`
- 底板优先关断时序 → chapter `troubleshooting` / SC ADC 系统设计
- kT/C noise 推导 → `blocks/base-cells/cmfb/switched-capacitor.md`
