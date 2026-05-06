---
chapter: troubleshooting
parent: cascode
summary: |
  cascode 三类典型症状对照：M_lower triode / Rout 不达预期 / output swing 不足。
  每条按"症状 → 物理因果 → 修复方向（沿因果链反向）"对照。
tokens: ~500
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/signal-tracing
  - circuit-method/causal-chain-debug
  - circuit-method/bias-tree-reasoning
---

# Cascode 故障诊断

> ⚠️ **使用规则**：本章给的是事实对照表。**思维过程**用 skill
> `circuit-method/signal-tracing`：State expectation → Observe → Identify deviation
> → Trace upstream → Verify cheapest。
> Cascode debug 的核心是**沿信号路径反推**（M_lower.Vds 不是 M_lower 自决）。

---

## 症状 1：M_lower 进 triode（dc_snapshot 显示 Vds_lower < Vov_lower）

**直接物理事实**：Vx（M_lower 的 drain）= Vbias_casc - Vgs_casc 不够高。
其中 Vgs_casc = Vth_eff(VSB_casc) + Vov_casc —— **debug 时先核 body 是否接 source**：cascode 高位管 VSB > 0 让 Vth_eff 比 Vth0 抬升 50-200 mV，会进一步压低 Vx。

**因果链**：
- Vbias_casc 偏低，或 Vth_eff 因 body effect 抬升 → Vx 偏低 → M_lower.Vds 偏低 → triode

**修复方向**（按因果反向）：

| 修复点 | 动作 | 因果 |
|---|---|---|
| Vbias_casc | 上调 50–200 mV | Vbias↑ → Vx↑ → Vds_lower↑ |
| Bias generator padding device | 减小 padding W → padding Vov 增大 → Vbias_casc 升高 | bias 是物理生成不是数字调 |
| Bias generator padding device | 或增大 padding L → 同样 | 长 L 给同 Id 下 Vov 大 |

**❌ 不要做的事**：
- 调 M_lower 的 W（不影响 Vds_lower）
- 调 M_lower 的 L（不影响 Vds_lower）
- 用理想电压源覆盖 Vbias_casc（PVT 角不真实）

**详细 padding device sizing 见 `blocks/base-cells/bias-generator/`**。

---

## 症状 2：Rout 远低于 gm·ro² 预期

**根因 A**：Vbias_casc 在 Vout sweep 范围内无法保持 M_lower saturation
- 验证：DC sweep Vout，看 Id 是否在某 Vout 范围突变 → 该范围 M_lower triode
- 修复：升 Vbias_casc 让 M_lower 在全 Vout 范围 sat

**根因 B**：L 太短，单管 ro 已经偏小
- 验证：dc_snapshot 看 ro_lower = VA·L/Id 数值（< 200kΩ 时 cascode 倍增也救不了）
- 修复：增大 M_lower 的 L（典型从 0.5µm → 1-2µm）

**根因 C**：Vbias_casc 用了理想源仿真"假阳性"
- 真实 bias 树时 Vbias_casc 随 PVT 漂动，cascode 部分时段失效
- 修复：用真实 bias generator 跑 PVT corner

**根因 D**：实际不需要 cascode（gm·ro 已经够）→ 简化设计
- single-stage CS + active load 的 Rout = ro 量级
- 如果 spec 容许 ro 量级 Rout，cascode 是过度设计

**根因 E**：需要 GΩ 量级 Rout（cascode 上限 100 MΩ 量级）
- 升级到 gain-boosted cascode（内嵌 OTA 钉死 Vx）
- 见 `chapter=gain-boosted`（Week 3）

---

## 症状 3：output swing 不够（Vout_min 过高）

**物理下限**（**不能突破**）：
```
Vout_min ≥ Vov_lower + Vov_casc
```

**两个 Vov 是堆叠 cascode 的固有代价**——除非用 wide-swing 拓扑。

**修复方向**：

| 方向 | 做法 | 代价 |
|---|---|---|
| 减小 Vov_lower | 选**大** gm/Id（如 8 → 12-15）→ Vov ≈ 2/(gm/Id) 减小（强反型 → 中等反型方向）| gm/Id 大 → 1/f noise 升 / 速度降 / 面积大 |
| 减小 Vov_casc | M_casc 的 W 加大（gm 同 Id 下 Vov ↓）| Cgs_casc 增加，BW 略降 |
| 用 wide-swing cascode | 不堆叠两个 Vds_sat | 设计复杂度增加 |
| 用 cascoded current mirror（mirror 场景）| 同 wide-swing | 同上 |

**❌ 不要做的事**：
- 调 Vbias_casc 想"压 swing 边界"——swing 边界是物理事实，不可议价
- 用 single-stage 替代 cascode（牺牲 Rout）—— 除非真不需要高 Rout

详细 wide-swing 设计见 `blocks/base-cells/current-mirror/wide-swing.md`（Week 3）。

---

## 症状 4：M_casc 自己 triode（Vout 极低或极高时）

**物理事实**：M_casc 也是 device，自己也能 triode。

- NMOS cascode：当 Vout 太低（< Vx + Vov_casc）→ M_casc triode
- PMOS cascode：当 Vout 太高（> Vx - Vov_casc）→ M_casc triode

**这个症状通常和症状 3 一起出现**——swing 边界外两端 device 都会出 saturation 边界。

**判别**：dc_snapshot 看 Vds_casc vs Vdsat_casc。

**修复**：限制 Vout 工作范围在 [Vov_lower + Vov_casc, VDD - Vov_load - Vov_casc]。

---

## 通用诊断流程

```
看 cascode 异常 →
  Step 1: dc_snapshot 拿 Vx / Vds_lower / Vds_casc / Vbias_casc
  Step 2: state expectation
    - Vds_lower 应 > Vov_lower + 50mV (margin)
    - Vds_casc 应 > Vov_casc + margin
    - Vx 应 ≈ Vbias_casc - Vgs_casc
  Step 3: identify deviation
  Step 4: trace upstream
    - 不合理节点 → 是谁决定的？
    - Vds_lower 错 → Vx 错 → Vbias_casc 错 → bias generator padding
    - Vds_casc 错 → Vout 边界（external） / Vx 错（internal）
  Step 5: verify cheapest
    - dc_snapshot 看 padding device 状态（不要直接改 cascode 重仿）
```

完整 mental model 见 skill `circuit-method/signal-tracing`。

## 不在本章范围

- **bias generator padding sizing**——见 `blocks/base-cells/bias-generator/`
- **wide-swing cascode 拓扑**——见 `blocks/base-cells/current-mirror/wide-swing.md`
- **gain-boosted cascode**——见 `chapter=gain-boosted`
- **cascoded current mirror 的 mismatch / Vds 调制问题**——见 `blocks/base-cells/current-mirror/cascoded.md`
- **PVT corner 测试方法学**——见 skill `circuit-method/monte-carlo-mismatch-method`
