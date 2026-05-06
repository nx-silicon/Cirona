---
chapter: replica
parent: bias-generator
summary: |
  Replica 偏置 —— 复制目标支路的工作点 / 反馈钉住 V_drain / PVT tracking 优于普通 mirror /
  常用于高精度 LDO pass FET 偏置 / cascode bias generation
tokens: ~600
prerequisite_chapters:
  - basic-mirror-tree
related_skills:
  - circuit-method/bias-tree-reasoning
  - circuit-method/ac-feedback-loop-method
related_knowledge: []
---

# Replica 偏置

## 拓扑（用 OTA 反馈复制目标工作点）

```
                  VDD
                   │
          ┌────────┴────────┐
          │                 │
    ┌─────┴─────┐     ┌─────┴─────┐
    │ M_main    │     │ M_replica │← 与 main 同尺寸 + 同 region
    │ (主支路)  │     │ (replica) │
    └─────┬─────┘     └─────┬─────┘
          ●─── V_main_actual    ●─── V_target_replica
                                     │
                              ┌──────┴──────┐
                              │ V_REF       │
                              │             │
                              ▼             ▼
                              ┌─────────────┐
                              │  EA (OTA)   │← 比较 replica 与 V_REF
                              └──────┬──────┘
                                     │
                                     ▼ vbias_out → 给 main 支路 gate
                                     
                              （反馈环：钉住 V_replica = V_REF）
```

**核心机制**：
- M_replica 与 M_main 同尺寸 + 同 region → 工作点完全跟踪
- EA 比较 V_replica 与 V_REF → 输出 vbias_out 调节 main + replica 共用 gate
- → V_replica = V_REF（精确）→ V_main_actual 也跟随（因 replica 与 main 完全 mirror）

**与 basic mirror 区别**：
- basic mirror 只复制电流（Iout = Iref × m_ratio）
- replica 复制**完整工作点**（V_drain + region + Vov），所以更精确跟踪 PVT

## 常见应用

### LDO pass FET 偏置（最经典）

```
        VDD
         │
       Vin（输入电压）
         │
      M_pass（PMOS pass FET）
         │
         ●─── V_out_LDO（反馈到 EA-）
         │
        负载

replica 支路：
       M_pass_replica（小尺寸缩比版）
         │
         ●─── V_replica（钉到 V_out_LDO 目标值）
       缩比电流源
         │
        VSS
```

EA 比较 V_replica 与 V_REF → 调 M_pass gate → V_out_LDO 跟踪 V_REF。

### cascode bias 生成（精确 vbpc/vbnc）

```
M_cascode_replica + M_pad_replica 串联（与主电路 cascode 完全镜像）
EA 钉住 replica 的 V_drain_pad = 目标 vbias_target
→ 输出 vbpc 给主 cascode 支路
```

→ replica 比简单 padding device mirror 准确 10-100 倍（因 EA loop gain）。

## sizing 关系

| 量 | 推荐 | 因果 |
|---|---|---|
| M_replica 尺寸 | M_main 的 1/N（N = 缩比因子，10-100）| 复制电流是 N 倍缩；电流小省功耗 |
| EA 增益 A | 30-60 dB | 高 A → 钉准；过高引入稳定性问题 |
| EA BW | < 主电路 BW 的 1/3 | 避免 replica 反馈环与主信号通路耦合 |
| M_replica L | = M_main L（必须）| L 不同 → V_th(L) 不一样 → tracking 失败 |

## 稳定性约束（关键）

replica 是反馈环 → **必须保 PM ≥ 60°**。

主极点：通常在 EA 输出节点（vbias_out）：
```
fp_main = 1/(2π × Rout_EA × C_gate_main)
```

次极点：M_replica drain 节点：
```
fp_2 = 1/(2π × ro_replica × C_drain_replica)
```

**修复**：
- EA 输出加 Cc Miller → 主极点低 → PM 改善
- 减 EA bandwidth（减 EA bias）→ 但 BW 也降

## 典型范例（LDO replica bias）

设计目标：LDO V_out = 1.2 V / V_in = 1.8 V / Iload_max = 100 mA / replica 缩比 100×

```
M_pass: PMOS, W = 1000 µm, L = 0.18 µm, Iload_max = 100 mA
M_pass_replica: W = 10 µm, L = 0.18 µm（**L 必须同 main**）
  Iload_replica = 1 mA（100× 缩；replica 1 mA 偏大，常见做法是 1000-10000× 缩到 µA 级
                      省 Iq；100× / 1mA 此处作为高精度 + 大电流案例展示）

EA: 5T-OTA，A = 50 dB, BW = 1 MHz（设计要远低于 LDO 主环 BW 100 MHz）
  - bias = 5 µA / Vov = 0.15 V

PM 验证:
  fp_main_EA = 1/(2π·Rout·Cc) = 1/(2π·1M·2p) = 80 kHz
  GBW_EA = A·fp = 316·80k = 25 MHz （应远小于 LDO 主环 BW 100 MHz ✓）
  次极点（M_pass_replica drain）= 1/(2π·1M·100f) = 1.6 MHz
  → 主次极点距离 20×，PM ≈ 75° ✓
```

## 验证清单

- [ ] dc_snapshot：V_replica 钉在 V_REF ± 5 mV
- [ ] dc_snapshot：M_replica + M_main 同 region（saturation）
- [ ] AC：replica loop PM ≥ 60°（断环测）
- [ ] AC：主电路 BW vs replica EA BW 距离 ≥ 3×
- [ ] PVT corner：V_replica 跟踪 V_REF ± 1%
- [ ] tran：负载阶跃 → main 支路工作点稳定（replica 反馈跟随）

## 常见误区

| 心里想 | 现实 |
|---|---|
| "replica 不需要稳定性分析" | 错——是反馈环，必须断环测 PM |
| "M_replica L 可以小一点节省" | 错——必须与 main 同 L（V_th(L) tracking）|
| "EA BW 越高越好" | 错——必须远低于主电路 BW，避免双环耦合 |
| "replica = replica regulation" | replica 是 bias 复制；regulation 是反馈电压控制；前者是后者的常用机制 |

## 不在本章范围

- 基础镜像树 → chapter `basic-mirror-tree`
- β-multiplier 自偏置 → chapter `beta-multiplier`
- LDO 整体设计 → `blocks/ldo/`
- EA（OTA）内部设计 → `blocks/5t-ota/`
- 反馈环 PM 通用方法 → skill `circuit-method/ac-feedback-loop-method`
