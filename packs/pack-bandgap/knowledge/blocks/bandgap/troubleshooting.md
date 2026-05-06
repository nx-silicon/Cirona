---
chapter: troubleshooting
parent: bandgap
summary: |
  PNP first-order Brokaw bandgap 系统级失败模式 + 物理因果链 + 根因可能性表。
  涵盖 Vref 不达标 / OTA polarity / 双稳态解 / TC 漂 / PSRR 偏低 / startup
  失败 / 外环 oscillation / mirror mismatch 等。诊断流程引用 systematic-debugging
  skill。startup 详细 5 类故障见 startup.md，本章合并 architecture 7 pitfalls
  + startup 5 modes 给系统级根因表。
tokens: ~1700
prerequisite_chapters:
  - architecture
  - startup
  - sizing-typical
  - loop-stability
related_skills:
  - meta-cognitive/systematic-debugging
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/bias-generator
  - blocks/5t-ota
---

# Bandgap Troubleshooting

> 通用诊断顺序见 `skill: systematic-debugging`（4-phase）+ `skill: signal-tracing`
> （信号反推）。本章节给的是 **bandgap 拓扑特有**的失败模式 + 物理因果链 +
> 根因可能性表。startup 详细 5 类故障见 `startup.md`；外环 AC oscillation
> 详见 `loop-stability.md`；本章合并所有失败模式给系统级根因表。

## 诊断顺序（**bandgap 推荐顺序**）

> 这是 bandgap 系统级**推荐诊断顺序**——bandgap 误差源多（startup / DC latch /
> TC / PSRR / PNP matching / OTA polarity），盲目调任一项救不了别的。
> **按 Vref（绝对值）→ na ≈ nb → startup → TC → PSRR 顺序排查**。

```
1. DC `op` 看 Vref 绝对值
   - Vref ≈ 0V → stuck-at-zero（startup 没起，模式 5 / startup.md Mode 1）
   - Vref ≈ 1.79V（near VDD）→ OTA polarity 反（模式 1）
   - Vref ≈ 1.19V → 进步骤 2
   ↓
2. 看 |V(na) - V(nb)| OTA lock error
   - > 1 mV → OTA 没锁好（模式 2，PMOS mirror mismatch / R2a/R2b 不匹配）
   - < 1 mV → 进步骤 3
   ↓
3. 跑 tb_startup tran 验证（DC `op` 不能证明 startup！）
   - 失败 → 见 startup.md 5 modes
   - PASS → 进步骤 4
   ↓
4. 跑 tb_tc_sweep 验证 TC
   - TC > 100 ppm/°C → 模式 3（zero-TC 比例 / R2/R1 偏 / PNP curvature）
   - TC OK → 进步骤 5
   ↓
5. 跑 tb_psrr 验证 PSRR
   - PSRR < 50 dB → 模式 4（mirror L 短 / OTA gain 不够 / non-cascoded）
   - PSRR > 50 dB → 进步骤 6
   ↓
6. 跑 tb_psrr / tb_startup tran ringing 看 outer loop stability
   - 振荡 → 模式 6（缺 Miller / Ccomp）→ loop-stability.md
   - 稳定 → bandgap 通过 sign-off
```

## 失败模式 1：Vref ≈ 1.79V（OTA polarity 反）

> ⭐ **bandgap 设计最危险的 silent failure**——`.op` 不报错，仅 Vref 绝对值
> 暴露。V3 efb0fa3 stranger-domain review case。

### 症状
```
inspect_node('vref'): V(vref) ≈ 1.79V (≈ VDD)
inspect_node('na', 'nb'): V(na) ≈ V(nb) ≈ 0V or 1.79V (latched)
inspect_device(MP1/2/3): Vsg ≈ 0V or VDD-Vth (cutoff or saturation extreme)
```

### 物理因果链（OTA polarity 反 → loop 反向）

```
bandgap 是闭环负反馈拓扑：
  OTA(vp, vn) → yg → 3 PMOS mirror → na/nb → 应回 OTA input

如果 OTA polarity 接错（如 2-stage OTA 用了单级 5T 的 vp=nb 约定）：
  na ↑ → OTA output yg ↑（应该是 ↓）
  yg ↑ → PMOS mirror Vsg ↓ → I_branch ↓ → na ↓ ... (理论)
  
但实际：OTA 设计了 forward loop 让 na = nb，反向 → DC latch 到错误的稳态分支
  (Vref = VDD − Vsg_min 或 Vref = 0 + V_threshold)
```

### 根因可能性表

| 可能根因 | 验证 | 修复 |
|---|---|---|
| **2-stage OTA 用 vp=nb 写法**（最常见）| 网表检查 OTA 输入接线 | 改 vp=na（2-stage 整体反相）|
| 单级 5T OTA 用 vp=na 写法 | 网表检查 + 数 stage 数 | 改 vp=nb（单级 OTA 整体非反相，Razavi 经典）|
| OTA stage 数错（应 2-stage 写成单级）| 看 OTA 内部网表 | 校正 stage 数 |
| Mirror polarity 错（PMOS ↔ NMOS）| 看 MP1/2/3 type | 校正 type |

### Anti-pattern
- ❌ **`.op` 显示 Vref ≈ 1.2V 就 OK**：可能 .op solver 跳到正常解，但 silicon
  上电仍可能 latch 到错误分支
- ❌ **靠改 startup 救 polarity 反**：startup 救 stuck-at-zero，不救 polarity 反

### 验证
- 写 OTA 接 bandgap 前**先画小信号 loop sign**（见 architecture.md Pitfall 4 决策表）
- DC `op` 显示 Vref 接近 rail（如 1.79V 或 0V）是 polarity 强嫌疑

---

## 失败模式 2：OTA lock error |V(na) - V(nb)| > 1 mV

**症状**：DC `op` 显示 V(na) ≠ V(nb)（差 > 1 mV）；Vref 偏离 nominal。

### 物理因果链
```
OTA 强制 V(na) = V(nb) 是 bandgap 闭环目标
lock_err 大 = OTA gain 不够 / PMOS mirror mismatch / R2a/R2b 失配

理论 lock_err = V_offset_OTA / A_OTA + ...
A_OTA = 30-40 dB → 30-100×衰减
V_offset_OTA = 5-15 mV typical → 50-500 µV expected lock_err
```

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| **R2a / R2b mismatch**（最常见 layout）| diff R2a / R2b 阻值 | 用同 unit cell × N 拷贝 + common-centroid layout |
| **PMOS MP1/MP2/MP3 mismatch** | diff M1.W vs M2.W vs M3.W | 严格 W/L/m 完全相同 |
| OTA gain 不够（< 30 dB）| OTA 自身 tb 测 gain | 增 OTA L_load 或加 cascode |
| OTA offset 过大（W·L 太小）| MC σ_OS_OTA | 加大 OTA input pair W·L |

---

## 失败模式 3：TC > 100 ppm/°C（first-order spec 30-80 ppm/°C）

**症状**：tb_tc_sweep -40 / 27 / 125°C 测出 TC > 100 ppm/°C；Vref 单调随
温度升或降。

### 物理因果链

zero-TC 条件：`R2/R1 = |∂Vbe/∂T| / (ln(N)·k/q) ≈ 12 for N=8`。

```
TC (ppm/°C) = (Vref_max - Vref_min) / (Vref_27 × ΔT)
偏 ±20% R2/R1 比例 → TC 漂 50+ ppm/°C
```

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| **R2/R1 比例不在 zero-TC 点**（最常见 sizing）| 算 R2/R1 vs 11.2-12 (N=8) | 校 R2/R1 比例（见 sizing-typical Step 4）|
| Resistor TC 不匹配（R1 与 R2 用不同 type）| 看 PDK 不同 R 的 TC | R1 / R2 / R_OUT 用同 type 抵消 |
| PNP curvature 主导（Vbe 二次温度项）| 看 Vref vs T 是否抛物线 | first-order 不能修，必须 curvature-corrected variant |
| Vref nominal 偏（不在 ~1.20V）| 验证 R_OUT 与 I_total | 校 R_OUT |

### 边界判断
- TC > 100 ppm/°C 且 R2/R1 已对 → curvature 主导 → 必须二阶补偿（不在 first-order 范围）
- TC 30-80 ppm/°C 是 first-order 物理上限，超严必须换拓扑

---

## 失败模式 4：PSRR < 50 dB DC

详见 `loop-stability.md` 范例 2。简短根因表：

| 根因 | 修复 |
|---|---|
| PMOS mirror L < 1 µm（ro 不够）| L_P ≥ 1 µm（架构 Pitfall 1）|
| OTA gain 不够 | OTA 加 cascode in stage1 |
| Non-cascoded mirror（物理上限 50-55 dB）| Cascoded mirror variant（必做 if PSRR > 70 dB spec）|
| External VDD coupling | 加 on-chip / package decap |

---

## 失败模式 5：Stuck-at-zero（startup 失败）

详见 `startup.md` Mode 1。简短：

| 根因 | 修复 |
|---|---|
| W_KICK 太小（拉 yg 不动）| W_KICK 5µ → 10-20µ |
| R_START 太大（v_sens ramp 慢）| R_START 500kΩ → 200kΩ（注意 PSRR）|
| OTA self-bias R_BIAS 太大（OTA 内部不 startup）| R_BIAS ≤ 2 MΩ |

---

## 失败模式 6：外环 oscillation

详见 `loop-stability.md` 范例 1。简短根因表：

| 根因 | 修复 |
|---|---|
| 缺外环 Ccomp（yg cap）| Ccomp 2 pF on yg ↔ vss |
| OTA 内 Miller 没加 Rz nulling | Rz = 1/gm6 ≈ 20 kΩ |
| OTA + mirror 极点接近 | 加 Cmiller 推 stage2 极点；加 Ccomp 推主极点 |

---

## 失败模式 7：Startup oscillation（kick 太强）

详见 `startup.md` Mode 2。简短：

| 根因 | 修复 |
|---|---|
| W_KICK 过大（kick over-pull）| W_KICK 减 50% |
| 同时遇外环 oscillation | 见模式 6 |

---

## 失败模式 8：MN_SENS 持续导通 → PSRR 退化

详见 `startup.md` Mode 3。简短：

| 根因 | 修复 |
|---|---|
| R_START < 200 kΩ | R_START 500 kΩ - 2 MΩ |
| MN_SENS 弱（W 小）| W_SENS ↑ |

---

## 失败模式 9：tb_startup 没 .ic / uic（DC 假阳性）

详见 `startup.md` Mode 4。

修复：tb_startup 必含 `tran ... uic`；可选加 `.ic v(yg)=1.8 v(vref)=0` 显式
强制零初值。

---

## 失败模式 10：VDD ramp 太快（false-fail）

详见 `startup.md` Mode 5。

修复：tb_startup VDD ramp ≥ 1 µs（典型 silicon 实际值）。

---

## 失败模式 11：NMOS-input OTA tail 进 triode

详见 `architecture.md` Pitfall 7。

修复：bandgap 必须用 PMOS-input OTA（na/nb ≈ 0.65V 共模 NMOS-input tail 没
headroom）。

---

## 失败模式 12：OTA oversize → Iq 过预算

详见 `architecture.md` Pitfall 5 + `sizing-typical.md` Step 7。

修复：bandgap OTA 用 small-W long-L（W=4µm/L=2µm input pair），不抄宽带 amp
模板。

---

## 失败模式 13：Cac 方向错误（应连 VSS 却接到 VDD）

> ⭐ **Demo 01 v6 实证教训** — 改 PSRR 想加 AC 旁路电容，连错方向反让 vbpc_p 跟踪 VDD，方向相反。浪费 ~25 turn。

### 症状
- 加 Cac 后 PSRR **不改善反更差**
- 加 Cac 后 startup 失败（Vref ramp 不到位 / stuck-at-zero）

### 物理因果

```
目标：让某高阻偏置节点（如 vbpc_p）在 AC 频率下"不动"（与电源纹波隔离）

方向 A（错误）：Cac 从 vbpc_p 连到 VDD
  → 等效：把 VDD 的 AC 信号通过 Cac 直接注入 vbpc_p
  → vbpc_p 跟踪 VDD！完全相反的效果
  → 启动时 Cac 把 vbpc_p 拉到 VDD → cascode Vsg=0 → 全关 → stuck-at-zero（兼 startup Mode 6）

方向 B（正确）：Cac 从 vbpc_p 连到 VSS
  → vbpc_p 的 AC 阻抗降低（被 Cac 短路到 AC 地）
  → VDD 纹波通过 Rbc1 分压后被进一步旁路到 VSS
  → 但片内电容 < 50pF 在 1kHz 阻抗 > 3MΩ，效果有限（详见 physical-constraints.md）
```

### 记忆口诀

> **AC 改善 = AC 接地（连 VSS）。连 VDD 是跟踪电源 = 抗扰度变差。**

### 修复
- 把 Cac 一端从 VDD 改到 VSS
- 加 Cac 后**必须验 startup**（见 `startup.md` Mode 6 大电容破启动）
- 改善 PSRR 优先选其他路径（提高 Rbc1 / 改拓扑）— 详见 `loop-stability.md`

详见 `physical-constraints.md` § 3 AC 接地方向哲学。

---

## When to load this chapter

- DC `op` 显示 Vref 异常（不在 1.19V ±50mV）
- tb_startup tran 失败 / Vref ramp 不到位
- TC sweep 超 spec
- PSRR 偏低 / 跨 corner 退化
- 外环 ringing（tb_psrr peaking 或 tran ringing）

## Related

- **架构选型 + zero-TC + 7 pitfalls** → `architecture.md`
- **4-step sizing recipe** → `sizing-typical.md`
- **外环 AC stability + Miller + Ccomp** → `loop-stability.md`
- **Startup 5 类详细 failure modes** → `startup.md`
- **Reference design + 标准 testbench** → `reference-design.md`
- **OTA 5T 子模块 sizing** → `blocks/5t-ota`
- **β-multiplier startup-helper 物理** → `blocks/base-cells/bias-generator/{beta-multiplier, startup-helper}`
- **通用诊断方法** → `skill: systematic-debugging` / `signal-tracing`
