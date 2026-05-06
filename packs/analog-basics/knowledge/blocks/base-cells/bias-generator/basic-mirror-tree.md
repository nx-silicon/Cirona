---
chapter: basic-mirror-tree
parent: bias-generator
summary: |
  基础镜像偏置树 —— 从 Iref 复制到多支路 / 简单电流源 sink / 各级 cascode bias 生成 /
  PVT tracking sizing 原则
tokens: ~700
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
  - circuit-method/bias-tree-reasoning
related_knowledge:
  - blocks/base-cells/current-mirror
---

# 基础镜像偏置树

## 拓扑（典型 PMOS 顶 + NMOS 底 镜像树）

```
       VDD
        │
    ┌───┴───┐ ┌───┴───┐ ┌───┴───┐ ┌───┴───┐
    │ Mp_ref│ │ Mp_1  │ │ Mp_2  │ │ Mp_3  │ ← PMOS bias 镜像（共 vb_p）
    │ diode │ │       │ │       │ │       │
    └───┬───┘ └───┬───┘ └───┬───┘ └───┬───┘
        ●─── vb_p（共连 PMOS gate）
        │           │       │       │
        ▼          out1    out2    out3
        Iref      （主电路各支路）
        │
    ┌───┴───┐ ┌───┴───┐ ┌───┴───┐
    │ Mn_ref│ │ Mn_1  │ │ Mn_2  │ ← NMOS bias 镜像（共 vb_n）
    │ diode │ │       │ │       │
    └───┬───┘ └───┬───┘ └───┬───┘
        ●─── vb_n（共连 NMOS gate）
        │           │       │
       VSS         VSS    VSS
```

**核心机制**：
- Iref 从外部（典型 bandgap）注入 → 流过 Mp_ref / Mn_ref（diode-connected 自洽）
- vb_p / vb_n 分别等于 Mp_ref / Mn_ref 的 Vgs → 为各支路 PMOS / NMOS 设定 bias
- 各支路 mirror 管复制 Iref 比例（W/L 比 + m 比例）
- **整树由 Iref 一个数值钉住**——Iref 漂全树漂

## 各分发点 Iref 比例（用 m 不用 W）

> ⚠️ **关键 sizing 原则（来自之前 cmfb / output-stage cell 的用户洞察）**：
> mirror 比例必须用 **m 比例**，**不**改 W。  
> 同 unit W·L → matching 好（Pelgrom σ ∝ 1/√(WL)）+ PVT tracking 同步。

```
Iout_branch_k = Iref × (m_branch_k / m_ref)

例：m_ref = 1, m_branch_1 = 5 → I_out_1 = 5 × Iref
    m_ref = 1, m_branch_2 = 0.5（用 m=2 ref + m=1 branch）→ 0.5 × Iref
```

## sizing 关系

| 量 | 推荐 | 因果 |
|---|---|---|
| Iref（外部）| µA-数十 µA 级 | bandgap 典型输出；配合主电路 Iq |
| Mp_ref / Mn_ref unit W·L | 中等（10-100 µm²）| matching σ ∝ 1/√(WL)；过小 → 各分支 σ_I/I 大 |
| **L 关键**：cascode mirror 用 4-8 × Lmin | matching + ro 提升（影响电流精度）| L 大 → λ·Vds 项小 → mirror ratio 受 V_drain 影响小 |
| 整树 Iq（bias 自身） | < 主电路 Iq 的 5-10% | 不让 bias 喧宾夺主 |

## 简单 current source / sink（最简形式）

不带 cascode 的单管 mirror = simple current source：
- Iout = (W_out·L_ref / W_ref·L_out) × Iref
- Rout = ro_out（一般 50 kΩ - 500 kΩ）
- 适合：bias 本身 / 不需高 Rout 的场合
- 不适合：active load / 高输出阻抗需求

## cascode bias 节点生成（vbpc / vbnc）

5T-OTA / FC / telescopic 都需要 cascode bias（vbpc 给 PMOS cascode gate / vbnc 给 NMOS cascode gate）：

```
        VDD
         │
    ┌────┴────┐
    │ Mp_ref  │ diode-connected → 提供 vb_p
    │ (PMOS)  │
    └────┬────┘
         ●─── vb_p
    ┌────┴────┐
    │ Mp_pad  │ ← padding device（生成 vbpc）
    │ (PMOS)  │
    └────┬────┘
         ●─── vbpc（cascode bias）
         │
         (流回 Iref or 接 NMOS branch)
```

**vbpc 公式**：
```
vbpc = vb_p - Vgs_M_pad
     = (VDD - Vgs_Mp_ref) - Vgs_Mp_pad
```

**关键物理**（来自 cmfb / output-stage cell 的物理审查教训）：
> ⚠️ **cascode 底部管的 Vds 不是它自己决定的**。  
> 例：M4a 是 cascode mirror 底部 → M4a.Vds = vbpc - Vgs_M4b（不是 M4a 的 W/L 决定）。  
> 修复 M4a triode 必须**调 padding device sizing 提 vbpc**，不调 M4a。

## sizing 范例（5T-OTA 偏置树）

> 📌 **@ vpdk180nm**（μn/p·Cox / Vth / VA / γ 数值参考 `pdks/vpdk180nm/index.md`）。换工艺需重算所有数值；公式形式（Vgs = Vth+Vov / vbnc = vb_n - Vgs_pad 等）跨工艺通用。

设计目标：5T-OTA Itail = 20 µA，需要 vb_n（tail bias）+ vbnc（NMOS cascode bias）+ vb_p（PMOS load mirror bias），Iref = 5 µA。

```
M_ref bias chain:
  M_ref_n (diode-connected NMOS): W_unit = 2 µm / L = 1 µm / m = 1
    → 流过 Iref = 5 µA → vb_n = Vth_n + Vov_n ≈ 0.65 V

  M_pad_n (NMOS padding): same unit W·L / m = 1
    → 单 Vgs 偏移模型 vbnc = vb_n - Vgs_pad = 0.65 - 0.65 = 0 V ✗（撞 VSS）

  ⚠️ 这里用 same-unit padding 是为了示意"vbnc = vb_n - Vgs_pad"在 NMOS 上贴 VSS 不可用。
     正确的 NMOS wide-swing vbnc 不能用"减小 W_pad → Vov_pad 增大 → vbnc 升高"这条路径
     —— 在该公式下 Vov_pad 增大会让 Vgs_pad 同向增大，vbnc 反而**更低**。
     正确推导是把目标式写成 `vbnc target ≈ Vth + Vov_main + Vov_cascode_bottom`，
     让 cascode 底部管 Vds 刚好 = Vov（最小 headroom）；详细见 `level-shifter-bias.md`。

5T tail mirror M5: m = 4 → I_M5 = 4 × Iref = 20 µA ✓ (= Itail)

PMOS load mirror M3/M4:
  尺寸上 m = 4 each → 每侧 mirror 比例对应 4 × Iref = 20 µA 的镜像能力（sizing 视角）
  但 5T-OTA 平衡工作点 each side = Itail / 2 = 10 µA（电路视角）
  不要把"尺寸镜像比"和"实际静态支路电流"混写
```

## 验证清单

- [ ] dc_snapshot：Iref 流入 → 全树各支路 Iout 比例正确（误差 < 1%）
- [ ] dc_snapshot：vb_p / vb_n / vbpc / vbnc 都在合理范围（不撞 rail）
- [ ] dc_snapshot：所有 mirror 管 saturation
- [ ] PVT corner（FF/SS/温度）：Iout 漂 ±20%，比例 < 5%
- [ ] noise：bias 噪声 → 主电路 input-referred 应 < 1% 主总噪声
- [ ] tran：Iref 阶跃 → 主电路 Iq 跟随建立时间

## 常见误区

| 心里想 | 现实 |
|---|---|
| "用 W ratio 实现镜像比" | 错——必须用 m 比例 + 同 unit W·L（PVT tracking） |
| "padding device W 大点 vbpc 就高" | 反方向——W 大 → Vov 小 → Vgs 小 → vbpc 高（M_pad 是 diode-connected）|
| "Iref 来源不重要" | 错——Iref 漂全树漂；Iref 必须是 bandgap-derived（PVT-stable）|
| "bias 树管 L 用 min" | 短沟道 mismatch + λ 调制大；典型 4-8× Lmin |
| "bias tree noise 可忽略" | OTA tail mirror noise 直接经 (gm_tail/gm_input)² 衰减后到输入；尾流大时主导 |

## 不在本章范围

- β-multiplier 自偏置 → chapter `beta-multiplier`
- replica 偏置 → chapter `replica`
- cascode 物理（管 Vds 决定）→ `blocks/base-cells/cascode/`
- 外部 Iref 来源（bandgap）→ `blocks/bandgap/`
- 故障诊断 → chapter `troubleshooting`
