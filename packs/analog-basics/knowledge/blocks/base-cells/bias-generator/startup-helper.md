---
chapter: startup-helper
parent: bias-generator
summary: |
  启动辅助 —— 用于 β-multiplier 等自偏置电路 / strong kick + 自禁用机制 /
  上电序列保证不 stuck-at-zero
tokens: ~600
prerequisite_chapters:
  - beta-multiplier
related_skills:
  - circuit-method/bias-tree-reasoning
related_knowledge: []
---

# 启动辅助（Startup Helper）

## 何时需要

任何**自偏置**电路（如 β-multiplier、self-biased bandgap）都有"零电流"双稳态：
- 上电时若所有管 Vgs = 0 → 全 cutoff → 0 电流 → 自洽
- → 没有外部 perturbation 永远 stuck-at-zero
- → **必须**靠 startup helper 把电路推到正常工作点

## 拓扑（典型 startup helper）

```
                      VDD
                       │
               ┌───────┴───────┐
               │               │
          ┌────┴────┐     ┌────┴────┐
          │ M_kick  │     │主电路  │
          │ (PMOS,  │     │bias    │
          │  weak)  │     │tree   │
          └────┬────┘     └────┬───┘
               │               │
               ●──────●────────● 注入到 bias chain 中关键节点
                      │                   (典型：vb_p / vb_n)
                ┌─────┴─────┐
                │  detector │ ← 检测 bias chain 是否启动（vb_n > Vth?）
                │ (NMOS)    │
                └─────┬─────┘
                      │
                     VSS
```

**核心机制**：
- **上电瞬间**：bias chain 全 cutoff → vb_n / vb_p = rail（cutoff 状态）
- **detector 关断 / M_kick 导通**（M_kick 是 weak PMOS）→ M_kick 注入小电流到 bias chain → 推 vb_n / vb_p 偏离 cutoff → β-multiplier 稳态平衡被打破 → 走向正常工作点
- **正常工作后**：bias chain 已建立 → vb_n > Vth → detector 导通 → 关断 M_kick → **自禁用**（避免持续耗电 + 干扰主 bias）

## 关键设计要点

### 1. M_kick 必须 weak

```
M_kick 流过的 I_kick << 主 bias 设计电流
典型 I_kick = 1-10% × I_bias_target
```

理由：M_kick 不能在正常工作时仍持续流大电流——会改变 bias chain 工作点。

### 2. detector 必须**与 bias chain 同 PVT**

detector 是 diode-connected NMOS（gate 接到 vb_n）：
- vb_n < Vth_detector → detector cutoff → M_kick 导通
- vb_n > Vth_detector → detector 导通 → M_kick gate 拉到 VDD → M_kick cutoff（自禁用）

→ detector 的 V_th 必须与 bias chain 的 NMOS 同型同 L → PVT 漂移同步。

### 3. 启动序列（事实）

```
T=0:   VDD 上电 → 全管 cutoff（零电流稳态）
T=0+:  bias 节点 rail-stuck（β-multiplier 的零电流平衡点）：
         vb_n ≈ 0 V    （NMOS 偏置节点：NMOS 全关 → 无路径拉高 → 由 leakage 维持在 VSS 附近）
         vb_p ≈ VDD    （PMOS 偏置节点：PMOS 全关 → 无路径拉低 → 维持在 VDD 附近）
       具体方向取决于拓扑（哪个 rail 通过 diode 上电更快），但**不会两个节点都 = VDD**
T+1τ:  M_kick 注入电流 → 把 vb_n 从 ~0 V 抬向 Vth_n → bias chain 进入正反馈启动
T+2τ:  bias chain 开始 ramp-up → vb_n 升至 Vth+Vov / vb_p 降至 VDD-|Vth|-|Vov|
T+5τ:  bias chain 稳定 → detector 导通 → M_kick gate 拉到 VDD → M_kick 关断
T+6τ:  自禁用完成 → bias chain 独立运行
```

τ 典型 1-100 ns（depends on Cgate × Rmirror）。

## 失败模式（startup 自身故障）

### 故障 1：M_kick 太弱 → 不 kick 起来

I_kick 不足以打破 stuck-at-zero → bias chain 仍 stuck。
**修复**：增 W_M_kick（增 I_kick）。

### 故障 2：M_kick 太强 → 持续耗电 / 改变工作点

I_kick 与 I_bias 同量级 → 正常工作时 M_kick 仍流电流 → 主 bias 偏离设计。
**修复**：减 W_M_kick / 改 detector threshold（让 detector 提前 trigger）。

### 故障 3：detector 在边界振荡

vb_n 在 Vth_detector 附近 → detector 在 ON/OFF 间振荡 → M_kick 周期性 ON → bias chain 跳动。
**修复**：detector 加 hysteresis（用 schmitt 结构）/ 或用单向 latch（一旦启动不再回滚）。

## sizing 范例（5 µA β-multiplier 配 startup）

> 📌 **@ vpdk180nm**（μn/p·Cox / Vth 数值参考 `pdks/vpdk180nm/index.md`）。换工艺需重算所有数值；β-multiplier + startup detector 拓扑跨工艺通用。

```
β-multiplier 设计 I_bias = 5 µA

M_kick (PMOS):
  目标 I_kick = 0.5 µA (10% of I_bias)
  Vov_kick = 0.1 V (weak)
  W/L = 0.5
  W = 0.36 µm, L = 0.72 µm（弱管）

Detector (NMOS):
  diode-connected
  W = 0.5 µm, L = 1 µm
  threshold: vb_n > 0.5 V (Vth_detector ≈ 0.5)

启动时序:
  T=0: VDD ramp 1 ns → 0V → 1.8V
  T=1ns: M_kick 流 0.5 µA 进 vb_n
  T=10ns: vb_n 充电到 ~0.4 V → β-multiplier 启动
  T=30ns: vb_n 稳定 ≈ 0.65V → detector 导通 → M_kick 关断
  T=50ns: bias chain 完全稳定，I_bias = 5 µA ± 5%
```

## 验证清单

- [ ] tran：VDD ramp-up（典型 1-10 µs）→ I_bias 在 < 1 µs 内建立到 95%
- [ ] tran：检查 M_kick 在稳态时 I_M_kick ≈ 0（自禁用 OK）
- [ ] tran：模拟"运气最坏"（VDD 高速 ramp + extreme PVT corner）→ 仍能启动
- [ ] PVT corner：SS（高 V_th）/ 低温 / 低 VDD 角 → detector 仍能 trigger（startup 最难的是慢角，不是 FF）
- [ ] tran：SS corner + 高温 → I_kick 是否够（V_th 升 → 启动慢）

## 常见误区

| 心里想 | 现实 |
|---|---|
| "β-multiplier 不需 startup" | **错** — 双稳态 stuck-at-zero 必须 startup |
| "用一个简单 R 拉 vb_n 就行" | R 在正常工作时持续耗电；startup 应自禁用 |
| "M_kick 永远导通就行" | 持续 I_kick 改变 bias chain 工作点 |
| "detector V_th 任意" | 必须与 bias chain 同型同 L → PVT 漂同步 |
| "VDD 慢 ramp 总是能启动" | 慢 ramp 反而难启动（M_kick 在 VDD 低时也弱）→ 必须 spec 最快 ramp + 最慢 ramp 都验证 |

## 不在本章范围

- β-multiplier 拓扑详细 → chapter `beta-multiplier`
- 基础 mirror 树 → chapter `basic-mirror-tree`
- bandgap startup（不同机制，但类似 stuck-at-zero 风险）→ `blocks/bandgap/startup`
- 故障诊断 → chapter `troubleshooting`
