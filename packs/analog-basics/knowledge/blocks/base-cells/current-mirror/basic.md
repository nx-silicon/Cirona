---
chapter: basic
parent: current-mirror
summary: |
  基础电流镜（simple mirror）：物理 / sizing / matching / Pelgrom 公式 +
  mirror ratio 实现（用 m，不改 W）+ Vds 调制误差因果
tokens: ~750
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
  - circuit-method/bias-tree-reasoning
related_knowledge:
  - blocks/base-cells/cascode    # 上叠 cascode 时底部管 Vds 因果
---

# 基础电流镜

## 拓扑结构（事实）

```
       VDD ──┬─── Iref ──┬─────────────┐
             │           │             │
             ▲           ▲           load
             │           │             │
             │       ┌───┴───┐         │
             │       │ M_ref │ Vgs (diode)
             │       └───┬───┘         │
             │           ║             │
             │           ║ Vgs ────────┤
             │           ║             │
             │       ┌───┴───┐         │
             │       │ M_out │         │
             │       └───┬───┘         │
             │           │             │
            VSS ────────┴─────────────VSS
                                       │
                                     Vout (compliance node)
```

**关键事实**：
- M_ref **是 diode-connected**（Vds=Vgs=Vth+Vov），**永远 saturation**（Vds_sat=Vov < Vds=Vth+Vov）—— 这是物理事实，不能误说"diode-load 易 triode"
- M_out 与 M_ref **共栅**：Vgs_out = Vgs_ref（前提：source 同电位）
- M_out 在 saturation 时 → Iout/Iref ≈ (W/L)_out / (W/L)_ref

## 镜像比例（physics）

理想（同 region + Vds 相同 + 无 mismatch）：
```
Iout / Iref = (W/L)_out / (W/L)_ref
```

实际（含 channel-length modulation）：
```
Iout / Iref = (W/L)_out / (W/L)_ref × (1 + λ·Vds_out) / (1 + λ·Vds_ref)
```

**因果链**：
- M_ref 的 Vds = Vgs ≈ Vth+Vov（固定）
- M_out 的 Vds = **Vout - Vss**（由上层电路决定）
- 两者 Vds 相差 = (Vout - Vss) - (Vth + Vov)
- 这个 Vds 差通过 (1+λ·ΔVds) 放大成镜像误差

**典型数值**：vpdk180nm L=0.5µm 工艺 λ ≈ 0.05/V，Vds 差 200mV → 误差 ≈ 1%。

## Sizing 三个变量（W / L / m）

每个变量服务不同目的，**不能互换**：

| 变量 | 服务 | 因果 |
|---|---|---|
| **W**（per finger 宽度）| 给定 Iref / gm 目标推 W | gm = √(2·μ·Cox·(W/L)·Id)，W 大 → gm 大 / Vov 小 |
| **L** | matching / 1/f noise / Rout | σ(ΔVth) ∝ 1/√(WL) + ro ∝ L/Id |
| **m**（multiplicity / fingers）| 镜像比例 + matched layout | m=N 等价 N 个相同 device 并联，Pelgrom 改善 √N |

### 镜像比例：用 m 不要改 W

**反例（不要这样）**：
```
M_ref: W=5µm L=1µm
M_out: W=20µm L=1µm           ← 4× 比例靠 W ratio
```
问题：m=4 拆分的主要优势是 **unit-device ratio + common-centroid 系统性匹配**（消除工艺梯度 / Vds 不一致）。
**随机 Pelgrom σ 由总 W·L 决定**：W=20µm × L=1µm 单管与 m=4 个 W=5µm × L=1µm 并联（总 W·L 相同）的随机 Vth 失配大致相当。m 拆分的真正收益是消"系统性"偏差，不是凭空让随机 σ 改善 √4。

**正例**：
```
M_ref: W=5µm L=1µm m=1
M_out: W=5µm L=1µm m=4        ← 4× 比例靠 m
```
m=4 是 4 个相同 finger 并联，Pelgrom matching 改善 √4。**layout 时**这 4 个 finger 与 ref 的 1 个 finger 用交叉指（common-centroid）布局 → systematic 失配也消。

### L 选择（事实）

| L 取值 | matching σ | 1/f noise | Rout | 适用 |
|---|---|---|---|---|
| Lmin (180nm) | σ_Vth ~ 5-10mV | 高 | 低（gds 大） | 高速、不严格 |
| 2×Lmin (360nm) | σ_Vth ~ 3-7mV | 中 | 中 | OTA input pair / mirror（典型）|
| 4×Lmin (720nm) | σ_Vth ~ 2-5mV | 低 | 高 | 高精度 mirror / EA tail |
| ≥ 1µm | σ_Vth ~ 1-3mV | 很低 | 很高 | bandgap PTAT mirror / DAC |

**Pelgrom 公式**（理论基础）：
```
σ(ΔVth) = AVT / √(W·L)              # AVT 是工艺参数，180nm 典型 5 mV·µm
σ(Δβ/β) = AB / √(W·L)               # AB 通常 1-2 %·µm
```

→ 1µm × 1µm 的器件 σ_Vth ≈ 5 mV；**100µm × 100µm** 的 σ_Vth ≈ 5 / √(100·100) = **0.05 mV**（按 √(W·L) 改善 100×）。
若想做到 σ_Vth ≈ 0.5 mV，对应器件约 10µm × 10µm（√100 = 10× 改善）。

## Vds 调制误差（关键约束）

simple mirror 的最大问题：**Iref 支路和 Iout 支路 Vds 不一样** → 镜像误差。

| Vds 差 | typical 镜像误差 |
|---|---|
| < 100 mV | < 0.5% |
| 200 mV | ~1% |
| 500 mV | ~3% |
| > 1V | > 5% |

**修复方向**（按修复力度递增）：
- 让 Vout 限定在窄范围（compliance）→ 减小 Vds 差
- 用 cascode mirror（屏蔽 M_out 的 Vds 受 Vout 影响）→ 误差降到 0.1%
- 用 regulated cascode（钉死 M_out 的 Vds）→ 误差降到 < 0.01%

## 启动 / supply 敏感性

**simple mirror 的 Iref 由参考支路决定**（如 Iref = (Vdd-Vss)/R_ref）：
- VDD 变化 → Iref 变化 → Iout 全镜像跟着变（**line sensitivity 差**）
- 解决：用 PTAT / bandgap-derived Iref（让 Iref 不依赖 VDD）

→ 真实 LDO / OTA 几乎不会用 simple resistor-derived Iref；用 β-multiplier 或 bandgap 给 Iref。见 `blocks/base-cells/bias-generator/beta-multiplier.md`。

## 验证清单（写完 sizing 后）

- [ ] dc_snapshot 显示 M_ref 在 saturation（必然，因 diode-connected）
- [ ] dc_snapshot 显示 M_out 在 saturation（如果在 triode → compliance 不够，问题在上层不在 mirror）
- [ ] op_point_check 报 M_ref / M_out 同 Vov（应一致 ±5%）
- [ ] 仿真 Iout / Iref 比例与设计目标一致（误差 < spec）
- [ ] PVT 角下 line sensitivity 满足 spec（VDD ±10% → ΔIout / Iout < spec）
- [ ] mismatch MC 仿真 σ 满足 spec（典型 100 次 MC）

## Sizing 范例（5T-OTA 内的 PMOS load mirror）

> 📌 **@ vpdk180nm**（μn/p·Cox / Vth / VA / Avt 数值参考 `pdks/vpdk180nm/index.md`）。换工艺需重算所有数值；mirror ratio = m 拓扑 / Pelgrom matching 公式跨工艺通用。

设计目标：
- Iout = 10 µA per side（5T 单边）
- mismatch σ < 2%
- Rout 不要求高（5T 有现成的 mirror-load）

**derivation chain**：
```
M3/M4 (PMOS mirror，M3 diode-connected as ref，M4 mirror as load):
  - role: 给 differential pair 当 active load mirror
  - Iref = Iout = 10 µA per side（5T 设计 Itail=20µA 平分）
  - 选 gm/Id = 6（PMOS 短沟，反型偏强 → noise 弱化目标）
    → gm3 = Iref × (gm/Id) = 60 µS
  - μp·Cox ≈ 67 µA/V²，反推 Vov_p:
    gm = 2·Id / Vov → Vov_p = 2 × 10u / 60u ≈ 0.33 V（足够 saturation）
  - W/L = 2·Id / (μp·Cox·Vov²) = 2 × 10 / (67 × 0.11) ≈ 2.7
  - L = 1.4 µm（约 8×Lmin，matching + 1/f noise + 减 gds 三重收益）
    → 这是 5T-OTA 设计**关键决策**——PMOS load 长 L 不是默认值，是 noise-driven 的物理选择
  - W ≈ 1.4 × 2.7 ≈ 3.8 µm
  - m = 1（per finger）
  - mismatch 估算：σ(ΔVth) = AVT / √(W·L) = 5 / √(3.8 × 1.4) ≈ 2.2 mV
    → ΔI/I ≈ 2 σ_Vth × gm/Id = 2 × 2.2m × 6 = 2.6%
    边缘超 spec → 增 L 到 2µm 或加 m=2 改善
```

## 常见误区（self-check）

| 心里想 | 现实 |
|---|---|
| "M_ref 是 diode-load，会 triode" | **物理错误**：diode-connected 永远 saturation（Vds_sat=Vov < Vds=Vth+Vov） |
| "镜像比 4× 用 W=4×Wref 就行" | matching 比用 m=4 差 √4=2 倍；用 m + 交叉指 layout |
| "L 用 minimum 节省面积" | matching σ 大幅恶化（σ ∝ 1/√L），高精度场合不能 |
| "M_out triode 是 mirror 的问题" | M_out 的 Vds 由上层电路 Vout 决定，**改 mirror 解决不了** → 上层 compliance 设计问题 |
| "PMOS load 的 L 跟 input pair 同 L" | 5T-OTA 设计常见错误：PMOS load **必须**长 L（noise / matching / gds 三重） |

## 不在本章范围

- **cascoded mirror 物理 / 偏置**——见 `chapter=cascoded`
- **wide-swing mirror compliance 巧妙偏置**——见 `chapter=wide-swing`
- **regulated cascode 高 Rout**——见 `chapter=regulated`
- **gm/Id 方法学**——见 skill `circuit-method/device-sizing`
- **PMOS load 的 noise factor 推导**——见 `blocks/5t-ota/sizing-typical.md`（含完整 (gm3/gm1)² 衰减分析）
- **layout 的 common-centroid / matched-fingers**——layout knowledge（V4 不在范围）
