---
chapter: strongarm
parent: comparator-latch
summary: |
  StrongARM 动态比较器 —— 预充电 / 评估 / 再生三相 / 输入对采样 +
  cross-coupled 再生 / kickback / offset 推导 / metastability 模型
tokens: ~850
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/differential-pair
---

# StrongARM 动态比较器

## 拓扑（三相工作流）

```
                    VDD
                     │
          ┌──────────┴──────────┐
          │                     │
   ┌──────┴───┐         ┌───────┴──┐
   │ M_p1     │         │ M_p2     │← cross-coupled PMOS
   │ (PMOS    │  ╳╳╳    │ (PMOS    │   (regen 上半部)
   │  reset)  │ <───── ───────>   │
   └──────┬───┘         └───────┬──┘
          ●─── Out- ── Out+ ────●
   ┌──────┴───┐         ┌───────┴──┐
   │ M_n1     │  ╳╳╳    │ M_n2     │← cross-coupled NMOS
   │ (NMOS    │ <───── ───────>   │   (regen 下半部)
   │  regen)  │         │          │
   └──────┬───┘         └───────┬──┘
          ●─── di+ ──── di- ─────●  ← internal nodes (sampling)
   ┌──────┴───┐         ┌───────┴──┐
   │ M_in1    │←Vin+    │ M_in2    │← Vin-
   │ (input   │         │ (input   │   (NMOS input pair)
   │   pair)  │         │   pair)  │
   └──────┬───┘         └───────┬──┘
          │                     │
          └─────────●───────────┘
                    │
                ┌───┴────┐
       CK ────→ │ M_tail │ ← tail current (clk-driven)
                │ NMOS   │
                └───┬────┘
                    │
                   VSS
```

**三相工作流**：

### Phase 1: Reset / Precharge（CK = low）
- M_tail 关断 → 没有 tail 电流
- M_p1 / M_p2（PMOS top）导通 → di+ / di- 充电到 VDD
- Out+ / Out- 也充电到 VDD（reset 输出）
- 输入对 M_in1 / M_in2 静态偏置但无电流流过

### Phase 2: Evaluate / Sample（CK = high 上升边沿）
- M_tail 导通 → tail 电流流过输入对
- M_in1 与 M_in2 因 V_in 差异 → I_M_in1 ≠ I_M_in2 → di+ 与 di- 放电速度不同
- → di+ / di- 发展出小差分电压（mV 级）
- 此阶段尚未触发 cross-coupled regen

### Phase 3: Regenerate（中后期，di+ 或 di- 跌到 Vth_n 以下）
- 当 di+ 或 di- 跌到 Vth_n 以下 → cross-coupled M_n1/M_n2 之一开始导通
- 正反馈放大 → 输出 Out+/Out- 之一被快速拉到 VSS
- M_p1/M_p2 之一开始导通 → 另一输出推到 VDD
- → 全摆幅 rail-to-rail 输出

## 关键性能指标

### Offset（输入参考失配）

主要源（按重要性）：
1. **input pair Vth 失配**：σ(ΔVth_in) = AVT / √(W·L)
2. **input pair β 失配**：σ(Δβ/β) = AB / √(W·L)
3. **regen pair 失配**（次要）：影响 metastability 但不直接是 offset
4. **内部节点 Cdb 失配**：影响初始 di+ / di- 不平衡

```
σ_OS_input_referred ≈ √(σ²_Vth_input + (V_OV/2)²·σ²_β/β)
```

**典型数值**（@ 180nm vpdk，input pair W=10µm/L=1µm）：
- σ_Vth ≈ AVT/√(WL) = 5/√10 ≈ 1.6 mV
- σ_OS_total ≈ 5-15 mV（含其他源）

**改善方法**：
- 增 W·L of input pair（√(WL) 关系）→ 增大面积
- 偏置 input pair gm/Id 高（Vov 小）→ Vth-dominated regime
- 后端校准（数字 trim / DEM）

### Decision Time（再生时间）

```
T_regen = τ_reg × ln(VDD / ΔV_initial)

τ_reg = C_node / gm_regen     # 再生时间常数

例：C_node = 50 fF / gm = 1 mS → τ_reg = 50 ps
ΔV_initial = 1 mV → T_regen = 50 ps × ln(1.8/1m) = 50 × 7.5 = 375 ps
ΔV_initial = 100 mV → T_regen = 50 × ln(18) ≈ 145 ps
```

→ **小输入差分需要更长 regen 时间**——这是 metastability 的根源。

### Metastability 概率

```
P_meta = P(ΔV_initial < V_threshold) × exp(-T_evaluate/τ_reg)

V_threshold ≈ σ_OS（信号小于 offset 时输出方向不确定）
T_evaluate = 时钟 high phase 持续时间
```

@ T_evaluate = 1 ns / τ_reg = 50 ps → exp(-20) ≈ 2e-9。这是"近阈值条件下"的指数项；
系统级 metastability 概率还要乘 P(ΔV_initial < V_threshold)（输入落入小差分窗口的概率），通常进一步降低 1-3 个数量级（典型每 1e10-1e12 次近阈值采样 1 次系统级元稳态）。

→ 高速 ADC 评估相位通常取 ≥ 10-20 × τ_reg：10× → exp(-10)≈4.5e-5；20× → exp(-20)≈2e-9。具体值按目标错误率定，1e-9 级需 ≥ 20 × τ_reg。

### Kickback Noise

```
Q_kickback = Cgd_input × ΔV_internal_node

ΔV_internal = di+ swing during evaluate ≈ 0.5 V (典型 di+ 从 VDD 到 VDD/2)
Cgd_input = Cox × W × L_overlap ≈ 5-10 fF @ W=10µm
Q_kickback = 5-10 fF × 0.5 V = 2.5-5 fC

ΔV_input = Q_kickback / C_input_source
```

→ ADC reference / SAR 中输入端 C 小（pF 级）→ kickback 引起 mV 级扰动 → 影响下次比较。

**改善**：preamp（在 StrongARM 前加增益级 + 隔离）；或选择 kickback-aware StrongARM 变体。

## sizing 关系（关键）

| 量 | 推荐范围 | 因果 |
|---|---|---|
| input pair W·L | 10-100 µm² | offset σ ∝ 1/√(WL)；面积 vs offset trade-off |
| input pair Vov | 0.1-0.2 V | 小 Vov → β 失配项小；与 Vth 失配相比 |
| regen pair W·L | 5-20 µm² | 小一些（不是 offset 主因，影响 τ_reg）|
| L | min L 或 2× | 速度优先；mismatch 与 W·L 一起调 |
| C_node 控制 | 减 layout par + 减 regen pair Cgd | τ_reg 减 → 高速 |

## sizing 范例（10-bit / 100 MSPS SAR ADC 比较器）

> 📌 **@ vpdk180nm**（μn/p·Cox / Vth / Avt 数值参考 `pdks/vpdk180nm/index.md`）。**short-channel L 用 long-channel 公式偏高 2-5×，必须 BSIM 实测**——StrongARM 常用 Lmin 速度优先。换工艺需重算 σ_OS / τ_reg；StrongARM 拓扑跨工艺通用。

```
spec: σ_OS ≤ 10 mV / metastability < 1e-9 / decision time < 5 ns

input pair (NMOS):
  σ_OS_target = 10 mV → 主要 input pair Vth 失配
  AVT @ 180nm = 5 mV·µm → σ_Vth = AVT/√(W·L)
  → 10 mV → W·L > 0.25 µm²（很小）
  实际取 W=10µm / L=1µm （W·L=10）→ σ_Vth = 1.6 mV
  其他源（regen + tail mismatch + 内部 Cdb）累加 → σ_OS ≈ 5-8 mV ✓

  Vov_in = 0.15V，Id = 100 µA（per side）→ gm/Id ≈ 13

regen pair:
  W=2µm / L=0.18µm，gm = 0.5 mS @ 50 µA
  C_node ≈ 30 fF → τ_reg = 60 ps

decision time:
  ΔV_initial @ 10 mV input = 5 mV（rough; depends on tail current and 时间）
  T_regen = 60 × ln(1.8/5m) = 60 × 5.9 = 354 ps（远 < 5 ns spec ✓）
  T_evaluate target = 10 × τ_reg = 600 ps（保 metastability < e^-10 ≈ 5e-5）

  ⚠️ 1e-9 metastability 需 T_eval ≥ 20 × τ_reg = 1.2 ns
  → fclk_max ≈ 800 MHz（含 reset phase）
```

## 验证清单

- [ ] tran：三相位时序无 race（non-overlap ≥ 100 ps）
- [ ] tran：reset 后 di+/di- = VDD（充满）
- [ ] tran：evaluate phase 按目标错误率取 ≥ N × τ_reg（10× → ~1e-5；20× → ~1e-9）
- [ ] MC 仿真：σ_OS in spec
- [ ] tran：feed slow ramp at V_in，统计 metastability rate
- [ ] AC：kickback ΔV_input < spec（注入 ΔV_internal 看反向耦合）
- [ ] PVT corner：FF/SS T_regen 漂 < 30%

## 常见误区

| 心里想 | 现实 |
|---|---|
| "增 W 减 offset 就行" | offset σ ∝ 1/√(W·L)，需 √4×W 才减一半；面积大 |
| "Vov 大速度快" | Vov 小 → β 失配项小（offset 主在 Vth 失配区域）；速度由 τ_reg = C/gm 决定 |
| "metastability 不会发生" | 输入接近 0 mV 时一定会发生，错误率 = 时钟 phase 长度 / τ_reg 决定 |
| "kickback 不影响 ADC" | SAR / pipeline 中前级 reference 是 kickback 受害者，会引入 INL/DNL 误差 |
| "StrongARM 只能 NMOS input" | 也可以 PMOS input（极性反 + 复位互换）；选择看共模 + 工艺 |

## 不在本章范围

- static latch（双稳态）→ chapter `static-latch`
- dynamic latch（clock-gated）→ chapter `dynamic-latch`
- 故障 debug → chapter `troubleshooting`
- 完整 ADC 时序 + 比较器整体接口 → `systems/sar-adc` / `systems/adc-pipeline`
- preamp + StrongARM 复合架构 → 高精度比较器 knowledge
- offset 数字校准 → ADC 系统 knowledge
