---
chapter: parasitic-miller
parent: miller-compensation
summary: |
  寄生 Miller 效应 —— Cgd × (1+|Av|) 倍增到输入端 / CS / LNA / 高速放大器主 BW 限 /
  与"故意 Miller 补偿"区分 / 对策（cascode / Ahuja / source-follower buffer）
tokens: ~700
prerequisite_chapters:
  - plain-miller
related_skills:
  - circuit-method/signal-tracing
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/common-source
  - blocks/base-cells/cascode
---

# 寄生 Miller 效应（Parasitic Miller Effect）

> **用户特别要求章节**：除"作为补偿元件"用法外，必须涵盖"寄生 Miller 效应"分析。
> 这是 LNA / 高速模拟设计中**关键现象**，单独章节，严禁与 plain Miller 补偿混为一谈。

## 区分两个 Miller（关键）

| 类型 | "故意"Miller 补偿 | **寄生 Miller 效应** |
|---|---|---|
| 元件 | 显式电容 Cc（fF-pF MOM/MIM）| MOSFET 自身 Cgd（fF 级寄生）|
| 目的 | 频率补偿 / 极点分裂 | **副作用**（不是设计意图）|
| 量级 | 几 pF | 几 fF（但被 (1+Av) 倍增）|
| 影响 | 改善 PM | **限制输入 BW**（输入端 Cin 增大）；在两级/CS 前馈路径中也可能贡献 RHP zero（依传递函数路径而定）|

## 物理机制（Miller 倍增因子）

任何反相增益级（CS / 互补 CS / opamp）都有 Cgd 跨 input 与 output：

```
        V_in ────┤ G ←── M_drv (CS) ────► V_out
                  │ (Cgd 跨 G-D)
                  │
                  Cgd（寄生）
                  │
        V_out ────┴────►
```

**Miller 倍增**：从 V_in 看进去，Cgd 等效**电容**为：
```
C_in_Miller = Cgd × (1 + |Av|)
```

**因果链**：
- 当 V_in 增 ΔV → V_out 减 |Av|·ΔV（反相）
- → Cgd 两端电压差变化 = ΔV - (-|Av|·ΔV) = (1+|Av|)·ΔV
- → 流过 Cgd 的电荷 = Cgd × (1+|Av|)·ΔV
- → V_in 看到等效输入电容 = Cgd × (1+|Av|)

**典型数值**：
- @ 180nm vpdk，CS amp Av = -50（mirror load）
- M_drv: W=10µm, L=0.5µm → Cgd ≈ 0.1·Cox·W·L = 4.3 fF
- C_in_Miller = 4.3f × 51 = **220 fF**（**比单 Cgd 大 50×**）

## 对 BW 的限制（最重要后果）

CS 输入节点的 BW 由 **驱动级 Rout × C_in_Miller** 决定：
```
fp_input = 1 / (2π × R_source × C_in_Miller)
        = 1 / (2π × R_source × Cgd × (1+|Av|))
```

例：R_source = 1 kΩ / Cgd × (1+Av) = 220 fF → fp = 720 MHz（远低于很多场景）。

→ **高速 CS 的 BW 不是被 drain 节点限制，是被 input 节点 Miller 倍增限制**。

## LNA / 高速放大器的 BW 影响

宽带 LNA / 高速 IF 放大器的关键约束：
- 信号源是 50 Ω（终端匹配阻抗）
- 输入节点 BW = 1/(2π·50·C_in_Miller) → 几 GHz 量级
- 若用 CS（增益 -10×）：C_in_Miller = Cgd·11 ≈ 50 fF → BW ≈ 60 GHz（OK）
- 若用 CS（增益 -50×）：C_in_Miller = Cgd·51 ≈ 200 fF → BW ≈ 16 GHz

→ 高增益 CS **同时也压低 BW**——这是 gain-BW product 限制的物理根源（GBW = const）。

## 对策（消除/减小寄生 Miller）

### 对策 1：Cascode（最经典）

CS 上叠一个 cascode 管：
- cascode 把 CS 漏极钉到固定 Vbias → CS drain 摆幅 ≈ 0
- → Cgd 两端 ΔV ≈ ΔV_in（不再被 Av 倍增）
- → C_in_Miller = Cgd × 1（几乎单 Cgd）

**结果**：BW 大幅扩展（典型 5-10×）。这是 cascode 在高速 LNA 中**广泛用的根本原因**——不是为了增益，是为了**消除 Miller 倍增**。

### 对策 2：Source-Follower Buffer

在 CS 之前加 source follower：
- SF 的 Rout = 1/gm（小）→ 驱动 CS input 的 R_source 极小
- → fp_input = 1/(2π·1/gm·C_in_Miller)，1/gm 几百欧 → BW 极高
- 代价：1×Vgs headroom

### 对策 3：Common-Gate（避开 Miller）

用 CG 替代 CS 作输入级：
- CG 的输入是 source（不是 gate）→ 没有 Cgd 反向倍增
- → BW 由 drain 节点 R·C 决定，不被 Miller 影响
- 详见 `blocks/base-cells/common-gate-stage/`

### 对策 4：Neutralization（RF 中常用）

故意加一个反相寄生电容 Cn（典型 cross-coupled NMOS pair）抵消 Cgd：
- LC tank 之上加 cross-coupled pair
- 可消 Miller 90%+
- 仅 RF 窄带

## 高速 LNA 中的实测影响

某 5 GHz cascoded LNA 设计：
- 无 cascode（单 CS）：BW = 1.5 GHz（被 Miller 限制）
- 加 cascode：BW = 8 GHz（5× 提升）

→ 这就是 cascode 不仅给增益增强，也消 parasitic Miller 的双重价值。

## 设计指引（事实）

| 场景 | 受 parasitic Miller 影响 | 对策 |
|---|---|---|
| 简单低速 CS（< 100 MHz）| 弱（C_load 通常更主导）| 不需特别处理 |
| 高速 CS / 视频 amp（GHz）| **强**（input BW 主限）| Cascode |
| LNA（GHz RF）| **极强** | Cascode + 可能 neutralization |
| OTA 内部级（中频）| 中等 | Cascode load + 适度 sizing |
| TIA（GHz 光通信）| **强**（C_PD + Miller）| 用 CG-TIA 避开 Miller |

## sizing 关系（决定 Miller 影响大小）

C_in_Miller 与 W 直接相关：
```
Cgd ∝ W
C_in_Miller = Cgd × (1+|Av|) ∝ W × (1+|Av|)
```

→ **同时增 W 和 |Av| 都让 BW 损失**——这是 high gain + high speed 的物理冲突。

## 验证清单

- [ ] AC：测 input 节点 -3 dB BW vs 公式
- [ ] AC：对比 single CS vs cascoded CS BW（看 Miller 抑制效果）
- [ ] tran：脉冲响应 rise time（与 BW 反比）
- [ ] EM 仿真（高频）：Cgd vs layout（不同 metal stack）

## 常见误区

| 心里想 | 现实 |
|---|---|
| "Miller 只是补偿用的电容" | 错——CS 中 Cgd 是 **寄生**，自动产生 Miller 倍增 |
| "增 W 让 gm 大 → BW 大" | 错——W 增 → Cgd 增 → C_in_Miller 增 → BW 减小（gm-BW 乘积守恒）|
| "cascode 只是为了增益" | 错——**消 parasitic Miller** 是 cascode 在高速电路中的同等重要价值 |
| "LNA 用 CG 是因为低 Rin" | 是部分原因；同时 CG 没 parasitic Miller 是另一关键原因 |
| "Cc 补偿 = 加 Cgd 反相" | 不是——Cc 是 designed 反馈，路径选择不同；Cgd 是寄生不可控 |

## 不在本章范围

- plain Miller 补偿（设计意图 Cc）→ chapter `plain-miller`
- nulling Rz / Ahuja 消 RHP zero → 对应 chapter
- nested Miller → chapter `nested-miller`
- 故障 debug → chapter `troubleshooting`
- cascode 物理详细 → `blocks/base-cells/cascode/`
- CG 拓扑（避开 Miller）→ `blocks/base-cells/common-gate-stage/`
- LNA 完整设计 → `blocks/lna-cmos/`（未来）
- RF neutralization 详细 → RF passive knowledge（V4 不在范围）
