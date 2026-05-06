---
chapter: physical-constraints
parent: bandgap
summary: |
  片内集成电路物理约束 cheat sheet — 片内电容尺寸上限 / 片内电阻量级 /
  AC 接地哲学 / 工艺常数实测必备清单 / 启动时间 vs 电容耦合约束。
  本章是 Demo 01 v6 实战盲区补丁（v6 浪费 ~55 turn / 57% 在违反这些物理约束的方案上），
  规则跨多 chapter 适用，避免在 architecture / sizing / troubleshooting 单独重复。
  注：本章是 bandgap 范围下的横切补丁；V4.5 P1 计划升级为全 PACK 共享章。
tokens: ~600
prerequisite_chapters: []
related_skills:
  - meta-cognitive/verification-before-completion
related_knowledge:
  - blocks/base-cells/bias-generator
---

# Bandgap Physical Constraints (cross-cutting)

> 这一章是给 LLM agent 的"什么不能做"清单，不是设计步骤。Demo 01 v6 案例显示，
> agent 在 sizing 时会盲选 100nF 片内电容、把 Cac 接到 VDD 等违反物理约束的方案 ——
> 这些**不是 sizing 数值问题，是物理边界问题**。

## 1. 片内电容尺寸约束（Iron Law）

| 容值范围 | 片内可行性 | 说明 |
|---|---|---|
| < 1 pF | ✅ 容易 | MOM/MIM 电容，极小面积 |
| 1 ~ 10 pF | ✅ 常见 | 标准模拟设计范围 |
| 10 ~ 50 pF | ⚠️ 可以但已大 | 面积可观，需评估 layout area |
| 50 ~ 100 pF | ⚠️ 极罕见 | 仅特定电源芯片（LDO/DCDC）外挂 pin |
| **100 pF ~ 1 nF** | 🛑 **片内基本不可** | 等同于方案错误 |
| **1 nF ~ 100 nF** | 🛑 **完全不可能** | 100nF ≈ 0.1 mm² 面积（@ 1fF/µm²），相当于一整个模块 |

**重要**：仿真中加 100nF "通了"是 SPICE 不管面积；tapeout 时 layout 工程师会**直接否决**。

**改善 PSRR 的被动元件方案的电容上限约 10pF**。要更高 PSRR 必须改拓扑（cascoded /
beta-multiplier / post-LDO）。

## 2. 片内电阻量级（Soft Iron）

| 阻值范围 | 片内可行性 | 适用 |
|---|---|---|
| < 1 kΩ | ✅ 容易 | poly-R / silicide |
| 1 kΩ ~ 100 kΩ | ✅ 常见 | poly-R 主体 |
| 100 kΩ ~ 1 MΩ | ⚠️ 大 | 高 sheet R poly / pinch-R |
| 1 MΩ ~ 10 MΩ | ⚠️ 极大 | 慎用，layout 走线成串 |
| > 10 MΩ | 🛑 用 MOS resistor 或 sub-Vth | 不能用普通 R |

bandgap 内典型最大 R：`R_START = 500 kΩ - 2 MΩ`（startup helper），`R_BIAS = 2 MΩ`
（OTA self-bias）—— 这是 bandgap 拓扑的物理上限附近。

## 3. AC 接地方向哲学（Iron Law）

> **AC 改善 = AC 接地（连 VSS）。连 VDD 是跟踪电源 = 抗扰度变差。**

| 目标 | 怎么做 |
|---|---|
| 让 X 节点 AC 隔离电源纹波 | Cac 连 **VSS**（参考地）|
| 让 X 节点跟踪电源（**很少需要**）| Cac 连 VDD |

**Demo 01 v6 实证**：v6 agent 把 Cac=100nF 接 vbpc_p → VDD，**方向反 + 大电容双重错误**，
浪费 ~25 turn。详细机理见 `troubleshooting.md` Mode 13 / `startup.md` Mode 6。

## 4. 工艺常数实测必备清单（Iron Law）

LLM agent 倾向用教科书值快推 sizing。以下常数**禁止抄教科书**，必须 PDK 仿真实测：

| 常数 | 教科书 | vpdk180nm 实测 | 误差影响 |
|---|---|---|---|
| dVbe/dT | -2.0 mV/°C | **-1.776 mV/°C** | 12% → TC 从 20 ppm → 198 ppm（v6 v5 baseline）|
| Vth_n | varies | 实测 | 影响所有 NMOS 偏置 |
| Vth_p | varies | 实测 | 影响所有 PMOS 偏置 |
| µ·Cox (n/p) | varies | 实测 | gm/Id sizing 必查 |
| BJT β / Va | depends | 实测 | bandgap 二阶项 / cascode ro |

**实测方法**：
- dVbe/dT → `sizing-typical.md` Step 4 「如何实测 dVbe/dT」段（已 codify）
- Vth / µ·Cox → V4.5 P1 计划新增 base-cell `bias-generator/process-extraction` chapter
- Va / λ → 见 `blocks/base-cells/cascode` § Va 实测

## 5. 启动时间约束（与电容耦合）

```
任何偏置节点的电容 C 必须满足：
  C / gm_load << t_startup_budget

@ t_startup_budget = 100µs, gm = 10µA/V:
  C << 1 nF（即 < 10 pF 给 10× margin）
```

**Iron Law**：**任何 ≥ 1pF 的电容改动后必须跑 tb_startup tran 验证**，不验等于没改。

详细机理 + 5 个具体 case 见 `startup.md` Mode 6。

## 6. 综合应用 — 改 PSRR 时的物理约束清单

Demo 01 v6 在改 PSRR 时连续违反 4 条约束：

| # | 违反 | 后果 |
|---|---|---|
| 1 | C=100nF 片内（违反 § 1）| 物理不可行 |
| 2 | Cac 连 VDD（违反 § 3）| 方向反，PSRR 退化 |
| 3 | C=100nF + 偏置节点（违反 § 5）| τ=10ms 破坏启动 |
| 4 | 想把 PSRR 从 37dB 改到 60dB 但不改拓扑 | 拓扑上限 ≠ trim 可达 |

**正确的 PSRR 改进决策树**：
```
spec PSRR ≤ 40 dB → R_BIAS + NMOS-diode OTA + L_P 增到 1µm 即可（first-order baseline）
spec PSRR 40-50 dB → 加 PMOS mirror cascode（loop-stability.md 范例 2）
spec PSRR 50-60 dB → 改 OTA 偏置为 beta-multiplier 自偏置（架构重设计）
spec PSRR 60-70 dB → 上述 + cascoded everywhere
spec PSRR > 70 dB → bandgap 后接 LDO 二级（系统级）
```

被动元件（cap / resistor）只在 ≤ 10pF 范围且接 VSS 时**有限改善 high-frequency PSRR**，
DC PSRR 由 loop gain × ro 决定，**任何 cap 都改不了 DC PSRR**。

## 不在本章范围

- **gm/Id sizing 通用方法** → skill `device-sizing`
- **Process extraction 详细脚本**（Vth / µ·Cox / Va）→ V4.5 P1 计划新增 base-cell chapter
- **拓扑级 PSRR 上限完整表（含具体偏置选项）** → `loop-stability.md` 范例 2
- **每个 PACK 的 spec_ceiling_table** → 各 PACK 的 `index.md` 头部

## Related

- `troubleshooting.md` Mode 13（Cac 方向错误）
- `startup.md` Mode 6（大电容破启动）
- `loop-stability.md` 范例 2（PSRR 上限随偏置拓扑变）
- `sizing-typical.md` Step 4（PDK 实测 dVbe/dT 操作步骤）
- `index.md` § spec_ceiling_table（拓扑能力上限）
