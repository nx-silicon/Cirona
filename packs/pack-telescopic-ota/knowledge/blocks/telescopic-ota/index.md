---
type: knowledge
domain: circuit
name: telescopic-ota
version: 1.0
summary: |
  Telescopic Cascode OTA 设计参考：4-stack core + 9-MOSFET wide-swing bias tree +
  reference cir/tb 路径 + 已知 wide-swing 同密度失配陷阱（V3 sizing 修复 case）。
  事实+因果格式，**Iron Law: 设计 Telescopic OTA 必先 load reference-design 章节**，
  4-stack headroom 紧 + ICMR 紧 + bias 树同密度铁律——从零造拓扑必踩 trap。

chapters:
  - name: architecture
    summary: 4-stack + 9-bias 拓扑细节 + variants（PMOS-input / wide-swing-input / gain-boosted / fd_cmfb）+ 与其他 OTA 4D 对比（power 优势 / ICMR 紧）
    tokens: ~1100
  - name: sizing-typical
    summary: spec → device 约束因果（含 ICMR 紧约束）+ 4-stack headroom budget 必先 + wide-swing 同密度铁律 + 7 步推进 + @vpdk180nm 起点表
    tokens: ~1500
  - name: bias-headroom
    summary: ⭐ Vds/Vdsat 物理约束 + R1 KVL 反推 + R2 镜像约束铁律（5 个 mirror）+ 4 处 bias 节点 triode 范例（MM1 / MMcasc / MMcasp / MM3）+ MMtail triode（Telescopic 核心新章）
    tokens: ~2200
  - name: ac-stability
    summary: 主极点 vout + cascode source 极点 + mirror node 极点 + 单级 cascode 不需 Miller 补偿 + 与 FC 对照（next pole 略远 → PM 略宽松）
    tokens: ~1100
  - name: troubleshooting
    summary: 12 类失败模式（gain 极低/wide-swing 密度失配 / gain 60dB / GBW / ICMR / PM / 4 处 cascode triode / MMtail / swing / S/D 接反）+ 根因表
    tokens: ~1700
  - name: reference-design
    summary: production-grade 4-stack + 9-MOSFET wide-swing bias tree 网表 + standard cir/tb 路径 + sizing 起点 + V3 sizing 修复教训 + connectivity 陷阱
    tokens: ~1200

trigger:
  explicit:
    user_selected_pack: telescopic_ota
  implicit:
    keywords:
      - telescopic
      - telescopic OTA
      - telescopic cascode
      - telescopic_ota
      - 套筒式
      - 套筒式 cascode
      - high-efficiency cascode OTA
      - power-eff OTA

related:
  knowledge:
    - blocks/base-cells/cascode
    - blocks/base-cells/current-mirror/wide-swing
    - blocks/base-cells/differential-pair
    - blocks/folded-cascode-ota   # 邻居拓扑：相同 gain 但 ICMR/swing 不同
    - blocks/5t-ota                 # baseline
    - blocks/two-stage-ota          # gain ceiling 替代
    - simulators/ngspice
    - pdks/vpdk180nm
  skills:
    - device_sizing
    - ac_feedback_loop_method
    - signal_tracing
  tools:
    - simulate
    - generate_testbench
    - dc_snapshot
    - op_point_check
    - causal_trace
    - inspect_device
    - inspect_node
    - propose_knob

hierarchy: block
applicable_pdks: any
applicable_simulators: [ngspice]
authors: ["cirona team"]
---

# Telescopic OTA 设计参考

## Quick Facts

- Telescopic OTA = NMOS 差分对 + NMOS cascode + PMOS cascode + PMOS mirror（**4-stack 单 branch**）
- 典型 gain **60-80 dB**（与 FC 相当），GBW 30-120 MHz @ CL=1pF
- 适用：power-efficiency 优先 + ICMR 可控 + VDD ≥ 1.5V 场景
- **Power 比 FC 省 1.5-2×**（单 branch vs FC 双 branch）
- **ICMR 紧（≈ 0.4V）+ swing 紧（0.4-0.6V）**——这是 power 优势的代价
- 9 个 bias tree MOSFET + **wide-swing 同密度铁律**（bias 支路 = 主支路 单管电流密度）

## Cheatsheet (vpdk180nm, VDD=1.8V, ibias=10µA, m_tail=8 → I_tail=80µA)

| Spec | 典型值 | 影响因素 |
|---|---|---|
| DC gain | 60-80 dB | gm_MM1 × (Rout_p ‖ Rout_n)，**Rout_n 含 ro_MM1**（Telescopic 特性）|
| GBW | 30-120 MHz | gm_MM1 / (2π·CL)（cascode source 节点 cap 较 fold node 小）|
| Phase margin | 55-70° | 第二极点 cascode source；通常较 FC 宽松 |
| Power | **100-500 µW** ⭐ | I_tail × VDD（**单 branch**，省 1.5-2× vs FC）|
| **Output swing** ⚠️ | **0.4-0.6V**（4-stack 紧） | 4 段 Vov 占 0.7-0.8V |
| **ICMR** ⚠️ | **0.4-0.5V 窗口** | input pair 在 cascode 路径中，VCM 严格依赖 vbnc |
| Input-referred noise | 低 | cascode 抑制 mirror flicker（与 FC 相当）|

## 4D Trade-off vs 其他 OTA

| 维度 | 5T | FC | **Tele** | 2-stage |
|---|---|---|---|---|
| Gain | 40-55 dB | 60-80 dB | **60-80 dB** | 80-100 dB |
| GBW | 1-50 MHz | 30-100 MHz | **30-120 MHz** | 10-50 MHz |
| **Power**（@gain 70dB）| 低 | 中-高 | **省（最低）⭐** | 较高 |
| **Swing** | ≈ 1.0V | 0.6-0.8V | **0.4-0.6V** ⚠️ | ≈ 1.6V |
| **ICMR** | 中 | 宽 | **紧 ⚠️** | 宽 |

详细对比见 `architecture.md`。

## Telescopic 设计 Iron Law（拓扑特有）

```
1. wide-swing 同密度铁律 ⭐:
   - bias 支路（MMbp_nc / MMbn_pc）m 倍数 = 主支路单管电流密度
   - MMbp_nc.m = m_load × m_tail / (2 × m_bias)
   - V3 sizing 修复 case：违反此则 gain 仅 3 dB（vbnc 落点错）

2. 4-stack headroom 严格预算:
   - 每段 Vov ≤ 0.20V（@VDD=1.8V）
   - 总 Vov + 5 × margin < VDD - swing_target
   - VDD < 1.5V → telescopic 物理不行（换 FC）

3. ICMR 严格落 VCM 窗口:
   - 典型 VCM = 0.7-0.9V @ VDD=1.8V（窗口 0.4-0.5V）
   - VCM_max = vbnc - 50mV
   - VCM_min = Vov_tail + Vth_n + Vov_diff + 50mV

4. 调主管 W/L 必同步 wide-swing 同名 device:
   - W_cascode = W_MMbnc_top（NMOS cascode 与 vbnc 生成 diode）
   - W_casp = W_MMbpc_bot（PMOS cascode 与 vbpc 生成 diode）
   - 单边动 → vbnc / vbpc 落点漂

5. 修 4 处 bias 节点 triode 都通过 padding 调（不调主管 W/L）:
   - MM1 triode    → vbnc ↑（L_pad_n ↑）
   - MMcasc triode → vbnc ↓（L_pad_n ↓）
   - MMcasp triode → vbpc ↑（L_pad_p ↓）
   - MM3 triode    → vbpc ↓（L_pad_p ↑）
```

## When to load this knowledge

- 用户 spec 含 "telescopic" / "套筒式" / "telescopic cascode"
- gain 60-80 dB 单级 OTA + power efficiency 优先（FC 太耗电时首选）
- ADC preamp（VCM 严格控制 → ICMR 紧不是问题）
- 低噪声放大器（cascode 抑制 mirror flicker）
- VDD ≥ 1.5V

## When NOT to load

- gain 要求 < 50 dB → 用 `blocks/5t-ota`（更简单）
- gain 要求 > 90 dB → 用 `blocks/two-stage-ota`（双级）
- ICMR 灵活（VCM 范围 > 0.5V）→ 用 `blocks/folded-cascode-ota`（fold 解耦 ICMR）
- VDD < 1.5V → 4-stack 撑不开，换 FC 或 2-stage
- LDO EA 大 dropout → telescopic input 跟随 vref 可能 ICMR 出范围

## Related

- `blocks/base-cells/cascode` cascode 物理 + bias 决定下管 Vds
- `blocks/base-cells/current-mirror/wide-swing` wide-swing bias scheme（vbnc / vbpc 生成 + 同密度铁律）
- `blocks/folded-cascode-ota` 邻居拓扑（相同 gain，但 ICMR/swing/power 取舍不同）
- `blocks/5t-ota` baseline 对比（gain 不够时升级到 Telescopic）
- `blocks/two-stage-ota` gain ceiling 替代（gain > 90 dB 时换）
- `skills/ac_feedback_loop_method` AC Method C 测 PM/GBW
- `skills/device_sizing` 通用 sizing 流程 + R1-R4 铁律
