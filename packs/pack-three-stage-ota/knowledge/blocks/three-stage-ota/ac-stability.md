---
chapter: ac-stability
parent: three-stage-ota
summary: |
  ⭐ 灵魂章 — Three-stage opamp Nested Miller Compensation 完整推导：3 极点
  分布 + pole splitting × 2 + RHP zero × 2 + Rc1 / Rc2 nulling 双消 +
  GBW = gm1/(2π·Cc1) + 双 PM 验证（quiescent + corner）。Miller 单级数学引用
  base-cell。
tokens: ~2000
prerequisite_chapters:
  - architecture
related_skills:
  - circuit-method/ac-feedback-loop-method
related_knowledge:
  - blocks/base-cells/miller-compensation
  - blocks/two-stage-ota
---

# Three-Stage Opamp AC Stability

> 通用 AC 断环方法（Method C：Rfb=1G + Cfb=1F）见 `skill: ac-feedback-loop-method`。
> Miller 补偿单级数学（pole splitting + RHP zero + nulling Rz）见
> `blocks/base-cells/miller-compensation`。2-stage Miller 见
> `blocks/two-stage-ota/ac-stability`。**本章节是 3-stage 真正的灵魂章** —
> NMC（Nested Miller Compensation）双重 pole splitting + 双 RHP zero 消除是
> 3-stage 与 2-stage 最大的差异。

## 极点分布（**未补偿** 3-stage）

3-stage 串联 → 3 个独立主极点：

```
f_p1 ≈ 1 / (2π · R_stage1_out · C_stage1_out)   ← stage1 输出 v1_out
f_p2 ≈ 1 / (2π · R_stage2_out · C_stage2_out)   ← stage2 输出 v2_out
f_p3 ≈ 1 / (2π · R_stage3_out · CL)              ← stage3 输出 vout

未补偿时 3 极点位置接近 → 总 phase 累计 -270° → 必振荡
```

**这是 3-stage 必须双重 Miller 补偿的物理本质** — 单 Miller cap 不够（只能
splitting 2 个极点），3 极点需要 NMC。

## NMC 极点分布（**Nested Miller pole splitting × 2**）

加 Cc1（外）+ Cc2（内）双 Miller cap：

### 外 Miller Cc1（跨 stage 2+3）

```
Cc1 + Rc1 配对：v1_out → ... → vout（跨 2 个 stage）
Cc1 让 stage1 输出节点的有效电容大幅放大 by (1 + |A_stage2 · A_stage3|)：
  C_stage1_eff ≈ Cc1 × |A_stage2 · A_stage3|
              ≈ Cc1 × 3e2 - 1e3 (50-60 dB cascade gain，linear scale)

→ f_p1' = 1 / (2π · R_stage1_out · Cc1 · A_total) ≈ 1-10 kHz
→ f_p2' 推高 by Miller effect on stage2 output (less aggressive due to inner Cc2)
→ f_p3' 推高 by Cc1 影响 stage3 input
```

### 内 Miller Cc2（跨 stage3）

```
Cc2 + Rc2 配对：v2_out → ... → vout（仅跨 stage3）
Cc2 让 stage2 输出节点的有效电容放大 by (1 + |A_stage3|)：
  C_stage2_eff ≈ Cc2 × A_stage3 ≈ Cc2 × 10²-10³

→ f_p2' = gm_stage_combined / (2π · CL × Cc1 / Cc2) ≈ 30-100 MHz
→ inner zero / pole 各自调整
```

### 极点位置完整图

```
   f_p1'        GBW            f_p2'                f_p3' / zeros (Rc 消除)
   |            |               |                          ∞
   ────────────|─────|─────────|──────────────  freq
   1k-100k Hz   5-30 MHz       >3×GBW                  >3×f_p2'
   (Cc1·A_total dominant)      (NMC inner pole)        (high freq)
```

**NMC pole ordering 是拓扑近似**，实际位置取决于 sizing；**必须 AC extraction
验证**而非闭式推断。

### GBW 计算（同 2-stage Miller 形式）

```
GBW = gm_stage1 / (2π · Cc1)
    ≈ 200 µS / (2π · 3 pF) ≈ 10.6 MHz   (V4 baseline)
```

⚠️ **公式书写**：本章及 reference-design 起点表中 `GBW = gm/Cc` 简写时务必
明示 `2π` 因子；省略 `2π` 是常见笔误（结果相差 6.28×）。

> **3-stage GBW 受 Cc1 限**——不像 2-stage 由 Cc 直接限，3-stage 因 NMC
> 双重补偿 + Cc1 主导 outer pole splitting，GBW 通常 < 30 MHz。

## PM 设计起点（NMC 标准准则）

```
PM > 60° 要求：
  f_p2' > 3 × GBW (基础 Miller 准则)
  f_p3' > 3 × f_p2' (NMC 特有：保 inner pole 不撞)
  f_z1, f_z2 (RHP zero) 远高于 GBW (Rc 消零)

NMC 标准 sizing 起点：
  Cc1 / CL ≈ 0.5-1 (V4 baseline 0.6)
  Cc2 / Cc1 ≈ 0.3-0.5 (V4 baseline 0.5)
  Rc1 = 1 / gm_stage_combined
  Rc2 = 1 / gm_stage3
```

## 2 个 RHP zero（**NMC 副作用，必须双消**）

每个 Miller cap 引入一个 RHP zero（feedforward path）：

```
Outer RHP zero (Cc1):
  f_z1 = gm_stage_combined / (2π · Cc1)
  Rc1 = 1 / gm_stage_combined → 推 zero 到 ∞

Inner RHP zero (Cc2):
  f_z2 = gm_stage3 / (2π · Cc2)
  Rc2 = 1 / gm_stage3 → 推 zero 到 ∞
```

**关键**：
- Rc1 用 stage_combined gm（stage2 + stage3 串联等效 gm）
- Rc2 用 stage3 单管 gm（仅 MP4 gm）
- **2 个 Rc 不同**——是 2 个不同 zero 各自消

> **NMC vs 2-stage Miller 关键差异**：2-stage 只 1 个 RHP zero + 1 个 Rz；
> 3-stage 是 2 个 RHP zero + 2 个 Rc。**Rc1 ≠ Rc2** 是 NMC 设计核心。

## ⭐ 范例 1：NMC 中段 PM 紧（f_p2' 接近 GBW）

### 症状
quiescent state：tb_ac_gain_bw 测 PM = 50°（略紧）；GBW = 10 MHz；
看 phase plot：在 30-100 MHz 区间 phase 急速下降。

### R1 KVL 反推
```
GBW = gm1 / (2π · Cc1) = 200µS / (2π · 3pF) = 10.6 MHz
f_p2' = gm_combined / (Cc1 / Cc2) ≈ ... 

实际 f_p2' / GBW 比例：
  设 Cc2 = Cc1 / 2 = 1.5 pF
  f_p2' ≈ gm_combined / (2π · CL × Cc1/Cc2) 
       = gm_combined / (2π · 5pF × 2)
       ≈ 16 MHz × Cc2/Cc1 ratio调整

f_p2' / GBW 不够 3× → PM 紧
```

### 三条调节路径
**路径 A — Cc2 重调（不是单方向 ↓）**：
- 按本章近似 `f_p2' ≈ gm_combined·Cc2 / (2π·CL·Cc1)`，**Cc2 ↑** 才推高 f_p2'；
  `Cc2 ↓` 反而让 f_p2' 下移（与早期教科书直觉相反）
- 但 Cc2 同时影响 inner pole/zero 位置（pole-zero pair），方向不单调
- **必须 sweep Cc2 + AC pole/zero extraction 验证**完整 phase plot

**路径 B — Cc1 ↑（降低 GBW，需重算 ratio）**：
- Cc1 = 3 → 4 pF → GBW = 7.95 MHz
- 但 `f_p2'` 也随 Cc1 增大（公式中 Cc1 在分母）→ `f_p2'/GBW` 不一定改善
- **必须用 AC extraction 验证**而非纯文字推断

**路径 C — m_stage2 ↑**（gm_combined ↑）：
- gm_combined ↑ → f_p2' ↑ → PM 余量增
- 副作用：power ↑，stage2 area ↑

### 优先级：Path B（最简单，PM 改善确定）→ Path A（如 GBW 不能损失）→ Path C

## ⭐ 范例 2：RHP zero 不完全消（Rc1 / Rc2 偏离）

### 症状
quiescent PM = 60° 看似 OK；但 phase plot 在 50-200 MHz 区间有 anomaly
（phase 不是单调下降）；THD 中频带 > spec。

### R1 KVL 反推
```
Rc 消零条件：Rc · gm = 1
  Rc1_design = 3 kΩ for gm_combined = 333 µS  → 实测 gm_combined = 250 µS
  → Rc1 应该 = 4 kΩ → V4 baseline 3 kΩ 不完全消

zero 实际位置：
  f_z' = 1 / (2π · Cc · (1/gm - Rc))
  Rc < 1/gm → zero 在 RHP 有限位置 → PM 退化
  Rc > 1/gm → zero 在 LHP（增 PM）→ 可接受 (waste BW)
```

### 修复路径
| 路径 | 怎么做 | 效果 |
|---|---|---|
| 重测 gm 后调 Rc | tb_dc_op 拿 gm_combined / gm_MP4 实测值 | Rc = 1/gm 准确 |
| 加 R-trim（数字校准）| Rc digitally 选 | sweep 找 best |
| 接受小 PM 退化 | 留 5-10° margin | 简化 |

## ⭐ 范例 3：3 stage gain 分配不均（gain ceiling 不达 100 dB）

### 症状
spec：gain ≥ 100 dB。tb_ac_gain_bw 测 gain = 92 dB（差 8 dB）。

### R1 KVL 反推
```
total_gain = A_stage1 (dB) + A_stage2 (dB) + A_stage3 (dB)

V4 baseline 起点：A1 ≈ 35, A2 ≈ 35, A3 ≈ 25 dB → 95 dB
Spec 100 dB → 任一 stage 提 5 dB

A_stage 提升路径：
  A_stage_i ∝ gm_i × ro_i
  gm 大 → A 大；ro 大 → A 大
  ro ∝ L → 增 L 提 ro
```

### 修复路径
| 路径 | 怎么做 | 效果 |
|---|---|---|
| L_diff_stage1 ↑（2 → 3µm）| ro_M1 ↑ → A1 ↑ | 直接提 5 dB |
| L_cs_stage2 ↑（1 → 2µm）| ro_M3 ↑ → A2 ↑ | 5 dB；副作用：BW 紧（M3 cap ↑）|
| L_cs_stage3 ↑（0.5 → 1µm）| ro_MP4 ↑ → A3 ↑ | 5 dB；副作用：drive 损失 |
| 加 cascode in stage1 | A1 30 → 50 dB | 总 gain 110+ dB |

### 优先级：Stage1 / Stage2 长 L 提 ro（速度影响小）→ Stage3 长 L（drive 损失）→ Cascode（复杂度大）

## ⭐ 范例 4：Cross-corner PM 退化

### 症状
TT @ 27°C PM = 60°；FF / SS / -40 / 125°C 任一 corner PM < 50°。

### 物理因果链
```
跨 corner gm 漂 → f_p2' / f_p3' 漂 → PM 余量减
跨 corner Cc / Cgs 比例漂 → pole 位置漂
```

### 修复路径
| 路径 | 怎么做 |
|---|---|
| quiescent PM 留 70°+ margin | 跨 corner 跌 10° 也仍 > 60° |
| Cc1 ↑（margin trade GBW）| 减 GBW 但 PM 余量大 |
| Cross-corner sweep 反推 | sizing-time 验证 worst case |

## 失稳模式总结

| 模式 | 物理 | 修复 |
|---|---|---|
| 1. f_p2' 太接近 GBW | Cc1 太小或 Cc2 太大 | Cc1 ↑ 或 Cc2 ↓ |
| 2. Rc1 / Rc2 偏离 1/gm | RHP zero 不消 | 实测 gm 后调 Rc |
| 3. 3 stage gain 分配不均 | 总 gain 不达 spec | 调各 stage L |
| 4. Cross-corner PM 退化 | gm 漂 | quiescent 留 margin |
| 5. Cc1 vs Cc2 比例错 | 单 Cc 主导，nested 失效 | Cc1 / Cc2 ≈ 2-3 |
| 6. ngspice vp() 弧度 | PM 错 57× | `set units = degrees` |

## ngspice testbench

### tb_ac_gain_bw.sp（Method C，CL=5pF）
期望 gain ≥ 100 dB / GBW 5-15 MHz / quiescent PM ≥ 60°（留 margin）。

### tb_loop_ac.sp（详细 PM 分析）
3-stage 极点多，需 dec 200 细扫看 phase 形状（不只单点 PM）。

### tb_step_ringing.sp
大信号 step 看 settling；正确 NMC 不应 ringing。

## 不在本章范围

- **通用 AC 断环原理（Method C）** → `skill: ac-feedback-loop-method`
- **Miller 补偿单级数学（pole splitting + RHP zero + Rz nulling）** → `blocks/base-cells/miller-compensation`
- **2-stage Miller 对照** → `blocks/two-stage-ota/ac-stability`
- **Vds-Vdsat 触发的 PM 假象** → `bias-headroom.md`
- **MNMC / NGCC / Active feedback 高级 NMC variant** → `architecture.md` Variants

## Related

- `skill: ac-feedback-loop-method` 通用断环 + Method C
- `blocks/base-cells/miller-compensation` ⭐ Miller comp + RHP zero + Rz
- `blocks/two-stage-ota/ac-stability` 2-stage 对照（理解 NMC 增量）
- `bias-headroom.md` 跨级耦合（v1_out / v2_out 静态偏 → gain 漂 → PM 假象）
- `simulators/ngspice/measurements` .meas 语法
