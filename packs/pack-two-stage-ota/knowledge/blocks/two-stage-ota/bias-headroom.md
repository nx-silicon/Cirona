---
chapter: bias-headroom
parent: two-stage-ota
summary: |
  ⭐ 2-stage OTA 拓扑特有的 Vds/Vdsat 物理约束 + R1 KVL 反推 + R2 镜像约束 +
  跨级耦合（stage1 输出 vx 由 mirror match 决定，影响 stage2 静态点）。
  核心范例：vx 跑到 rail（mirror 失配）+ MN6 / MP6 triode（stage2 静态点偏）。
tokens: ~1700
prerequisite_chapters:
  - reference-design
related_skills:
  - device_sizing
  - signal_tracing
related_knowledge:
  - blocks/5t-ota
  - blocks/base-cells/common-source
  - blocks/base-cells/current-mirror
---

# Two-Stage OTA Bias & Headroom Reasoning

> 通用 vds-vdsat 推理范式见 `skill: device-sizing`（W6+ R1-R4 铁律）。
> 本章节给的是 **2-stage 拓扑特有的器件 Vds / Vdsat 物理约束**与失稳调整顺序。
> 工具：`inspect_device(<device>)` 看 Vds/Vdsat margin；`inspect_node(<node>)`
> 看节点电压由谁决定；`propose_knob(<target>, <direction>)` 给可调旋钮排序。

## 跨级 Headroom Budget（VDD = 1.8V 典型）

2-stage 与单级 OTA 的关键差异：**每级独立 headroom，但 stage1 输出 vx 决定 stage2 静态点**。

### Stage 1（5T 结构，PMOS-input）

参照 `blocks/5t-ota/bias-headroom`——5T 内部约束完全适用：

| 路径 | 器件堆栈 | 最小 Vds 占用 |
|---|---|---|
| VDD → vx 路径 | \|Vds_MPTAIL\| + \|Vds_MP2\| + Vds_MN4 | (\|Vov_MPTAIL\|+50) + (\|Vov_MP2\|+50) + (Vov_MN4+50) ≈ 0.5V |
| vx 节点上限 | VDD - \|Vov_MPTAIL\| - \|Vov_MP2\| - 50mV | ≈ 1.45V |
| vx 节点下限 | Vov_MN4 + 50mV ≈ 0.35V | — |
| **vx 静态点目标** | **VDD/2 = 0.9V** | （mirror match 决定）|

### Stage 2（NMOS-CS + PMOS-load）

stage2 是单管输出 → swing 几乎 rail-to-rail：

| 路径 | 器件 | 最小 Vds 占用 |
|---|---|---|
| vout 上限 | VDD - \|Vds_MP6\| | \|Vov_MP6\| + 50mV ≈ 0.25V |
| vout 下限 | Vds_MN6 | Vov_MN6 + 50mV ≈ 0.25V |
| **总 swing** | **≈ VDD - 0.5V = 1.3V**（@VDD=1.8V）| **接近 rail-to-rail** |

> **2-stage 的 swing 优势**：stage2 单管堆叠 → 总 Vov 占用 < 0.5V，是
> 4 OTA 中**唯一接近 rail-to-rail** 的拓扑。

### 跨级耦合：vx 决定 stage2 静态工作点

```
vx = MN4.D = MP2.D     ← stage1 mirror 输出 + stage2 input
MN6.G = vx
I_MN6 = (μ·Cox · W/L) · (vx − Vth_n)² / 2      ← stage2 静态电流
```

如果 stage1 mirror 不平衡（MN3 ≠ MN4 sizing 或 MP1 ≠ MP2 sizing）：
- vx 不在 VDD/2 → 跑到 rail
- I_MN6 错（要么 cutoff，要么过大）→ stage2 静态电流 ≠ MP6 mirror 电流
- vout 跑到 rail（任一管进 triode）

**所以 stage1 mirror match 比 stage2 sizing 更先决**——见范例 1。

## 每个器件的 Vds 物理因果（KVL 反推）

| 器件 | Vds 公式（KVL）| 调节路径 |
|---|---|---|
| **MP1, MP2**（PMOS input pair）| \|Vds_MP1\| = V(ntail) − V(vx_l) | ntail 由 PMOS tail Vov 决定，vx_l 由 mirror diode |
| **MPTAIL** | \|Vds_MPTAIL\| = VDD − V(ntail) | tail 节点由 PMOS input pair Vgs 决定 |
| **MN3**（diode）| Vds_MN3 = V(vx_l) − 0 = Vgs_MN3 ≈ Vth_n + Vov_MN3 | 永远 saturation（diode 物理不变量）|
| **MN4**（mirror）| Vds_MN4 = V(vx) − 0 = V(vx) | ⭐ vx 由 stage1 mirror match 决定（**自校正**）|
| **MN6**（stage2 NMOS-CS）| Vds_MN6 = V(vout) | vout 由 stage2 KCL 决定（I_MN6 = I_MP6）|
| **MP6**（stage2 PMOS load）| \|Vds_MP6\| = VDD − V(vout) | 同上（cross-determined）|

## ⭐ 范例 1：vx（stage1 输出）跑到 rail / MN6 静态点偏

**这是 2-stage OTA 最常见的失败，跨级耦合的经典案例**（LDO v3 H-005 + H-006 实战）。

### 症状

```
inspect_node('vx'):
  V(vx) = 1.65V  ← 接近 VDD（应该 ≈ 0.9V）

inspect_device(MN6):
  region: triode
  Vds_MN6 = 0.10V        ← vout 也跑低了
  Vdsat_MN6 = 0.20V

inspect_device(MN4):
  region: triode
  Vds_MN4 = V(vx) = 1.65V  ← 太高，但不是 triode；问题在 vx 失控
```

或反方向：vx 跑到 0.1V → MN6 不导通 → vout 拉到 VDD → MP6 triode。

### R1 KVL 反推 — vx 由什么决定？

```
vx 节点 KCL（小信号忽略）:
  I_MP2 = I_MN4 (设计要求)
  
  完美 mirror: I_MN3 = I_MN4 (W/L/m 相同)
                I_MP1 = I_MP2 (W/L/m 相同)
  
  → vx 由 stage1 内部 KCL 自校正 (mirror feedback) 到 V(vx) ≈ V(vx_l)
  → V(vx_l) = Vth_n + Vov_MN3 ≈ 0.6V (MN3 diode)
```

**vx 静态点本应该等于 vx_l**（mirror 强制），≈ 0.6V。但实际跑到 1.65V →
mirror **完全失配**：I_MP2 ≠ I_MN4 → vx 节点没有 KCL 平衡 → 漂到 rail。

### 三条调节路径

**路径 A — 修 stage1 mirror match**（**首选**）：

| 失败原因 | 修复 |
|---|---|
| MN3 / MN4 W/L/m typo | 严格统一 W/L/m（MN3 = MN4）|
| MN4.G ≠ vx_l（误接 vbp 或别处）| MN4.G = vx_l |
| MN3 不 diode-connected（G ≠ D）| MN3.G = MN3.D = vx_l |
| MP1 / MP2 W/L/m typo | 严格统一 |

**路径 B — 修 MN6 静态点（vx 校正后仍偏）**：

如果 vx ≈ 0.6V（正常）但 MN6 仍偏（如 vout 偏低）：
- 调整 MP6 mirror ratio（`m_MP6 / m_MPBIAS`）→ I_MP6 改变 → vout 平衡点改变
- 不要直接调 W_MP6（破坏 mirror）

**路径 C — 修 stage2 输出节点工作点**：

如果 I_MN6 = I_MP6 但 vout 偏（stage2 没设到 VDD/2）：
- 微调 MP6 的 m → 让 I_MP6 = I_MN6 在 vout = VDD/2 时成立
- 或调 MN6 W/L 让 Vov_MN6 + Vth_n = vx 时 I_MN6 落到目标

### R2 镜像约束铁律 ⭐⭐⭐

2-stage 中 **3 个 mirror 关系** 必须保持（缺一不可）：

```
1. Stage1 NMOS mirror:   MN3 (diode master) ↔ MN4 (mirror slave)
   - MN3.G = MN3.D = vx_l, MN4.G = vx_l
   - W/L 严格相同（m 可不同）

2. Stage1 PMOS pair:     MP1 ↔ MP2
   - W/L/m 严格相同（不是 mirror，但是 differential pair matching）

3. Stage2 PMOS bias:     MPBIAS (diode master) ↔ MPTAIL ↔ MP6
   - MPBIAS.G = MPBIAS.D = vbp（diode）
   - MPTAIL.G = MP6.G = vbp
   - I_MPTAIL = ibias × (W_MPTAIL/W_MPBIAS)
   - I_MP6 = ibias × (W_MP6/W_MPBIAS)        ← 通过 m_MP6 调 stage2 电流
```

> ⚠️ **LDO v3 H-005 教训**：agent 误把 MN4.G 接到 vx 而不是 vx_l → mirror
> 不追 master → vx 跑到 rail。**MN4.G 必须 = vx_l**。

### R3 推理路径（agent 应该走的完整链）

```
看到 vx 跑到 rail
  ↓
inspect_node('vx', 'vx_l')
  → vx_l 是否在 0.5-0.7V？(MN3 diode 应该在这范围)
  → 如果 vx_l 也异常 → 问题在 stage1 输入 / tail
  ↓
inspect_device(MN3, MN4)
  → MN3 region = sat? (diode 必须 sat)
  → MN3.G = MN3.D? (diode connectivity)
  → MN4.G = vx_l? (mirror gate)
  ↓
inspect_device(MP1, MP2)
  → 两侧 W/L/m 严格一致？
  → 两侧 region = sat?
  ↓
如果 stage1 mirror OK 但 vx 仍偏 → 看 stage2:
  inspect_device(MN6, MP6)
  → I_MN6 vs I_MP6 是否匹配
  → MP6 mirror ratio 是否对（m_MP6 / m_MPBIAS）
  ↓
propose_knob([
  ('MN3.W', 'sync to MN4.W'),    # mirror match（路径 A1）
  ('MN4.G', 'should be vx_l'),   # mirror gate connectivity（路径 A2）
  ('m_MP6', 'tune'),             # stage2 静态电流（路径 B）
  ('W_MN6', 'tune Vov_target'),  # stage2 静态点（路径 C）
])
```

> ⚠️ **W6+ 实测显示 LLM 常忽略跨级耦合**——直接调 stage2 救 vx，但根因在 stage1。
> chapter 写作必须强调"先验 stage1 mirror，再调 stage2"。

### R4 testbench 验证

修 stage1 mirror 之前先搭最小 testbench 验 stage1 单独工作：

```spice
* tb_stage1_only.sp — stage1 独立验证（无 stage2 / 无 Miller）
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include '../design/stage1_only.cir'
.param VCM = 0.9
Vdd vdd 0 DC 1.8
Vinp vinp 0 DC VCM
Vinn vinn 0 DC VCM
Ibias vdd ibias 20u
X1 vinp vinn vx ibias vdd 0 stage1_5t

.op
.control
  set units = degrees
  run
  print v(x1.vx) v(x1.vx_l)
  print @m.x1.mn3[id] @m.x1.mn4[id] @m.x1.mp1[id] @m.x1.mp2[id]
.endc
.end
```

期望：v(vx) ≈ v(vx_l) ≈ 0.6V，`I_MN3 = I_MN4` (一致)，`I_MP1 = I_MP2` (一致)。

### 不要做（anti-pattern）

- ❌ **跳过 stage1 直接调 stage2 救 vx**：根因在 stage1 mirror，stage2 调
  也只是把问题压回去（DC 看起来对，AC 不平衡仍存在）
- ❌ **加理想电压源压 vx**：违反 self-bias 设计原则，stage1 mirror feedback
  失效后整个 OTA 不闭合
- ❌ **同时改 MN3 和 MN4 W**：mirror 变了但 still mismatch，等同 sizing typo

## ⭐ 范例 2：MN6 / MP6 triode（stage2 输出 vout 跑到 rail）

通常发生在 stage1 vx 正常但 stage2 mirror 不平衡。

### 症状
```
inspect_device(MN6): triode, Vds_MN6 = 0.10V
inspect_node('vout'): V(vout) = 0.1V (跑到 VSS)
```

### R1 KVL 反推
```
V(vout) 由 stage2 KCL 决定：
  I_MN6 = I_MP6
  I_MN6 = (μn·Cox · W_MN6/L_MN6) · (vx − Vth_n)² / 2     ← function of vx
  I_MP6 = ibias × (W_MP6/W_MPBIAS)                        ← mirror，与 vout 无关

  如果 I_MN6 > I_MP6 (在 vout = VDD/2 时) → vout 拉低 → MN6 进 triode → I_MN6 ↓ → 平衡在更低
```

### 调节路径

| 路径 | 怎么做 | 副作用 |
|---|---|---|
| 增大 m_MP6（提 I_MP6 → 平衡点 vout ↑）| stage2 更快收 + power ↑ | 同步 m_MN6 也调（保 gm6 与 PM）|
| 减小 W_MN6 / 增 L_MN6（减 I_MN6）| 平衡点 vout ↑ | gm6 ↓ → PM ↓ |
| 调 vx → 提 I_MN6 → 影响 vout | 不要！vx 由 stage1 自校正 | 破坏 stage1 mirror |

> **R2 镜像约束**：MP6 与 MPBIAS 是 mirror（共 vbp gate）。**调 m_MP6 是
> 调 mirror ratio，可以；但不要调 MP6.W**——会破坏 stage2 mirror precision。

## ⭐ 范例 3：MPTAIL（stage1 tail）进 triode

同 5T-OTA 的 M_tail triode 范例（PMOS 极性翻转）。

```
V(ntail) = Vinp + |Vgs_MP1| = Vinp + (|Vth_p| + |Vov_MP1|)
|Vds_MPTAIL| = VDD − V(ntail) = VDD − Vinp − |Vgs_MP1|

修复：
路径 A — 减小 |Vov_MP1| → V(ntail) ↑ → |Vds_MPTAIL| ↓...等等？
反过来：|Vov_MP1| 减 → V(ntail) 减 → |Vds_MPTAIL| 增（PMOS 视角，对了）
```

详见 `blocks/5t-ota/bias-headroom` 范例 1（NMOS-input → PMOS-input 镜像翻转适用）。

---

## Headroom 设计原则（2-stage OTA 特定）

| # | 原则 | 理由 |
|---|---|---|
| 1 | **VCM = VDD/2 = 0.9V**（@VDD=1.8V）| stage1 PMOS-input 在中等共模 saturate |
| 2 | **vx 静态点 = VDD/2**（mirror match 强制）| stage2 静态工作点正确 |
| 3 | **vout 静态点 = VDD/2**（stage2 KCL 平衡）| 输出双向 swing 对称 |
| 4 | **Vov_stage1 0.15-0.20V**（gm/Id 12-15）| noise 主导，倾向 weak inversion |
| 5 | **Vov_stage2 0.20-0.25V**（gm/Id 8-12）| 大电流 + 大 gm + matching |
| 6 | **L_load_stage1 > L_diff_stage1**（典型 1µm vs 0.5µm）| stage1 gain ceiling + 噪声 |
| 7 | **L_stage2 0.5-1.0 µm**（trade-off ro vs fT）| stage2 gain 30-50 dB 即可 |
| 8 | **I_stage2 = 4-10 × I_stage1** | slew rate + p2 = gm6/CL > 3·GBW |

## 配套工具（W6+ inspect 三件套）

| 工具 | 用途 | 何时调 |
|---|---|---|
| `inspect_device(<device>)` | Vds / Vdsat / region / margin | dc_snapshot 显示某 device 不 sat 时 |
| `inspect_node(<node>)` | 节点电压由谁决定（driver 反推）| vx / vout 跑到 rail 时先查谁决定 |
| `propose_knob(<target>, <direction>)` | 给可调旋钮排序 | 推理完 R1/R2 后挑修复路径 |

## When to load this chapter

- `dc_snapshot` 显示 vx 或 vout 接近 rail（不在 VDD/2 ±200mV 内）
- stage1 / stage2 任一管 region != saturation
- 设计推进到 sizing 阶段，需要分配 stage1 vs stage2 vs Miller 三块预算
- vx 偏后想直接调 stage2（**先停！见范例 1 R3 推理链**）

## Related

- **W6+ R1-R4 推理铁律**：`skill: device-sizing` 通用 sizing 流程（pre-sim / post-sim）
- **信号路径反推**：`skill: signal-tracing`
- **stage1 5T 内部约束**：`blocks/5t-ota/bias-headroom`（PMOS-input 镜像版本）
- **stage2 CS 物理 + bias**：`blocks/base-cells/common-source`
- **mirror 物理 + matching**：`blocks/base-cells/current-mirror`
- W6+ sizing 范例（W6+ sizing-2 P0-D-H 5 cell sizing-reasoning chapter）
