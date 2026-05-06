---
chapter: ac-stability
parent: two-stage-ota
summary: |
  ⭐ 2-stage OTA 极点分布特征 + Miller 补偿核心章 + pole splitting + RHP zero +
  nulling resistor。涵盖 GBW = gm1/Cc 推导 + p2 = gm6/CL 推 PM > 60° 的设计
  起点 + Cc/Rz 联调。通用断环方法见 ac-feedback-loop-method skill。
tokens: ~1700
prerequisite_chapters:
  - architecture
related_skills:
  - ac_feedback_loop_method
related_knowledge:
  - blocks/base-cells/miller-compensation
  - blocks/5t-ota
  - simulators/ngspice
---

# Two-Stage OTA AC Stability

> 通用 AC 断环方法（Method C：Rfb=1G + Cfb=1F）见 `skill: ac-feedback-loop-method`。
> 本章节是 **2-stage OTA 真正的灵魂章**——Miller 补偿是双级 OTA 的核心设计点，
> Cc / Rz / RHP zero 三件套互相耦合，是 2-stage 与单级 OTA 最大的差异。
> Miller 补偿原理（pole splitting + nulling Rz）见 `blocks/base-cells/miller-compensation`，
> 本章节给的是 **2-stage 拓扑应用 Miller 补偿的设计起点 + 极点位置 + 失稳模式**。

## 极点分布（**未补偿** 双级 OTA）

如果直接级联两级 OTA 不加 Miller 补偿，会有 **两个独立主极点**：

```
f_p1 ≈ 1 / (2π · R_stage1_out · C_stage1_out)   ← stage1 输出节点 vx
f_p2 ≈ 1 / (2π · R_stage2_out · C_stage2_out)   ← stage2 输出节点 vout
```

两极点位置相近 → loop 经过 -180° 时 gain 仍 > 0 dB → **必振荡**。

**这是 2-stage 必须 Miller 补偿的原因**——两级独立堆叠，不补偿不可用。

## Miller 补偿后的极点分布（pole splitting）

加 Cc 跨 stage2（vx ↔ vout），通过 Miller effect 把 stage1 输出节点的有效
电容放大 (1 + |A_stage2|) 倍：

```
C_stage1_eff ≈ Cc × (1 + |A_stage2|) ≈ Cc × A_stage2     (A_stage2 = gm6 × ro_stage2)
f_p1' = 1 / (2π · R_stage1_out · Cc · A_stage2)         ← 主极点被推 ↓ 100×
f_p2' = gm6 / (2π · CL)                                  ← 次极点被推 ↑（pole splitting）
```

**物理意义**：Miller effect 把两个相近的极点 **拉开** —— 主极点压低（GBW 降但
单极点主导），次极点推高（远离 GBW，PM 改善）。

### GBW 与 Cc 的关系（**取代 CL**）

```
GBW = gm1 × |A_stage2| × R_stage1_out / Cc / A_stage2 = gm1 / Cc

GBW = gm1 / (2π · Cc)             ← Miller 后 GBW 由 Cc 决定，不是 CL
```

> ⚠️ **2-stage GBW 不能用 gm1/CL 算**——这是单级 OTA 的公式。Miller 后 GBW
> 由 gm1/Cc 决定。Cc 越大 GBW 越低。

### PM 与 p2 / GBW 比例

```
PM = 90° − arctan(GBW / f_p2')
PM > 60° ⇔ f_p2' / GBW > 3
       ⇔ gm6 / (2π·CL) / (gm1 / 2π·Cc) > 3
       ⇔ gm6 × Cc / (gm1 × CL) > 3
       ⇔ gm6 / gm1 > 3 × CL / Cc

如果 Cc = CL/4 → gm6 / gm1 > 12   ← 这是 stage2 gm 远大于 stage1 的物理来源
```

> **2-stage 设计 Iron Law**：**gm6 ≥ 12 × gm1**（@ Cc = CL/4）。这是 PM > 60°
> 的物理硬约束，不是建议值。

## RHP zero（**Miller 补偿的副作用**）

Miller cap **直接** 把 stage1 输出耦合到 stage2 输出，引入一条 feedforward
路径（与 stage2 inverting 路径并联）。这条 feedforward 在低频被主路径压
（gm6 主导），高频时 Cc 短路 → feedforward 占主导 → 出现 **零点**。

```
RHP zero: f_z = gm6 / (2π · Cc)
```

**这是 right-half-plane zero**——它**降 PM**（与极点同方向贡献相位）！

> **RHP zero 与 p2 的位置关系**：
> ```
> f_z (RHP) = gm6 / (2π · Cc)
> f_p2'      = gm6 / (2π · CL)
> ```
> 如果 Cc < CL（典型 Cc = CL/4 = 0.25 × CL）→ f_z > f_p2' → RHP zero 在 p2
> 之后；但即使在 p2 之后，RHP zero 仍贡献额外相位滞后（与 LHP zero 相反），
> **PM 仍可能进一步减少** —— 不能因为"f_z 在 GBW 之后"就忽略它。

## Nulling resistor Rz（消除 RHP zero）

加 Rz 串联在 Cc 路径上（vx → Rz → ncc → Cc → vout）：

```
新零点位置：f_z' = 1 / (2π · Cc · (1/gm6 − Rz))

设 Rz = 1/gm6   → f_z' → ∞   ← RHP zero 推到无穷远，消除
设 Rz < 1/gm6   → f_z' 仍在 RHP（有限位置），PM 退化
设 Rz > 1/gm6   → f_z' 在 LHP（增 PM，但浪费 BW）
```

**设计起点**：`Rz = 1/gm6`（精确消零）。如果实测 PM 仍紧（55-60°），稍微
增大 Rz 把零点推到 LHP，做 PM enhancement。

> **Cc 与 Rz 协同**：
> - Cc 决定 GBW + 主极点位置
> - Rz 决定零点位置
> - 单 Cc 不能完全救 PM，必须 Cc + Rz 配合

## 极点分布完整图（Miller + Rz）

```
   主极点 p1'               GBW              p2'         (RHP zero 被 Rz 消除)
   |                           |                 |                ∞
   |  ────────────────────────|─────────────────|───────────  freq
       gm1·R1·Cc·A2           gm1/Cc          gm6/CL
       ≈ kHz                    ≈ MHz          ≈ 100MHz
```

## PM 设计起点（vpdk180nm，CL=5pF）

| Cc / CL 比例 | gm6 / gm1（@ PM > 60°）| GBW（@ gm1=200µS）| 备注 |
|---|---|---|---|
| 0.10（Cc=0.5pF）| > 30 | 64 MHz | 高 BW，需要大 gm6 → power 高 |
| 0.20（Cc=1.0pF）| > 15 | 32 MHz | 平衡起点 |
| **0.30（Cc=1.5pF）** | **> 10** | **21 MHz** | **V4 reference 默认** |
| 0.50（Cc=2.5pF）| > 6 | 13 MHz | 低 BW，省 power |

> Cc 选择是 GBW vs power（gm6）的 trade-off。**起点 Cc = 0.25-0.30 × CL**。

## 失稳模式（PM < 50°）

### 模式 1: Cc 太小 → pole splitting 不足

**症状**：tran 仿真有 ringing，AC PM < 45°，主极点接近 stage2 极点。

**根因路径**：
```
Cc 小 → C_stage1_eff = Cc · A_stage2 不够大 → p1' 不够低 → 与 p2' 距离不足
```

**修复路径**：
1. **Cc ↑**（30% 步长）—— 把 GBW 推低 → PM 改善
2. 同步检查 Rz = 1/gm6（保零点消除）

### 模式 2: Rz 不对（RHP zero 没消）

**症状**：PM 似乎随 Cc 变化不敏感，stuck around 50-55°。

**根因路径**：
```
Rz 偏离 1/gm6 → RHP zero 仍在有限位置 → PM 长期紧
```

**修复**：
1. 算实际 gm6（用 op_point_check）
2. Rz = 1 / gm6_measured（不能用 sizing 时的估算值）

### 模式 3: gm6 太低（p2 太靠近 GBW）

**症状**：PM < 50°，无论 Cc / Rz 怎么调都救不了。

**根因路径**：
```
p2 = gm6 / (2π · CL)
如果 gm6 < 12 × gm1 → p2 < 3 × GBW → PM 物理上不可能 > 60°
```

**修复**：
1. **m_stage2 ↑**（W_MN6 + W_MP6 同步，保 stage2 平衡）
2. 或 I_stage2 ↑（增 ibias 或 mirror ratio）
3. 不要靠 Cc 救 → Cc ↑ 让 GBW ↓ 但 p2 不变，比例 OK 但 GBW 损失太大

### 模式 4: stage1 mirror 不平衡（PM 数字假象）

**症状**：DC OP 显示 vx 偏，但 PM 测出来"正常" 60-70°。

**根因**：vx 偏 → MN6 静态点偏 → gm6 实际值 ≠ 设计值 → PM 测得值不可靠。

**修复**：先回 `bias-headroom.md` 范例 1 修 stage1 mirror。

### 模式 5: ngspice vp() 当度数 → PM 假象 178°

**症状**：testbench 漏 `set units = degrees` → vp() 返回 radians → PM 数字
看似 178° 实际 3°。

**修复**：testbench 必含 `set units = degrees`。详见 `simulators/ngspice/measurements`。

## CL 对 PM 的影响（与单级 OTA 完全不同）

**单级 OTA**：CL ↑ → f_p1 ↓ → GBW ↓ → PM ↑（更稳）。

**2-stage OTA**：CL ↑ → f_p2 ↓ → 与 GBW 距离缩短 → **PM ↓（更不稳）**。

```
PM > 60° ⇔ p2' / GBW > 3 ⇔ gm6 / CL · Cc / gm1 > 3 ⇔ Cc / CL > 3 · gm1 / gm6
```

**CL 增大时**：必须同步增大 Cc（保 ratio）或增大 gm6（power）—— 这是 2-stage
驱动大 CL（class-AB）的物理要求。

## ngspice testbench（Method C 断环）

参见 `reference-design.md` 的 `tb_ac_gain_bw.sp` 模板。**Iron Law**：
- `set units = degrees`（不写 PM 数字 178° 假象）
- Rfb = 1G + Cfb = 1F（DC 闭环 + AC 开环）
- AC source 接 vinp DC bias + AC 1
- `.meas ac` 用 `dc_gain` / `gbw_hz` / `pm_deg` 三件套
- **加 CL 显式**（2-stage 的 PM 强烈依赖 CL，不能用浮空输出）

具体 .meas 写法 + 工艺标 .lib 见 `simulators/ngspice/measurements`。

## 不在本章范围

- **通用 AC 断环原理（Method C）** → `skill: ac-feedback-loop-method`
- **Miller 补偿原理 + pole splitting 完整推导** → `blocks/base-cells/miller-compensation`
- **ngspice .meas / .ac 语法** → `simulators/ngspice/analyses`
- **不同 OTA 拓扑的极点对比** → `blocks/5t-ota/ac-stability`（单极点）/ `folded-cascode-ota/ac-stability`（fold 极点）
- **Vds-Vdsat 触发的 PM 假象** → `bias-headroom.md`（device 不 sat 时 PM 数值无意义）

## Related

- `skill: ac-feedback-loop-method` 通用断环 + Method C 推导
- `blocks/base-cells/miller-compensation` ⭐ pole splitting / RHP zero / nulling Rz 完整推导
- `blocks/5t-ota/ac-stability` 单极点对照（理解为什么 5T 不需要 Cc）
- `blocks/folded-cascode-ota/ac-stability` 单级 cascode 对照（fold 极点 vs Miller）
- `simulators/ngspice/measurements` .meas 语法
