---
chapter: diode-load
parent: active-load
summary: |
  Diode-connected MOSFET 作 load —— Vgs=Vds 短接 / 永远 sat /
  R_load = 1/gm（低）/ Av = -gm_drv/gm_load（1-5）/ 宽 BW / 线性好
tokens: ~600
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/current-mirror
  - blocks/base-cells/common-source
---

# Diode-Connected Load

## 拓扑（事实）

```
        VDD
         │
    ┌────┴────┐
    │ M_load  │  ← diode-connected: gate 短接到 drain
    │ (PMOS   │     Vgs_load = Vds_load = Vth + Vov
    │  diode) │     永远 saturation
    └────┬────┘
         ●─── V_out
    ┌────┴────┐
    │ M_drv   │  ← gain device（CS/diff pair 输入管）
    │  NMOS   │
    └────┬────┘
         │
        VSS
```

**核心机制**：M_load 的 gate-drain 短接 → Vds = Vgs ≥ Vth + Vov →  **永远 saturation**（Vds_sat = Vov < Vds = Vth + Vov）。

> ⚠️ **物理事实强调**：diode-connected 永远 saturation，**严禁**写"diode load 易 triode"。
> 触发"M_load 进入 triode"是 mirror-load（其 Vds 由 Vout 决定，可能小到 < Vov），
> 不是 diode-load。

## 小信号公式

### R_load = 1/gm_load

由 diode 连接 → small-signal: i = gm·v + v/ro ≈ gm·v（忽略 ro）→ R_eq = 1/gm。

典型数值：gm = 0.1-10 mS @ Id = 10 µA - 1 mA → R_load = 100 Ω - 10 kΩ。

### Av = -gm_drv / gm_load

```
Av = -gm_drv × R_load = -gm_drv / gm_load
```

**关键**：Av 由两个 gm 之比决定，**与 ro 无关**（diode 短路掉了 ro 的贡献）。

| 实现 | Av 范围 | 因果 |
|---|---|---|
| 同尺寸（gm_drv ≈ gm_load）| ≈ -1 | 简单 buffer，几乎单位增益 |
| 不对称 sizing（W_drv > W_load）| -2 ~ -5 | gm_drv > gm_load → 增益略放大 |
| 极端不对称 | > -10 | 通常更佳用 mirror-load 而非 diode |

## 带宽优势（事实）

输出节点主极点：
```
fp = gm_load / (2π · C_out)
```
对比 mirror-load 的 fp = 1/(2π·ro·C_out) —— **diode-load 主极点高 ~ro·gm 倍**（典型 50-500×）。

→ diode-load 适合宽带（GHz）应用。

## 线性度（事实）

diode-load 的非线性主要来自 Vgs-Id 的平方律（不是 ro 的非线性）→ 比 mirror-load 线性度更好。

**应用**：高线性 buffer / log 转换器 / current-input cell（共栅级输入端 diode-load 给参考电流）。

## sizing 关系（与上层 gain device 协同）

| 起点 | 推导 | 因果 |
|---|---|---|
| Av_target | gm_drv/gm_load = |Av| | 决定两 gm 比 |
| 总功耗 | Id_共享（CS 单管 stack）| diode load 与 drv 串联 → I_drv = I_load |
| Vov_load | 0.1-0.2V（小匹配差，大 swing 损）| Vov ↑ → R_load ↓ → Av ↓；Vov 太小（<80mV）短沟道 ro 反不升 |
| L_load | 4-8 × Lmin | matching + ro（虽然 diode 不靠 ro 增 Av，但 mismatch 仍影响）|

## sizing 范例（共栅 + diode load）

> 📌 **@ vpdk180nm**（μn/p·Cox / Vth 数值参考 `pdks/vpdk180nm/index.md`）。换工艺需重算所有数值；公式形式（Av = -gm_drv/gm_load）跨工艺通用。

设计目标：CS gain stage with Av = -3, Id = 100 µA, VDD = 1.8 V

```
M_drv (NMOS):
  - 选 gm/Id = 12 → gm_drv = 1.2 mS
  - Vov_drv = 167 mV / W = 5 µm / L = 0.36 µm（2× Lmin）

M_load (PMOS diode):
  - gm_load = gm_drv / |Av| = 1.2m / 3 = 0.4 mS
  - Vov_load = 2·Id/gm = 0.5V → 偏大，缩为 0.2V
  - 用 PMOS：μp/μn ≈ 0.4 → W_load = (gm_drv/gm_load) × W_drv × (μn/μp) ≈ 3 × 5 × 2.5 = 37.5 µm
  - L_load = 0.72 µm（4× Lmin）

DC OP 验证:
  V_drain_drv = VDD - Vgs_load = 1.8 - 0.7 = 1.1 V（M_drv saturation OK）
  M_load.Vds = Vgs_load = 0.7 V > Vov = 0.2 V ✓ saturation
```

## 验证清单

- [ ] dc_snapshot：M_load.Vds = M_load.Vgs（diode-connected 自洽）
- [ ] dc_snapshot：M_drv saturation（Vds_drv > Vov_drv）
- [ ] AC：测 Av = V_out/V_in，应 ≈ -gm_drv/gm_load
- [ ] AC：BW 应为 fp = gm_load/(2π·C_out)（远高于 mirror-load）
- [ ] tran：大信号 1V_pp distortion 应低（diode 平方律线性度好）

## 常见误区

| 心里想 | 现实 |
|---|---|
| "diode load 容易 triode" | **物理错误**：diode-connected Vds = Vgs，**永远 saturation** |
| "diode load 增益由 ro 决定" | 错——Av = -gm_drv/gm_load，ro 几乎不参与 |
| "diode load Av 可以做到 100" | 不实际；Av > 10 通常需要 mirror-load 或 cascode |
| "L_load 用 Lmin 反正不靠 ro" | 短沟道 mismatch 大；Pelgrom σ ∝ 1/√(WL) 仍要保 L ≥ 2-4×Lmin |

## 不在本章范围

- mirror-load（独立 bias）→ chapter `mirror-load`
- cascode-load（堆叠）→ chapter `cascode-load`
- 故障 debug → chapter `troubleshooting`
- gm/Id 方法学 → skill `circuit-method/device-sizing`
