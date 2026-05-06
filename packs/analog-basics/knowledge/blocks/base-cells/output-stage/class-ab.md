---
chapter: class-ab
parent: output-stage
summary: |
  Class-AB 输出级 —— 偏置展开网络 / Iq 控制 / 交越失真 / 短路电流 / 自适应偏置 /
  PVT tracking / gm/Id sizing 全流程
tokens: ~900
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/source-follower
  - blocks/base-cells/bias-generator
  - blocks/base-cells/miller-compensation
---

# Class-AB 输出级

> **Class-AB 是偏置策略，不是单一拓扑**——它可以套在互补 SF 或互补 CS 任一拓扑之上。
> 本章主以**互补 SF + 偏置展开**作为讨论起点（最经典 class-AB 实现）；
> 互补 CS 的 Class-AB 化在 [push-pull](./push-pull.md) 章节末讨论。

## 拓扑：互补 SF + 偏置展开 spreader

**关键结构提醒**：互补 SF 的 drain 接 rail / source 接 V_out（不是漏极共点输出，那是 CS）。

```
        VDD ──────────┐  (NMOS drain 接 VDD)
                      │
                  ┌───┴───┐
        Vbias_n ─→│  Mn   │  (NMOS SF 上拉; Vbias_n = Vin + Vgs_n)
                  │ NMOS  │
                  └───┬───┘
                      ●─── V_out  (Mn.source / Mp.source 共点)
                  ┌───┴───┐
        Vbias_p ─→│  Mp   │  (PMOS SF 下拉; Vbias_p = Vin - |Vgs_p|)
                  │ PMOS  │
                  └───┬───┘
                      │
        VSS ──────────┘  (PMOS drain 接 VSS)

        spreader 在 Vbias_n 与 Vbias_p 之间产生 Vspread = Vgs_n + |Vgs_p|
        （static 时两管同导通 Iq；中间节点 = Vin = V_out）
```

**核心机制**：spreader 在两 gate 间维持固定电压差 `Vspread = Vgs_n(Iq) + |Vgs_p(Iq)|`。静态 Iq_n = Iq_p = Iq；大信号 Vin ±ΔV → 两 gate 同步移动 → 一管深导通另一管浅导通 / cutoff → 提供 Imax ≫ Iq 的瞬时驱动电流。

## Class A vs Class AB 关键对比

简表（详细对比见 [push-pull.md](./push-pull.md)）：
- Class A：Iq = Ibias（大），单方向 SR 受限，无交越失真，效率 ~25%
- Class AB：Iq ≪ Imax，双向 SR = Imax/Cload，**有**交越失真（需 Iq 控制）/ shoot-through，效率 ~78.5%

**关键洞察**：opamp / SC 电路输出 buffer 中，Class-A 单方向 SR 常是瓶颈 → Class-AB 双向大电流解决。

## 偏置展开网络（spreader 实现）

### A. Diode-connected 偏置对（最常用 / 默认）

```
                 Iref（参考电流，由 bias chain 提供）
                  │
                  ▼
              ┌───────┐
       Vbias_n│  Md_n │  (diode-connected NMOS, 与输出 Mn 同型同尺寸)
              └───┬───┘
                  ● ←── 中间节点 = Vin（信号输入）
              ┌───┴───┐
       Vbias_p│  Md_p │  (diode-connected PMOS, 与输出 Mp 同型同尺寸)
              └───────┘
                  │
                 Iref 流回 / 接到 sink
```

**关键尺寸约束（PVT tracking 硬要求）**：

> ⚠️ **diode 偏置管必须与输出管同尺寸（W=W_out / L=L_out）**。
> 这是 PVT tracking 的硬要求——V_th(W,L,T,corner) 在 diode 管和输出管间漂移方向同步，
> 才能让 Vspread 自动跟随 V_th 变化，保 Iq 稳定。
> **不能通过单独改 diode 管 W 来调 Iq**——那会破坏 tracking。

**Iq 通过 mirror 比例 m 决定**（而不是改 W）：

```
Iq_out = Iref × (m_out / m_diode)     # m 是 multiplicity / 并联指数

例：m_diode = 1, m_out = 10, Iref = 5 µA
    → Iq_out = 5 µA × 10 = 50 µA
    （输出管的 W·m 是 diode 管的 10 倍，相同 Vgs 下流 10 倍电流）
```

| sizing 决策 | 含义 | 因果 |
|---|---|---|
| 输出管 W / L | 由 SR / Imax 决定 | 详见后文 sizing 关系 |
| diode 管 W / L | **= 输出管 W / L**（强制相同）| PVT tracking |
| Iq 量值 | 由 Iref 和 m_out / m_diode 比例决定 | 改 Iref 或改 m_out 来调 Iq |
| W 整体放大（输出+diode 同步）| 调 **Class-A vs Class-B 程度**（不是直接调 Iq）| W ↑ → Vov ↓ → 偏置点更接近 cutoff → 越偏 Class-B（导通余量小，瞬态切换敏感）；W ↓ → Vov ↑ → 越偏 Class-A（深导通） |
| Layout 邻近 + matching | 减小 ΔVth 失配 | Pelgrom σ ∝ 1/√(WL)；mismatch 直接转 Iq 偏差 |

### B. 浮动电压源（floating voltage source / Vbe-stack spreader）

```
Vspread 由独立的 floating Vbe stack 或 floating MOS-Vgs stack 产生
（不是用电流源直接夹在两高阻 gate 之间——那行不通，gate 是高阻节点，
   单独一个理想电流源无法定义高阻节点电压）
```
- 实际实现：电流源 + 多个串联 diode-connected MOS（构成 floating Vbe stack）
- 优点：可独立调整 Vspread（不强制 diode 与输出管同尺寸）
- 代价：占 layout 面积，PVT tracking 需额外设计

### C. 自适应偏置（adaptive bias）

Iq 随输出电流动态变化：小信号 Iq 小（省功耗）/ 大信号 Iq 大（保 gm）。实现复杂（min-selector 反馈），适合极低功耗 + 偶发大驱动场景（音频 / wireless TX driver）；本 cell 不展开。

## Iq 选择（事实 + 因果）

**下限**：避免死区 + 控交越失真
- Iq ≥ 10 × 输出管亚阈值漏电流（避免完全 cutoff）
- 量化目标：零交叉处 (gm_P + gm_N)_min × R_load 决定 THD_crossover

**上限**：静态功耗预算
- P_static = VDD × Iq

**典型范围**：Iq = 0.05 × ~ 0.2 × Imax（更保守 0.1 × 是好默认）。

**因果链**（Iq → 交越失真）：
- Iq ↑ → 静态 gm_min ↑ → 零交叉处增益不掉 → THD ↓
- 但 Iq ↑ → P_static ↑ + shoot-through 风险 ↑ → trade-off

## Sizing 关系（事实 + 因果，gm/Id 方法）

**核心推导链**：spec → Imax → 输出管 W/L → Iq 通过 m 比例反推 Iref。

### Sizing 关系表

| 量 | 公式 / 关系 | 因果 |
|---|---|---|
| Imax | SR_spec × Cload | spec 直接决定；对称设计 source = sink |
| 输出管 Vov | 由 gm/Id @ Imax 决定（典型 gm/Id = 5-10 强反型 → Vov 200-400 mV） | gm/Id 越小 → Vov 越大 → Vdsat = Vov 越大 → 摆幅压缩 |
| 输出管 Id/W | gm/Id 表 lookup（不要套公式）；若用长沟道近似：Id/W = 0.5·μCox·(1/L)·Vov² | 公式只在 long-channel approx 下成立；短沟道用查找表 |
| 输出管 W | Imax / (Id/W) | NMOS：W_n_out；PMOS：W_p_out = (μn/μp) × W_n_out（对称 SR）|
| 输出管 L | 4-8 × Lmin | matching + ro 增 → distortion 改善；过大则 Cgs ↑ 影响前级驱动 |
| diode 偏置管 W / L | **= 输出管 W / L**（强制相同，PVT tracking）| 见上文 §A 硬要求 |
| Iref_diode | 由 Iq 反推：Iref = Iq × (m_diode / m_out) | 例 Iq = 50 µA、m_out:m_diode = 10:1 → Iref = 5 µA |
| Iq 调节（设计 / debug）| 改 **Iref** 或 **m_out:m_diode** 比例 | **不要** 改 diode W（破坏 tracking） |
| Class-A 偏多 vs Class-B 偏多 | 整体 W ↑↓（输出 + diode 同步）| W ↑ → Vov ↓ → spread Vbias 收窄 → 偏置点接近 cutoff → 偏 Class-B；W ↓ → 偏 Class-A |

### 验证项

- `.op` 仿真 → Mp / Mn 静态 Id = Iq_target ± 20%
- PVT corner（FF/SS, -40°C / 125°C）→ Iq 漂 < ±30%
- 大信号 PM 验证：tran 阶跃后 gm 跑到 Imax 处取最大；此 gm 下重 AC 测 PM ≥ 60°
- 不达标 → 加 Cc Miller / 改 nested Miller（见 `blocks/base-cells/miller-compensation`）

## Sizing 范例（OPamp 输出 buffer）

> 📌 **@ vpdk180nm @ 3.3V IO**（nch_33/pch_33 模型）。

设计目标：
- VDD = 3.3 V / Cload = 100 pF / SR_spec = 5 V/µs
- 摆幅 0.2 - 3.1 V（≈ rail-to-rail 减 200mV headroom 各侧）
- I_quiescent ≤ 50 µA / THD < -60 dB @ 1 V_pp

**derivation chain**：
```
Imax: SR × Cload = 5e6 × 100e-12 = 0.5 mA
Iq_target: 50 µA = 0.1 × Imax（典型 AB 比例）

输出管 sizing（gm/Id 表 lookup，不要套长沟道公式）:
  NMOS Mn（输出）:
    - 选 gm/Id = 8 @ Imax = 0.5 mA（强反型，速度优先）
    - 查 gm/Id 表（@ 180nm vpdk）→ Id/W ≈ 25 µA/µm
    - 总 W_n_total = Imax / (Id/W) = 500 / 25 = 20 µm
    - 取 m_n_out = 10 → W_unit_n = 2 µm（每 finger）
    - L = 1 µm（4 × Lmin matching + Vds_modulation 改善）

  PMOS Mp（输出）:
    - μn / μp ≈ 2.5 → 总 W_p_total ≈ 50 µm（保 SR 对称）
    - 取 m_p_out = 10 → W_unit_p = 5 µm（每 finger）
    - L = 1 µm

偏置 diode 对（用户洞察：unit 尺寸必须与输出管同 W、同 L）:
  Md_n: W = 2 µm, L = 1 µm（**= W_unit_n**，单 finger）
  Md_p: W = 5 µm, L = 1 µm（**= W_unit_p**，单 finger）
  m_diode_n = m_diode_p = 1

Iq 通过 m 比例决定:
  Iq_out = Iref × (m_out / m_diode) = Iref × (10 / 1) = 10 × Iref
  目标 Iq = 50 µA → Iref_diode_branch = 5 µA

Vspread 验证（@ Iref = 5 µA in diode pair）:
  - Vgs_n_diode @ 5 µA in W=2µm → Vth_n + Vov ≈ 0.5 V
  - |Vgs_p_diode| @ 5 µA in W=5µm → ≈ 0.55 V
  - Vspread = Vgs_n_diode + |Vgs_p_diode| = 1.05 V
  - 输出管单 finger 在此 Vspread 下 → I_per_finger = 5 µA → Iq_out = 5 µA × m_out = 50 µA ✓（PVT 自动跟踪）
```

**调节策略示例**（Iq 设计变更）:
- Iq 想从 50 µA 降到 30 µA → 改 Iref 从 5 µA → 3 µA（**不动 W**）
- Iq 想从 50 µA 加到 100 µA → 改 m_out 从 10 → 20 + Iref 不变；或 Iref 提到 10 µA 不改 m
- 想偏 Class-B 多一些（应对 shoot-through / 减小导通重叠）→ 整体 W ↑（输出 + diode unit 同步增大）→ Vov ↓ → 偏置点更接近 cutoff，保 PVT tracking；Iq 量值仍由 Iref 和 m 比例决定

## 验证清单

- [ ] dc_snapshot：Mp / Mn 静态 Id = Iq_target ± 20%
- [ ] dc_snapshot：偏置 diode 对在 saturation
- [ ] op_point_check：输出管 Vds 在 spec 内（看 swing 是否够）
- [ ] PVT corner（FF/SS/温度）：Iq 漂移 < ±30%
- [ ] tran：阶跃响应 SR_up / SR_down 满足 spec（注意 PMOS 驱动 source up 慢一些）
- [ ] tran：完整环路 settling 不振铃（最坏 gm 下 PM ≥ 60°）
- [ ] tran：检查 IDD 在过渡瞬间不超 5 × Iq（shoot-through 限）
- [ ] MC：Iq 分布 σ < 30% / 交越对称性 < 5% mismatch

## 常见误区（self-check）

| 心里想 | 现实 |
|---|---|
| "输出管 W 小一点省面积" | W 由 SR / Imax 决定，**不是**小信号增益；W 不够 SR 直接挂 |
| "Iq 越小越省电越好" | 太小 → 死区 → THD 飙升；典型 0.05-0.2 × Imax 是平衡点 |
| "用理想电压源给 Vspread" | 没 PVT tracking → V_th 温漂让 Iq 漂 ±30%（必须用 diode 对，diode 与输出管同尺寸）|
| "改 diode 管 W 来调 Iq" | 破坏 PVT tracking！调 Iq 应改 Iref 或 m 比例，diode 管尺寸必须 = 输出管 |
| "静态 PM ok 就行" | Class-AB gm 大信号 ≫ gm_q → 大信号 PM 才是临界 |
| "PMOS / NMOS W 取相同" | μ 不对称 → Imax 不对称 → SR 上下不对称 |
| "Miller 补偿按静态 gm 算" | 必须按 gm_max（大信号）算 Cc，否则大信号失稳 |

## 不在本章范围

- 互补 SF vs 互补 CS 拓扑结构对照 → chapter `push-pull`
- Iq 漂移 / shoot-through / 大信号 PM debug → chapter `troubleshooting`
- gm/Id 表 / Vov 选 / Vth(L) 工艺数据 → `devices/bsim4` / `pdks/<工艺>/`
- LDO pass FET 整体设计（含反馈环）→ `blocks/ldo/architecture.md`
- 二级 OTA 第二级 Miller 补偿 → `blocks/base-cells/miller-compensation`
