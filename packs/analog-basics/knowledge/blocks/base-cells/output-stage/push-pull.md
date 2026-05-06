---
chapter: push-pull
parent: output-stage
summary: |
  Push-pull 输出级结构语义 —— 互补源跟随 vs 互补共源拓扑对照。
  与 Class-A/AB 偏置策略的概念区分。NMOS/PMOS 不对称影响
tokens: ~650
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/source-follower
  - blocks/base-cells/common-source
---

# Push-Pull 输出级结构

## Push-Pull vs Class-AB 概念区分（关键）

这两个词常被混用，但**含义不同**：

| 术语 | 描述维度 | 含义 |
|---|---|---|
| **Push-Pull** | **结构** | 互补器件对（NMOS + PMOS）双向驱动负载 |
| **Class-AB** | **偏置** | 控制 Iq → 静态微弱导通 → 兼顾效率与交越 |

**关系**：Class-AB 是 push-pull 结构 **加上** 特定偏置约束的子集。
- Pure push-pull = 任意偏置（Class A / AB / B / C 都行）
- Class-AB = push-pull + 受控 Iq 偏置

本章只讲**结构**层面的拓扑选择，偏置控制（Iq、偏置展开）见 chapter `class-ab`。

## 两大互补拓扑（结构对照）

### 拓扑 A：互补源跟随（Complementary Source-Follower）

**关键结构**：两管的 **drain 各接 rail，source 共接 V_out**（这是 SF 定义——drain 是高阻端接固定电压，source 是输出端跟随 gate）。

```
        VDD ──────────┐  (NMOS drain 接 VDD)
                      │
                  ┌───┴───┐
        Vin+Vbias→│  Mn   │  (NMOS SF 上拉)
        (top gate)│ NMOS  │
                  └───┬───┘
                      ●─── V_out  ← (Mn.source 与 Mp.source 共点)
                  ┌───┴───┐
        Vin-Vbias→│  Mp   │  (PMOS SF 下拉)
        (btm gate)│ PMOS  │
                  └───┬───┘
                      │
        VSS ──────────┘  (PMOS drain 接 VSS)

        Vbias_spreader = Vgs_n + |Vgs_p| 在两 gate 间（中点 = Vin）
```

**特征**：
- 增益 Av ≈ +1（单位增益跟随，V_out = Vin）
- Rout = (1/gm_n) ‖ (1/gm_p) = 1/(gm_n + gm_p)（典型 Ω 量级）
- 摆幅受 **Vgs / Vth + body effect** 限（不是 Vdsat headroom）：
  - V_out_max = VDD - Vgs_n（NMOS 上拉时 V_out 比 gate 低 Vgs；gate 最高 = VDD → V_out_max = VDD - Vgs_n_min ≈ VDD - 0.6 V）
  - V_out_min = VSS + |Vgs_p|（PMOS 下拉时类似）
  - **典型摆幅 = VDD - (Vgs_n + |Vgs_p|) ≈ VDD - 1.2 V**（比 CS 摆幅小很多）
- **天然稳定**（Rout 小 → 主极点高 → 大 Cload 也容易稳）
- **body effect**：NMOS source 接 V_out（不是 VSS）→ V_SB > 0 → Vth_n 升高 → 摆幅进一步压缩

### 拓扑 B：互补共源（Common-Source Push-Pull）

```
        VDD
         │
    ┌────┴────┐
    │  Mp     │  ← Vin (PMOS gate, signal-driven)
    │  PMOS CS│
    └────┬────┘
         ●  V_out (drain shared with Mn)
    ┌────┴────┐
    │  Mn     │  ← Vin (NMOS gate, signal-driven)
    │  NMOS CS│
    └────┬────┘
         │
        VSS
```

**特征**：
- 增益 Av = -(gm_P + gm_N) × (ro_P‖ro_N)（**电压增益**，远大于 1）
- Rout = ro_P‖ro_N（典型 kΩ-MΩ）
- 摆幅受 **Vdsat headroom** 限：V_out_max = VDD - |Vdsat_p|，V_out_min = VSS + Vdsat_n
  - @180nm Vdsat 100-200 mV → V_swing_pp ≈ VDD - 0.3 V（**比 SF 摆幅大很多**）
- **需 Miller 补偿**（高 Rout × Cload 极点低）
- 应用：**Class-AB 高驱动输出**（音频 / LDO 二级 / 大 Cload buffer）；**注意：经典二级 OTA 第二级是 *单管 CS + current-source load* 不是互补 CS**——互补 CS push-pull 是大驱动输出的二级变体

## 拓扑选择决策表

| 需求 | 推荐 | 理由 |
|---|---|---|
| 缓冲大电阻 / 大电容负载 | 互补 SF | 低 Rout 天然稳定 |
| OPamp 内部级（需电压增益）| 互补 CS | 低 Rout 不能提供增益 |
| LDO pass FET（特殊 PMOS source） | 互补 CS 变体（PMOS pass）| 给 EA 一个增益级 + 大电流驱动 |
| Rail-to-rail 输出 | 任一种（看是否需增益）| 互补 SF 在小 Vdd 下 PMOS 可能 cutoff |

## NMOS / PMOS 不对称的影响

CMOS 工艺典型 μn / μp ≈ 2.5 - 3.5×。

**对源 / sink 对称的影响**：
```
Imax_n = (1/2) × μn·Cox × (W/L)_n × Vov²
Imax_p = (1/2) × μp·Cox × (W/L)_p × Vov²
```
若两管 W = L 相同 → Imax_n ≈ 3 × Imax_p → **不对称**。

**修复**：W_PMOS = (μn / μp) × W_NMOS ≈ 2.5 - 3.5 × W_NMOS。

**额外 layout 收益**：W_PMOS 大 → Cgs_P 大 → 抵消部分 PMOS 上拉慢的劣势。

## 输出阻抗推导（事实）

**互补 SF**：两 SF 并联（一个上拉 / 一个下拉，从 vout 看回去都是 1/gm）：
```
Rout_SF = (1/gm_P) ‖ (1/gm_N) = 1 / (gm_P + gm_N)
```
典型 gm_P + gm_N = 10 mS → Rout = 100 Ω。

**互补 CS**：两 CS 并联（漏极共享）：
```
Rout_CS = ro_P ‖ ro_N
```
典型 ro = 100 kΩ → Rout = 50 kΩ。

**因果关系**（Rout → 稳定性）：
- Rout 小（SF）→ 主极点 = 1/(2π·Rout·Cload) 高 → PM 大 → 稳
- Rout 大（CS）→ 主极点低 → 与 OTA 主级或 Miller 补偿耦合 → 必须显式补偿

## 输出摆幅（SF vs CS 完全不同）

**互补 CS** 摆幅受 **Vdsat headroom** 限（drain 在 V_out 上，只要保持 saturation 即可）：
```
V_out_max_CS = VDD - |Vdsat_p|
V_out_min_CS = VSS + Vdsat_n
V_swing_pp_CS = VDD - |Vdsat_p| - Vdsat_n   ≈ VDD - 0.3 V @ 180nm
```

**互补 SF** 摆幅受 **Vgs / Vth + body effect** 限（source 是 V_out，必须维持 |Vgs| > |Vth|）：
```
V_out_max_SF = VDD - Vgs_n_min            (NMOS 顶 SF 上拉极限)
V_out_min_SF = VSS + |Vgs_p_min|          (PMOS 底 SF 下拉极限)
V_swing_pp_SF ≈ VDD - (Vgs_n + |Vgs_p|)   ≈ VDD - 1.2 V @ 180nm
+ body effect 影响：Vth_eff_n ↑ → 摆幅再压缩 50-100 mV
```

**因果**：CS 摆幅几乎接 rail（Vdsat 小），SF 摆幅至少损 1 个 Vgs（典型 0.6 V）每侧。这是互补 CS 在 rail-to-rail 应用中胜出的根本原因。

## Body-Effect 注意（互补 SF 特有）

NMOS SF 的 source 接 V_out（不接 VSS） → V_SB > 0 → V_th_n 升高（body effect）：
```
V_th_n_eff = V_th_n0 + γ × (√(2·φ_F + V_SB) - √(2·φ_F))
```
PMOS SF 类似（source 在 V_out 上方，Vsb 反向）。

**因果**：V_th 升高 → Vov 减小 → gm_eff 减小 → Rout = 1/gm 升高 + SR 损失。

**修复**：W_NMOS 取大一些（典型 1.5 × theoretical），或用 deep N-well 隔离 NMOS source 与 bulk。

## 验证清单

- [ ] dc_snapshot：两输出管区域（SF 应都 saturation；CS 同样）
- [ ] dc_snapshot：摆幅扫描验证 V_out_min / V_out_max 满足 spec
- [ ] AC：Rout 测量与公式预测对照（误差 < 30%）
- [ ] tran：源 / sink 大信号驱动对称性（5% 以内 mismatch ok）
- [ ] PVT corner：body effect 影响（NMOS SF Vov 在 SS 角是否仍 > 50 mV）

## 常见误区（self-check）

| 心里想 | 现实 |
|---|---|
| "Push-pull 就是 Class-AB" | 错。Push-pull 是结构，Class-AB 是偏置策略 |
| "互补 SF 比互补 CS 增益低不要紧反正是输出" | 经典二级 OTA 第二级是**单管 CS + current-source load**（不是互补 CS）；互补 CS push-pull 是高驱动场景的变体，提供电压增益 + 双向大电流 |
| "NMOS / PMOS 用相同 W" | μ 不对称 → SR 上下不对称 → 输出 distortion |
| "互补 SF 不需要补偿" | 一般负载下对，但驱动极大 Cload（pF 级）+ 高 Rout 前级时仍要查 PM |
| "Body effect 可忽略" | 输出摆幅大时 V_SB 大 → V_th 漂移可达 100 mV → 影响 Iq 和 SR |

## 不在本章范围

- 偏置展开网络 / Iq sizing / 交越失真控制 → chapter `class-ab`
- 故障 debug → chapter `troubleshooting`
- gm/Id 表 / Vov 选择 → skill `circuit-method/device-sizing`
- 二级 OTA 整体设计（含 Miller 补偿）→ `blocks/two-stage-ota/`
- LDO pass FET 选择（PMOS pass 是 push-pull 的特殊变体）→ `blocks/ldo/architecture.md`
