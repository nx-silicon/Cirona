---
chapter: transmission-gate
parent: switch
summary: |
  传输门（NMOS+PMOS 并联）—— rail-to-rail 摆幅 / 互补 Ron 部分线性化 /
  charge cancellation 部分（不彻底）/ 双时钟（CK + CKB）需求
tokens: ~600
prerequisite_chapters:
  - nmos-only
related_skills:
  - circuit-method/device-sizing
related_knowledge: []
---

# 传输门（Transmission Gate, TG）

## 拓扑（NMOS + PMOS 并联）

```
                CK    CKB（互补时钟）
                │      │
                ▼ Vg_n ▼ Vg_p
       ┌─────────┐    ┌─────────┐
       │  M_n    │    │  M_p    │
       │  NMOS   │ ║ │  PMOS   │ ← 并联
       └─────────┘    └─────────┘
              ▲              ▲
              │              │
              ●─── V_in ─────●─── V_out
                 (source/drain 对称)
```

**核心机制**：
- NMOS 和 PMOS 并联 + 互补时钟（CK / CKB）控制
- 两管在 V_signal 不同区域接力提供低 Ron：
  - V_signal ≈ 0：NMOS Ron 极低（Vov_n ≈ 1.3V）；PMOS 几乎关断
  - V_signal ≈ VDD：PMOS Ron 极低；NMOS 几乎关断
  - V_signal ≈ VDD/2：两管都"半开"，Ron 中等
- 总 Ron = Ron_n ‖ Ron_p

## Ron 跨摆幅特性

```
1/Ron_total = 1/Ron_n + 1/Ron_p
            = μn·Cox·(W/L)_n · (V_clk - V_signal - Vthn_eff(VSBn))
            + μp·Cox·(W/L)_p · (V_signal - |Vthp_eff(VSBp)|)
```

**body effect 注意**：bulk 通常固定在 VSS（NMOS）/ VDD（PMOS）→ 中高共模时 VSB 大 → Vth_eff 显著上升。
TG 只能部分线性化 Ron；即便补足 W_p/W_n 比，也仍残留 1.5-3× Ron 跨摆幅变化（不是教科书常见的"近恒定"理想曲线）。

| V_signal | NMOS 贡献 | PMOS 贡献 | Ron 总 |
|---|---|---|---|
| 0 V | 强（Vov_n ≈ 1.3V）| 弱（关断）| 主 NMOS |
| VDD/2 | 中 | 中 | 较低（两管协同）|
| VDD | 弱 | 强 | 主 PMOS |

→ Ron 跨摆幅变化 1.5-3× （vs nmos-only 5-10×）→ **线性度改善**。

**典型 Ron**（W_n=5µm / W_p=12µm @ 180nm vpdk）：
- V_signal = VDD/2: Ron ≈ 0.5-1 kΩ
- V_signal = 0 or VDD: Ron ≈ 1-2 kΩ

## sizing 决策（NMOS / PMOS W 比）

为让 Ron 跨摆幅尽可能恒定：
```
(W/L)_p ≈ (μn/μp) × (W/L)_n ≈ 2.5-3 × (W/L)_n
```
实际略偏 PMOS 比理论大（应对 PMOS Vth 高 + 短沟道效应）。

## charge injection cancellation（部分）

两管关断时通道电荷分别注入：
- NMOS 关断：注入正电荷 → Q_inj_n
- PMOS 关断：注入负电荷 → Q_inj_p

理想对称（W·L 比例 + 同时关断）→ Q_inj_n + Q_inj_p ≈ 0（互补抵消）。

**实际**：
- W·L 不完全互补（即 (W·L)_n × Vov_n ≠ (W·L)_p × Vov_p across V_signal）
- 时序不完全同步
- 互补抵消通常 50-70%（不是 100%）

→ TG 比 nmos-only charge inj 减小 2-5×。

## clock feedthrough（双向部分抵消）

CK 上升 → NMOS Cgd_n 把脉冲耦合到 V_out（正方向）；同时 CKB 下降 → PMOS Cgd_p 耦合负方向 → **理想抵消**。

实际抵消 60-80%（layout / 时序不完全对称）。

## 应用边界

✅ **适合**：
- rail-to-rail 模拟传输（multiplexer / mux 输入）
- 中精度 SC 电路（10-12 bit ADC）
- 大 V_signal 摆幅但不要求极致 Ron 线性

❌ **不适合**：
- 高精度 ADC（≥ 14 bit）→ Ron 残留 1.5-3× 变化仍引起失真
- 极低功耗（双时钟 + PMOS 大 W）

## sizing 范例（10-bit SC ADC sample switch）

> 📌 **@ vpdk180nm**（μn/p·Cox / Vth 数值参考 `pdks/vpdk180nm/index.md`）。换工艺重算 W_n/W_p；transmission gate 拓扑（NMOS+PMOS 互补）跨工艺通用。

设计目标：V_signal 0 - 1.8 V / Ron < 1 kΩ across full swing / charge inj ΔV < 1 mV @ C_sample=2pF

```
NMOS sizing:
  V_signal=0V → Ron_n_target = 0.5 kΩ
  μn·Cox=200µA/V², Vov_n=1.3V
  (W/L)_n = 1/(500·200µ·1.3) = 7.7
  L = 0.18 µm，W_n = 1.4 µm × m=2 → W_n = 2.8 µm

PMOS sizing:
  W_p = 2.5 × W_n = 7 µm, L_p = 0.18 µm

charge inj 估算:
  Q_n = W·L·Cox·Vov = 2.8 × 0.18 × 8.6f × 1.3 = 5.6 fC
  互补抵消 60% → 残留 2.2 fC, α=0.5 → Q_inj = 1.1 fC
  ΔV = 1.1f / 2p = 0.55 mV ✓
```

## 验证清单

- [ ] DC sweep：Ron vs V_in 曲线（应在 0.3-0.7 kΩ 范围，跨摆幅）
- [ ] tran：charge inj 误差 < spec
- [ ] tran：clock feedthrough 在 CK / CKB 边沿对称
- [ ] PVT corner：FF / SS Ron 漂 < ±30%

## 常见误区

| 心里想 | 现实 |
|---|---|
| "TG 完全消除 charge inj" | 仅部分抵消（50-70%）；底板优先关断仍是优先策略 |
| "TG 总比 NMOS 好" | 错——面积 + 时钟数 + sizing 复杂；信号摆幅小（< VDD/2）时 NMOS 已够 |
| "W_p = W_n 就行" | 不行——μ 不对称 → Ron 不对称；PMOS W 必须 2.5-3× NMOS |
| "TG 用于 GHz 采样" | 不推荐——bootstrap 在线性度 + 速度都更优 |

## 不在本章范围

- nmos-only 基础 → chapter `nmos-only`
- bootstrap → chapter `bootstrapped`
- 故障 debug → chapter `troubleshooting`
- 完整 SC ADC 时序 → `systems/sar-adc`
