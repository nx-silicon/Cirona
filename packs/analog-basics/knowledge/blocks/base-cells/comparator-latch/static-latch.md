---
chapter: static-latch
parent: comparator-latch
summary: |
  静态锁存（static latch）—— 双稳态交叉耦合 / 持续供电 / 数字接口 /
  无 clock 也能保持 / 与 dynamic / StrongARM 区分
tokens: ~600
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
related_knowledge: []
---

# 静态锁存（Static Latch）

## 拓扑（双稳态交叉耦合 inverter）

```
                  VDD
                   │
            ┌──────┴──────┐
            │             │
       ┌────┴────┐   ┌────┴────┐
       │  P1     │   │  P2     │ ← 两个互补 inverter
       └────┬────┘   └────┬────┘
            │             │
            ●──────╳──────● ← 双稳点（cross-coupled）
            │             │
       ┌────┴────┐   ┌────┴────┐
       │  N1     │   │  N2     │
       └────┬────┘   └────┬────┘
            │             │
            └──────●──────┘
                   │
                  VSS

   Q ──────●               ● ──── Q_bar
            (双稳态保持点)
```

**核心机制**：两个 inverter 头尾相连构成双稳态网络。
- 状态 A：Q = VDD, Q_bar = 0
- 状态 B：Q = 0, Q_bar = VDD
- 两状态都是稳定平衡点；中间态（Q = Q_bar = VDD/2）是不稳定平衡 → 任何扰动会推到 A 或 B

## 与 dynamic latch / StrongARM 区分

| 维度 | Static latch | Dynamic latch | StrongARM |
|---|---|---|---|
| 信号输入 | 数字（rail-to-rail） | 数字 | 模拟差分（mV 级）|
| 时钟需求 | 无（输入直接驱动）| 必需 | 必需 |
| 静态电流 | 持续（cross-coupled inverter 都偏置）| ~0 | 0（仅时钟）|
| 保持时间 | 永久（只要供电）| 受 leakage 限（µs 级）| 1 个时钟 phase |
| 速度 | 由 inverter 边沿决定（典型几百 ps）| 高 | 极高（tens of ps）|
| 应用 | digital flip-flop / SRAM cell | clock-gated dynamic logic | ADC 比较 |

## 应用场景

✅ **典型应用**：
- **D Flip-Flop / SR Latch / RS Latch**：数字逻辑标准库
- **SRAM cell**（6T cell 是 cross-coupled inverter + 2 access transistors）
- **Schmitt trigger** + latch（hysteresis 设计）
- 长时间数据保持（power-gated 设计中保留 retention state）

❌ **不适合**：
- 高速比较器（用 StrongARM）
- 低功耗 clock-gated logic（用 dynamic latch）
- 模拟比较（输入 < rail-to-rail，不能直接驱动）

## 关键性能（事实）

### 静态电流（持续功耗）

```
I_static ≈ I_subVth_inverter + I_leak
       
@ 180nm typical: I_static = 几 nA / inverter
@ 65nm: 几十 nA - 几百 nA（leak 显著）
```

→ 大型 cell（SRAM 阵列）leak 是主要功耗。

### Setup / Hold time（数字时序约束）

D flip-flop 用 master-slave 结构（两 latch 串联）：
- **Setup time**：CK 上升前 D 必须稳定的时长
- **Hold time**：CK 上升后 D 必须保持的时长

典型 @ 180nm：t_setup = 100-300 ps / t_hold = 50-200 ps。

### Metastability（数字 latch 也会有！）

如果 D 在 setup/hold window 内变化 → latch 进入 metastable 状态：
- Q 输出停留在中间态
- 最终概率 50/50 落到某状态
- **解决时间** τ_resolve 服从指数分布

→ 数字设计要求"clock domain crossing"用同步器（多级 FF），降低 metastability 概率。

## sizing 关系（数字 sizing 通用）

| 量 | 取值 | 因果 |
|---|---|---|
| W_pmos / W_nmos | 2-3× | 平衡 inverter 上下沿驱动 |
| L | min L | 速度优先 |
| W 总 | 由驱动需求决定（fan-out / load）| 标准库 cell sizing |

注：static latch 是数字电路 base-cell，详细 sizing 参考数字标准库设计 guideline。

## 验证清单（数字标准 + 模拟特别）

- [ ] tran：上电后双稳态正确（无中间态停滞）
- [ ] tran：输入触发后切换正确（无毛刺）
- [ ] PVT corner：FF/SS 下保持时间充足
- [ ] noise：电源 noise 是否会破坏双稳态（典型 spec：电源 200 mV 跳变不破坏 hold）
- [ ] ESD：输入端 ESD 保护

## 常见误区

| 心里想 | 现实 |
|---|---|
| "static latch 没静态功耗" | 错——cross-coupled inverter 在工艺角下有 sub-Vth 漏电 + 短路电流 |
| "static latch 等于 dynamic latch" | dynamic latch 用 clock 充电节点保持，static 用持续 inverter 反馈；机制不同 |
| "static latch 用于 ADC 比较" | static latch 输入是数字信号；模拟比较用 StrongARM |
| "metastability 只是模拟问题" | 数字 latch 也有，setup/hold window 内输入变化会触发 |

## 不在本章范围

- StrongARM 动态比较器 → chapter `strongarm`
- dynamic latch（clock-gated）→ chapter `dynamic-latch`
- 故障 debug → chapter `troubleshooting`
- 数字 flip-flop 详细 sizing / setup-hold 时序 → 数字 standard cell library knowledge
- SRAM cell 完整设计（6T / 8T / 读写余量）→ memory IP knowledge
