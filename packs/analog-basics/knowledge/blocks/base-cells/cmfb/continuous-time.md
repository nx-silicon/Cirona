---
chapter: continuous-time
parent: cmfb
summary: |
  连续时间 CMFB —— resistive divider / source-follower buffer / EA-driven 三种实现
  的物理 / sizing / 加载 / BW / 注入点选择对照
tokens: ~850
prerequisite_chapters: []
related_skills:
  - circuit-method/ac-feedback-loop-method
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/differential-pair
  - blocks/base-cells/active-load
---

# 连续时间 CMFB（CT CMFB）

## 通用拓扑（事实）

```
       voutp ──┬─ R_sense_p ─┐
               │             │
              load           ├─── vcm_sense ───┐
               │             │                 │
       voutn ──┴─ R_sense_n ─┘                 ▼
                                        ┌──────────┐
                                Vcm_ref ┤  EA(CMFB)│
                                        └────┬─────┘
                                             │ vcmfb_ctrl
                                             ▼
                              注入点（PMOS load gate / tail / 折叠 bias）
```

**核心机制**：
- 检测节点 `vcm_sense` ≈ (voutp + voutn) / 2（两 R 平均，或 SF 缓冲后平均，或 EA 直接对 voutp/voutn 取差分）
- EA 对比 `vcm_sense` 与 `Vcm_ref` → 输出 `vcmfb_ctrl`
- `vcmfb_ctrl` 接到注入点（典型 PMOS load gate，调节 load 上拉电流 → 双输出共同上下移动）

## 三种检测变体（事实 + 因果）

### 变体 A：Resistive Divider（最常见起点）

两 R 直接平均：vcm_sense = (voutp + voutn) / 2（R 相等假设下）。

| 维度 | 数值 / 公式 | 因果 |
|---|---|---|
| R_sense | ≥ 5 × Rout_ota（200kΩ-1MΩ）| 主 OTA 输出端看到的有效负载 = R_sense‖Rout_ota；gain_factor = R_sense/(R_sense+Rout_ota)，R_sense=5×Rout 时 ≈ 0.83（损 -1.6 dB）|
| 输出节点附加极点 | f_extra = 1/(2π · (R_sense‖Rout_ota) · Cload)| R 越大有效阻抗越接近 Rout_ota，极点位置主要由 Cload 决定 |
| sense 节点等效噪声 | Vn² = 4kT · (R_sense/2)（R-divider 中点等效电阻）| R_sense=100kΩ → R_eq=50kΩ → ≈ 29 nV/√Hz；与差分通路噪声叠加 |

**因果链**（加载 vs 噪声 vs 极点 trade-off）：
- R_sense ↑ → 加载 ↓ + 噪声 ↑ + 主 OTA 输出极点 ↓
- R_sense ↓ → 加载 ↑（gain 损失）+ 噪声 ↓ + 极点 ↑

### 变体 B：Source-Follower Buffer

每个输出先经一个 SF（NMOS / PMOS 视极性）缓冲到低阻节点，再用 R 或直接接 EA。

| 维度 | 数值 / 公式 | 因果 |
|---|---|---|
| Headroom 代价 | Vov_SF + Vth（NMOS SF：典型 0.5-0.8V）| Vout 高摆幅时 SF 进 triode → 检测失真 |
| 加载主 OTA | 静态 ≈ 0；动态 = SF gate 电容（Cgs+Cgd）| **`1/gm_SF` 是 SF 输出端阻抗（看进 sense 节点的小阻抗），不是主 OTA 看到的负载**；gate 是高阻输入 |
| 附加极点 | f_pole_SF = gm_SF/(2π · CL_SF)| SF 输出节点（即 sense 节点）电容引入的次极点，典型 10-100 MHz |

**何时选 SF**：输出节点是高阻 cascode / regulated cascode 输出（Rout_ota > 10MΩ），R-divider 加载会让主 OTA gain 损失 > 6 dB 时。

### 变体 C：EA 直接差分检测（无 R-divider）

EA 是全差分输入，直接接 voutp / voutn，内部用 cross-coupled diff pair 提取 (voutp+voutn)/2。

| 维度 | 数值 / 公式 | 因果 |
|---|---|---|
| 加载 | EA 输入对 Cgs（fF 级）| 几乎零静态加载 |
| 噪声 | EA input pair flicker + thermal | 由 EA sizing 决定，不引入 R noise |
| EA 复杂度 | 比简单 R-divider EA 高（需 cross-coupled pair）| 设计/审查负担更大 |

## EA Sizing 关系（事实 + 因果）

EA sizing 由 **BW 目标**反推，不是按 bias 大就行。

### 关键关系（推导链）

```
BW_cmfb = 0.1-0.5 × GBW_ota（约束）
gm_ea_target = 2π · BW_cmfb · C_ctrl（反推）
I_cmfb 选定 → gm_ea_actual = (gm/Id)·I_per_side（实际值）
A_cmfb = gm_ea · (ro_n‖ro_p)（增益验证）
```

### Sizing 关系表

| 量 | 公式 / 范围 | 因果 |
|---|---|---|
| BW_cmfb | 0.1-0.5 × GBW_ota | >0.5× → 双环耦合 PM 退化 ≥ 20°；<0.1× → 共模建立 > 10 τ_OTA |
| C_ctrl（注入点 gate cap）| 50-200 fF（典型 PMOS load gate）| 由注入点 W·L 决定；layout 完成后才精确 |
| gm_ea_target | 2π · BW_cmfb · C_ctrl | 例 BW=2MHz / C=100fF → gm = 1.3 µS |
| I_cmfb | 0.05-0.2 × Itail_ota（5-20 µA）| 功耗预算；I_cmfb 与 gm/Id 共同决定实际 gm |
| gm/Id | 8-15（noise-speed 平衡）| 影响 W/L 和 Vov |
| A_cmfb | 20-40 dB | <20 dB → 静态共模误差 > 50 mV；>40 dB → PM 退化 |

### 关键陷阱：gm 实际值 ≫ 目标值不是好事

**反直觉但重要**：选 I_cmfb 偏大 + gm/Id 偏大 → gm_ea_actual 可能 ≫ gm_ea_target（如目标 1.3 µS 实际 60 µS）。这**不**给"PM margin"——反而：
- 实际 gm 大 → 实际 BW_cmfb 高 → 与主 OTA GBW 重叠 → **PM 恶化**

**正确做法**（gm 过大时三选一）：
1. 减 I_cmfb 直到 gm_actual ≈ gm_target（最直接，省功耗）
2. 调整 W/L（注意：改 W 会改变 inversion level，gm/Id 也会变；不能假设 gm/Id 不变）
3. 在 EA 输出加补偿电容 / 注入端加 R-C 衰减，把有效环路 BW 限到目标 ≤ 0.5 × GBW_ota

### Sizing 范例（GBW_ota=10 MHz / Itail_ota=200 µA）

```
目标 BW_cmfb = 2 MHz（= 0.2 × GBW_ota）
注入点 PMOS load gate W·L → C_ctrl ≈ 100 fF
gm_ea_target = 2π × 2e6 × 100e-15 = 1.26 µS

选 I_cmfb = 10 µA（= 0.05 × Itail_ota，节能侧）
I_per_side = 5 µA
选 gm/Id = 10（中等）→ gm_ea_actual = 50 µS

→ gm_actual ≫ gm_target（约 40×）→ 必须降
方案：选更小 I_cmfb = 0.5 µA（tail 总电流 → I_per_side = 0.25 µA；gm/Id=10 时
     gm_actual ≈ 2.5 µS，约 2× 目标 1.26 µS）
     + 在 EA 输出加 1 pF Cc → 引入主极点 fp = 2.5µ/(2π·1p) ≈ 400 kHz
     → 实际 BW_cmfb ≈ 400 kHz（远 < 2 MHz target，偏保守，可减 Cc 调到 ~1 MHz）

A_cmfb 验证：gm × (ro_n‖ro_p) = 2.5µ × 10MΩ = 25 → 28 dB ✓
（ro 在 0.5 µA 偏置下偏大，约 10 MΩ）
```

## 注入点选择（按上层 OTA 拓扑）

| OTA 拓扑 | 推荐注入点 | vcmfb_ctrl 接到 | 因果 |
|---|---|---|---|
| 全差分 5T-OTA | PMOS load gate | M3/M4 gate | 同时调两侧 PMOS load 电流 → 双输出共同上下移动 |
| Folded-cascode OTA | PMOS load gate 或折叠 bias | M3/M4 gate / Vbcp | 折叠 bias 注入会改变 cascode 工作点，需重新核 headroom |
| Telescopic OTA | PMOS cascode gate | Vbcp（cascode bias）| 调 cascode bias → 改变两 cascode 管 Vds → 间接调输出共模 |
| Two-stage OTA | 第一级 PMOS load gate（更稳定）或第二级 bias | 视补偿策略 | 第二级注入会与 Miller 补偿耦合 |

**关键约束**：注入点选错不只是无效，会**侵蚀差分通路 swing**——比如把 vcmfb_ctrl 接到 cascode gate 但 cascode bias 还有其他用途，会引发偏置冲突。

## 验证清单

- [ ] dc_snapshot：vcm_out 在 Vcm_ref ± 10 mV 内
- [ ] dc_snapshot：vcmfb_ctrl 离 rail ≥ 100 mV（避免 EA 饱和）
- [ ] op_point_check：EA 输入对 + tail 全部 saturation
- [ ] AC 断环测 CMFB loop PM ≥ 60°（用 skill `ac-feedback-loop-method` 的通用断环思路）
- [ ] 主 OTA 差分 AC 加 / 不加 CMFB 对比 GBW / PM 变化 < 10%
- [ ] PVT corner（FF/SS/温度）共模误差仍 < 10 mV

## 常见误区（self-check）

| 心里想 | 现实 |
|---|---|
| "BW_cmfb 越高共模建立越快越好" | BW_cmfb > 0.5 × GBW_ota → 双环耦合，主 OTA PM 退化 |
| "R_sense 取小一点 EA 检测准" | R_sense < 5 × Rout_ota → 拉低主 OTA gain，得不偿失 |
| "EA 极性肉眼看接对了" | 极性反 = 正反馈推 rail；正确验证：对 vcm_out 注入 +50mV 扰动，看 vcmfb_ctrl 是否驱动共模回降 |
| "CMFB 不影响差分增益" | 注入点经过 active load → 差分通路也受 vcmfb_ctrl 影响，需仿真对比 |

## 不在本章范围

- **switched-capacitor 实现**——见 chapter `switched-capacitor`
- **CMFB 故障 debug**——见 chapter `troubleshooting`
- **AC 断环具体配置（断点选择 / Rfb / Cfb）**——见 skill `circuit-method/ac-feedback-loop-method`
- **EA input pair 的 Pelgrom mismatch sizing**——见 `blocks/base-cells/differential-pair/basic.md`
- **PMOS load 的 noise factor 推导**——见 `blocks/5t-ota/sizing-typical.md`
