---
chapter: dynamic-latch
parent: comparator-latch
summary: |
  动态锁存（dynamic latch）—— clock-driven 预充电 + 评估 / 比 static 省功耗 /
  leakage 限制保持时间 / 用于 dynamic logic 链
tokens: ~500
prerequisite_chapters:
  - static-latch
related_skills:
  - circuit-method/device-sizing
related_knowledge: []
---

# 动态锁存（Dynamic Latch）

## 拓扑（clock 驱动的双相）

```
                    CK
                     │
         ┌───────────┼───────────┐
         │ φ1=Low    │  φ2=High  │
         │  Precharge│  Evaluate │
         └───────────┼───────────┘
                     │
                ┌────┴────┐
                │ M_p_pre │  ← clock-driven precharge PMOS
                │  PMOS   │
                └────┬────┘
                     ●─── Out（保持节点）
                     │   ↑
                ┌────┴────┐  evaluate path（pull-down logic）
       In ────→│  M_eval │
                │  NMOS   │
                └────┬────┘
                     │
                CK ──┤  M_n_clk  ← evaluate clock NMOS
                     │
                    VSS
```

**核心机制**（PMOS precharge + NMOS clock 拓扑：CK 低位 precharge / CK 高位 evaluate）：
- **Phase 1 (CK = low → φ1, precharge)**：M_p_pre 导通，M_n_clk 关断 → Out 充电到 VDD（precharge），evaluate path 切断
- **Phase 2 (CK = high → φ2, evaluate)**：M_p_pre 关断，M_n_clk 导通 → 若 In 为 high → Out 经 M_eval / M_n_clk 放电到 VSS；In 为 low → 节点 Out 仅靠寄生电容保持 VDD（保持时间受 leakage 限）

→ 输出值反映了 evaluate phase 期间 input 的逻辑功能。Out 节点是 dynamic node（无 keeper），不是独立 hold 相；保持时间靠节点电容 + 漏电流决定。

## 与 static latch 区分

| 维度 | Static latch | Dynamic latch |
|---|---|---|
| 节点保持机制 | cross-coupled inverter 持续反馈 | 节点 C 上的电荷储存 |
| 静态电流 | 持续（subthreshold + 短路）| ~0（仅泄漏 + 时钟动态）|
| 保持时间 | 永久（电源不断）| **有限**（leakage 限制 µs-ms 级）|
| 时钟需求 | 无 | **必需** |
| 应用 | flip-flop / SRAM cell | dynamic logic / clock-gated 流水 |

## 适用场景

✅ **典型应用**：
- **Domino logic / NORA logic**：dynamic CMOS 高速链
- **Clock-gated retention**：低功耗 SoC 中休眠状态保持
- **Dynamic D flip-flop**：高速时钟域（一般是用 master-slave dynamic 结构）
- **Pulse latch**：CPU 流水线寄存器替代 master-slave FF

❌ **不适合**：
- 长时间保持（> ms）→ leakage 让节点电压漂；用 static latch
- 不可时钟控制场合 → 需要静态时钟使能

## 关键性能（事实）

### Leakage 限制保持时间

```
T_hold_max ≈ V_node × C_node / I_leak

@ 180nm typical I_leak = 1 nA / C_node = 50 fF / V_node = 1V → T_hold ≈ 50 µs
@ 65nm I_leak = 100 nA / C_node = 20 fF / V_node = 1V → T_hold ≈ 200 ns
```

→ 工艺越先进，保持时间越短（leak 增 100×）。

### 速度（vs static）

dynamic latch 通常更快：
- pull-down 路径（NMOS 链）只需要 logic 评估，无 cross-coupled 反馈
- 典型 evaluate time = 几十 ps - 几百 ps（depends on logic depth）
- 适合高频时钟链（GHz 级）

### Charge sharing 问题

如果 evaluate path 中有内部节点（中间 NMOS 节点），上一周期残留电荷可能错误放电 Out：
```
若 V_internal_residual >> 0 + V_out_precharged → Out 部分被拉低
```

→ 必须在 logic 中加 **keeper transistor**（弱 PMOS feedback）或仔细管理 charge sharing。

## sizing 关系

| 量 | 取值 | 因果 |
|---|---|---|
| M_p_pre | 大 W（快 precharge）| precharge time = C_node / (I_pre × Vov) |
| M_n_clk | 适中（不太大也不太小）| 太大 → 寄生 par；太小 → evaluate 慢 |
| evaluate path 中各 NMOS | 平衡（大 W 速度，小 W 节省）| logic 设计（数字 path） |
| Keeper PMOS（如有）| **小**（< 1/10 evaluate NMOS 强度）| 强 keeper 会阻碍 evaluate |

## 验证清单

- [ ] tran：CK low → Out 充电到 VDD
- [ ] tran：CK high + In high → Out 放电到 VSS
- [ ] tran：CK high + In low → Out 保持（看 leakage drift）
- [ ] tran：保持时间长 phase 测 droop 速率
- [ ] PVT corner：FF/SS 下 leakage / Vth 漂移影响保持
- [ ] noise：电源 spike 通过 Cgd 影响 Out 节点

## 常见误区

| 心里想 | 现实 |
|---|---|
| "dynamic latch 没静态功耗" | 几乎；但时钟驱动的 CV²f 在高频下显著 |
| "dynamic 永远比 static 快" | 不一定——如果 logic 深度大 + charge sharing 严重 → 速度反而劣于优化 static |
| "dynamic latch 适合所有保持场合" | 错——leakage 限保持时间，要长保持必须 static 或加 refresh |
| "keeper 越强越好" | 错——keeper 强会让 evaluate 失败；典型 keeper 是 evaluate 路径的 1/10 强度 |

## 不在本章范围

- StrongARM（模拟比较）→ chapter `strongarm`
- static latch（持续保持）→ chapter `static-latch`
- 故障 debug → chapter `troubleshooting`
- domino / NORA / dynamic CMOS 完整设计 → 数字 high-speed logic knowledge
- pulse latch / time-borrowing → CPU 流水线 knowledge
