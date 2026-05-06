---
chapter: level-shifter-bias
parent: bias-generator
summary: |
  电平移位偏置 —— 用 Vgs stack / floating Vbe 生成各级 cascode bias /
  wide-swing bias / 跨电源域 bias 传递
tokens: ~600
prerequisite_chapters:
  - basic-mirror-tree
related_skills:
  - circuit-method/bias-tree-reasoning
related_knowledge:
  - blocks/base-cells/cascode
---

# 电平移位偏置

## 目的

生成与基础 vb_n / vb_p 相差固定 Vgs 的偏置节点（典型用于 cascode bias / wide-swing bias / floating Vbe spreader）。

## 拓扑变体

### 变体 A：单 Vgs 偏移（最简）

```
Iref ──┐
       │
   ┌───┴───┐
   │ M_pad │ ← diode-connected
   └───┬───┘
       ●─── vb_target = vb_source - Vgs_pad
       │
   ┌───┴───┐
   │ M_src │ ← 偏置源 mirror
   └───┬───┘
      VSS
```

**vb_target = vb_source - Vgs_pad**（NMOS）或 **vb_source + |Vgs_pad|**（PMOS）。

应用：cascode bias（vbnc 从 vb_n 偏移一个 Vgs）。

### 变体 B：Wide-swing cascode bias

⚠️ **NMOS 与 PMOS 的 wide-swing 公式不同方向**，必须分开写：

```
NMOS wide-swing（生成 vbnc）:
  目标式：vbnc ≈ Vth_n + Vov_main + Vov_cascode_bottom
         （即让 cascode 底部管 M_b 的 Vds = Vov，保 sat 最小 headroom）
  实现：用 wide-swing pad，让 M_pad 的 Vov_pad = 2 × Vov_main（典型 (W/L)_pad = (W/L)_main / 4 同 Iref）
       vbnc = Vgs_pad = Vth_n + 2·Vov_main ✓（直接等于 padding diode Vgs）
  ❌ 不要写成 vbnc = vb_n - Vgs_pad —— 在 NMOS 上这给出贴近 0V 的结果（撞 VSS）

PMOS wide-swing（生成 vbpc，对称镜像）:
  目标式：vbpc ≈ VDD - (|Vth_p| + |Vov_main| + |Vov_cascode_top|)
  实现：vbpc = VDD - |Vgs_pad| = VDD - (|Vth_p| + 2|Vov_main|)
       即 vbpc = vb_p + |Vgs_pad_pmos|（vb_p ≈ VDD - |Vgs_main|）
```

**因果**：wide-swing 让 M_pad 的 Vov 比 main mirror 大一倍 → 生成的 cascode bias 让 cascode 底部 Vds 刚好 = Vov（最小 headroom，最大摆幅）。NMOS 和 PMOS 的偏置生成方向相反，注意不要混用公式。

### 变体 C：Floating Vbe（Class-AB spreader）

class-AB 输出级（output-stage 章见过）的 spreader 用 floating Vgs stack：
```
        ┌── PMOS gate
        │  Vbias_p = Vin - |Vgs_p|
   ┌────┴────┐
   │ Vgs_p   │ floating spreader
   ├─────────┤ (typical: diode-stack)
   │ Vgs_n   │
   └────┬────┘
        │  Vbias_n = Vin + Vgs_n
        └── NMOS gate
```

详细见 `blocks/base-cells/output-stage/class-ab.md` § 偏置展开网络。

## sizing 关系

| 量 | 推荐 | 因果 |
|---|---|---|
| M_pad unit W·L | = mirror unit W·L（PVT tracking）| Vgs(W,L,T) 漂同步 |
| M_pad 的 Vov 调节 | 改 m 比例（Iref / m_pad）| 不改 W！调 m 让 Iref 在 M_pad 上的 Vov 不同 |
| L | = mirror L | 必须同 |

## 与 padding device 区别

> 注：在 cascode 章节我们说"调 padding device sizing 提 vbpc"——
> 这里的 padding device 实际就是 M_pad（level-shifter）。术语在不同来源可能 padding 或 level-shifter，本 cell 视为同一概念。

## 典型范例（Wide-swing NMOS cascode bias 生成）

设计：5T-OTA NMOS cascode wide-swing → 生成 vbnc，让 cascode 底部管 Vds 刚好 = Vov（最小 headroom，最大摆幅）。

### 目标式（先写最终目标，再推 sizing）

```
cascode 底部管 M_b：W/L 与 main mirror 同（mirror tracking）
  → Vov_M_b = Vov_main = 0.15 V
  → 期望 V_M_b.drain = vbnc - Vgs_cascode_top（cascode 顶部 M_t 的 Vgs）

目标：让 V_M_b.Vds ≈ Vov_M_b = 0.15 V（saturation 边缘最小 headroom）

vbnc target = V_M_b.Vds + Vgs_M_b = 0.15 + (Vth + 0.15) = Vth + 2·Vov_main
            = 0.5 + 0.30 = 0.80 V

cascode 顶部 M_t 的 Vgs：
  M_t source = V_M_b.drain = 0.15 V，gate = vbnc = 0.80 V
  → Vgs_M_t = 0.65 V = Vth + Vov_main → M_t 也工作在 main Vov，sat ✓
```

### 用 wide-swing pad 实现 vbnc = Vth + 2·Vov_main

要让 padding 链产生 vbnc = 0.80 V（即比 vb_n = 0.65 V 高 0.15 V），最常见的做法是：

```
做一条与 main 并联的 padding 链，让 padding 管以 4× Vov 工作：
  M_pad: 在与 main 相同 Iref 下，让 (W/L)_pad = (W/L)_main / 4
  → Vov_pad = 2 × Vov_main = 0.30 V （∵ Vov ∝ 1/√(W/L) at fixed I）
  → Vgs_pad = Vth + Vov_pad = 0.5 + 0.30 = 0.80 V
  → 把这个 Vgs_pad 直接当作 vbnc 输出（即让 vbnc 等于 padding diode 的 Vgs）
  → vbnc = 0.80 V ✓
```

### 关键提醒

- **不要写成 vbnc = vb_n - Vgs_pad**：在 NMOS 上这条公式让 vbnc 趋近 0V（撞 VSS）。NMOS wide-swing vbnc 应直接等于 padding diode 的 Vgs（高于 vb_n），而不是 vb_n 减去某个 Vgs。
- **PMOS wide-swing vbpc 才用 vbpc = vb_p + |Vgs_pad|**（对称镜像）。两套公式不要混用。
- 调 vbnc 数值靠改 (W/L)_pad 比例（即 Vov_pad），不要调 L 也不要破坏 unit tracking。

## 验证清单

- [ ] dc_snapshot：vb_target 在合理范围（不撞 rail）
- [ ] dc_snapshot：M_pad saturation
- [ ] dc_snapshot：下游 cascode 底部管 Vds ≥ Vov + margin（关键）
- [ ] PVT corner：vb_target 跟随 mirror 漂移
- [ ] noise：M_pad noise 影响下游 → typically 小

## 常见误区

| 心里想 | 现实 |
|---|---|
| "level-shifter 与 cascode 是不同 cell" | 实际上 level-shifter / padding / Vgs-stack 都是 cascode bias 生成的不同名字 |
| "改 W 调 vb_target 数值" | 调 W 破坏 unit tracking；用 m 比例或改 Iref 调 |
| "M_pad L 可以与 main 不同" | 错——必须同 L（V_th(L) tracking）|

## 不在本章范围

- 基础 mirror 树 → chapter `basic-mirror-tree`
- cascode 物理 / wide-swing 详细 → `blocks/base-cells/cascode/`
- class-AB output stage 偏置展开 → `blocks/base-cells/output-stage/class-ab.md`
- 故障 debug → chapter `troubleshooting`
