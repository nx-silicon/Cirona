---
chapter: reference-design
parent: folded-cascode-ota
summary: |
  Production-grade FC-OTA reference (NMOS-input single-ended)：5 group core + 9-MOSFET wide-swing bias tree
  + standard cir/tb 路径 + sizing 起点 + PMOS cascode connectivity 陷阱（FC-OTA E2E v3 实战卡点）。
  Iron Law: 写 FC-OTA 必先复用 reference cir，不要从零造拓扑。
tokens: ~900
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

# FC-OTA Reference Design

## Iron Law

**Reference design 优先**：写 FC-OTA 时**必须**先用 `load_knowledge(name='folded-cascode-ota', asset='reference_designs/fc_ota.cir')` 拿 321 行 self-contained 网表，复制为起点。**从零造 FC-OTA 拓扑几乎必踩 PMOS cascode source/drain 接错 trap**（FC-OTA E2E v3 实战：agent 把 MP5_top.D 接到 NMOS fold junction → 反向导通 → vout 锁死 1.8V，浪费 10+ turn 修复）。

## Quick reference (assets)

| Asset | 用途 |
|---|---|
| `reference_designs/fc_ota.cir` | 完整网表（321 行, 20 MOSFET） |
| `reference_designs/tb_dc_op.sp` | DC OP testbench |
| `reference_designs/tb_ac_gain_bw.sp` | AC gain/BW/PM testbench |

通过 `load_knowledge(name='folded-cascode-ota', asset='<上表 Asset 列>')` 拿原文。**禁止用 `read_file` 读知识库内容** — knowledge tool 是唯一合规入口。

## Standard subckt port order

```spice
.subckt folded_cascode_ota vinp vinn vout ibias vdd vss
```

## Core topology — 5 group (11 core MOSFETs)

```
                               VDD
                  +-------------+-------------+
                  |                           |
           [MP1_bottom]                [MP3_bottom]   Group 2: PMOS fold sources
              S=vdd                       S=vdd       (G=vbias_fold)
              D=vmid_left1                D=vmid_right1
                  |                           |
                  +-- vmid_left1              +-- vmid_right1
                  |                           |
            [MP2_top]                  [MP4_top]      Group 3: PMOS cascode (top!)
            S=vmid_left1               S=vmid_right1   ← S 接 fold 输出
            G=vbc_p                     G=vbc_p       (vbc_p 来自 bias tree)
            D=vd_left                   D=vout        ← D 接 mirror master / 输出
                  |                           |
            [MN1] (G=vinp, D=vmid_left1, S=ntail)        Group 1: NMOS diff pair
            [MN2] (G=vinn, D=vmid_right1, S=ntail)        signal current 注入 fold junction
              |                                                  |
            [MNtail] (G=ibias, D=ntail, S=vss)
                  |
                  +-- vd_left                +-- vout (输出节点)
                  |                           |
            [MN6_top]                  [MN8_top]      Group 4: NMOS cascode (top!)
            S=vmid_left2               S=vmid_right2   ← S 接 mirror drain
            G=vbc_n                     G=vbc_n
            D=vd_left                   D=vout        ← D 接 cascode high-Z 节点
                  |                           |
                  +-- vmid_left2              +-- vmid_right2
                  |                           |
          [MN5_bottom]               [MN7_bottom]    Group 5: NMOS mirror (bottom)
          D=vmid_left2               D=vmid_right2
          G=vd_left (master diode)   G=vd_left (slave mirror)
          S=vss                       S=vss
                  |                           |
                  +-------------+-------------+
                                |
                               VSS
```

**关键 connectivity rules（违反必锁死）**：

| Group | Device | source 接 | drain 接 | gate 接 | 常见错 |
|---|---|---|---|---|---|
| 2 PMOS fold | MP1_bottom / MP3_bottom | **vdd**（PMOS source 接 vdd）| vmid_left1 / vmid_right1（fold junction）| vbias_fold | gate 接 ibias 而非 vbias_fold → 没 mirror fold 电流 |
| 3 PMOS cascode | MP2_top / MP4_top | **vmid_left1 / vmid_right1**（fold junction，PMOS source 在高电压侧）| **vd_left / vout**（mirror master / 输出）| vbc_p | ⚠️ S/D 接反 → vd_left 高于 vmid_left1，PMOS 反向导通 → vout 锁死 1.8V（FC-OTA v3 t40 challenge_dv_verdict 实战） |
| 4 NMOS cascode | MN6_top / MN8_top | **vmid_left2 / vmid_right2**（mirror drain，NMOS source 在低电压侧）| **vd_left / vout**（cascode high-Z）| vbc_n | S/D 接反 → 类似锁死 |
| 5 NMOS mirror | MN5_bottom / MN7_bottom | vss | vmid_left2 / vmid_right2 | **vd_left**（共 gate）| MN5 没 diode-connected (D≠G) → mirror 失效；MN5 D=vd_left 让它 diode 是错（应该 D=vmid_left2，diode 通过 cascode MN6 link 到 vd_left）|

> ⚠️ **PMOS cascode source 在高电压、drain 在低电压**：MOSFET 物理 — 电流从 PMOS source 流向 drain（与 NMOS 相反）。MP2_top 的 source 在 vmid_left1（≈ 1.4V），drain 在 vd_left（≈ 1.0V）。**反过来接 = 反向导通**。

## Bias tree (9 MOSFETs, generates 4 bias voltages)

| Bias node | 由谁生成 | 用途 |
|---|---|---|
| `ibias` (NMOS Vgs) | `MMNbias` (NMOS diode) | 所有 NMOS mirror 的 gate ref（MNtail / MMNfold_bias / MMN_vbcp_sink） |
| `vbias_fold` | `MMPfold_bias` (PMOS diode, matches fold W/L) → `MMNfold_bias` (sink) | PMOS fold (MP1/MP3) gate；MMP_vbcn_src gate 复用此 |
| `vbc_p` (PMOS cascode bias) | `MMP_vbcp_1` (padding triode) → `MMP_vbcp_2` (PMOS diode) → `MMN_vbcp_sink` | MP2_top / MP4_top gate |
| `vbc_n` (NMOS cascode bias) | `MMP_vbcn_src` (PMOS source) → `MMN_vbcn_2` (NMOS diode) → `MMN_vbcn_1` (padding triode) | MN6_top / MN8_top gate |

**Wide-swing scheme**：`vbc_n = Vgs(MMN_vbcn_2) + Vds(MMN_vbcn_1)` ≈ (Vth + Vov) + Vov_pad → MN5_bottom Vds ≈ Vov_pad → output swing 下沿 ≈ 2·Vov（不是 Vth+2·Vov）。详见 `blocks/base-cells/current-mirror/wide-swing`。

## DC current paths

| Path | 方向 | KCL |
|---|---|---|
| 1 Left signal | VDD → MP1_bottom → vmid_left1 → MP2_top → vd_left → MN6_top → vmid_left2 → MN5_bottom → VSS | I(MP1_bottom) = I(MP2_top) + I(MN1) |
| 2 Right (output) | VDD → MP3_bottom → vmid_right1 → MP4_top → vout → MN8_top → vmid_right2 → MN7_bottom → VSS | I(MP3_bottom) = I(MP4_top) + I(MN2) |
| 3 Tail | (vmid_left1 / vmid_right1 via MN1/MN2) → ntail → MNtail → VSS | Itail = ibias × (m_tail / m_bias) |

## Sizing 起点 (vpdk180nm, ibias=10µA)

| 参数 | role | W | L | m | 备注 |
|---|---|---|---|---|---|
| `W_diff` | NMOS diff pair (MN1/MN2) | 4.4 µm | 1 µm | 1 | gm/Id ≈ 12, 主 gain 决定 |
| `W_bias` | NMOS bias diode (MMNbias / MNtail / mirrors) | 3.3 µm | 1 µm | 1 (m_tail=2) | Itail = ibias × 2 = 20µA |
| `W_fold` | PMOS fold (MP1_bottom/MP3_bottom + MMPfold_bias) | 24.7 µm | 2 µm | 2 | I_fold = 2 × I_branch |
| `W_pcasc` | PMOS cascode (MP2_top/MP4_top + MMP_vbcp_2) | 8.9 µm | 2 µm | 6 | 共享 m=6 multiplier 提 ro |
| `W_ncasc` | NMOS cascode (MN6_top/MN8_top + MMN_vbcn_2) | 9.1 µm | 1 µm | 1 | matches mirror W |
| `W_nmirror` | NMOS mirror (MN5_bottom/MN7_bottom) | 4.4 µm | 1 µm | 1 | mirror reference |
| `W_pad_p` | padding in vbc_p generator | 1 µm | 2 µm | 1 | 调 vbc_p headroom |
| `W_pad_n` | padding in vbc_n generator | 1 µm | 2 µm | 1 | 调 MN5 Vds（wide-swing 关键）|

## Standard testbench 模板（DC OP 与 AC 共用激励）

> ⭐ **IRON LAW（DC 与 AC 必须用同一激励）**：
> - **DC OP 默认 closed-loop**（Rfb=1G/100Meg + Cfb=1F），与 AC testbench 同一组
>   Vinp/Ibias/Rfb/Cfb 激励，仅切换 `.op` ↔ `.ac`
> - **High-gain 单级 OTA (60-80dB) open-loop DC 不可靠**：fold ratio mismatch /
>   cascode bias misalignment / 上下电流不匹配，被开环增益放大就让 vout 飘 rail
> - **Open-loop DC（VINP=VINN 强制）仅作 sanity 备用**：与 closed-loop 对比定位
>   Rfb 量级问题 vs sizing 真问题
> - 详见横切章 `simulators/ngspice/testbench-patterns`

实际 reference testbench 在 `assets/reference_designs/`：
- `tb_dc_closed.sp` ← ⭐ **DC OP closed-loop**（主推，与 AC 共用激励）
- `tb_dc_op.sp`     ← DC OP sanity 备用（open-loop，mismatch=0 对照）
- `tb_ac_gain_bw.sp` ← Method C closed-loop（AC 测 PM 用，下方模板）

### Template 1: DC OP（closed-loop，主推）

```spice
* DC Operating Point — closed-loop（与 AC testbench 同一激励，仅切 .op）
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include '../design/fc_ota.cir'
.param VCM = 0.9
Vdd  vdd 0  DC 1.8
Vinp vinp vcm DC 0 AC 1     $ AC 1 仅 .ac 用，.op 模式下不影响
Vcm  vcm 0  DC VCM
Rfb  vout vinn 1G           $ DC 闭环 (fc≈0.16nHz)；不收敛时降至 100Meg-10Meg
Cfb  vinn 0 1               $ Cfb=1F：AC 路径上 vinn 接地
Ibias vdd ibias 10u
X1   vinp vinn vout ibias vdd 0 folded_cascode_ota
.op
.control
  set noaskquit
  run
  echo "=== vinn vs Vcm（验 closed-loop 收敛）==="
  print v(vinp) v(vinn) v(vout)
  * 各 device region 检查：见 tb_dc_closed.sp 完整列表
.endc
.end
```

**Pass criterion**：所有 device region=SAT，Vds_margin > 50mV，**vinn 应与 Vcm
收敛在 50mV 以内**（偏离过大 → Rfb 太大 / fold mirror imbalance）。

### Template 2: AC gain / GBW / PM（与 Template 1 共用激励）

```spice
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include '../design/fc_ota.cir'
.param VCM = 0.9
Vdd  vdd 0  DC 1.8
Vinp vinp vcm DC 0 AC 1     $ 同 Template 1
Vcm  vcm 0  DC VCM
Rfb  vout vinn 1G           $ 同 Template 1
Cfb  vinn 0 1               $ 同 Template 1
Ibias vdd ibias 10u
X1   vinp vinn vout ibias vdd 0 folded_cascode_ota
.ac dec 50 1 1G
.control
  set units = degrees
  run
  let gain_db   = db(abs(v(vout)/v(vinp)))
  let phase_deg = vp(vout) - vp(vinp)
  meas ac dc_gain      find gain_db    at=1
  meas ac gbw_hz       when gain_db=0  cross=1
  meas ac phase_dc     find phase_deg  at=1
  meas ac phase_at_ugf find phase_deg  when gain_db=0 cross=1
  * Anchor-difference PM (universal):
  *   PM = 180° - (phase_dc - phase_at_ugf) — phase 走过的距离与 -180° 的余量
  * 适用：FC-OTA 主极点远高于 1Hz，phase_dc=at(1Hz) 干净
  meas ac pm_deg       param='180 - (phase_dc - phase_at_ugf)'
.endc
.end
```

### Template 1b: DC OP sanity（open-loop，仅作诊断对照）

仅当 Template 1 closed-loop 下 vout 飘 rail 时用本模板做对照（见 `tb_dc_op.sp`）。
诊断逻辑：
- T1 fail / T1b pass → Rfb 量级或 fold mirror imbalance
- T1 fail / T1b fail → 真 sizing 问题（fold ratio / cascode bias / W·m）
- T1 pass / T1b 飘 rail → **预期常态**（high-gain open-loop 物理本不可靠）
```

## 已知设计陷阱（FC-OTA E2E v3 + V3 历史教训）

| 陷阱 | 表现 | 修复 |
|---|---|---|
| **PMOS cascode S/D 接反**（MP2/MP4） | DC OP fail，vout 锁死 1.8V，nvg=0V | MP2.S=vmid_left1, MP2.D=vd_left（fold→cascode→mirror 路径），不要反 |
| **NMOS cascode S/D 接反**（MN6/MN8） | 类似 | MN6.S=vmid_left2, MN6.D=vd_left |
| **fold ratio coupling**：改 m_tail 不同步改 m_fold | 一边 cascode branch 缺电流 → device cutoff | I_fold (= ibias × m_fold/m_bias) ≥ Itail/2 + 安全裕度 |
| **MN5 triode**（wide-swing 失效）| MN5.Vds < Vdsat → mirror master 在 triode | 调 W_pad_n / L_pad_n 让 MMN_vbcn_1 提供合适 Vds |
| **vbias_fold 共享但 W/L 不 match**（MMPfold_bias ≠ MP1_bottom W/L）| vbias_fold 不 mirror 真 I_fold | MMPfold_bias W/L 必须 = MP_fold W/L（current ratio = m_bias/m_fold）|
| AC vp() 当度数 → PM 错 57× | PM 178° 实际 3° | testbench `set units = degrees` |

## When to use this reference

- gain 60-80 dB 单级 OTA / FC-OTA / 折叠共源共栅
- LDO EA loop gain 60-80 dB 设计

## When NOT to use

- gain < 50 dB → 5T-OTA 简单太多
- gain > 90 dB → two-stage OTA 双级 EA
- 1.2V 以下 VDD（FC-OTA 9 bias 树堆 headroom 紧）→ 用 telescopic-low-voltage 变体（不在本章）

## 不在本章范围

- cascode 物理 + bias 决定下管 Vds 因果链 → `blocks/base-cells/cascode`
- wide-swing bias scheme 详细推导 → `blocks/base-cells/current-mirror/wide-swing`
- gm/ID sizing 通用方法 → skill `device_sizing`
- AC Method C 通用断环 → skill `ac_feedback_loop_method`

## 下一步 Required Action

1. 通过 `load_knowledge(name='folded-cascode-ota', asset='reference_designs/fc_ota.cir')` 抄拓扑（device 连接 / fold 结构 / bias tree，不复制数值）；同样方式拿 `reference_designs/tb_dc_closed.sp` 和 `reference_designs/tb_ac_gain_bw.sp`
2. 推导自己 spec 的 W/L/m（R0 铁律：diff pair / fold PMOS / cascode / mirror sizing 必须按目标 GBW 和 ibias 重推，bias 支路电流密度与主支路保持一致，不可复制参考数值）
3. `write_file` → `design/fc_ota.cir` + `design/sizing.yaml`
4. `simulate` `testbench/tb_dc_closed.sp` → 验证 DC OP（closed-loop 主测）/ 再跑 `tb_ac_gain_bw.sp` 验 gain/PM（与 DC 共用激励）。仅当 vout 飘 rail 需诊断时再跑 `tb_dc_op.sp` 做 open-loop sanity 对照
