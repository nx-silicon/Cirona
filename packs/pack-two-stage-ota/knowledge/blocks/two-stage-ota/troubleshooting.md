---
chapter: troubleshooting
parent: two-stage-ota
summary: |
  2-stage OTA 系统级失败模式 + 物理因果链 + 根因可能性表（不写流程，
  诊断顺序由通用 systematic-debugging skill 提供）。涵盖 PM 紧 / RHP zero
  / gain 低 / vx rail / MN6 triode / slew rate 慢 / 大 CL 失稳。
tokens: ~1600
prerequisite_chapters:
  - architecture
  - bias-headroom
  - ac-stability
related_skills:
  - systematic_debugging
  - signal_tracing
  - device_sizing
---

# Two-Stage OTA Troubleshooting

> 通用诊断顺序见 `skill: systematic-debugging`（4-phase）+ `skill: signal-tracing`
> （信号反推）。本章节给的是 **2-stage 拓扑特有**的失败模式 + 物理因果链 +
> 根因可能性表。**device 不 saturation 触发的失败**（如 vx rail / MN6 triode）
> 见 `bias-headroom.md` —— 本章不重复 R1/R2 推理细节，只列根因表 + 链接。
> **AC 极点 / Miller 补偿失稳** 见 `ac-stability.md`。

## ⭐ 优先诊断分支

| 主症状 | 先看模式 |
|---|---|
| DC OP triode_count ≥ 2 + vout 飘到 rail (≈VDD 或 ≈VSS) | 模式 9（DC OP 不收敛 → 多根因排查） ⭐ |
| DC OP triode（vinp/vinn 在 Vcm_in 附近）+ tail 进 triode | 模式 3 / `bias-headroom.md` |
| AC PM < 50° | 模式 1 |
| DC gain < 80 dB | 模式 2 |
| vx ≈ 0V or rail | 模式 3 |
| slew rate 慢 | 模式 4 |
| 大 CL 失稳 | 模式 5 |

**铁律**：DC OP 失败时**先确认是否用了 closed-loop 模板**（推荐主用 `tb_dc_closed.sp`，
DC closed via Rfb=1G/10Meg + Cfb=1F）。**high-gain (≥60dB) two-stage OTA open-loop
DC 不可靠** —— 即使 VINP=VINN 数学强制，stage1/stage2 mismatch 被开环增益放大就
飘 rail，这是物理规律不是 sizing bug。closed-loop 失败再去查 sizing / mirror match /
Rfb 取值。

## 失败模式 1：PM < 50°（**2-stage 最常见失败**）

**症状**：tran 仿真 ringing，AC PM 测得 < 50°。

> 这是 2-stage OTA 实战最常见的失败——Miller 补偿三件套（Cc / Rz / gm6）
> 互相耦合，任何一个偏离设计点 PM 都崩。

### 物理因果链

见 `ac-stability.md` 模式 1-3。本章只列根因表 + 修复路径。

### 根因可能性表

| 可能根因 | 验证 | 修复 |
|---|---|---|
| **Cc 太小**（最常见，pole splitting 不足）| Cc / CL < 0.2 | Cc ↑ 30% 步长（CCOMP = 1.5p → 2p）|
| **Rz 偏离 1/gm6**（RHP zero 没消）| 算 gm6 实测，看 Rz × gm6 ≈ 1 | Rz = 1/gm6（用实测 gm6，不是 sizing 估算）|
| **gm6 < 12 × gm1**（p2 不够远）| 算 gm6 / gm1 比例 | m_stage2 ↑ + I_stage2 ↑ |
| **Cc 接错节点**（vx_l ↔ vout 而非 vx ↔ vout）| 网表检查 Cc 两端 | Cc 一端必须 vx（高增益节点），不是 vx_l |
| **stage1 mirror 不平衡**（vx 偏 → gm6 实际值漂移）| `inspect_node('vx')` 是否 ≈ VDD/2 | 见 `bias-headroom.md` 范例 1 修 stage1 mirror |
| **device 不 sat**（PM 数字假象）| `dc_snapshot` region | 见 `bias-headroom.md` |
| testbench `set units = degrees` 漏 | 看 PM 数值是否在 -180 ~ 180 度 | 加 `set units = degrees` |

### Anti-pattern（不要做）

- ❌ **盲调 Cc 大幅度（× 10）想救 PM**：会 kills GBW（GBW = gm1/Cc，Cc × 10 → GBW ÷ 10）
- ❌ **加第二个 Cc 想"双重补偿"**：物理上 2-stage 只需要一对 Cc / Rz
- ❌ **直接加 Rload 想阻尼 ringing**：RC 滤波器隐藏问题，AC 测出来仍不稳
- ❌ **用 stage1 5T 的 fix 救 stage2 失稳**：跨级耦合 ≠ 单级问题

---

## 失败模式 2：DC gain 低（< 80 dB）

**症状**：simulate AC 测出 gain < 80 dB（spec target 80-100 dB）。

### 物理因果链
```
gain = gm1 × ro1 × gm6 × ro6
                ↑       ↑
              stage1  stage2
              (30-50dB)(40-60dB)
```

任一级弱 → 总 gain 弱。**2-stage gain ceiling**：每级 ~50 dB → 总 ~100 dB。

### 根因可能性表

| 可能根因 | 验证 | 物理原因 | 修复 |
|---|---|---|---|
| **L_load_stage1 短**（最常见）| `op_point_check` 看 ro_MN3 / ro_MN4 | ro ∝ L | L_LOAD 0.5 → 1 µm |
| L_diff_stage1 短 | `op_point_check` 看 ro_MP1 / ro_MP2 | ro ∝ L | L_DIFF 0.5 → 0.7 µm |
| L_stage2 短 | `op_point_check` 看 ro_MN6 / ro_MP6 | ro ∝ L | L_STAGE2 0.5 → 1.0 µm |
| **stage2 gm6 不足**（也降总 gain）| `op_point_check` 看 gm6 | gm6 ∝ √(W·Id/L) | m_stage2 ↑ |
| **某 device 不 sat**（致命）| `dc_snapshot` region | triode → ro 几乎为 0 | 见 `bias-headroom.md` |
| stage1 mirror 不平衡 | vx 不在 VDD/2 | I_MN3 ≠ I_MP1 → mirror feedback 失效 | 见 `bias-headroom.md` 范例 1 |

### Anti-pattern

- ❌ **加 stage3 想救 gain**：变成三级了，要重新 Miller 补偿（双 Cc），不在本章
- ❌ **加 cascode in stage1 救 gain**：可以，但是 architecture variant 改造
  （见 `architecture.md` Variant 2），需要重新 sizing
- ❌ **盲增 ibias 想提 gain**：gm × ro 在 strong inversion 几乎不变（gm ↑ ro ↓ 抵消）；
  且影响所有 mirror ratio

### 边界判断（spec 不可达时）

gain target > 100 dB → 2-stage **物理上限**。直接换：
- 三级 OTA + 双 Miller（独立类别，复杂度大幅 ↑）
- gain-boosted 2-stage（auxiliary OTA 加 cascode bias）

---

## 失败模式 3：vx 跑到 rail / MN6 triode

> **2-stage 跨级耦合的经典失败**（LDO v3 H-005 实战）。

详见 `bias-headroom.md` 范例 1 + 范例 2。简短根因表：

| 根因 | 修复 |
|---|---|
| stage1 NMOS mirror typo（MN3.W ≠ MN4.W 或 MN4.G ≠ vx_l）| stage1 mirror 严格 match |
| stage1 PMOS pair typo（MP1.W ≠ MP2.W）| 严格 match |
| stage2 mirror ratio 错（m_MP6 / m_MPBIAS）| 调 m_MP6（不调 W_MP6！）|
| Cc 接错（vx_l ↔ vout 而非 vx ↔ vout）| Cc 一端必须 vx |

⚠️ **跨级耦合铁律**：vx 偏时**先验 stage1 mirror，不要直接调 stage2**——
根因在前级 mirror match。

---

## 失败模式 4：slew rate 慢（大信号 settling）

**症状**：tran 阶跃响应慢（小信号 GBW 正常但大信号 settling 慢）。

### 物理因果链
```
正向 slew (vout 上升): SR+ = I_MP6 / CL          ← MP6 push-up
负向 slew (vout 下降): SR- = (I_MN6_max − I_MP6) / CL ← MN6 sink + MP6 push 反差

SR = min(SR+, SR-)
通常 SR− 主导（class-A 输出，stage2 最大 sink 由 MN6 决定）
```

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| I_stage2 太低（同 stage1 量级）| Itail_stage2 vs Itail_stage1 | I_stage2 = 4-10 × I_stage1（增 m_stage2 + m_MP6 同步）|
| CL 大 | 看 testbench .param CL | 校 testbench；如真实负载 → 加 stage2 m |
| Stage1 limited（大信号 vx 摆不开）| 看 vx tran 波形 | 增 I_stage1 |

### Anti-pattern

- ❌ **加 boost cap 想救 slew**：只在 push-up / pull-down 短暂工作，引入新极点
- ❌ **靠增大 W 不增 I 救 slew**：gm 大但 SR = I/CL 不变（slew 与 I 直接成正比）

---

## 失败模式 5：driving 大 CL 失稳（CL > 10pF）

**症状**：CL 小（1-5pF）时 PM 60°+，CL 增大到 10-20pF 时 PM < 50°。

### 物理因果链
```
p2 = gm6 / (2π · CL)
CL ↑ → p2 ↓ → 与 GBW 距离缩短 → PM ↓
```

**2-stage 与单级 OTA 反向**：单级 CL ↑ 是 PM ↑（更稳），2-stage CL ↑ 是 PM ↓
（更不稳）。物理本质：单级 CL 决定主极点，2-stage CL 决定次极点。

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| **gm6 / CL 比例 < 3·GBW**（必然失稳）| 算 gm6/CL 与 GBW | m_stage2 ↑ |
| Cc 没同步增大 | Cc / CL ratio 偏离 0.25-0.30 | Cc ↑ 同步 CL（保 ratio）|

### Anti-pattern

- ❌ **接受 CL 任意大**：物理上 2-stage 受 gm6/CL 限制；CL 大用 class-AB 输出
- ❌ **靠减 GBW 救 PM**：合法但 GBW 损失太大；优先 m_stage2 ↑

---

## 失败模式 6：Cc 误接 vx_l ↔ vout（**LDO v3 H-005 镜像症状**）

**症状**：DC 看似正常（vx ≈ VDD/2），但 AC PM 远低于设计值；GBW 明显偏低。

### 物理因果链
```
Cc 应该跨 stage2:  vx (stage1 高 gain 输出) → vout (stage2 输出)
误接：            vx_l (stage1 diode 端，低 gain) → vout

vx_l 是 mirror 的 reference（diode 端），其 swing 远小于 vx。
Cc 接 vx_l ↔ vout → Miller effect 几乎消失（A_stage2 看到的不是 vx_l）
```

### 修复
```
检查网表：CC1 ncc vout CCOMP 中 ncc 来源应是 RZ1 vx ncc RZ
                                      ↑
                              一端必须 vx 不是 vx_l
```

---

## 失败模式 7：testbench `set units = degrees` 漏 → PM 178° 假象

**症状**：AC 测 PM = 178° 看起来"非常稳"，但实际等同 3°（不稳）。

### 修复
testbench `.control` 块必含 `set units = degrees`。详见 `reference-design.md`
testbench 模板 + `simulators/ngspice/measurements`。

---

## 失败模式 8：Stage 2 输入 vx 不在 VDD/2（mirror imbalance）

详见 `bias-headroom.md` 范例 1。3 类常见 connectivity bug：

| Bug | 症状 | 修复 |
|---|---|---|
| MN3 不 diode（G ≠ D）| stage1 完全失败，vx 卡 rail | MN3.G = MN3.D = vx_l |
| MN4.G 接 vx 而非 vx_l | mirror 不追 master | MN4.G = vx_l |
| MP1 / MP2 W/L typo | systematic offset | 严格统一 |

---

---

## 失败模式 9：DC OP 不收敛 / vout 飘 rail（多根因）⭐

**症状**：
- DC OP `_op_state.json` 显示 `triode_count ≥ 2`（多个 device 进 triode）
- vout ≈ VDD 或 VSS（钉死，无法收敛到 ≈ VDD/2）
- vx (Stage1 输出) ≈ 0V 或 ≈ VDD
- 多个 device Vds ≈ 0V

### 物理解释

two-stage OTA 是高增益运放（80-100dB）。**open-loop DC 模板**（VINP=VINN 强制）下，
stage1 上下电流任何不匹配（mismatch + 数值精度）都会被开环增益放大到 vout 飞 rail；
**closed-loop DC 模板**（Rfb=1G/10Meg + Cfb=1F）下也会失败 —— 但失败原因更接近真实
sizing 问题，因为反馈环路把 vout 拉回 Vcm 附近，是 sizing/mirror match/Rfb 取值
真有问题才发散。

### 根因可能性表（按发生频率排）

| 可能根因 | 验证 | 修复 |
|---|---|---|
| **当前用的是 open-loop 模板**（high-gain 不可靠）| 看 testbench 是否含 `Rfb vout vinn ...` + `Cfb vinn 0 ...` | **换成 `tb_dc_closed.sp`**（DC closed via Rfb=1G/10Meg + Cfb=1F），与 `tb_ac_gain_bw.sp` 共用激励 |
| Stage1 mirror imbalance（MN3.W ≠ MN4.W / MN4.G 接错节点）| 看 vx 是否远离 VDD/2；`inspect_node('vx')` | 严格 match MN3/MN4 W·m；MN4.G = vx_l |
| Stage2 上下电流不匹配（MP6 ratio vs MN6 ratio 错）| 算 m_MP6 × W_MP6 vs m_MN6 × W_MN6 / I_stage2 设计值 | 调 m_MP6（**不调 W_MP6**），保 mirror ratio |
| Tail headroom 不够（MPTAIL 进 triode）| `inspect_device('mptail')` Vds vs Vdsat | 减 W_diff / 加 L_tail；详见 `bias-headroom.md` 范例 |
| Input pair 极性错（PMOS-input + Vcm > VDD−|Vth_p|−0.1）| Step 0.2 cm-range L2 self-check | 切 NMOS-input variant（详见 `architecture.md`）|
| Rfb 太大（high-gain 时 closed-loop 也太"软"）| Rfb=1G + 极高增益 → DC loop 微弱 | Rfb 降至 10Meg-100Meg；DC 拉回 vinn ≈ Vcm 更紧 |
| Bias chain ratio 算错（Itail 漂大/小）| 算 mirror W·m 比 vs 设计 ratio | 见 `architecture.md` Pitfall 3 |

### 决策树

```
DC OP triode_count > 1 / vout 飘 rail
  ├─ Step 1: 当前 testbench 是 open-loop（VINP=VINN 强制）？
  │    ├─ 是 → 换 closed-loop 模板 (tb_dc_closed.sp) 重跑
  │    │       └─ 仍 fail → 进 Step 2
  │    │       └─ Pass    → 完成（high-gain open-loop 不可靠是常态）
  │    └─ 否 → 进 Step 2
  │
  ├─ Step 2: closed-loop 下 vinp/vinn 是否在 Vcm 附近 (差 < 50mV)?
  │    ├─ 是 → 真 sizing 问题
  │    │      ├─ 看 stage1 mirror match (MN3/MN4 W·m / MN4.G 节点)
  │    │      ├─ 看 stage2 上下电流匹配 (m_MP6 vs m_MN6)
  │    │      ├─ 看 tail headroom (MPTAIL Vds vs Vdsat)
  │    │      └─ 看 input pair 极性 (cm-range L2)
  │    └─ 否（vinn 仍偏离 Vcm 30mV+）→ Rfb 太大或 stage1 imbalance
  │            ├─ Rfb 降 1G → 10Meg / 100Meg 试
  │            └─ 同时验 stage1 mirror match
  └─ Step 3: 全 device sat 但 spec 不达标
       → 单纯 spec margin 不够，调 sizing (sizing-typical.md Phase A/B/C)
```

### Anti-pattern（不要做）

- ❌ **看到 vout 飘 rail 就归因为 testbench 模式错** —— 真因更可能是 sizing/mirror match
- ❌ **强行用 open-loop DC 当默认模板**（high-gain 运放上不可靠，且与 AC 激励不一致）
- ❌ **DC 用 open-loop / AC 用 closed-loop 混用** —— 两者 OP 不同，AC 测出的 gain/PM
  与实际部署状态无关。**DC 与 AC 必须用同一激励**（同一 testbench 拓扑），调好 DC
  工作点的目的就是给 AC 一个正确合理的小信号模型。

---

## When to load this chapter

- AC / DC 仿真后 spec 不达标（任一项）
- 看到 dc_snapshot 异常前先回 `bias-headroom.md` 验 headroom
- PM 紧 → 先看 ac-stability.md 极点分布
- agent 在调 sizing 撞壁（多次试都没收敛）
- ⭐ DC OP triode_count > 1 / vout 飘 rail → 优先看模式 9

## Related

- **device 不 saturation** → `bias-headroom.md`（KVL/R2 推理 + 跨级耦合）
- **Miller 补偿 / RHP zero / Rz 详细推导** → `ac-stability.md` + `blocks/base-cells/miller-compensation`
- **sizing trade-off + 推进顺序** → `sizing-typical.md`
- **拓扑选型** → `architecture.md`（spec > 2-stage 上限时换拓扑）
- **通用诊断方法** → `skill: systematic-debugging` / `signal-tracing`
