---
chapter: plain-miller
parent: miller-compensation
summary: |
  基础 Miller 补偿 —— Cc 跨第二级 / pole splitting 推导 / RHP zero 副作用 /
  GBW = gm1/(2π·Cc) / PM 60° 准则
tokens: ~700
prerequisite_chapters: []
related_skills:
  - circuit-method/ac-feedback-loop-method
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/common-source
---

# 基础 Miller 补偿

## 拓扑（两级 opamp + Cc）

```
                              VDD
                               │
                          ┌────┴────┐
                          │  load1  │ (PMOS mirror)
                          └────┬────┘
                               ●─── V_int (第一级输出)
                               │
                  Vin+─────────┤   ┌─────●  Vout (第二级输出)
                          ┌────┴───┴┐
                          │ M1/M2   │   Cc (Miller cap，跨 V_int 与 Vout)
                          │ diff    │   ←
                          │  pair   │       Cc 反向反馈
                          └────┬────┘   →
                               │            ●─── Vout
                              tail          │
                                       ┌────┴────┐
                                       │  M_o    │ ← 第二级 CS（NMOS）
                                       │  CS     │
                                       └────┬────┘
                                            │
                                       (load2 PMOS active load)
```

## 极点分裂（Pole Splitting）

无 Cc 时（自由两极点）：
```
fp1 = 1/(2π × Rout_1 × C_int)    @ V_int 节点（高阻）
fp2 = 1/(2π × Rout_2 × C_load)   @ Vout 节点
```
两极点接近（同 kHz-MHz 量级）→ PM 差。

加 Cc 后（Miller 效应放大）：
```
C_int_eff = C_int + Cc·(1 + |Av_2|) ≈ Cc·|Av_2|     # |Av_2| 几十倍 → Cc 等效放大
fp1' = 1/(2π × Rout_1 × Cc·|Av_2|)                  # 主导极点（低）
fp2' = gm_2 / (2π × CL)                             # output node 被 Cc short → C_eff = CL
                                                     # （C_int 的影响经 Miller 反向变成驱动 Vout）
```

**结果**：fp1' << fp1 (拖低) / fp2' >> fp2 (推高) → **极点分裂**！双极点距离拉开 → PM 改善。

## GBW 公式

```
GBW = gm_1 / (2π · Cc)
```

→ GBW **由前级 gm 决定**，与第二级 gm 无关。

物理因果：在 GBW 频率附近，Miller 补偿让 Cc 等效连接 input 与 GND（高频 short）→ 整体回路看起来是单极点 RC（gm1·1/Cc）。

## RHP Zero 副作用

Cc 同时提供**前馈路径**：信号可以从 V_int **直接**通过 Cc 到 Vout，不经过第二级反相 → 与正常反相通路相加 → **右半平面零点**：

```
ω_z = gm_2 / Cc
```

**RHP zero 危害**：
- 与 LHP 极点不同：RHP zero 让 magnitude 升 + phase **减**（不是加）→ 等效"额外极点"恶化 PM
- 典型 ω_z 在 GBW 附近 → 直接吃掉 PM margin

## sizing 关系（GBW + PM 反推）

| 量 | 公式 | 因果 |
|---|---|---|
| GBW_target | spec | 由系统 spec |
| Cc | gm_1 / (2π × GBW) | 由前级 gm 选 Cc |
| fp2' (要求 ≥ 3 × GBW @ PM 60°)| gm_2 / (2π × CL) | 由第二级 gm 反推 → CL_max |
| fp_z (RHP) | gm_2 / Cc | gm_2 增 → fp2 增 + zero 也增；要 fp2 / fp_z ≈ 1（zero 与 fp2 互相对消？不行，zero 是 RHP）|

**关键**：plain Miller 通常 PM 仅 45-55°（被 RHP zero 拉走 10-20°）→ 实际工程几乎都加 nulling resistor 消零。

## sizing 范例（两级 opamp）

> 📌 **@ vpdk180nm**（μn/p·Cox / Vth / Cox 数值参考 `pdks/vpdk180nm/index.md`）。换工艺重算 Cc / Iout_2nd；Miller 主极点分裂 + RHP zero（gm₂/Cc）公式跨工艺通用。

设计目标：GBW = 10 MHz / PM = 60° / Cload = 5 pF / VDD = 1.8 V / Itail_1st = 20 µA / Iout_2nd = 100 µA

```
第一级 (5T 差分对): gm_1 由 spec gm/Id = 12 → gm_1 = 240 µS @ Itail=20µA

Cc:
  Cc = gm_1 / (2π × GBW) = 240µ / (2π × 10M) = 3.8 pF

第二级 (CS): gm_2 选 gm/Id = 8 → gm_2 = 800 µS @ Iout=100µA

fp2 = gm_2 / (2π × Cload) = 800µ / (2π × 5p) = 25 MHz → 远大于 GBW 10 MHz ✓

fp_z (RHP) = gm_2 / Cc = 800µ / 3.8p = 33 MHz → 与 fp2 同量级 → PM 退化

→ PM 估算（含 RHP zero）：
   GBW 处 phase = -90° (主极点)
                - arctan(GBW/fp2) ≈ -arctan(10/25) ≈ -22°
                - arctan(GBW/fp_z) ≈ -22°  (RHP 减分)
                - 90 (主极点)+22 (fp2)+22 (RHP) = 134° → PM = 180-134 = 46° ✗

→ 加 nulling resistor 消 RHP zero，详见 chapter `nulling-resistor`
```

## 验证清单

- [ ] AC：测 GBW vs gm_1 / Cc 公式（误差 < 10%）
- [ ] AC：测 PM 在 GBW（应 ≥ 60° spec；plain Miller 通常 45-55°）
- [ ] AC：找 RHP zero 位置（gm_2 / Cc）vs fp2 比较
- [ ] 大信号 PM：用 skill `circuit-method/ac-feedback-loop-method` 检查最坏 gm
- [ ] PVT corner：fp2 / fp1 / GBW 漂 < 30%

## 常见误区

| 心里想 | 现实 |
|---|---|
| "GBW 由 Cc 决定，调 Cc 就行" | GBW = gm_1/Cc，要保 GBW 必须保 gm_1·1/Cc 比例 |
| "增大 Cc 总是更稳" | 是，但 GBW 等比例下降 → 速度损 |
| "RHP zero 不影响" | 错——直接吃 PM 10-20°，是 plain Miller 的核心问题 |
| "大 Cload 不影响"（plain Miller）| Cload 增 → fp2 降 → PM 退；plain Miller 不适合大 Cload |
| "Cc 用 MOM 还是 MIM" | MOM matching 好但 area 大；MIM 需特殊工艺；选择看 PVT 与精度需求 |

## 不在本章范围

- 消 RHP zero（nulling resistor）→ chapter `nulling-resistor`
- 完全消零 + 速度优化（Ahuja）→ chapter `ahuja-style`
- 三级 opamp 嵌套 Miller → chapter `nested-miller`
- 寄生 Miller（不是补偿）→ chapter `parasitic-miller`
- 故障 debug → chapter `troubleshooting`
- 二级 opamp 整体设计 → `blocks/two-stage-ota/`
