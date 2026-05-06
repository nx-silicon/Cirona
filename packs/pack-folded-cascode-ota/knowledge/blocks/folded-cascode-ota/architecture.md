---
chapter: architecture
parent: folded-cascode-ota
summary: |
  FC-OTA 拓扑细节（5 group core + 9-MOSFET wide-swing bias tree）+ variants
  文字描述 + 与其他 OTA 4D（gain/BW/power/swing）对比 + 适用场景。
tokens: ~1100
prerequisite_chapters: []
related_knowledge:
  - blocks/5t-ota
  - blocks/telescopic-ota
  - blocks/two-stage-ota
  - blocks/base-cells/cascode
  - blocks/base-cells/current-mirror/wide-swing
---

# FC-OTA Architecture

## 拓扑本质

**Folded-cascode = 信号电流"折叠"换 headroom 的单级 cascode OTA**。

物理本质：把 5T-OTA 的 NMOS-input → PMOS-mirror 直接堆叠改为
"NMOS-input → PMOS fold（电流转向）→ 双 cascode 高阻输出"。
信号电流不再受 input 共模直接限制（telescopic 的痛点），同时通过 cascode
把 ro 提到 gm·ro × ro 量级。

```
单级 cascode OTA：gain = gm × (Rout_p ‖ Rout_n)
  Rout_p = gm_pcasc · ro_pfold · ro_pcasc      (PMOS 侧输出阻抗)
  Rout_n = gm_ncasc · ro_nmirror · ro_ncasc    (NMOS 侧输出阻抗)
```

**关键约束**：FC 的 9-MOSFET wide-swing bias tree 有 4 个内部 bias 节点
（`vbias_fold` / `vbc_p` / `vbc_n` / `ibias`），其中 `vbc_n` / `vbc_p`
由 padding device（线性区）+ diode 串联生成 —— 这是 FC 区别于其他 cascode
拓扑的设计点（**调 cascode bias 不能用理想电压源 hack**）。

## Standard variant（V4 reference: NMOS-input single-ended）

```
Group 1 (input)         : MN1, MN2     NMOS diff pair, S=ntail
Group 2 (PMOS fold)     : MP1_bottom, MP3_bottom   S=vdd, G=vbias_fold
Group 3 (PMOS cascode)  : MP2_top, MP4_top         S=fold junction, G=vbc_p
Group 4 (NMOS cascode)  : MN6_top, MN8_top         S=mirror drain,  G=vbc_n
Group 5 (NMOS mirror)   : MN5_bottom, MN7_bottom   S=vss, master diode-via-cascode
Tail                    : MNtail                    S=vss, mirror Mbias
9 bias-tree MOSFETs（生成 vbias_fold / vbc_p / vbc_n）
```

V4 `reference-design.md` 提供此变体的 production-grade 网表（321 行
self-contained，9-MOSFET wide-swing bias tree 已调好）。**新设计先 load
reference design，不要从零造拓扑**——FC bias tree 复杂，hand-wire 几乎
必踩 PMOS cascode S/D 接反 trap。

## Variants（从 reference 怎么改）

### Variant 1: PMOS-input + NMOS-fold（high-VCM 场景）

适用：VCM 接近 VDD（0.8-1.6V @VDD=1.8V），希望 input pair 在高共模下
saturate；需要 input flicker noise 较低（PMOS 通常优于 NMOS）。

**怎么改 reference**：
- Group 1: MN1/MN2 → PMOS（type 反转），S=ntail（top tail，PMOS）
- Group 2: PMOS fold → NMOS fold（S=vss，G=vbias_fold_n）
- Group 3/4: cascode 极性整体翻转（PMOS cascode ↔ NMOS cascode 角色互换）
- Group 5: mirror 改 PMOS（S=vdd）
- Tail（Mtail）：NMOS → PMOS（top tail）
- bias tree N/P 镜像翻转

物理对照：
- 总 swing 与 NMOS-input 变体相当（≈ 0.6-0.8V @ VDD=1.8V）
- input flicker noise ↓（PMOS 1/f 通常较 NMOS 小同 W·L）
- ICMR 上限 → 接近 VDD - |Vov_ptail|；下限 → ≈ |Vth_p| + |Vov_p|

### Variant 2: Fully-differential FC + CMFB（fd_cmfb）

适用：高 PSRR / 共模抑制要求 / pipeline ADC 子模块 / 大信号差分应用。

**怎么改 reference**：
- 保留两侧 cascode branch（不收敛到单端）→ 同时输出 vout_p / vout_n
- 删除 NMOS mirror（diff-to-SE 转换器）
- 加 CMFB（common-mode feedback）block：感知 Vout_cm = (V(vout_p)+V(vout_n))/2，
  反馈到 PMOS mirror gate 共节点（替代 5T-style 自镜像 sink）
- CMFB block 通常用 2 级 OTA 或 SC（switched-capacitor）实现（独立设计）

物理对照：
- gain 与 SE 变体相当（70-80 dB），但 swing × 2（差分有效摆幅）
- 复杂度 ↑（CMFB 是独立子电路），DC stability 多一层闭环要保
- PSRR / 共模噪声抑制大幅改善

> CMFB 设计本身见 `blocks/base-cells/cmfb`（独立章节）。本文档专注 SE 变体。

### Variant 3: Gain-boosted FC（regulated cascode）

适用：单级 gain target 80-100 dB（FC SE 物理上限 80 dB，再高需 gain-boost 或换 2-stage）。

**怎么改 reference**：
- Group 3（PMOS cascode）和 Group 4（NMOS cascode）的 gate 不再接静态
  vbc_p / vbc_n，而是接小型 auxiliary OTA 的输出
- auxiliary OTA 强制 cascode source = 设计电压 → 输出阻抗再乘一个 (1 + A_aux)
- 总 gain ≈ gm × ro × A_main · A_aux

物理对照：
- gain ↑ 20-30 dB（auxiliary OTA gain 30 dB 即可）
- 复杂度 ↑（每个 cascode 一个 aux OTA）
- 多一组极点 → PM 设计更难（aux OTA 的 GBW 与 main GBW 关系要 tune）

> 完整设计见 `blocks/ota-gain-boosted` (W7+ planned)（独立章节，本文档不展开）。

### Variant 4: Low-VDD FC（VDD < 1.2V）

适用：1.0-1.2V 低压工艺，FC SE 在 1.8V 下 swing 0.6-0.8V，1.0V 下被压到 < 0.3V，不可用。

**怎么改 reference**：
- 用 wide-swing bias tree（V4 reference 已默认是此版）+ 低 Vov 设计（每段 80-100mV）
- 必要时换 telescopic + wide-swing input（input pair 进 mirror 内部）

物理对照：
- 低压 FC 极限：每个 cascode 段 Vov ≈ 80-100mV，4 段堆叠占 0.32-0.4V，
  剩 swing < 0.3V @ VDD=1.0V
- 多数低压设计直接换 2-stage（class-AB 输出级提供 rail-to-rail swing）

## 4D Trade-off：FC-OTA vs 其他 OTA

| 维度 | 5T | **FC** | Tele | 2-stage |
|---|---|---|---|---|
| **Gain** | 40-55 dB | **60-80 dB** | 60-80 dB | 80-100 dB |
| **GBW**（@CL=1pF）| 1-50 MHz | **30-100 MHz** | 30-120 MHz | 10-50 MHz（Miller 限）|
| **PM** | 易 | **中**（fold 节点 + cascode 极点）| 中 | 难（Miller / RHP zero）|
| **Power** | 30-100 µW | **200-800 µW**（左右两 branch + bias tree）| 100-500 µW | 300-1000 µW |
| **Swing**（VDD=1.8V）| ≈ 1.0V | **≈ 0.6-0.8V**（cascode 占）| 0.4-0.6V（双 cascode）| ≈ 1.6V（rail-rail）|
| **ICMR**（@VDD=1.8V）| 中（0.5-1.0V）| **宽（0.3-1.6V）**（fold 解耦）| 紧（≈ 0.4V）| 宽 |
| **Noise**（input-referred）| 中 | **低**（cascode 抑制 mirror noise）| 低 | 中 |
| **复杂度** | 最简单 | **中-高**（9-MOS bias tree）| 中 | 复杂（需补偿）|
| **典型适用** | 简单 buffer | **LDO EA / ADC 子模块 / 高 ICMR**| 高 gain + 低噪 | 高 gain + rail-rail |

> **FC vs Telescopic**：两者 gain / GBW / power 几乎相当，**关键差异是 ICMR 和 swing**——
> FC 用 fold 把 input 共模与输出堆叠解耦，ICMR 宽（0.3-1.6V），但代价是多一条
> branch（power × 1.5-2）；Telescopic 把 input 直接堆进 cascode 路径，
> ICMR 紧（≈ 0.4V）但 power 省。**输入共模需要灵活 → FC**；**功耗优先且
> 输入共模可控 → Telescopic**。

## When to use FC-OTA

- ✅ Gain 需求 60-80 dB 单级（5T 不够，但不愿上 2-stage 的 Miller 复杂度）
- ✅ ICMR 需要灵活（input 范围跨度大，如 LDO EA 中 vref 0.4V 也要工作）
- ✅ LDO EA loop gain 60-80 dB（双级 EA 不必要时 FC 单级足够）
- ✅ ADC 子模块（preamp / sample-hold buffer）
- ✅ VDD ≥ 1.2V（FC swing 0.6-0.8V 仍可用）

## When NOT to use FC-OTA

- ❌ Gain > 90 dB → 物理上 FC 单级到顶——上 2-stage 或 gain-boost 变体
- ❌ Rail-to-rail swing 需求 → cascode 占 headroom 物理限制——上 2-stage
- ❌ VDD < 1.0V → headroom 不够，4 段 cascode 撑不开——上低压专用拓扑
- ❌ Power-tight 应用（< 100µW）→ FC 至少 200µW（左右两 branch）——上 5T

## Related

- 4 OTA 拓扑详细对比：`blocks/5t-ota/architecture` / `telescopic-ota/architecture` / `two-stage-ota/architecture`
- cascode 物理（gm × ro × ro 推导）：`blocks/base-cells/cascode`
- wide-swing bias scheme（vbc_n / vbc_p 生成原理）：`blocks/base-cells/current-mirror/wide-swing`
- 设计推进顺序：见 `sizing-typical.md` 拓扑特定步骤
