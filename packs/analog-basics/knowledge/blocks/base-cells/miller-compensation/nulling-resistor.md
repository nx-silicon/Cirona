---
chapter: nulling-resistor
parent: miller-compensation
summary: |
  Nulling resistor 消 RHP zero —— Rz 与 Cc 串联 / Rz = 1/gm2 推到无穷 /
  PVT tracking 实现 / 二级 opamp 标准方案
tokens: ~600
prerequisite_chapters:
  - plain-miller
related_skills:
  - circuit-method/device-sizing
related_knowledge: []
---

# Nulling Resistor 消 RHP Zero

## 拓扑

```
            V_int (第一级输出)
              │
              ●─── Rz ─── Cc ───● Vout (第二级输出)
              │       串联
              │
            (第一级)            (第二级 CS)
```

**核心机制**：在 Cc 路径上串联电阻 Rz → 改造前馈传递函数：

```
plain Miller zero:    ω_z = gm_2 / Cc        (RHP)
nulling Rz Miller:   ω_z = 1 / (Cc × (1/gm_2 - Rz))
```

当 **Rz = 1/gm_2** → ω_z → ∞ → **零点被推到无穷远**（理想抵消）。

实际 Rz 略大于 1/gm_2（典型 1.5-2× 1/gm_2）→ 把 zero 推到 LHP 形成 LHP zero（与极点抵消，净 PM 改善）。

## sizing 关系（Rz 选值）

```
Rz_target = (1.5-2) × 1/gm_2

例：gm_2 = 800 µS → 1/gm_2 = 1.25 kΩ → Rz = 2-2.5 kΩ
```

**Rz 实现方式**：
- **poly resistor**：精度好但 layout 大；不跟 PVT
- **triode-region MOS**（最常用）：W/L 反比 (μ·Cox·Vov)，与 1/gm tracking
  - 用 NMOS 偏置在 triode：R_on = 1/(μn·Cox·(W/L)·Vov)
  - 选 (W/L)_Rz·μn·Cox·Vov ≈ 1/Rz_target → tracking gm_2
  - PVT 漂同步 → 零点位置随 gm_2 漂同步抵消

### Triode-MOS Rz sizing

```
Rz target: 1/gm_2 ≈ 1.25 kΩ
选 V_g = bias 让 Vov_Rz = 0.3 V（典型 PMOS gate 接 vbias）
W/L_Rz = 1 / (Rz · μn·Cox·Vov) = 1 / (1.25k × 200µ × 0.3) ≈ 13
取 W = 1.3 µm, L = 0.18 µm（min L 速度）

PVT tracking: 
  gm_2 ∝ √(μn·(W/L)_2·Id) → μ漂时 gm_2 漂
  Rz_MOS ∝ 1/(μn·(W/L)_Rz·Vov)
  → Rz × gm_2 ∝ √(W·Id/((W/L)_Rz·Vov²)) → 残留漂动 ~10-30%（不完美但 acceptable）
```

## 与 plain Miller 对比

| 维度 | plain Miller | + nulling Rz |
|---|---|---|
| RHP zero | gm_2/Cc（恶化 PM） | 推到 ∞ 或 LHP（改善 PM） |
| PM 典型值 | 45-55° | 60-75° |
| 复杂度 | 低 | 低（仅多 1 个 R 或 MOS） |
| 速度（GBW）| ≈ baseline | 略低（5-10%，Rz 引入次极点）|

## 次极点风险

Rz 与 Cc 串联也会引入次级寄生极点：
```
fp_extra = 1/(2π × Rz × C_node_at_Vint)
```

但 C_node_at_Vint 通常很小（< 100 fF）+ Rz 是 kΩ 级 → fp_extra > 1 GHz → 远高于 GBW，不影响。

## 验证清单

- [ ] AC：实测 zero 位置（应被推到 LHP 或 > 10× GBW 的频率）
- [ ] AC：PM 提升到 60° spec（vs plain Miller 的 45-55°）
- [ ] PVT corner：Rz · gm_2 比例漂 < 50%（保证 zero 大致还在 LHP）
- [ ] tran：阶跃响应不振铃

## 常见误区

| 心里想 | 现实 |
|---|---|
| "Rz 越大零点越远" | 错——Rz = 1/gm_2 时 zero 跑到 ∞；**Rz > 1/gm_2 时 zero 移到 LHP**（不是 RHP）。LHP zero 反而能补相，但若位置过低会改变 PM；不会"跌回 RHP" |
| "用 poly Rz 就行" | poly 不跟 gm_2 漂；triode-MOS 更优 |
| "Rz 加进去就消零" | 必须 Rz ≈ 1/gm_2 才生效；要 PVT tracking 用 triode-MOS |
| "Rz 没副作用" | 极小副作用（高频次极点 + 略损 GBW）；几乎所有二级 opamp 标配 |

## 不在本章范围

- plain Miller 基础 → chapter `plain-miller`
- Ahuja-style（完全消 RHP zero 的另一方法）→ chapter `ahuja-style`
- nested Miller → chapter `nested-miller`
- 故障 debug → chapter `troubleshooting`
- 二级 opamp 整体设计 → `blocks/two-stage-ota/`
