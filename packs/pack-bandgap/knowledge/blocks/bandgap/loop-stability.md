---
chapter: loop-stability
parent: bandgap
summary: |
  Bandgap 外环 AC 稳定性专章 — 多极点位置（yg / mirror / na/nb / vref load）+
  OTA 内 Miller 补偿 + 外环 yg cap Ccomp 选取 + tb_psrr / tb_loop_ac 模板 +
  ringing 失稳调整范例。类比 OTA ac-stability（bandgap 是 OTA + mirror +
  PNP 复合 loop）。Miller 补偿原理见 base-cell。
tokens: ~1500
prerequisite_chapters:
  - architecture
related_skills:
  - circuit-method/ac-feedback-loop-method
related_knowledge:
  - blocks/base-cells/miller-compensation
  - blocks/5t-ota
  - simulators/ngspice
---

# Bandgap Loop Stability

> 通用 AC 断环方法（Method C：Rfb=1G + Cfb=1F）见 `skill: ac-feedback-loop-method`。
> OTA 内 Miller 补偿原理（pole splitting + RHP zero + nulling Rz）见
> `blocks/base-cells/miller-compensation` + `blocks/two-stage-ota/ac-stability`。
> 本章节给的是 **bandgap 拓扑特有**的：(1) 外环多极点分布；(2) OTA Miller +
> 外环 Ccomp 双重补偿决策；(3) tb_psrr / tb_loop_ac 模板；(4) ringing 失稳
> 调整范例。

## 极点分布（**bandgap 外环 = OTA + mirror + PNP 复合 loop**）

bandgap 在目标工作点附近形成 **闭环负反馈** 调节环路（OTA 强制 V(na)=V(nb)，
3-leg PMOS mirror 由 OTA 输出 yg 驱动）。startup 支路负责脱离零电流稳态分支，
但不是正常调节环路的反馈路径。loop 关键节点（高阻 / 大寄生）：

### 候选主极点 1：yg 节点（OTA 输出 + mirror gate）

```
f_p_yg = 1 / (2π · R_OTA_out · C_yg)
其中 R_OTA_out = OTA 输出阻抗（2-stage 输出 ≈ ro_M2 ‖ ro_MP6）≈ 100 kΩ - 1 MΩ
      C_yg = Cgs_MP1 + Cgs_MP2 + Cgs_MP3 + Cgd × (1+A) + Ccomp（外加 cap）
            （3 PMOS mirror gate cap 共 yg 节点）
```

**典型位置**：W_P=10µm × 3 leg → C_yg ≈ 30-50 fF + Ccomp 2 pF → C_yg 总 ≈ 2 pF
（Ccomp 主导）→ f_p_yg ≈ 100 kHz - 1 MHz。

### 候选主极点 2：core sense 节点（na / nb / vref）

```
f_p_core = 1 / (2π · R_branch · C_branch)
其中 R_branch = R2 ≈ 180 kΩ（na/nb branch）+ R_OUT ≈ 165 kΩ（vref branch）
      C_branch = Cdb_PNP + 寄生（≈ 几十 fF）
```

**典型位置**：~ MHz 级（branch R 大但 cap 小）。

### 候选次极点：vref load + decap

```
f_p_load = 1 / (2π · R_OUT · C_load)
若 vref 直接加 decap C_load = 1-10 pF → f_p_load ≈ 100 kHz - 1 MHz
```

> **复合 loop 关键事实**：bandgap 外环至少有 2 个主极点候选（yg + core）
> + 1 个 vref load 极点。哪两个成为慢极点取决于 OTA sizing / PNP model /
> load。这是 bandgap 与单级 OTA 最大差异——**不是单极点主导**，必须主动
> 补偿。

## 补偿哲学（**双重补偿铁律**）

bandgap 标准补偿是**双重**：

```
1. OTA 内 Miller compensation（跨 stage2）:
   Cmiller = 3 pF
   Rz = 1 / gm6 ≈ 20 kΩ（消 RHP zero）
   作用：保证 OTA 自身 PM > 60°（不带外环 mirror 时）

2. 外环 yg cap Ccomp：
   Ccomp = 2 pF（yg ↔ vss）
   作用：把 yg 节点极点 f_p_yg 推得足够低（成为主极点），
        让其他极点远高于 GBW
```

> **R2 双重补偿铁律**：
> - 单 Miller（无 Ccomp）→ OTA 稳但 mirror 加上后外环可能振荡
> - 单 Ccomp（无 Miller）→ OTA 内 RHP zero 让 PM 退化
> - **必须双重**（Miller 救 OTA + Ccomp 救外环）

## 极点分布完整图（双重补偿后）

```
   主极点 f_p_yg              GBW              其他高频极点
   |                           |                         
   |  ────────────────────────|─────────────────────  freq
       100 kHz                  10-100 kHz 级（loop）        > MHz
       (Ccomp + OTA Rout)
```

> **bandgap loop 期望 GBW 极低（< 100 kHz）**——bandgap 不是高速电路，
> loop BW 主要保证 PVT settle、PSRR 中频带 + LDO load step response。

## ⭐ 范例 1：外环 oscillation（缺 Ccomp）

### 症状
tb_startup tran 后 Vref 持续振荡（mid-MHz 频率，不收敛）；或 tb_psrr 在
1 MHz 附近有 peaking > 5 dB。

### R1 KVL 反推
```
两个极点（f_p_yg + f_p_core）位置接近 → loop 经过 -180° 时 gain 仍 > 0 dB
→ 振荡条件成立

f_p_yg = 1/(2π · R_OTA_out · C_yg)
f_p_core = 1/(2π · R_branch · C_branch)

如果 |f_p_yg - f_p_core| < 1 decade → PM 紧张/崩
```

### 三条调节路径
**路径 A — 加 Ccomp 在 yg 上**（首选）：
- 让 f_p_yg 大幅下降 → 主极点更主导 → 其他极点相对推远
- 起点 Ccomp = 1-5 pF；V3 baseline 用 2 pF

**路径 B — 调 OTA Miller**：
- 让 OTA 自身 stage2 极点远离 → OTA 输出 stage 不再贡献第二极点
- Cmiller = 1-5 pF，配 Rz = 1/gm6

**路径 C — 减 OTA gain**：
- gain ↓ → loop gain ↓ → unity gain 频率提前 → 在 -180° 之前已 < 0 dB
- 副作用：PSRR / line reg 退化

### R3 推理
```
看到 Vref ringing 或 PSRR peaking
  ↓
inspect_node('yg'): tran 看 yg 是否同样 ringing
  ↓
inspect_node('na', 'nb'): 看 na/nb 是否跟 yg 同步 ringing
  ↓
判定：
  - yg + na/nb 都 ringing → 外环失稳 → 路径 A（加 Ccomp）
  - 只 OTA 内部 ringing（na/nb 稳）→ OTA 自身失稳 → 路径 B（调 Miller）
  - 跨 corner 才 ringing → 边界 case → 路径 A + 增 margin
```

### 不要做
- ❌ **加大 Ccomp 大幅度（> 10 pF）**：让主极点过低，loop BW 严重缩水，
  PSRR 中频带退化
- ❌ **同时调 Miller + Ccomp 又增 OTA gain 又 ...**：变量太多 sweep 不收敛
- ❌ **靠减 OTA gain 救振荡**：不仅 PSRR / line reg 都退化，loop 锁定 na ≈ nb
  也变弱（lock_err 增）

## ⭐ 范例 2：PSRR 偏低（< 50 dB DC）

### 症状
tb_psrr 测 PSRR @ DC < 50 dB；spec 通常 60-70 dB。

### R1 反推
```
DC PSRR 由 OTA loop gain × mirror ro 复合决定。
单位修正：ro_PMOS（Ω）不能直接转 dB 与 OTA gain 加；需以无量纲 (gm·ro) 形式
代入 loop gain 闭环表达式才得 dB。趋势：

A_OTA ↑（30 → 40 dB）→ DC PSRR ↑
mirror L ↑（0.18 → 1 → 2 µm）→ ro_PMOS ↑ → 进入 loop gain → DC PSRR ↑
non-cascoded mirror → supply feedthrough 仍显著，工程 50-60 dB 是常见上限区间
cascoded mirror → ro 翻倍数提升 → DC PSRR > 70 dB 可达
```

### 修复路径
| 路径 | 怎么做 | 副作用 |
|---|---|---|
| L_P ↑（1 → 2µm）| ro_PMOS ↑ → PSRR ↑ | mirror gate cap ↑（不影响 DC PSRR）|
| OTA gain ↑（30 → 40 dB）| 加 cascode in OTA stage1 | OTA 复杂度 ↑ |
| **Cascoded mirror** | 加 PMOS cascode → ro × gm·ro 倍数 | PSRR > 70 dB 唯一路径 + 占 headroom |
| 外加 LDO 后级 | LDO 用 bandgap 当 reference + LDO 自有 PSRR | 系统级 |

> **R2 铁律**：first-order non-cascoded bandgap PSRR 物理上限**随 OTA 偏置类型而变**：
>
> | OTA 偏置拓扑 | 实测 PSRR @ 1kHz | 原因 |
> |---|---|---|
> | **R_BIAS + NMOS-diode self-biased OTA**（V3 baseline / Demo 01 v6 实证）| **~37-40 dB** | bp 节点 VSS 参考，Vsg_M_TAIL = VDD - bp 直接随 VDD 调制 |
> | + PMOS mirror cascoded（cascode gate VSS-ref）| ~45-55 dB | 加 cascode 改善 ~10 dB |
> | **beta-multiplier 自偏置 OTA**（bp 与 VDD 解耦）| 60-70 dB | 架构重设计，bp 不再随 VDD 走 |
> | **cascoded everything + post-LDO 二级** | > 70 dB | 系统级方案 |
>
> **Spec PSRR > 50 dB 时必须升级偏置拓扑，不是参数微调**（Demo 01 v6 用 50+ turn 验证此结论 —— 在 R_BIAS+NMOS-diode 偏置下追逐 60dB 不可达）。

### Anti-pattern
- ❌ **加 cap 想救 PSRR**：cap 改频率特性不改 DC PSRR
- ❌ **加 OTA gain 大幅度（> 50 dB）**：bandgap 不需要那么大 gain，且 stability 难保

## ⭐ 范例 3：Cross-corner PSRR 退化

**症状**：TT @ 27°C PSRR OK；FF / SS / -40 / 125°C 任一 corner PSRR 跌 5+ dB。

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| OTA gain 跨 corner 退化 | tb_psrr 跨 corner 跑 + 看 OTA 自身 gain 漂 | OTA 加 cascode 或加 m_tail 给余量 |
| Mirror ro 跨 corner 退化 | 看 ro_PMOS 跨 corner | L_P ↑（gives margin）|
| Vbe slope 跨 temperature 改变（影响 OTA input 共模）| OTA input region 跨 -40/125 看 saturation | 留 OTA tail Vov 余量 |

## tb_psrr.sp / tb_loop_ac.sp 模板

### tb_psrr.sp（标准 PSRR @ DC + AC）

```spice
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './bandgap.cir'
VDD vdd 0 DC 1.8 AC 1                $ AC 注入到 VDD
Xdut vdd 0 vref bandgap

.ac dec 50 1 10Meg
.control
  set units = degrees
  run
  let psrr_db = -vdb(vref)            $ PSRR = -20·log10(|vref/vdd|)
  meas ac psrr_dc      find psrr_db at=1
  meas ac psrr_at_1k   find psrr_db at=1k
  meas ac psrr_at_1M   find psrr_db at=1Meg
  print psrr_dc psrr_at_1k psrr_at_1M
  wrdata psrr.dat psrr_db
.endc
.end
```

### tb_loop_ac.sp（外环 PM / GBW，Method C 断环）

bandgap loop 断点选在 **yg 节点 ↔ mirror gate 之间**：

```spice
* 断 OTA 输出 yg 与 mirror MP1/MP2/MP3 gate 之间
* 加 Rfb=1G + Cfb=1F 让 DC 闭环 / AC 开环
... (Method C 标准 setup) ...

.ac dec 50 1 10Meg
.control
  set units = degrees
  run
  let gain_db   = db(abs(v(yg_open) / v(yg_closed)))
  let phase_deg = vp(yg_open) - vp(yg_closed)
  meas ac dc_gain      find gain_db    at=1
  meas ac gbw_hz       when gain_db=0  cross=1
  meas ac phase_dc     find phase_deg  at=1
  meas ac phase_at_ugf find phase_deg  when gain_db=0 cross=1
  * Anchor-difference PM (universal):
  *   PM = 180° - (phase_dc - phase_at_ugf)
  * Bandgap loop GBW 10-50kHz，主极点 ~Hz 级，phase_dc=at(1Hz) 略有滞后
  * 但 1Hz 仍在主极点附近 (误差 < 10°)，方法 B 可用；
  * 如外环 Ccomp 大让主极点 << 1Hz，改用 LDO 方法 C 起点观察法
  meas ac pm_deg       param='180 - (phase_dc - phase_at_ugf)'
  print dc_gain gbw_hz pm_deg
.endc
.end
```

期望：DC loop gain ≥ 60 dB / GBW 10-50 kHz / PM ≥ 60°。

## 不在本章范围

- **OTA 内 Miller 补偿物理推导（pole splitting + RHP zero + Rz 数学）** → `blocks/base-cells/miller-compensation` + `blocks/two-stage-ota/ac-stability`
- **OTA 5T 自身 PM**（not loaded with mirror）→ `blocks/5t-ota/ac-stability`
- **Cascoded mirror PSRR > 70 dB variant** → `blocks/base-cells/{cascode, current-mirror}`
- **TC sweep / curvature 分析** → `architecture.md` § zero-TC 条件
- **Startup tran ringing**（与外环 ringing 区分）→ `startup.md` Mode 2
- **OTA polarity 错引发的 DC latch（不是 AC 失稳）** → `architecture.md` Pitfall 4

## Related

- `architecture.md` zero-TC + Pitfall 6（外环 oscillation 总览）
- `sizing-typical.md` Step 7-9（OTA + Miller + Ccomp sizing）
- `startup.md` Mode 2（startup oscillation 区别）
- `blocks/base-cells/miller-compensation` Miller 补偿物理
- `blocks/two-stage-ota/ac-stability` 2-stage OTA 内部 Miller
- `skill: ac-feedback-loop-method` Method C 通用断环
