---
chapter: bias-headroom
parent: 5t-ota
summary: |
  5T-OTA 每个器件的 Vds / Vdsat 物理约束 + R1 KVL 反推 + R2 镜像约束 +
  失稳器件调整顺序。配 W6+ inspect_device / inspect_node / propose_knob
  三件套 + device-sizing R1-R4 推理铁律使用。
tokens: ~1500
prerequisite_chapters:
  - reference-design
related_skills:
  - device_sizing
  - signal_tracing
related_knowledge:
  - blocks/base-cells/differential-pair
  - blocks/base-cells/current-mirror
---

# 5T-OTA Bias & Headroom Reasoning

> 通用 vds-vdsat 推理范式见 `skill: device-sizing`（W6+ R1-R4 铁律）。
> 本章节给的是 **5T-OTA 拓扑特有的器件 Vds / Vdsat 物理约束**与失稳调整顺序。
> 工具：`inspect_device(<device>)` 看 Vds/Vdsat margin；`inspect_node(<node>)` 看节点电压由谁决定；`propose_knob(<target>, <direction>)` 给可调旋钮排序。

## Headroom Budget（VDD = 1.8V 典型）

5T-OTA 信号通路堆叠：
- **VDD → Vout 路径**：1 个 PMOS（M4）
- **Vout → VSS 路径**：2 个 NMOS 堆叠（M2 + M5）

每段必须 Vov + 50mV 裕度才 saturation。

| 路径 | 器件堆栈 | 最小 Vds 占用 | swing 占比 |
|---|---|---|---|
| Vout 上限 | VDD - \|Vds_M4\| | \|Vov_M4\| + 50mV ≈ 0.35V | Vout_max ≈ VDD - 0.35V = 1.45V |
| Vout 下限 | Vds_M2 + Vds_M5 | (Vov_M2 + 50mV) + (Vov_M5 + 50mV) ≈ 0.45V | Vout_min ≈ 0.45V |
| **总 swing** | — | — | **≈ 1.0V**（@VDD=1.8V） |

⚠️ **降 VDD 时 5T 第一个撞墙**：VDD ≤ 1.2V 时 Vout 下限 + Vout 上限 占满，剩余 swing < 0.4V，应换 cascode-free 拓扑或 wide-swing 镜像变体。

## 每个器件的 Vds 物理因果（KVL 反推）

| 器件 | Vds 公式（KVL）| 调节路径 |
|---|---|---|
| **M1, M2**（NMOS input pair）| Vds_M1 = V(vd_l) - V(tail)<br>Vds_M2 = V(out) - V(tail) | M1.Vds 由 mirror node 决定；M2.Vds 由 vout 决定（输出闭环时 ≈ VCM - V(tail)） |
| **M3**（PMOS diode 镜像 master） | Vds_M3 = V(vd_l) - VDD<br>\|Vds_M3\| = \|Vsg_M3\| = Vth_p + Vov_M3 | **永远 saturation**（diode-connected 物理不变量） |
| **M4**（PMOS mirror output） | \|Vds_M4\| = VDD - V(out) | vout 高时 \|Vds_M4\| 小可能 triode（限 Vout_max） |
| **M5**（NMOS tail current source）⭐ | **Vds_M5 = V(tail) = Vinp - Vgs_M1** | 不是 M5 自己决定的——见范例 1 |

## ⭐ 范例 1：M5（tail）进 triode 怎么办？

**这是 5T-OTA 最常见的 bias 失稳，也是 R1-R4 推理的经典案例。**

### 症状

```
inspect_device(M5):
  region: triode
  Vds_M5 = 0.08V
  Vdsat_M5 = 0.20V
  margin = -120 mV  ← 负值，已进 triode
```

### R1 KVL 反推 — Vds_M5 由什么决定？

```
Vds_M5 = V(tail) - V(vss) = V(tail)
V(tail) = Vinp - Vgs_M1 = Vinp - (Vth_n + Vov_M1)
```

**tail 节点电压不是 M5 自己决定的，是 input pair M1 决定的。**

调用 `inspect_node('tail')` 验证：tail 节点的 driver 是 M1.S（input pair source），不是 M5.D。

### 两条调节路径

**路径 A — 提升 V(tail)**（让 M5 有更多 Vds）：
- 需要降低 Vgs_M1 = 降低 Vov_M1
- = 增大 W_DIFF / L_DIFF（gm/Id ↑ → Vov ↓）
- ⚠️ 增大 W_DIFF 会增 mirror node 寄生电容 → 影响 PM（见 ac-stability.md）

**路径 B — 降低 Vdsat_M5**（让 M5 在低 Vds 下仍 saturate）：
- 需要降低 Vov_M5
- ⚠️ **不能直接调 M5 的 W/L**！见下面 R2 铁律

### R2 镜像约束铁律 ⭐⭐⭐

M5 是 Mbias 镜像出来的电流源：
```
Mbias.G ─┬─ M5.G   (mirror Vgs 同步)
         └─ ibias  (mirror reference)
```

**直接调 M5.W/L 的后果**：mirror ratio 变化 → Itail 变化 → 整个 OTA bias 全乱。

**正确做法**（CMOS 电流复制范式）：
1. **先调 Mbias** 的 W/L（控制 Vov_Mbias = Vov_M5）
2. M5 设成与 Mbias **同 W/L**（或 m 倍数关系，保持 Vov 一致）
3. 镜像后 M5.Vov 自动跟着 Mbias

> **CMOS 设计本质**：电流复制——本管子参数不直接调，是通过 bias 偏置管调好了再镜像过来。**这是 LLM 最常忽略的物理约束**，写 5T-OTA sizing 时必须显式遵守。

### R3 推理路径（agent 应该走的完整链）

```
看到 M5 triode
  ↓
inspect_device(M5)
  → Vds_M5 / Vdsat_M5 / region
  ↓
inspect_node('tail')
  → V(tail) driver = M1.S（不是 M5.D！）
  ↓
KVL: V(tail) = Vinp - Vgs_M1 → Vds_M5 = V(tail)
  ↓
问 1: Vinp 可调？（spec 决定 VCM，多数不可调）
问 2: Vgs_M1 可调？= 改 input pair sizing
问 3: Vdsat_M5 可降？= 改 Mbias sizing（R2 铁律）
  ↓
propose_knob([
  ('Mbias.W', 'decrease'),    # 减 W → Vov 增？错！需先想清方向
  ('Mbias.L', 'increase'),    # 增 L → Vov 增 → Vdsat_M5 增（错）
  ('M1.W', 'increase'),       # 增 W → Vov_M1 减 → V(tail) 增（对）
  ...
])
```

⚠️ **W6+ v11 实测显示 LLM 常忽略 R2 镜像约束**——直接调 M5 的 W/L。chapter 写作必须强调"CMOS 设计要通过 bias 调"。

### R4 testbench 验证

调好 Mbias 之前先搭最小 testbench 验证 Vov 落点：

```spice
* tb_check_bias.sp — Mbias Vov 落点扫描
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.param IBIAS = 10u
.param W_bias = 10u
.param L_bias = 0.5u

Vdd vdd 0 DC 1.8
Ibias vdd ibias DC IBIAS
Mbias ibias ibias 0 0 nch W=W_bias L=L_bias

.dc W_bias 5u 30u 1u
.meas dc Vov_bias find @m.mbias[vdsat] when ...
.end
```

确定 W_bias 让 Vov_bias = 目标值 → 然后 M5 用同 W/L → 镜像后 M5.Vov 自动到位。

### 不要做（anti-pattern）

- ❌ **直接增大 W_TAIL / W_M5**：破坏 mirror，所有 branch 电流错乱
- ❌ **增大 ibias 想"提升 Vds_M5"**：改变所有 branch 电流，新增问题（gain / power 都影响）
- ❌ **减小 W_DIFF 想降 V(tail)**：kills gm_M1 → gain 直接掉
- ❌ **接受 M5 在 triode**："反正 V(tail) 还在变"——triode 的 M5 不是恒流源，gain / CMRR / PSRR 全垮

## ⭐ 范例 2：M4（mirror output）进 triode

### 症状
```
inspect_device(M4):
  region: triode
  |Vds_M4| = 0.15V
  |Vdsat_M4| = 0.25V
```

通常发生在 V(out) 接近 VDD（高输出摆幅 / 大 VCM）。

### R1 KVL 反推
```
|Vds_M4| = VDD - V(out)
```
V(out) → VDD 时 |Vds_M4| → 0 → triode。这是 5T-OTA 输出 swing 上限的物理来源。

### 调节路径

| 路径 | 怎么做 | 副作用 |
|---|---|---|
| 降低 V(out) target | 改 VCM 0.9V → 0.7V（如 spec 允许） | 影响下行 swing margin |
| 降低 \|Vov_M4\| | 增大 W_LOAD / L_LOAD | mirror node cap ↑ → PM ↓ |
| 接受 swing 限制 | 标 Vout_max = VDD - \|Vov_M4\| - 50mV | 缩小 spec |

### R2 镜像约束（M3/M4 PMOS mirror）

M3 是 diode-master，M4 是 mirror output。**两者必须同 W / L / m**。调 W_LOAD 时 M3 + M4 一起改（不能只改一个）。

⚠️ V3 LDO 实战教训（H-006）：曾把 M4.G 接外部 vbp 而不是 vd_l → mirror 不追 M3 → DC offset 大。**M4.G 必须 = vd_l**（V4 reference-design.md 已强调）。

---

## Headroom 设计原则（5T-OTA 特定）

| # | 原则 | 理由 |
|---|---|---|
| 1 | **VCM = VDD/2 = 0.9V**（@VDD=1.8V） | 给 M2+M5 留 ≈ 0.45V，给 M4 留 ≈ 0.9V，对称 swing |
| 2 | **Vov ≤ 0.25V**（多数 device） | 否则 swing 太紧；总 Vov 占用 < 0.5V |
| 3 | **Vov ≥ 0.1V**（除 input pair） | weak inversion gm/Id > 18 → gm/W 小 → gm 不够 |
| 4 | **input pair Vov 0.1-0.15V**（gm/Id 12-15） | 噪声主导，倾向 weak inversion |
| 5 | **mirror load + tail Vov 0.2-0.3V**（gm/Id 8-12） | matching + headroom |
| 6 | **PMOS load L > input pair L**（典型 1µm vs 0.5µm） | gain ceiling + 噪声衰减（gm3 << gm1） |

## 配套工具（W6+ inspect 三件套）

| 工具 | 用途 | 何时调 |
|---|---|---|
| `inspect_device(<device>)` | Vds / Vdsat / region / margin | dc_snapshot 显示某 device 不 sat 时 |
| `inspect_node(<node>)` | 节点电压由谁决定（driver 反推） | 想"提升 V(tail)"时先查谁决定 |
| `propose_knob(<target>, <direction>)` | 给可调旋钮排序 | 推理完 R1/R2 后挑修复路径 |

## When to load this chapter

- `dc_snapshot` 显示某 device 不在 saturation 或 margin < 50mV
- 设计推进到 sizing 阶段，需要分配 Vov budget
- 调 sizing 撞 R2 镜像约束（多次试 W/L 都没改对——典型信号）

## Related

- **W6+ R1-R4 推理铁律**：`skill: device-sizing` 通用 sizing 流程（pre-sim / post-sim）
- **信号路径反推**：`skill: signal-tracing`
- input pair 物理细节：`blocks/base-cells/differential-pair/index`
- mirror 物理细节：`blocks/base-cells/current-mirror/basic`
- W6+ sizing 范例（W6+ sizing-2 P0-D-H 5 cell sizing-reasoning chapter）
