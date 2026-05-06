---
chapter: active-load
parent: differential-pair
summary: |
  差分对 + active load —— PMOS mirror-load 把双端转单端 / 增益跳 30-50 dB /
  ICMR 与 output swing trade-off / PMOS load L > input pair L 的物理理由
tokens: ~800
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/active-load
  - blocks/base-cells/current-mirror
---

# Differential Pair with Active Load

## 拓扑（NMOS 输入 + PMOS mirror-load，单端输出）

```
                    VDD
                     │
              ┌──────┴──────┐
              │             │
          ┌───┴────┐    ┌───┴────┐
          │ M3     │ ◄►│ M4     │   PMOS mirror-load
          │ (diode)│   │ (mirror)│   M3 diode-connected
          └───┬────┘    └───┬────┘   M4 mirror M3 的 Vgs
              ●(Vx)         ●─── Vout（单端）
          ┌───┴────┐    ┌───┴────┐
   Vinp ──┤ M1     │    │ M2     ├── Vinn
          │ (NMOS) │    │ (NMOS) │
          └───┬────┘    └───┬────┘
              │             │
              └──────┬──────┘
                     │
                ┌────┴────┐
                │  M5     │ tail
                │ Itail   │
                └────┬────┘
                    VSS
```

**信号路径**：
- Vinp 增 → M1 Id 增 → M3 Id 增（M3 diode）→ Vx 降（M3 Vgs 增）→ M4 Vgs 增 → M4 Id 增（PMOS source 接 VDD：|Vgs| 增 = Vsg 增 → Id 增）
- 同时 Vinp 增 → 差分对让 M2 Id 减 → 单端从 M2 drain 拉低
- 两路相加：M4 推电流上升 + M2 抽电流下降 → Vout 摆动 = 2× 单管贡献

## 核心机制

active load 把**双端**差分输出转成**单端**：
- M3 抓 M1 侧电流变化 → M4 镜像 → 加到 M2 侧节点
- 使 Vout 节点的小信号电流 = M4_id - M2_id = 2 × gm_drv × (Vinp - Vinn)/2 = gm_drv × Vid
- 增益翻倍（vs 直接拿 M2.drain 单端，效益 +6 dB）

## 小信号公式

```
Av = gm_M1 × (ro_M2 ‖ ro_M4)
   ≈ gm_drv × ro_drv / 2    （ro_drv ≈ ro_load 时）
   量级：30-50 dB（180nm，Id = 10 µA / side）
```

主极点：fp1 = 1/(2π × Rout × Cload)，Rout = ro_M2 ‖ ro_M4 ~ MΩ 级。

## ⚠️ PMOS load L > input pair L 的物理理由（必查）

| 指标 | 因果 | 推论 |
|---|---|---|
| **input-referred noise** | v_n_in² ≈ v_n_M1² × [1 + (gm_M3/gm_M1)²] | 想噪声小 → gm_M3 << gm_M1 |
| | gm = √(2·μ·Cox·W·L·Id) | 同 Id 下 gm 越小需 W·L 小？错 —— 用 gm/Id 视角更准 |
| | gm_p / gm_n at fixed Id：gm_p 本就小（μ_p ~ 1/3 μ_n）| 已部分有利，但还要进一步压 |
| | 增 L_p 让 PMOS 进**强反型**（gm/Id 小）→ gm 进一步降 | **L_p 增 = 噪声有利方向** |
| **matching** | σ(ΔVth) ∝ 1/√(W·L) | 大 W·L 改善 matching；增 L 比增 W 同 area 下随机 σ 一致，但 systematic 更好 |
| **gds**（影响 Av） | gds ∝ 1/L | L 大 → gds 小 → ro 大 → Av 大 |

**结论**：PMOS load L 通常取 **2-4× input pair L**（vs input pair L）。
- 例：input pair L=0.36µm（180nm 2×Lmin），PMOS load L=0.72-1.5µm
- 不要写"PMOS load L = input pair L"或不解释为什么取这个 L

## ICMR 与 output swing

```
V_in_max（NMOS input）= VDD - |Vov_M4| - |Vth_p|
                     ≈ VDD - 0.6V（典型）

V_in_min = VSS + Vov_tail + Vth_n + Vov_M1
        ≈ VSS + 0.7V（典型）

V_out_max = VDD - |Vov_M4| ≈ VDD - 0.15V
V_out_min = Vov_tail + Vov_M1 ≈ 0.3V
```

input common-mode range（ICMR）受 NMOS Vth + tail headroom 限。如要 rail-to-rail input 必须用 PMOS 输入对（或互补 P/N rail-to-rail 拓扑）。

## Sizing 关系

| 量 | 推荐 | 因果 |
|---|---|---|
| L_input pair | 2×Lmin（180nm 0.36µm）| matching σ_Vth ~3-5mV；速度 / 1/f noise 折衷 |
| L_PMOS load | **2-4× input pair L** | **noise / matching / gds 三重收益；详见上文** |
| W_input pair | gm/Id 5-15 反推 | OTA EA 通常 gm/Id=10-15（弱 → 中反型）|
| W_PMOS load | gm_M3 << gm_M1 → 弱反型 → 大 W·L | matching = 1/√(WL) 也帮 |
| Itail | 2× 单管 Id | EA 单管 5-50 µA 典型 |
| m（cross-coupled layout） | input pair 用 m≥4 共心 | 消 systematic offset |

## sizing 范例（LDO EA 单级 OTA）

> 📌 **@ vpdk180nm**（μn/p·Cox ≈ 270/67 µA/V²、|Vth| ≈ 0.35-0.5 V、Avt 数值参考 `pdks/vpdk180nm/index.md`）。**PMOS load L 必须 > input pair L** 的因果（noise/matching/gds 三重收益）跨工艺通用，但具体 L 数值各工艺不同。换工艺重算所有数值；公式形式（Av=gm·Rout / Vos=Avt/√WL / gm/Id 表）通用。

```
设计目标：Av = 50 dB / Itail = 20 µA / VDD = 1.8 V / Cload = 1 pF / GBW > 1 MHz

input pair (M1/M2):
  Itail = 20 µA → Id_M1 = 10 µA each
  gm/Id = 12 → gm_M1 = 120 µS / Vov = 0.167 V
  L = 0.36 µm（2× Lmin）
  W/L = 2·Id/(μn·Cox·Vov²) ≈ 2·10/(270·0.028) ≈ 2.6 → W ≈ 1 µm
  matching: σ_Vth at W·L=0.36 µm² ≈ 5/√0.36 = 8.3 mV → 偏大
  增 W 到 W=10µm（W·L=3.6 µm² → σ_Vth ≈ 2.6 mV）
  实际 W/L=10/0.36=27.8 → Vov ≈ √(2·10/(270·27.8)) = 0.052 V → gm/Id ≈ 38
  → 实际 gm_M1 = 38 × 10µ = 380 µS（远超初设）

PMOS load (M3/M4):
  Id_M3 = 10 µA each
  L_load = 1 µm（约 3× input L）— **物理审查关键点：必须比 input L 大**
  目标 gm/Id_M3 = 5 → Vov_p = 0.4 V → gm_M3 = 50 µS
  W/L = 2·10/(80·0.16) = 1.56 → W = 1.56 µm
  matching σ_Vth ~ 7/√1.56 ≈ 5.6 mV
  
  ⚠️ noise check: gm_M3/gm_M1 = 50/380 = 0.13 → noise factor (gm_M3/gm_M1)² = 0.017
  → input-referred noise from PMOS load 几乎可忽略 ✓

Rout & Av:
  ro_M2 ≈ 5 MΩ @ Id=10µA L=0.36µm
  ro_M4 ≈ 8 MΩ @ Id=10µA L=1µm（L 大 → ro 大）
  Rout = ro_M2‖ro_M4 = 3.1 MΩ
  Av = gm_M1 × Rout = 380µ × 3.1M = 1180 V/V = 61 dB ✓ spec

GBW:
  GBW = gm_M1 / (2π·Cload) = 380µ / (2π·1p) = 60 MHz ✓ spec
```

## 验证清单

- [ ] dc_snapshot：M1/M2/M3/M4/M5 全 saturation
- [ ] dc_snapshot：M1.Id ≈ M2.Id ≈ Itail/2（差分平衡）
- [ ] dc_snapshot：Vx ≈ Vout 静态（共模 OK）
- [ ] dc_snapshot：**L_M3/M4 > L_M1/M2**（不应同 L）
- [ ] AC：Av ≥ spec / GBW ≥ spec / PM（带反馈）≥ 60°
- [ ] AC：noise check input-referred < spec（PMOS load 贡献 < input pair）
- [ ] DC sweep：ICMR 验证（V_in_cm 从 0 到 VDD，Av 不掉）
- [ ] MC mismatch：σ_VOS < 5 mV（input pair Pelgrom + PMOS load systematic）
- [ ] PVT corner：Av / GBW / PM 在 FF/SS/温度全过

## 常见误区（self-check）

| 心里想 | 现实 |
|---|---|
| "L_M3 = L_M1 简单" | **错**——PMOS load L 通常 2-4× input pair L（noise + matching + gds 三重） |
| "active load 增益翻倍是 6 dB" | 是的，从 M2 单管 ro 到 M2‖M4 双 ro 增了 ~6 dB（实际略少，因为 ro_M4 不无穷） |
| "PMOS load 选 W/L 同 input pair" | matching σ 受 W·L 控；不必同 W/L 但需大 W·L |
| "input ICMR 跨 rail" | NMOS input 限 V_in_max < VDD - |Vth_p|，要 rail-to-rail 用 P/N 互补输入 |
| "gm_M3 大点 noise 才小" | 反——gm_M3 << gm_M1 才让 noise factor 小（PMOS load 起 noise"放大器"作用，不希望它 transconductance 大） |

## 不在本章范围

- basic（resistor-load 或电流源 tail-sourced）→ chapter `basic`
- current-steering（高速开关电流）→ chapter `current-steering`
- source-degenerated（带 R_S 提线性度）→ chapter `source-degenerated`
- PMOS active load 物理 / mirror-load 详细 → `blocks/base-cells/active-load/mirror-load.md`
- cascode-load（提 Av 到 80+ dB）→ `blocks/base-cells/active-load/cascode-load.md`
- 故障 debug → chapter `troubleshooting`
- 完整 5T-OTA sizing 推导（含此 cell + tail mirror + bias）→ `blocks/5t-ota/`（待建）
