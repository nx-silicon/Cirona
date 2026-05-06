---
chapter: reference-design
parent: telescopic-ota
summary: |
  Production-grade Telescopic Cascode OTA reference (NMOS-input single-ended)：
  4-stack core (diff pair + NMOS cascode + PMOS cascode + PMOS mirror) +
  9-MOSFET wide-swing bias tree + standard cir/tb 路径 + sizing 起点。
  Iron Law: 写 Telescopic OTA 必先复用 reference cir，4-stack headroom 紧，
  从零造拓扑必踩 cascode bias 接错 + padding sizing trap。
tokens: ~1200
prerequisite_chapters: []
related_skills:
  - device_sizing
  - ac_feedback_loop_method
related_knowledge:
  - blocks/base-cells/cascode
  - blocks/base-cells/current-mirror/wide-swing
  - simulators/ngspice
  - pdks/vpdk180nm
---

# Telescopic OTA Reference Design

## Iron Law

**Reference design 优先**：写 Telescopic OTA 时**必须**先用
`load_knowledge(name='telescopic-ota', asset='reference_designs/telescopic_ota.cir')` 拿网表
复制为起点。**Telescopic 4-stack headroom 极紧（VDD=1.8V 下 swing 仅 0.4-0.6V）**——
从零造拓扑几乎必踩：
1. cascode bias 接错（MMcasc.S vs MMcasc.D 极性翻）
2. padding device sizing trap（线性区 Vds 决定 vbnc/vbpc 落点）
3. bias 支路电流密度与主支路不匹配 → wide-swing 失效

**V3 实战教训**（2026-04-22 sizing 修复）：原 sizing 让 vbnc 偏置支路只跑
`ibias` (10µA)，主 cascode 跑 `I_tail/2` (40µA) → 密度失配 → vbnc 塌陷 →
diff pair 进 triode → gain 仅 3 dB。修法：让 bias 支路 m 倍数 = `m_tail/2`
（与主支路同电流密度），强制 wide-swing pad 的 Vgs 与主 cascode 匹配。

## Quick reference (assets)

| Asset | 用途 |
|---|---|
| `reference_designs/telescopic_ota.cir` | 完整网表（199 行 self-contained, 18 MOSFET） |
| `reference_designs/tb_dc_op.sp` | DC OP testbench |
| `reference_designs/tb_ac_gain_bw.sp` | AC gain/BW/PM testbench |

通过 `load_knowledge(name='telescopic-ota', asset='<上表 Asset 列>')` 拿原文，做最小 sizing 调整后 `write_file` 写到自己的
`<project>/<cell>/design/` 目录。**禁止用 `read_file` 读知识库内容** — knowledge tool 是唯一合规入口。

## Standard subckt port order

```spice
.subckt telescopic_ota vinp vinn vout ibias vdd vss
```

## Core topology — 4-stack (10 core MOSFETs)

```
                  VDD
        +----------+----------+
       MM3                  MM4         Group 4: PMOS mirror（MM3 diode-via-cascode, G=vout_n; MM4 mirror）
        D=nload_n            D=nload
        |                    |
      MMcasp3              MMcasp4      Group 3: PMOS cascode（G=vbpc, S=nload_n/nload, D=vout_n/vout）
        |                    |
      MMcasc1              MMcasc2      Group 2: NMOS cascode（G=vbnc, S=ncasc_n/ncasc, D=vout_n/vout）
        |                    |
       MM1                  MM2         Group 1: NMOS diff pair（G=vinp/vinn, S=ntail, D=ncasc_n/ncasc）
        |                    |
        +---------+----------+
                  |
               MMtail                   Tail（G=ibias, D=ntail, S=vss, mirror MMbias）
                  |
                 VSS
```

**Telescopic vs FC 拓扑关键差异**：input pair 直接堆在 cascode 路径中
（MM1.D = MMcasc1.S = ncasc），电流不"折叠" → 省一条 branch（power 比 FC
省 1.5-2×）；FC 是 input pair 独立 branch + fold 到 cascode（多一 branch，
ICMR 宽）。

**关键 connectivity rules（违反必锁死）**：

| Group | Device | source 接 | drain 接 | gate 接 | 常见错 |
|---|---|---|---|---|---|
| 1 NMOS diff pair | MM1 / MM2 | **ntail**（共 source）| **ncasc_n / ncasc**（接 cascode source）| vinp / vinn | ⚠️ MM1.D 接 vout_n 而非 ncasc_n → 跳过 cascode → telescopic 变 5T |
| 2 NMOS cascode | MMcasc1 / MMcasc2 | **ncasc_n / ncasc**（input pair drain，NMOS source 在低电压侧）| **vout_n / vout**（cascode high-Z）| vbnc | S/D 接反 → 反向导通锁死 |
| 3 PMOS cascode | MMcasp3 / MMcasp4 | **nload_n / nload**（mirror drain，PMOS source 在高电压侧）| **vout_n / vout** | vbpc | S/D 接反，类似 FC PMOS cascode trap |
| 4 PMOS mirror | MM3 / MM4 | vdd | nload_n / nload | **vout_n**（共 gate，diode-via-cascode）| MM3.G 接 nload_n（diode 自身端）→ mirror 失败；正确是 G=vout_n（cascode 上方节点）|

> ⚠️ **MM3 / MM4 的 diode-connect 路径**：MM3 是 mirror master，但它的 gate
> 不是直接接 D（nload_n），而是接 cascode 上方（vout_n）—— 这是 **cascoded
> mirror diode** 的标准接法（diode-connect 通过 cascode 形成）。直接接 nload_n
> 会让 mirror feedback 不经过 cascode，cascode 高 ro 失效。

## Bias tree (9 MOSFETs, generates 4 bias voltages)

| Bias node | 由谁生成 | 用途 |
|---|---|---|
| `ibias` (NMOS Vgs) | `MMbias` (NMOS diode) | 所有 NMOS mirror 的 gate ref（MMtail / MMbn2p / MMbn_pc）|
| `nbias_p` | `MMbn2p` (NMOS sink) → `MMbp_ref` (PMOS diode) | PMOS mirror 的 gate ref（MMbp_nc）|
| `vbnc` (NMOS cascode bias) | `MMbp_nc` (PMOS source) → `MMbnc_top` (NMOS diode) → `MMbnc_bot` (NMOS linear pad) | MMcasc1 / MMcasc2 gate |
| `vbpc` (PMOS cascode bias) | `MMbpc_top` (PMOS linear pad) → `MMbpc_bot` (PMOS diode) → `MMbn_pc` (NMOS sink) | MMcasp3 / MMcasp4 gate |

**Wide-swing scheme（telescopic 关键）**：
```
vbnc = Vgs(MMbnc_top) + Vds(MMbnc_bot_pad)     ← linear pad Vds 调 vbnc 落点
vbpc = VDD − |Vds(MMbpc_top_pad)| − |Vgs(MMbpc_bot)|

→ ncasc = vbnc − Vgs_MMcasc ≈ Vds_pad         ← cascode source = padding Vds
→ Vds_MM1 = ncasc − ntail                      ← 由 padding 决定 input pair 余量
```

**这是 telescopic 4-stack headroom 紧的物理来源**：每段 Vds 都由 cascode bias
间接决定，padding 是抓手。

## DC current paths

| Path | 方向 |
|---|---|
| 1 Left (signal) | VDD → MM3 → nload_n → MMcasp3 → vout_n → MMcasc1 → ncasc_n → MM1 → ntail → MMtail → VSS |
| 2 Right (output) | VDD → MM4 → nload → MMcasp4 → vout → MMcasc2 → ncasc → MM2 → ntail → MMtail → VSS |
| 3 Bias ref | ibias → MMbias(diode) → VSS （mirrors to MMtail / MMbn2p / MMbn_pc）|
| 4 vbnc gen | VDD → MMbp_nc → vbnc → MMbnc_top(diode) → MMbnc_bot(linear pad) → VSS |
| 5 vbpc gen | VDD → MMbpc_top(linear pad) → MMbpc_bot(diode) → vbpc → MMbn_pc → VSS |

KCL：主支路 1/2 单边 = `I_branch = I_tail / 2`；bias 支路 4/5 = `I_branch`（同密度）。

> ⚠️ **wide-swing 关键**：bias 支路（4/5）必须与主支路（1/2）跑**同电流密度**
> —— 否则 MMbnc_top 的 Vgs 与 MMcasc 的 Vgs 不匹配，vbnc 落点错，wide-swing
> 失效。`m_MMbp_nc = m_load × m_tail / (2 × m_bias)`（V3 sizing 修复 2026-04-22）。

## AC signal flow (vinp > vinn)

1. MM1.gm × dvinp → I_MM1 ↑ → I_MMcasc1 ↑（cascode 透传）
2. I_MMcasp3 ↑ → 经 MM3 diode 形成 vout_n ↓
3. MM4 G=vout_n ↓ → |Vgs_MM4| ↑ → I_MM4 ↑（mirror 翻倍）
4. 输出 vout: MMcasp4(push) ↑ + MMcasc2(sink，I_MM2 ↓) ↓ → 净电流 ↑ → vout ↑

**Gain**: Av = gm_MM1 × Rout
- Rout = Rout_p ‖ Rout_n
- Rout_p = gm_casp · ro_MM3 · ro_MMcasp
- Rout_n = gm_casc · ro_MMtail · ro_MMcasc（**与 FC 不同**：tail 共享，ro_tail 进 Rout）
- 典型 gain：60-80 dB

**GBW**: gm_MM1 / (2π · CL)

## Sizing 起点 (vpdk180nm, ibias=10µA, m_tail=8 → I_tail=80µA, I_branch=40µA)

| 参数 | role | W | L | m | gm/Id | Vov | 备注 |
|---|---|---|---|---|---|---|---|
| `W_diff` | NMOS diff pair (MM1/MM2) | 10 µm | 1 µm | 8 | ~12 | 0.18 V | gm 主导 + 长 L 提 ro_MM1 |
| `W_load` | PMOS mirror (MM3/MM4) | 20 µm | 1 µm | 8 | ~10 | 0.20 V | μp/μn ≈ 1/4 → W_p 较 W_n 大 |
| `W_casc` | NMOS cascode (MMcasc1/2 + MMbnc_top) | 10 µm | 0.5 µm | 4 | ~10 | 0.18 V | matches diff pair density (W_eff = m × W) |
| `W_casp` | PMOS cascode (MMcasp3/4 + MMbpc_bot) | 20 µm | 0.5 µm | 4 | ~10 | 0.20 V | matches load density |
| `W_pad_n` | NMOS padding (MMbnc_bot, linear) | 1.5 µm | 1.5 µm | 1 | — | — | W/L ≈ 1 → Vds_pad ≈ 0.55V → ncasc ≈ 0.55V |
| `W_pad_p` | PMOS padding (MMbpc_top, linear) | 10 µm | 0.72 µm | 2 | — | — | sized for \|Vds\| ≈ \|Vov_load\| |
| `W_bias` | NMOS bias diode (MMbias / MMtail / MMbn_pc) | 5 µm | 1 µm | m_bias=1 / m_tail=8 / m=m_tail/2 | — | — | bias chain reference |
| `W_load_mirror_bias`（MMbp_nc）| PMOS bias mirror | 20 µm | 1 µm | `m_load × m_tail / (2 × m_bias)` | — | — | wide-swing 同密度铁律 |

⚠️ **数值标 @vpdk180nm**：换工艺时 µ·Cox 不同，要重新算 W。fold-free /
4-stack / wide-swing 关系跨工艺通用。

## Standard testbench 关键内容

```spice
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include '../design/telescopic_ota.cir'
.param VCM = 0.9
Vdd  vdd 0  DC 1.8
Vinp vinp 0 DC VCM AC 1
Rfb  vout vinn 1G        $ DC 闭环
Cfb  vinn 0 1
Ibias vdd ibias 10u
* port order: vinp vinn vout ibias vdd vss
X1   vinp vinn vout ibias vdd 0 telescopic_ota
CL   vout 0 2p
.ac dec 50 1 1G
.control
  set units = degrees
  run
  let gain_db   = db(abs(v(vout)/v(vinp)))
  let phase_deg = vp(vout) - vp(vinp)
  meas ac dc_gain      find gain_db    at=1
  meas ac gbw_hz       when gain_db=0  cross=1
  meas ac phase_at_gbw find phase_deg  when gain_db=0 cross=1
  meas ac pm_deg       param='180 + phase_at_gbw'
.endc
.end
```

## 已知设计陷阱（V3 实战教训 + Telescopic 物理特点）

| 陷阱 | 表现 | 修复 |
|---|---|---|
| **wide-swing bias 支路密度失配**（最常见，V3 修复案例）| dc_gain 仅 3-10 dB；vbnc 塌陷；diff pair 进 triode | bias 支路 m 倍数 = `m_tail/2`（同主支路密度）|
| **MM3 diode-connect 错（G=nload_n 而不是 vout_n）**| mirror 不经 cascode → ro 失效 → gain 30-40 dB | MM3.G = vout_n（cascode 上方）|
| **NMOS cascode S/D 接反**（MMcasc1/2）| DC 锁死，vout 卡 rail | MMcasc1.S=ncasc_n, MMcasc1.D=vout_n |
| **PMOS cascode S/D 接反**（MMcasp3/4）| 类似锁死 | MMcasp3.S=nload_n, MMcasp3.D=vout_n |
| **input pair Vds 不足**（MM1 进 triode）| sat_mm1 < 0；gain 低 | L_pad_n ↑ 提 vbnc → ncasc ↑ → MM1 Vds ↑（与 FC 范例 1 同范式）|
| AC vp() 当度数 → PM 错 57× | PM 178° 实际 3° | testbench `set units = degrees` |
| **VDD < 1.5V 用 telescopic**（4-stack headroom 不够）| swing 几乎为 0 | 换 FC-OTA（fold 解耦）|

## When to use this reference

- gain 60-80 dB 单级 OTA + 高 power 效率（FC 太耗电时首选）
- 输入共模可控且不需要 rail-to-rail input（telescopic ICMR 约 0.4V）
- VDD ≥ 1.5V（4-stack headroom 需 0.7-0.8V）
- 适合 ADC preamp / 高 gain low-noise OTA

## When NOT to use

- 输入共模需要灵活（VCM 范围 > 0.5V）→ 用 FC-OTA（fold 解耦 ICMR）
- gain > 90 dB → 用 2-stage OTA
- VDD < 1.5V → 4-stack headroom 不够，换 FC 或 2-stage
- LDO EA 大 dropout → telescopic input 跟随 vref，可能 ICMR 出范围

## 不在本章范围

- cascode 物理 + bias 决定下管 Vds 因果链 → `blocks/base-cells/cascode`
- wide-swing bias scheme 详细推导 → `blocks/base-cells/current-mirror/wide-swing`
- gm/ID sizing 通用方法 → skill `device_sizing`
- AC Method C 通用断环 → skill `ac_feedback_loop_method`
- 4 处 bias 节点 R1-R4 修复推理 → `bias-headroom.md`

## 下一步 Required Action

1. 通过 `load_knowledge(name='telescopic-ota', asset=...)` 拿以下文件抄拓扑（4-stack 连接 / bias tree，不复制数值）：
   - `reference_designs/telescopic_ota.cir`
   - `reference_designs/tb_dc_op.sp`
2. 推导自己 spec 的 W/L/m（R0 铁律：diff pair / cascode / mirror / bias 支路 m 倍数必须按目标 I_branch 和 wide-swing 密度匹配规则重推，不可复制参考数值）
3. `write_file` → `design/telescopic_ota.cir` + `design/sizing.yaml`
4. `simulate` `testbench/tb_dc_op.sp` → 验证 DC OP / 再跑 `tb_ac_gain_bw.sp` 验 gain/PM
