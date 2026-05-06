---
chapter: mirror-load
parent: active-load
summary: |
  Current-mirror 作 load —— bias 独立 / R_load = ro / Av = -gm·(ro_drv‖ro_load)（20-80）/
  Vds 调制造成差分失配 / 5T-OTA 经典负载
tokens: ~700
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/current-mirror
  - blocks/base-cells/differential-pair
---

# Current-Mirror Load

## 拓扑（差分对的 PMOS mirror load 是经典实现）

```
        VDD ─────────┬─────────┐
                     │         │
                ┌────┴───┐ ┌───┴────┐
                │ M3     │ │  M4    │ ← gate 共连（mirror connection）
                │ (diode │ │(mirror │
                │ ref)   │ │  out)  │
                └────┬───┘ └───┬────┘
                     ●         ●─── Vout（差分→单端转换点）
                ┌────┴───┐ ┌───┴────┐
                │  M1    │ │  M2    │
                │ (NMOS  │ │(NMOS   │
                │  in+)  │ │ in-)   │
                └────┬───┘ └───┬────┘
                     │         │
                     └────●────┘
                          │
                       I_tail
                          │
                         VSS
```

**核心机制**：
- M3 是 diode-connected（**永远 saturation**），M4 是 mirror output（**Vds 由 Vout 决定**）
- 两 PMOS 共 gate（Vgs 相同）→ M4 复制 M3 的电流（mirror）
- M1 信号引起的电流不平衡 → 通过 M3-M4 mirror → 单端转出 Vout
- M4 也是 active load：Vout 节点高阻 = ro_M4‖ro_M2 → 增益放大

## 小信号公式

### R_load = ro_M4

```
R_load = ro_load = 1/(λ × Id_load)
```
典型 ro = 50 kΩ - 500 kΩ @ Id = 10 µA - 1 mA / L = 0.36 - 1 µm。

### Av = -gm_drv · (ro_drv ‖ ro_load)

```
Av = -gm_M1 × (ro_M1 ‖ ro_M4)
```

| 工艺 / sizing | Av 典型 |
|---|---|
| 180nm Lmin / Vov 200mV | 20-30 |
| 180nm 4×Lmin / Vov 150mV | 50-80 |
| 65nm Lmin | 10-20（短沟道 ro 差）|
| 65nm 4×Lmin | 30-50 |

**因果**：
- gm_M1 ∝ √(Id) → Id ↑ Av ↑（弱）
- ro ∝ L/Id → **L ↑ ro ↑ → Av ↑（强）**；Id ↑ ro ↓ → Av ↓
- → Av 主要靠 L，不是 Id

## Vds 调制误差（mirror load 关键问题）

差分应用中两支路对称要求 M3.Vds ≈ M4.Vds。

实际：
- M3 是 diode → V_drain_M3 = VDD - Vgs_load（固定）
- M4 是 mirror output → V_drain_M4 = Vout（随信号变）

→ **M3.Vds ≠ M4.Vds**（差异通常 100-500 mV）→ 通过 (1+λ·ΔVds) 项产生镜像比例误差。

| ΔVds | 失配（典型 λ=0.05/V）| 影响 |
|---|---|---|
| 100 mV | < 0.5% | 可接受 |
| 200 mV | ~1% | 边缘 |
| 500 mV | ~3% | 显著 systematic offset |
| > 1V | > 5% | 必须用 cascode-load 屏蔽 |

**修复方向**：用 cascode-load（chapter `cascode-load`）屏蔽 M4 的 Vds 变化。

## sizing 关系（与 PMOS load 的 L 选择）

> ⚠️ **关键决策**：**PMOS load 的 L 通常 > input pair L**（5T-OTA 设计中最常被忽略的细节）。

三重收益（按重要性）：
1. **noise**：input-referred noise 中 PMOS load thermal 经过 (gm_load/gm_drv)² 衰减；要让这个比小 → gm_load << gm_drv → Vov_load 大 → **增 L 优于减 W**（减 W 损 swing）
2. **matching**：σ(ΔVth) ∝ 1/√(WL)，L 大改善 systematic offset
3. **gds 减小**：ro 增 → Av 增

典型 5T-OTA：W_load 与 W_drv 接近（mobility 补偿后），但 **L_load = 4-8 × L_drv**。

| 量 | 推荐范围 | 因果 |
|---|---|---|
| Vov_load | 0.1-0.2V | 太小匹配差 + 短沟道 ro 不升；太大 swing 损 |
| L_load | 4-8 × L_drv（5T-OTA 典型 0.7-1.5 µm @ 180nm）| 三重收益（noise/matching/ro）|
| W_load | 由 (W/L)_load + L_load 决定 | gm/Id 表 lookup |
| Id_load = Id_drv | 共享支路 | 5T-OTA 中 Id_load = I_tail/2 |

## sizing 范例（5T-OTA PMOS mirror load）

> 📌 **@ vpdk180nm**（μn/p·Cox / Vth / VA / γ 数值参考 `pdks/vpdk180nm/index.md`）。换工艺需重算所有数值；公式形式跨工艺通用。

设计目标：5T-OTA Av = 60 dB / Itail = 20 µA / L_drv = 0.36 µm @ 180nm

```
推导（按 Av → 反推 ro → L_load）:
  Av = 60 dB = 1000
  gm_M1 = 2 × 10µA / 0.15V = 133 µS（Vov_drv = 0.15V，noise 优先）
  Av = gm·(ro_M1‖ro_M4) → 1000 = 133µ × (ro‖ro) → ro 等效 7.5 MΩ
  → 单 ro 至少 15 MΩ → L_load 必须 ≥ 1µm + Vov_load ≥ 0.2V

PMOS load sizing:
  Vov_load = 0.2V, L = 1.5 µm
  gm/Id_load 在此 Vov 下 ≈ 10 → gm_load = 100 µS
  Id = 10 µA → W_load 由 gm/Id 表查 → ~1.5 µm（PMOS @ 180nm vpdk）
  m = 1

noise factor 验证:
  (gm_load/gm_drv)² = (100/133)² ≈ 0.57 → load thermal 衰减 0.57×（不够好）
  → 要 (gm3/gm1)² ≤ 0.25 → gm_load ≤ gm_drv/2 = 67 µS
  → 改 Vov_load = 0.3V，gm_load = 67 µS, L = 2 µm → noise OK
```

## 验证清单

- [ ] dc_snapshot：M3 / M4 saturation（M3 必然，M4 看 Vout 摆幅）
- [ ] dc_snapshot：M3.Vds vs M4.Vds 差距（< 200 mV 系统失配）
- [ ] AC：Av 在 spec 内
- [ ] AC：BW = 1/(2π · ro_load‖ro_drv · C_out)
- [ ] DC sweep：Vout 摆幅 → 看 M4 何时进入 triode（V_load 撞 Vov）
- [ ] MC：失配 σ(ΔVth) 验证

## 常见误区

| 心里想 | 现实 |
|---|---|
| "增大 W_load → matching 好 swing 大" | 错——增 W 让 Vov ↓ 但 swing 不一定好；mismatch 由 σ∝1/√(WL) 改善 |
| "L_load 与 L_drv 同" | **通常应**取更长 L_load > L_drv（noise / matching / gds 三重收益）；速度 / 面积优先时可同 L 但需写明取舍理由 |
| "增 Id_load 增 Av" | 错——Av ∝ gm·ro = √(Id·μ·W/L)·(L/Id) = √(μ·W·L/Id)；Id ↑ Av ↓ |
| "M3 / M4 sizing 完全对称" | 是，但**注意 L_load > L_drv** 的层级原则——load 与 drv 的 W/L 不必同 |

## 不在本章范围

- diode-load（更简单变体）→ chapter `diode-load`
- cascode-load（屏蔽 M4 Vds 调制）→ chapter `cascode-load`
- 故障 debug → chapter `troubleshooting`
- 完整 5T-OTA sizing 推导 → `blocks/5t-ota/sizing-typical.md`（待建）
- noise factor (gm3/gm1)² 完整推导 → `blocks/5t-ota/sizing-typical.md`（待建）
