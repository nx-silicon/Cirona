---
chapter: bias-headroom
parent: three-stage-ota
summary: |
  Three-stage opamp 拓扑特有的 Vds/Vdsat 物理约束 + R1 KVL 反推 + R2 镜像
  约束 + 跨级耦合（v1_out → v2_out → vout 静态点链式决定）。核心范例：
  Stage1 v1_out 跑 rail（同 2-stage）+ Stage2 v2_out 失锁（中间级独有）+
  Stage3 输出 vout 偏（输出极性反相）。
tokens: ~1700
prerequisite_chapters:
  - reference-design
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/5t-ota
  - blocks/base-cells/common-source
  - blocks/base-cells/current-mirror
---

# Three-Stage Opamp Bias & Headroom Reasoning

> 通用 vds-vdsat 推理范式见 `skill: device-sizing`（W6+ R1-R4 铁律）。
> Stage1 5T 内部约束完全适用 `blocks/5t-ota/bias-headroom`。
> 2-stage 跨级耦合（v1_out 跑 rail）见 `blocks/two-stage-ota/bias-headroom`。
> 本章节给的是 **3-stage 拓扑特有**的：(1) 3 stage 跨级耦合（v1_out → v2_out
> → vout 链式）；(2) 反相极性叠加（3 stage 总极性 = + - - = +）；(3) 失稳
> 调整顺序。

## 跨级 Headroom Budget（VDD = 1.8V 典型）

3-stage 与 2-stage 关键差异：**多一级 stage2，跨级耦合链更长**。

### Stage 1（5T 5T-style）

参照 `blocks/5t-ota/bias-headroom`——5T 内部约束完全适用：
- v1_out 静态 ≈ V(v1_n) ≈ Vth_n + Vov_M3 ≈ 0.6V（NMOS-input + PMOS load）
- 注意 V4 reference 用 NMOS-input，所以 v1_out 静态由 NMOS+PMOS mirror 平衡决定

> **3-stage Stage1 v1_out 静态点与 2-stage 一样由 mirror match 决定**——
> Stage1 mirror imbalance 会直接传递到 Stage2 input。

### Stage 2 (NMOS-CS, 反相)

```
MN3 G=v1_out, S=vss, D=v2_out
MN3 静态电流 = µn·Cox·W/L · (v1_out - Vth_n)² / 2

MP3 是 PMOS current source (G=vbias_p)：固定 I_load
v2_out 是 KCL 平衡点：Id_MN3 = Id_MP3
  → v1_out 决定 Id_MN3 → v2_out 落点
```

**关键事实**：v2_out 不由 W/L 直接决定，由**Stage1 v1_out 静态 + MP3 mirror
ratio**决定。**Stage1 偏 → v1_out 偏 → MN3 Id 偏 → v2_out 跑 rail**。

### Stage 3 (PMOS-CS output, 反相)

```
MP4 G=v2_out, S=vdd, D=vout
MP4 静态电流 = µp·Cox·W·m/L · (VDD - v2_out - |Vth_p|)² / 2

MN4 是 NMOS current source (G=vbias_n)：固定 I_sink
vout 是 KCL 平衡点：Id_MP4 = Id_MN4
  → v2_out 决定 Id_MP4 → vout 落点
```

**最终 vout 静态由 cascade（v1_out → v2_out → vout）决定**。

### 反相极性总账

```
3-stage 极性：
  Stage1 (5T)    : 非反相 (vinp ↑ → v1_out ↑)
  Stage2 (NMOS-CS): 反相 (v1_out ↑ → MN3 sinks more → v2_out ↓)
  Stage3 (PMOS-CS): 反相 (v2_out ↓ → MP4 sources more → vout ↑)

总极性：vinp ↑ → vout ↑ (3 stage: + → − → −  =  +)
       vinn ↑ → vout ↓

→ 标准 negative feedback：vout 接 vinn 端
   loop sign: vout - vinn → vinp 反向 ... → vout - vinn 减小 → 锁定
```

⚠️ **3 stage 反相极性叠加错** → loop sign 反 → DC latch 错误分支。**写
3-stage 网表前画小信号 loop sign 验证**。

## 每个器件的 Vds 物理因果（KVL 反推）

| 器件 | Vds 公式（KVL）| 调节路径 |
|---|---|---|
| Stage 1 各管 | 同 5T-OTA / 2-stage class-A | 见 `blocks/5t-ota/bias-headroom` |
| **MN3**（Stage2 NMOS-CS）| Vds_MN3 = V(v2_out) | 由 v1_out + MP3 mirror 决定（KCL 平衡点）|
| **MP3**（Stage2 PMOS load）| \|Vds_MP3\| = VDD - V(v2_out) | 同上对侧 |
| **MP4**（Stage3 PMOS-CS）| \|Vds_MP4\| = VDD - V(vout) | 由 v2_out + MN4 决定 |
| **MN4**（Stage3 NMOS sink）| Vds_MN4 = V(vout) | 同上对侧 |

## ⭐ 范例 1：Stage1 v1_out 跑 rail（跨级耦合源头）

> 同 2-stage class-A 范例 1。v1_out 静态偏 → Stage2/Stage3 全错。

### 症状
inspect_node('v1_out'): V(v1_out) ≈ 0.2V or 1.65V（应 ≈ 0.6-0.9V）；
Stage2 v2_out 跟随偏；vout 跑 rail。

### 修复路径
**路径 A — 修 Stage1 mirror match**（首选）：
- MP1 / MP2 W/L typo → 校
- MN1 / MN2 W/L typo → 校
- MP1.G ≠ D（diode 错）→ 校 G=D=v1_n
- MP2.G ≠ v1_n（mirror 错）→ 校 G=v1_n

详见 `blocks/two-stage-ota/bias-headroom` 范例 1（跨级耦合最常见根因）。

## ⭐ 范例 2：Stage2 v2_out 失锁（中间级）

> **3-stage 特有**：2-stage 没有 stage2 输出节点（直接到 stage3 = 输出），
> 3-stage 中间 v2_out 是新失锁节点。

### 症状
inspect_node('v1_out'): V(v1_out) ≈ 0.7V OK
inspect_node('v2_out'): V(v2_out) ≈ 0.1V or 1.7V（跑 rail）
inspect_device(MN3 or MP3): triode

### R1 KVL 反推
```
v2_out 由 KCL 决定:
  Id_MN3 = Id_MP3 (设计要求)
  Id_MN3 = µn·Cox·W·m/L · (v1_out - Vth_n)² / 2  ← 由 v1_out 决定
  Id_MP3 = ibias × (W_MP3 · m_MP3) / (W_MP_bias · m_MP_bias)  ← mirror，与 v2_out 无关

v2_out 不平衡：
  - 如果 Id_MN3 > Id_MP3 (太强 stage1 输出 v1_out 高于设计) → v2_out 拉低 → MN3 进 triode
  - 如果 Id_MN3 < Id_MP3 (v1_out 低) → v2_out 拉高 → MP3 进 triode
```

### 三条调节路径
**路径 A — 验证 Stage1 v1_out 静态**（首选，根因 80% 在这）：
- v1_out 偏 → Stage2 mirror 不平衡 → 见范例 1

**路径 B — 调 MP3 mirror ratio**（stage2 内部）：
- m_MP3 / m_MP_bias 不对 → I_MP3 与 I_MN3 不匹配 → v2_out 平衡点偏
- 校 mirror m 比例

**路径 C — 调 MN3 sizing**（最后选择）：
- 增大 MN3 W·m → gm2 ↑ → stage2 gain ↑（不直接修 v2_out 静态）
- 减小 MN3 W·m → gm2 ↓ → 但 KCL 平衡可能改善

### R2 镜像约束（Stage2）

```
1. Stage2 PMOS mirror: MP_bias diode → MP3
   要求 MP_bias W/L = MP3 W/L (m 倍数控制电流)
   
2. NMOS bias chain: MN_bias → MN_bias2 → vbias_p (复杂!)
   MN_bias 与 MN_bias2 W/L 严格相同
```

## ⭐ 范例 3：Stage3 vout 偏（输出极）

### 症状
inspect_node('v1_out', 'v2_out'): 都 OK
inspect_node('vout'): V(vout) ≈ 0.1V or 1.7V

### 物理因果链
```
vout 由 KCL 决定:
  Id_MP4 = Id_MN4 (设计要求)
  Id_MP4 = µp·Cox·W·m/L · (VDD - v2_out - |Vth_p|)² / 2  ← 由 v2_out 决定
  Id_MN4 = ibias × (W_MN4 × m_MN4) / (W_MN_bias × m_MN_bias)  ← mirror
```

### 修复路径
| 根因 | 修复 |
|---|---|
| Stage2 v2_out 偏（cascade）| 见范例 2 |
| MN4 mirror ratio 错 | 校 m_MN4 |
| MP4 W·m 偏离设计 | 校 W·m_MP4 |

## ⭐ 范例 4：Output stage triode（rail-to-rail 极限）

同 class-AB 范例 3（stage3 PMOS-CS 接近 VDD 时 triode）：
- vout → VDD → \|Vds_MP4\| → 0 → triode
- vout → 0V → Vds_MN4 → 0 → triode

物理边界：vout_max ≈ VDD - \|Vov_MP4\| - 50mV；vout_min ≈ Vov_MN4 + 50mV。
要纯 rail 必须换 class-AB output stage（变成 class-AB 3-stage variant，超本章）。

## R2 镜像约束铁律（**3-stage 多重 mirror**）

3-stage 中 **6 个 mirror 关系** 必须保持：

| # | mirror | 用途 |
|---|---|---|
| 1 | Stage1 PMOS mirror: MP1 ↔ MP2 | Stage1 mirror（同 5T）|
| 2 | Stage1 NMOS bias: MN_bias → MN_tail | tail mirror |
| 3 | Stage1 NMOS bias: MN_bias → MN4 | Stage3 sink mirror |
| 4 | N-to-P bias: MN_bias → MN_bias2 → MP_bias | NMOS to PMOS bias 转换 |
| 5 | Stage2 PMOS mirror: MP_bias → MP3 | Stage2 load |
| 6 | bias chain N/P symmetry | 整体 bias 一致 |

> **R2 铁律**（3-stage 强化版）：bias chain 跨 6 个 mirror 必须严格 W/L 同步
> （m 不同 OK）；任一 mirror 失配让某 stage 偏 → cascade 全错。

## Headroom 设计原则（3-stage 特定）

- VCM = VDD/2 = 0.9V（@VDD=1.8V）：Stage1 mirror match 强制
- v1_out 静态 ≈ 0.6-0.9V（取决于 5T 类型；NMOS-input 默认 ≈ V(v1_n) ≈ 0.6V）
- v2_out 静态 ≈ VDD/2（Stage2 KCL 平衡）
- vout 静态 ≈ VDD/2（Stage3 KCL 平衡）
- 3 stage Vov 均 0.15-0.25V
- 6 mirror 严格 W/L 同步（m 不同 OK）
- Stage1 / Stage2 / Stage3 长 L 选择（gain 优先）：L=2µm/1µm/0.5µm
- 反相极性：3 stage 总 sign = + (vinp port)；feedback 接 vinn

## 配套工具

`inspect_device(stage_i)` 看 region；`inspect_node('v1_out', 'v2_out', 'vout')`
跨级 cascade；`propose_knob` 排旋钮。详见 `skill: device-sizing` W6+ 通用 sizing 流程。

## When to load this chapter

跨级 v1_out / v2_out / vout 任一节点偏 → 跨级耦合诊断必读。

## Related

- `skill: device-sizing` W6+ 通用 sizing 流程 + R1-R4 铁律
- `blocks/5t-ota/bias-headroom` Stage1 5T 内部
- `blocks/two-stage-ota/bias-headroom` 2-stage 跨级耦合（v1_out 跑 rail）
- `blocks/base-cells/common-source` Stage2/3 CS 物理
- `sizing-typical.md` 4 阶段 sizing 顺序
