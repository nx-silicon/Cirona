---
chapter: basic
parent: cascode
summary: |
  基础 cascode：物理 / sizing / 内节点 Vx 由 Vbias_casc 决定的因果链 +
  output swing vs Rout 折衷
tokens: ~700
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/bias-generator
---

# 基础 Cascode

## 拓扑结构（事实）

```
            Vout (output node)
              │
            ┌─┴─┐
       │←───│M_casc│  Vgs_casc = Vbias_casc - Vx
       │    └─┬─┘
       │      │ Vx (internal node, "屏蔽点")
   Vbias_casc │
       │    ┌─┴─┐
            │M_lower│  Vds_lower = Vx - Vss
            └─┬─┘
              │
            Vss (or current source below)
```

**核心机制**：
- M_lower 决定支路电流（以及 transconductance 如果是输入级）
- M_casc 是**common-gate** 配置——栅极接 Vbias_casc（AC 接地），source 接 Vx，drain 接 Vout
- 当 Vout 摆动时，**主要由 M_casc 吸收**（Vx 几乎不动）→ M_lower 的 Vds 几乎恒定 → ro 调制误差极小

## 关键物理因果链

### 内节点 Vx 由谁决定？（**反直觉但关键**）

```
Vx = Vbias_casc - Vgs_casc
   = Vbias_casc - (Vth_eff(VSB_casc) + Vov_casc)
   其中 Vth_eff = Vth0 + γ(√(2ΦF + VSB) - √(2ΦF))   # body effect
```

⚠️ **body effect 提醒**：cascode 高位管 source = Vx ≠ ground/VDD（VSB > 0），Vth_eff 会比 Vth0 抬升 50-200 mV @ 180nm γ ≈ 0.4 V^0.5。
若把 cascode 管 body 接 source（需 deep n-well 工艺）可消此项；标准工艺必须算上。

**M_lower 的 Vds 是 Vx**（M_lower drain 接 Vx，source 接下方）。

→ **M_lower.Vds 不是 M_lower 自己决定的**——是上游 Vbias_casc 减去 M_casc 的 Vgs。

这是 LDO / OTA cascode 设计**最常被误解的点**。看到 M_lower triode 的反应应该是：

| 错误反应 | 正确反应 |
|---|---|
| ❌ "M_lower 的 W 太大，减 W" | ✅ 问 "M_lower.Vds 是谁决定的？" → Vx 不够高 |
| ❌ "M_lower 的 L 加长" | ✅ 沿因果链反推 Vbias_casc → 调上游 bias generator |

### 修复方向（沿因果链反向）

1. 算出 M_lower 需要的 Vds_min = Vov_lower + 50 mV margin
2. 反算需要的 Vx = Vds_min（Vx 就是 M_lower 的 Vds）
3. 反算需要的 Vbias_casc = Vx + Vgs_casc = Vx + (Vth + Vov_casc)
4. 调 bias generator 的 padding device 把 Vbias_casc 顶到这个值

详细 padding device sizing 见 `blocks/base-cells/bias-generator/`。

## Output Resistance（事实 + 因果）

```
Rout ≈ gm_casc · ro_casc · ro_lower
```

**因果链推导**：
- 下管 ro_lower 在 Vds 不变时是 ∂Vds/∂Id 的逆
- M_casc 让 Vds_lower 不动 → Vout 任何摆动只通过 M_casc 的 ro_casc 看到 Id 变化
- 但 M_casc 也是 ro_casc 量级，加上 gm_casc 反馈调节 → 等效电阻被放大 (1 + gm_casc · ro_casc) ≈ gm_casc · ro_casc 倍

**典型数值**（180nm, Id=10µA, L=1µm）：
- ro = VA·L/Id = 10 × 1 / 10µ = 1 MΩ
- gm = 100 µS（gm/Id=10）
- gm · ro = 100，gm · ro² = 100 MΩ

## Output Swing 损失（折衷）

```
Vout_min = Vds_sat_lower + Vds_sat_casc + Vss
        = Vov_lower + Vov_casc (+ Vss)
```

**比单管 CS 多损失 1 个 Vov_casc** ≈ 100–250 mV。

低压（VDD=1.2V）项目中 cascode 设计要权衡：
- Rout ↑（gm·ro²）
- Output swing ↓（少 Vov_casc）
- Headroom budget 紧张

→ 这就是 **wide-swing cascode** 出现的原因（在 cascode bias 设计上做手脚把 swing 压回到 cascoded mirror 的水平），见 wide-swing 章节（Week 3）。

## Sizing Guideline

### M_lower（主要承担 transconductance / current）

按 `circuit-method/device-sizing` 决定 W/L：
- 由 Id（spec 给）+ gm/Id（typical 8-15）→ 反推 W/L
- L ≥ 2×Lmin（matching + ro）

### M_casc（屏蔽用，**典型同 W/L 同 m**）

**为什么同尺寸**：
- 同 Id（串联）→ 同 Vov_casc（如果 W/L 相同）
- M_casc 的 Vgs 仅用于 cascode bias 推算，不需要特殊 sizing
- 异尺寸会增加 cascode bias 设计复杂度（要算两个不同 Vov）

**例外**：wide-swing 拓扑会让 M_casc W 大于 M_lower W（让 Vov_casc 小）—— 那是 wide-swing 章节的事。

## 验证清单

- [ ] dc_snapshot 显示 M_lower 在 saturation（Vds_lower ≥ Vov_lower + 50mV）
- [ ] dc_snapshot 显示 M_casc 在 saturation
- [ ] dc_snapshot 显示 Vx ≈ Vbias_casc - Vgs_casc（计算式与实测一致）
- [ ] Output sweep（DC sweep Vout）：Vout 从 (Vov_lower + Vov_casc) 到 (VDD - Vov_load) 之间 Id 变化 < 1%
- [ ] AC sweep：Rout 与公式（gm_casc · ro_casc · ro_lower）数量级一致
- [ ] Vbias_casc 来自真实 bias generator（不是理想电压源 — 否则 PVT 角下不真实）

## Sizing 范例（NMOS cascode current source，Id=10µA target Rout=50MΩ）

> 📌 **@ vpdk180nm**（μn·Cox ≈ 270 µA/V²、Vth_n ≈ 0.35 V、long-channel L ≥ 1µm 时 VA ≈ 10 V/µm）。short-channel 工艺（L < 0.5µm）VA_eff 比公式小 2-5×，ro 必须 BSIM 实测；公式形式（Rout = gm·ro·ro）跨工艺通用。

```
M_lower (NMOS, source 接 vss):
  - role: 设定支路电流 + transconductance
  - 选 gm/Id = 10（中等反型，平衡 noise + speed）
    → gm_lower = Id × (gm/Id) = 10µ × 10 = 100 µS
  - Vov_lower = 2/(gm/Id) = 0.2 V
  - μn·Cox ≈ 270 µA/V²
    W/L = 2·Id/(μn·Cox·Vov²) = 2×10/(270×0.04) ≈ 1.85
  - L = 1 µm（matching + ro：ro_lower = VA·L/Id = 10×1/10µ = 1 MΩ）
  - W ≈ 1.85 µm，m=1
  - 验证：gm·ro = 100µ × 1M = 100（足够支撑 cascode 倍增）

M_casc (NMOS, source 接 Vx，drain 接 Vout):
  - role: 屏蔽 M_lower 的 Vds 漂移
  - 同 Id, 同 W/L, 同 L, 同 m（first-pass）
  - Vov_casc = 0.2 V, Vgs_casc = Vth + Vov ≈ 0.65 V
  - ro_casc 同 ro_lower = 1 MΩ
  - 期望 Rout = gm_casc × ro_casc × ro_lower = 100µ × 1M × 1M = 100 MΩ ✓

Vbias_casc 设计:
  - 目标 Vds_lower = Vov_lower + 50mV margin = 0.25 V (= Vx)
  - Vbias_casc = Vx + Vgs_casc = 0.25 + 0.65 = 0.9 V
  - 由 bias_generator 的 cascode padding device 自动追踪生成（不要用理想源！）

Output swing:
  - Vout_min = Vov_lower + Vov_casc = 0.4 V（vs 单管 CS 的 0.2V，损失 200mV）
```

## 常见误区（self-check）

| 心里想 | 现实 |
|---|---|
| "M_lower triode 是 M_lower 太大" | M_lower.Vds 由 Vbias_casc 和 Vgs_casc 共同决定，不是 M_lower 自决 |
| "用理想电压源给 Vbias_casc 验证" | PVT 角下 Vbias_casc 必须用真实 bias 树追踪，理想源仿真"假阳性" |
| "Rout 不够再叠一级 cascode" | 理想双 cascode 可再乘 ~gm·ro（量级 30-100×），但代价是 headroom（多 1×Vdsat）+ bias 复杂度 + swing 损 + 寄生极点；若需 ≥ 100 dB 增益，gain-boosted 通常比双 cascode 更经济 |
| "cascode 不会 triode" | M_casc 自己也能 triode：当 Vout 极低时 Vds_casc < Vov_casc → triode |

## 不在本章范围

- **gain-boosted cascode**（内嵌 OTA 钉死 Vx）→ `chapter=gain-boosted`
- **wide-swing cascode**（牺牲部分 Rout 换 swing）→ `chapter=wide-swing`（属 current-mirror 章节，因为 wide-swing 在 mirror 场景常用）
- **Vbias_casc 具体生成电路**（padding device sizing）→ `blocks/base-cells/bias-generator/`
- **cascoded current mirror 的镜像精度**（不只是 ro）→ `blocks/base-cells/current-mirror/cascoded.md`
- **common-gate 作为输入级**（不同 use case）→ `blocks/base-cells/common-gate-stage/`
