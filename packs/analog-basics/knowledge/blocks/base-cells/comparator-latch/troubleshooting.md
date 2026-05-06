---
chapter: troubleshooting
parent: comparator-latch
summary: |
  比较器锁存五大故障：offset 大（输入对失配）/ metastability 错误率超 /
  kickback 影响前级 / 时序 race / 电源耦合
tokens: ~600
prerequisite_chapters:
  - strongarm
  - dynamic-latch
related_skills:
  - circuit-method/signal-tracing
  - meta-cognitive/systematic-debugging
related_knowledge: []
---

# Comparator-Latch 故障诊断

> ⚠️ **使用规则**：本章是事实对照表。**思维过程**用 skill `circuit-method/signal-tracing`
> 沿信号路径反推（"offset 是哪个失配源主导？metastability 时间够吗？"）。

---

## 症状 1：offset 大于 spec

**表现**：MC 仿真 σ_OS = 20 mV，spec 要求 ≤ 10 mV。

**物理因果**：
- input pair Vth 失配（Pelgrom σ ∝ 1/√(WL)）—— 通常主因
- input pair β（W/L）失配（次要）
- 内部节点 Cdb 失配（次次要）
- regen pair 失配（影响 metastability 不直接是 offset）

**诊断**：
1. MC 仿真分别看 Vth_input、Vth_regen、tail 失配的贡献（独立 sweep 各失配项）
2. 公式估算 σ_OS_predicted = AVT/√(W·L) → 与 MC 对照

**修复方向**（按效果）：

| 修复 | 因果 | 代价 |
|---|---|---|
| 增 input pair W·L | σ_OS ∝ 1/√(WL)，加倍 W·L 减 σ √2 倍 | 面积 + Cgs ↑（速度损）|
| 减 Vov_input | offset = √(σ_Vth² + Vov²·σ_β/β/2²)；Vov 小 → β 项小 | gm ↓ → decision time 升 |
| 后端校准 | 数字 trim / dynamic element matching | 设计 + 数字 DSP 复杂度 |
| 加 preamp 在 StrongARM 前 | preamp 增益除掉 StrongARM offset | 静态功耗 + complexity |

**❌ 不要**：单纯调 input pair Vov 不增 W·L（offset 与 Vov 关系弱，主要是 W·L）。

---

## 症状 2：metastability 错误率超 spec（输出有时未确定）

**表现**：tran 长仿真 1e6 次比较，发现 100 次输出在 evaluate 结束时仍处中间态（典型 P_meta = 1e-4）。

**物理因果**：
- ΔV_initial 小于 σ_OS 时 regen 时间不足
- T_evaluate phase 不够长

**诊断**：
1. 测 τ_reg = C_node / gm_regen
2. 看 T_evaluate（CK high 持续时间）
3. P_meta = exp(-T_evaluate / τ_reg)

**修复方向**：

| 修复 | 因果 |
|---|---|
| 增 T_evaluate | P_meta 指数减小；但 fclk_max 降 |
| 减 τ_reg（增 gm_regen / 减 C_node）| 速度优化；regen pair 增 W |
| 加 preamp 增大 ΔV_initial | 让 ΔV >> σ_OS，从根上避免 metastability |

例：要 P_meta < 1e-9 → T_evaluate ≥ 20 × τ_reg；@ τ_reg = 50 ps → T_eval ≥ 1 ns。

---

## 症状 3：kickback 干扰前级

**表现**：ADC INL/DNL 异常 / SAR 中前几位决定影响后位。

**物理因果**：StrongARM 内部节点 di+/di- 摆幅大（~VDD/2）→ 通过 Cgd_input 反向耦合到输入端。
```
ΔV_kickback = (Cgd / C_input_source) × ΔV_internal
```

**诊断**：tran 注入 evaluate 边沿，看输入端反向跳变：
- 典型 5-50 mV 跳变 @ ADC reference 节点
- 如果 reference 是高阻（pF 级 C）→ kickback 显著

**修复方向**：

| 修复 | 因果 |
|---|---|
| 加 preamp（隔离 + 增益）| preamp 隔离 Cgd 反向路径；同时 ΔV_initial 大 → metastability ↓ |
| 减 input pair W | Cgd 减小（但 offset 升）|
| 选 kickback-aware StrongARM 变体 | 内部节点摆幅小（如 dynamic comparator with reset switches）|
| 增 reference C 或 buffer | C_source 大 → ΔV 减；buffer 隔离 |

---

## 症状 4：时序 race（reset 与 evaluate 冲突）

**表现**：tran 看到 reset 阶段未完成 di+/di- 还没到 VDD，evaluate 就开始 → output 不正确。

**诊断**：
- 测 reset phase 持续时间是否 ≥ 5 × precharge τ
- 时钟 non-overlap 间隔
- M_tail 关断 vs M_p_pre 导通的时序顺序

**修复**：
- reset phase ≥ 5 × τ_pre（典型 100-500 ps）
- non-overlap 间隔 ≥ 50-100 ps
- 时钟 phase generator 严格设计 + 仿真验证

---

## 症状 5：电源耦合（VDD spike 影响输出）

**表现**：电源 noise 100 mV → 输出错误率上升（spurious flips）。

**物理因果**：
- VDD 跳变通过 PMOS Cgs 耦合到 di+/di- 节点
- 不对称耦合 → di+ 与 di- 不平衡 → regen 错误方向

**修复**：
- 大量 bypass cap 在 StrongARM VDD pin（≥ 100 pF MOM 紧邻）
- VDD 单独 LDO（不与数字共享）
- layout 对称（di+ / di- 完全对称的 metal stack）

---

## 关联 skill（诊断思维过程）

Comparator-latch 诊断框架：
- **沿信号路径反推**：用 skill `circuit-method/signal-tracing`（"offset 主源？metastability 频率？kickback 路径？"）
- **根因优先**：用 skill `meta-cognitive/systematic-debugging`（不要先调 W，先确认根因）

特定症状的"是谁决定"指引：
- offset 不对 → input pair Vth 失配 vs β 失配 vs 寄生 Cdb 失配
- metastability → τ_reg vs T_evaluate 比例
- kickback → Cgd × ΔV_internal / C_source 链
- 时序错 → reset phase 时长 vs precharge τ
- 电源耦合 → VDD bypass + layout 对称性

## 不在本章范围

- StrongARM / static / dynamic latch 详细 → 对应 chapter
- 完整 ADC offset 校准 → ADC 系统 + DSP knowledge
- 时钟 non-overlap 生成 → 时钟分配 knowledge
- 数字 setup/hold 严格分析 → digital timing analysis
- VCO/PLL 内 PFD（用相位检测不是比较）→ `systems/pll`
