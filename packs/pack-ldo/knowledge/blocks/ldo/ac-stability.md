---
chapter: ac-stability
parent: ldo
summary: |
  LDO AC 稳定性：主极点 / 次极点位置 + 断环 testbench 配置 +
  补偿策略（ESR / Miller / Cload）+ Iload 影响因果
tokens: ~900
prerequisite_chapters:
  - architecture
related_skills:
  - circuit-method/ac-feedback-loop-method
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/miller-compensation
  - simulators/ngspice
---

# LDO AC 稳定性

## LDO 极点结构（事实）

LDO 是**两极点系统主导**（多数情况）：

| 极点 | 位置 | 频率（典型）| 因果 |
|---|---|---|---|
| **主极点 fp_main** | 输出节点 | 1 - 100 kHz | 1/(2π × Rout × Cload)，Cload 主导 |
| **次极点 fp_EA** | EA 输出（pass FET 栅）| 100 kHz - 10 MHz | 1/(2π × Rout_EA × Cgs_pass)，pass FET Cgs 大决定 |
| 零点（ESR）| 由 Cload 串 ESR 引入 | f_ESR = 1/(2π × ESR × Cload) | ESR 在 0.1-10 Ω 时给 1k-1MHz 零点 |

**关键事实**：pass FET Cgs 很大（W ~ 1400 µm → Cgs ~ pF 级）+ EA 输出阻抗也高（cascode / 双级几百 kΩ）→ fp_EA 在 100 kHz - 1 MHz 间。**LDO 是 fundamentally output-pole-dominated** + **pass-gate-pole-secondary** 的两极点系统。

## 稳定性判据（因果）

| PM | 含义 | LDO 实际表现 |
|---|---|---|
| > 60° | 稳定 + 过冲小 | spec 推荐 |
| 45-60° | 稳定但 ringing | 边缘可接受（spec 通常要求 ≥ 45°）|
| < 45° | 边缘 / 不稳定 | 拒绝；改补偿或 EA gain |
| 30° 以下 | 振荡 / 不稳定 | 几乎肯定测得 vout 振荡 |

**关键因果链**：
- Cload 增大 → fp_main 降低 → 与 fp_EA **更分离** → PM 改善
- EA gain 增大 → loop UGB 推高 → 离 fp_EA **更近** → PM **下降**
- Iload 增大 → gm_pass 增大（√Id 关系）→ Rout 降低（gm_pass 大让 Cload 节点输出阻抗减少）→ fp_main **升高** → 离 fp_EA 更近 → PM **下降**
- ESR 适度 → 引入零点抵消 fp_EA 影响 → PM 改善（但 ESR 不能太大，会出新极点）

## Iload 是稳定性变化主因（必须全 corner 测）

```
gm_pass = (μp·Cox)·(W/L)·Vsg = √(2·μp·Cox·(W/L)·Iload)        # 平方律
fp_main = 1/(2π × Rout × Cload)
       Rout 含 1/gm_pass × (1+T_local) 等小项 → 仍随 Iload 变
UGF ≈ T₀ × fp_main
```

→ Iload 1mA → 50mA 时 UGF 可能升 5-10 倍（实测 V3 ldo overview 给的极端例子：1.7 kHz @ 1mA → 290 kHz @ 50mA = 170× 漂——这是补偿错的征兆，正常应 5-10×）。

**实战清单**：
- 必须仿 Iload_min / Iload_typ / Iload_max 三点 PM
- PM 最差通常在 Iload_max（heavy load）
- 全 corner 测（FF / SS / TT × 温度低 / 高）

## AC 断环 testbench（LDO 特定 — Method C 标准实现）

> ⚠️ **Iron Law（LDO v4 实战教训）**：写 LDO AC testbench **必须** 直接用 `load_knowledge(name='ldo', asset='reference_designs/tb_ac_loopgain.sp')` 拿 65 行 production-grade testbench 作为起点。**不要从 skill 模板自己合成 testbench** —— LDO v4 实测 5 次 hypothesis declare/close 都因 Method C 实现细节卡住（floating Vac 不收敛 / Vac DC=0 钳偏置 / 断点错 / 测量公式符号反 / loop gain 结果 ≈ 0），用 V3 reference template 直接跳过。

### V3 reference testbench assets

| Asset | 用途 |
|---|---|
| `reference_designs/tb_ac_loopgain.sp` | 完整 Method C AC OL（65 行） |
| `reference_designs/tb_psrr.sp` | 完整 Method C PSRR（52 行） |
| `reference_designs/tb_load_transient.sp` | load transient（46 行） |

通过 `load_knowledge(name='ldo', asset='<上表 Asset 列>')` 拿原文。

### 推荐断点：vfb 节点（反馈分压器后）

```
        VDD ──┬──────────┬────────────────┐
              │          │                │
            EA gain   pass FET           Iload
              │          │                │
              ▼          ▼                ▼
            vg_pass ───►│              vout ──┬─ Cload + ESR
              ▲                                │
              │ (EA inv input)              R1│
                                              │
                                           vfb│ ← AC 断点（注入 + 测量）
                                              │
                                           R2 │
                                              │
                                            VSS
```

**为什么在 vfb 断**：
- vfb 节点是低阻（被 R2 钳位 + EA 输入电容很小）→ Cfb=1F 不会拖动 DC
- 断点之后是完整 forward path（EA + pass + Cload）+ feedback divider，loop gain 正确包含全环

### Method C 标准 testbench template（**直接抄，不要改细节**）

```spice
* ==================================================================
* AC loop gain — PMOS LDO (Method C — Middlebrook-style)
*   Rfb = 1 GΩ from vout to vfb_dc (DC loop closed)
*   Cfb = 1 F  from vfb_dc to GND  (AC ground → loop AC-broken)
*   Vinj = AC 1 between vfb and vfb_dc (注入 AC at vfb)
*   T(f) = v(vout) / v(vfb)
* ==================================================================

.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include '../design/your_ldo.cir'

Vvdd   vdd    0      DC 1.8
Vvss   vss    0      DC 0
Vref   vref   0      DC 0.9         $ external bandgap or ideal source
Ibias  vdd    ibias  DC 10u
Iload  vout   vss    DC 10m         $ light load (PM 通常 worst @ heavy load)

* Output filter: 1 µF + 0.1 Ω ESR (典型 LDO 外置 cap)
Resr   vout    vout_cap  0.1
CL     vout_cap vss      1u

* ── Method C AC break at vfb ──
*   DC: Rfb 1G 闭环 (vfb_dc 跟 vout); Vinj DC=0 → vfb=vfb_dc=vout (DC 闭环)
*   AC: Cfb 1F 接地 vfb_dc; Vinj AC=1 让 vfb 在 AC 摆 1V，vfb_dc 静默
Rfb   vout    vfb_dc  1e9
Cfb   vfb_dc  0       1
Vinj  vfb     vfb_dc  DC 0 AC 1     $ 浮动 Vac，DC=0=短路，AC=1=注入 ⭐ KEY

X1 vdd vss vout ibias vref vfb your_ldo

.control
  set noaskquit
  set units = degrees      $ vp() / wrdata 直接输出度数（不用 180/PI 转换）
  ac dec 50 1 1G
  setplot ac1              $ AC mixed plot 必须切 (op1 → ac1)

  let gain_db   = db(abs(v(vout)))
  let phase_deg = vp(vout)         $ set units=degrees 后直接是度

  meas ac dc_gain      find gain_db   at=1
  meas ac ugf          when gain_db=0 cross=1
  meas ac phase_dc     find phase_deg at=1
  meas ac phase_at_ugf find phase_deg when gain_db=0 cross=1

  * ── Anchor-difference PM 公式（convention-independent，无 ±180° wrap 陷阱）──
  let phase_loss   = phase_dc - phase_at_ugf
  let phase_margin = 180 - phase_loss

  echo "=== AC loop gain results ==="
  print dc_gain ugf phase_dc phase_at_ugf phase_margin

  wrdata ../simulation/tb_ac/ldo_loopgain.dat gain_db phase_deg
.endc
.end
```

### LDO v4 实战卡过的细节（5 次 hypothesis 教训 codify）

| 错误写法 | 后果 | 正确做法 |
|---|---|---|
| `Cfb vinn 0 1` (Cfb 接 EA 输入端 vinn 而非 vfb_dc) | DC 偏置失败（Cfb 把 vinn 短路到地，M2.Vgs 错）| Cfb 必须接 **vfb_dc** 节点（Rfb 的另一端，不是 EA 输入）|
| `Vac vfb 0 AC 1` (Vac 一端接地，DC=0 钳住 vfb) | vfb DC=0 → M2 反馈失败 → vout 漂 | **浮动** Vinj：`Vinj vfb vfb_dc DC 0 AC 1`（**两端都接节点不接地**）|
| `Vac vfb 0 DC 0.9 AC 1` (用 Vac 钳 DC=0.9) | Vac 把 vfb 钳固定 0.9V，反馈不动 → loop gain ≈ 0 | 浮动 Vinj，DC 由 Rfb 闭环自动 |
| 测量点用 `v(vfb)` 或 `v(vdiv)` | 测的不是 loop gain | T(f) = `v(vout) / v(vfb)`，因为 v(vfb) ≈ 1V@AC，所以 `db(abs(v(vout)))` 直接 = T_db |
| PM 公式 `180 + phase_at_gbw` | 当 phase 跨过 ±180° wrap 时算错 | **anchor-difference**: `phase_margin = 180 - (phase_dc - phase_at_ugf)`，convention-independent |
| 没设 `set units = degrees` | vp() 返回弧度，PM 数字 57× 错 | **必加** `set units = degrees` 在 `.control` 块顶 |

### Iload corner sweep（必做）

不要只测 Iload=10mA 一点，必须 worst case：

```spice
* tb_ac_loopgain_100ma.sp（同上 testbench，仅改 Iload）
Iload vout vss DC 100m       $ heavy load corner

* PM 通常在 heavy load 最差（gm_pass↑ → fp_main 移动 → 离 fp_EA 近 → PM↓）
```

通用断环思路（为什么 Rfb=1G / Cfb=1F / 不在高阻节点断）见 skill `circuit-method/ac-feedback-loop-method`。
LDO 整体 reference design（cir + 各 testbench）见 chapter `reference-design`。

## 补偿策略（事实 + 因果）

| 策略 | 原理 | 代价 | 何时用 |
|---|---|---|---|
| **大 Cload + ESR** | Cload 降 fp_main / ESR 引入零点抵消 fp_EA | 面积大 / 启动慢 | 标准 LDO 默认 |
| **Miller Cc** | Cc 跨 EA 2nd stage 拉低主极点 + 推 fp_EA 高 | EA 面积 + GBW 折损 | 双级 EA + 期望 capless 或小 Cload |
| **Cc + 串联 R（nulling resistor）** | 消除 RHP zero（Cgd_pass × Cc 引入）| 调 R 选 1/(gm_pass) | Miller 补偿 LDO 必加 |
| **Ahuja / current buffer Miller** | 完全消除 RHP zero | 多一个器件 | 高速 LDO |
| **buffered EA**（FVF / pre-buffer）| 隔离 pass gate 大 Cgs | 加一级 → headroom 紧 | capless 高效 LDO |

**补偿决策序列**（不是流程，是事实分级）：
- ESR 控制（外置 cap）：标准 LDO 第一选项
- 调 EA gain（适度降低）：用过补偿换 PM——慎用，PSRR 会降
- Miller Cc（双级 EA 必需）：第二选项
- Ahuja / FVF：高频 / 高效 LDO 才用

## 验证清单

- [ ] DC OP 解出 vout ≈ vref（断环后仍闭合 DC，Iload 自动调节）
- [ ] EA tail device 在 saturation（polarity 验证，参考 architecture chapter）
- [ ] pass FET 在 saturation（DC 状态）
- [ ] gain_dc > 50 dB（5T-EA 不够 → 见架构 chapter）
- [ ] gbw 在 100 kHz - 2 MHz（典型）
- [ ] PM > 60° @ TT typical Iload
- [ ] **PM > 45° @ Iload_max + corner FF**（worst case）
- [ ] Cload + ESR 模型与生产物料一致（陶瓷 vs 钽）

## 常见 AC 稳定性陷阱

| 心里想 | 现实 |
|---|---|
| "Cload 用 ideal cap 仿稳定就行" | 没 ESR → 主/次极点不分裂 → 实际 PCB 必振 |
| "PM 60° 一个 Iload 点过了就行" | 必须全 Iload_min/max + corner，PM 通常在 heavy load 最差 |
| "改 Cc 试试看" | 没 Iron Law derivation 先停——参考 skill `circuit-method/device-sizing` 给 Cc 物理因果 |
| "EA gain 调高一点" | gain ↑ → UGF ↑ → 离 fp_EA 近 → PM ↓——可能反向 |
| "断环看着 PM=178° 应该稳" | 100% 是 `vp` 弧度未转度（180/π 误差）；查 ngspice common-errors |
| "DC sweep + Rfb=1G 拖动 vout" | 对，DC sweep 不能用这个断环，要专门 testbench |

## 不在本章范围

- **通用断环思路 / 为什么 1G+1F**——见 skill `circuit-method/ac-feedback-loop-method`
- **Miller 补偿原理 / RHP zero 消除**——见 `blocks/base-cells/miller-compensation/`
- **PSRR 频段特性**——见 `chapter=psrr`（Week 3）
- **Cc / nulling R 具体 sizing**——见 skill `device-sizing` + `blocks/base-cells/miller-compensation/sizing-typical.md`
- **load transient 过冲**——见 `chapter=overshoot`（Week 3）
- **ngspice setplot / meas / wrdata 语法**——见 `simulators/ngspice/analyses.md` + `measurements.md`
