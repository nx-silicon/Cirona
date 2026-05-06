---
chapter: architecture
parent: telescopic-ota
summary: |
  Telescopic Cascode OTA 拓扑细节（4-stack core + 9-MOSFET wide-swing bias tree）
  + variants 文字描述 + 与其他 OTA 4D（gain/BW/power/swing）对比 + 适用场景。
tokens: ~1100
prerequisite_chapters: []
related_knowledge:
  - blocks/folded-cascode-ota
  - blocks/5t-ota
  - blocks/two-stage-ota
  - blocks/base-cells/cascode
  - blocks/base-cells/current-mirror/wide-swing
---

# Telescopic OTA Architecture

## 拓扑本质

**Telescopic = input pair 直接堆在 cascode 路径中的高 power-efficiency 单级 cascode OTA**。

物理本质：把 5T-OTA 的 NMOS-input → PMOS-mirror 直接堆叠 + 加 NMOS cascode +
加 PMOS cascode = **4-stack**（diff pair + NMOS cascode + PMOS cascode + PMOS mirror）。
信号电流不"折叠"（不像 FC），直接从 VDD 经 cascode 堆叠到 VSS，单条 branch
完成 → power 最省。

```
单级 cascode OTA：gain = gm × (Rout_p ‖ Rout_n)
  Rout_p = gm_pcasp · ro_load · ro_pcasp     (PMOS 侧高阻)
  Rout_n = gm_ncasc · ro_diff · ro_ncasc     (NMOS 侧高阻；包含 ro_diff！)

I_total = I_branch × 2 = I_tail               (FC 是 I_tail × 2，多一条 branch)
```

**关键约束**：4-stack headroom 紧——VDD = 1.8V 时 4 段 Vov 占 0.6-0.8V，
swing 仅 0.4-0.6V。**ICMR 也紧**：VCM 必须保 input pair + tail + cascode
都 saturate，典型 VCM 窗口仅 0.4V。

> **Telescopic 与 FC 的拓扑根本差异**：
> - **Telescopic**：input pair 在 cascode 路径中（**单 branch**）→ I_total 省 1.5-2×；ICMR 紧；swing 紧
> - **FC**：input pair 单独 branch + fold 到 cascode（**双 branch**）→ I_total 大；ICMR 宽；swing 中

## Standard variant（V4 reference: NMOS-input single-ended）

```
Group 1 (input)         : MM1, MM2     NMOS diff pair, S=ntail, D=ncasc
Group 2 (NMOS cascode)  : MMcasc1, MMcasc2     S=ncasc, G=vbnc, D=vout
Group 3 (PMOS cascode)  : MMcasp3, MMcasp4     S=nload, G=vbpc, D=vout
Group 4 (PMOS mirror)   : MM3, MM4              S=vdd, G=vout_n（diode-via-cascode）
Tail                    : MMtail                S=vss, mirror MMbias
9 bias-tree MOSFETs（生成 vbnc / vbpc / nbias_p）
```

V4 `reference-design.md` 提供此变体的 production-grade 网表（199 行
self-contained，9-MOSFET wide-swing bias tree 已调好）。**新设计先 load
reference design，不要从零造拓扑**——4-stack headroom 紧，hand-wire 几乎
必踩 cascode bias / padding sizing trap。

## Variants（从 reference 怎么改）

### Variant 1: PMOS-input + NMOS-mirror（high-VCM 场景）

适用：VCM 接近 VDD（0.8-1.6V @VDD=1.8V），希望 input pair 在高共模下
saturate；PMOS-input 1/f noise 较 NMOS 小。

**怎么改 reference**：
- Group 1: MM1/MM2 → PMOS（type 反转），S=ntail（top tail，PMOS）
- Group 2: NMOS cascode → PMOS cascode（极性翻转）
- Group 3/4: PMOS cascode + mirror → NMOS cascode + mirror
- Tail: NMOS → PMOS（top tail）
- bias tree N/P 镜像翻转（vbnc ↔ vbpc role 互换）

物理对照：
- swing 与 NMOS-input 相当（≈ 0.4-0.6V @VDD=1.8V）
- input flicker noise ↓
- ICMR：从"高 VCM 紧" → "低 VCM 紧"（极性翻转）

### Variant 2: Wide-swing input（input pair 进 cascode 内）

适用：极端低压 telescopic（VDD ≈ 1.0V），4-stack 撑不开 → 把 input pair
"塞"进 cascode 区域，腾出顶部 cascode 空间。

**怎么改 reference**：
- 把 NMOS cascode（MMcasc1/2）放到 input pair **下方**（变成 input pair 是
  cascode 上管，cascode 是 input pair 下管的角色互换 —— 罕见但可行）
- 或：input pair 共享 cascode bias（gate 共 vbnc）

物理对照：
- 4-stack 总 headroom 同（物理上没省），但 swing 分配可微调
- gain 略降（input pair 不在最敏感位置）
- 仅适用极限低压

### Variant 3: Gain-boosted Telescopic

适用：单级 gain target 80-100 dB（telescopic 物理上限 80-90 dB，再高需 gain-boost）。

**怎么改 reference**：
- 与 FC gain-boost 同：cascode gate 接 auxiliary OTA 输出，强制 cascode source
  = 设计电压 → 输出阻抗再乘 (1 + A_aux)
- 总 gain ≈ gm × ro × A_main × A_aux

物理对照：
- gain ↑ 20-30 dB
- 复杂度 ↑（每个 cascode 一个 aux OTA）
- 多极点 → PM 设计更难

> 完整设计见 `blocks/ota-gain-boosted` (W7+ planned)。

### Variant 4: Fully-differential Telescopic + CMFB

适用：高 PSRR / 共模抑制 / pipeline ADC 子模块。

**怎么改 reference**：
- 删除 PMOS mirror（MM3/MM4），改为左右对称 cascode（双输出 vout_p / vout_n）
- 加 CMFB block 控制两输出共模

物理对照：
- swing × 2（差分有效摆幅）
- 共模噪声大幅抑制
- CMFB 引入额外极点 → PM 设计更难

## 4D Trade-off：Telescopic vs 其他 OTA

| 维度 | 5T | FC | **Tele** | 2-stage |
|---|---|---|---|---|
| **Gain** | 40-55 dB | 60-80 dB | **60-80 dB**（与 FC 相当）| 80-100 dB |
| **GBW**（@CL=1pF）| 1-50 MHz | 30-100 MHz | **30-120 MHz**（略高于 FC）| 10-50 MHz |
| **PM** | 易 | 中 | **中**（cascode 极点）| 难（Miller 三件套）|
| **Power**（@gain 70dB）| — | 200-800 µW | **100-500 µW** ⭐ | 300-1000 µW |
| **Swing**（@VDD=1.8V）| ≈ 1.0V | 0.6-0.8V | **0.4-0.6V** ⚠️ | ≈ 1.6V |
| **ICMR**（@VDD=1.8V）| 中 | 宽（0.3-1.6V）| **紧（≈ 0.4V）** ⚠️ | 宽 |
| **Noise**（input-referred）| 中 | 低 | **低**（与 FC 相当）| 中 |
| **复杂度** | 最简单 | 中-高 | **中**（少一条 branch）| 复杂 |
| **典型适用** | 简单 buffer | LDO EA / 高 ICMR | **ADC preamp / power-eff 高 gain** | LDO EA / rail-rail |

> **Telescopic vs FC**（同 gain target 60-80 dB 时的选择）：
> - **Power 优先 + ICMR 可控** → Telescopic（省 1.5-2× power）
> - **ICMR 灵活 / VDD 紧 / swing 大** → FC
> - **VDD < 1.5V** → 直接换 FC，telescopic 4-stack 撑不开

## When to use Telescopic OTA

- ✅ Gain 60-80 dB + power efficiency 优先（power-tight 应用）
- ✅ ADC preamp（VCM 由 ADC 共模电路严格控制，ICMR 紧不是问题）
- ✅ 低噪声放大器（cascode 抑制 mirror flicker，与 FC 相当）
- ✅ VDD ≥ 1.5V（4-stack headroom 够）
- ✅ Swing 需求小（0.4-0.6V 够用）

## When NOT to use Telescopic OTA

- ❌ ICMR 需要灵活（输入共模范围 > 0.4V）→ 用 FC-OTA（fold 解耦）
- ❌ Rail-to-rail swing 需求 → 4-stack 占太多 headroom，换 2-stage
- ❌ VDD < 1.5V → 4-stack 不够，换 FC 或 2-stage
- ❌ LDO EA 大 dropout → telescopic input 跟随 vref 可能 ICMR 出范围
- ❌ Gain > 90 dB → 单级到顶，换 2-stage 或 gain-boosted variant

## Related

- 4 OTA 拓扑详细对比：`blocks/5t-ota/architecture` / `folded-cascode-ota/architecture` / `two-stage-ota/architecture`
- cascode 物理（gm × ro × ro 推导）：`blocks/base-cells/cascode`
- wide-swing bias scheme（vbnc / vbpc 生成）：`blocks/base-cells/current-mirror/wide-swing`
- 4-stack headroom 详细分析 + 4 处 bias 修复 R1-R4：`bias-headroom.md`
- 设计推进顺序（4 group 同步 sizing）：`sizing-typical.md`
