---
chapter: architecture
parent: 5t-ota
summary: |
  5T-OTA 拓扑细节 + variants 文字描述 + 与其他 OTA 4D（gain/BW/power/swing）
  对比 + 适用场景。
tokens: ~900
prerequisite_chapters: []
related_knowledge:
  - blocks/folded-cascode-ota
  - blocks/two-stage-ota
---

# 5T-OTA Architecture

## 拓扑本质

**5 transistors = 1 input pair (2) + 1 mirror load (2) + 1 tail (1)**

物理本质：**单级 transconductance 放大器**——把差分输入电压转成 push-pull 的输出电流，由输出节点的 ro 转电压。

```
单级 OTA = transconductance stage （没有 cascode 增强 / 没有 buffer / 没有补偿）
gain = gm × Rout
GBW  = gm / (2π · CL)
```

**关键约束**：单级 OTA 的 gain 完全由 gm × ro 决定。VDD = 1.8V / vpdk180nm 下 gm × ro ≈ 100-300（即 40-50 dB）。要 gain > 55 dB **物理上不行**——必须换 cascode（FC / Tele）或两级（Two-stage）。

## Standard variant（V4 reference）

```
NMOS-input + PMOS-mirror + NMOS-tail
- Input pair: NMOS（适合低 VCM 0.5-1.0V）
- Load: PMOS current mirror（M3 diode + M4 mirror）
- Tail: NMOS current source（mirror Mbias）
```

V4 `reference-design.md` 提供此变体的 production-grade 网表（含 standard port order + bias chain + sizing 起点）。**新设计先 load reference design，不要从零造拓扑**。

## Variants（从 reference 怎么改）

不是为每个变体提供独立网表——**reference design baseline + 文字描述变体怎么改**。

### Variant 1: PMOS-input + NMOS-mirror（high-VCM 场景）

适用：VCM 接近 VDD（0.8-1.6V @VDD=1.8V），需要 input pair 在高 VCM 下 saturation。

**怎么改 reference**：
- M1/M2: NMOS → PMOS（type 反转）
- M3/M4: PMOS → NMOS
- M5: NMOS tail → PMOS tail（top tail）
- VDD/VSS connection：input pair source 接 top tail（PMOS），output 节点接 NMOS mirror 底部

物理对照：
- Headroom 镜像（VDD ↔ VSS 反转）
- 总 swing 依然 ≈ 1.0V（@VDD=1.8V）
- 噪声特性：PMOS-input flicker noise 通常较 NMOS 小（同 W·L）

### Variant 2: Cascoded mirror load（gain ceiling 提升）

适用：要 gain 50-65 dB（超出基础 5T 上限）但仍单级简单。

**怎么改 reference**：
- M3/M4 → 替换为 cascoded current mirror（参见 `blocks/base-cells/current-mirror/cascoded.md`）
- 加 1-2 个 cascode device（M3a, M4a），新增 cascode bias 节点 vbc_p

物理对照：
- gain ↑ 10-20 dB（从 ro 单倍 → ro × gm·ro）
- swing ↓ 0.3-0.5V（cascode 占 headroom）
- mirror node 寄生 cap ↑ → PM 紧
- ⚠️ cascode bias 偏置如果偏低 → cascode 底部管 triode（**见 bias-headroom.md 范例 + W6+ sizing-reasoning chapter for cascode**）

### Variant 3: Wide-swing mirror load

适用：低 VDD（< 1.2V）下需要保 swing 但仍要一定 gain ceiling。

**怎么改 reference**：
- M3/M4 → wide-swing current mirror（`blocks/base-cells/current-mirror/wide-swing.md`）
- 多一个 padding device 控制 cascode bias

物理对照：
- swing 比 cascoded variant 大 0.2-0.3V
- 但 gain 提升不如 cascoded variant

### Variant 4: 5T_edu（教学用，**不要 ship**）

V3 残留：纯单级 5T 作为 LDO 教学示例。**实际 LDO loop gain 60-80 dB 单 5T 永远不够**——通过 `load_knowledge(name='ldo', asset='reference_designs/ldo_5t_edu.cir')` 拿到的网表仅做对比演示。

## 4D Trade-off：5T-OTA vs 其他 OTA

| 维度 | 5T | FC | Tele | 2-stage |
|---|---|---|---|---|
| **Gain** | 40-55 dB | 60-80 dB | 60-80 dB | 60-90 dB |
| **GBW**（@CL=1pF）| 1-50 MHz | 1-100 MHz | 1-100 MHz | 1-50 MHz（受 Miller 限制）|
| **PM** | 易（单极点）| 中（mirror 极点）| 中（cascode 极点）| 难（Miller / RHP zero）|
| **Power** | 低（30-100µW）| 中（50-200µW）| 中（50-200µW）| 较高（100-500µW）|
| **Swing**（VDD=1.8V）| ≈ 1.0V | ≈ 0.6-0.8V（cascode 占）| ≈ 0.4-0.6V（双 cascode）| ≈ 1.2V（last stage 单管）|
| **Noise**（input-referred）| 中 | 低（cascode 抑制 mirror noise）| 低 | 中 |
| **复杂度** | 最简单 | 中 | 中 | 复杂（需补偿）|
| **典型适用** | 简单 buffer / 数字接口 | 高 gain + headroom 紧 | 高 gain + 低噪声 | 高 gain + 大 swing |

## When to use 5T-OTA

- ✅ Gain 需求 30-55 dB（明确单级够）
- ✅ 简单 unity-gain follower / 数字接口 / charge pump 控制
- ✅ 设计入门 / 教学
- ✅ 作为 OTA 设计 baseline（先验证 5T 是否够，不够再换更复杂拓扑）

## When NOT to use 5T-OTA

- ❌ Gain > 60 dB（物理上不行——`blocks/folded-cascode-ota/` 或 `blocks/two-stage-ota/`）
- ❌ 严苛 PSRR / line regulation（5T 单级 PSRR 通常 < 30 dB @ 1kHz）
- ❌ 大 swing 需求接近 rail-to-rail（5T 总 swing ≈ VDD - 0.5V，rail-to-rail 需要 class-AB 输出级）
- ❌ LDO error amplifier（loop gain 60-80 dB，必须双级 EA）

## Related

- 4 OTA 拓扑详细对比 → `blocks/folded-cascode-ota/architecture` / `blocks/telescopic-ota/architecture` / `blocks/two-stage-ota/architecture`
- input pair 物理 → `blocks/base-cells/differential-pair`
- mirror load 物理 → `blocks/base-cells/current-mirror` / `blocks/base-cells/active-load`
- 设计推进顺序 → 见 `sizing-typical.md` 拓扑特定步骤
