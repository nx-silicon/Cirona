---
chapter: standard-tests
parent: two-stage-ota
summary: |
  Two-stage OTA 标准测试套件（OTA-T1~T6）— DC OP closed-loop (主推) / AC
  Method C closed-loop / PSRR / Slew rate / ICMR / Settling。
  Iron Law: DC 与 AC 必须用同一激励（DC closed via Rfb=1G/10Meg + Cfb=1F →
  AC open at f > fc≈0.16nHz）。high-gain (≥60dB) two-stage open-loop DC
  不可靠（mismatch 被开环增益放大），open-loop 仅作 sanity 备用模板。
tokens: ~900
prerequisite_chapters:
  - reference-design
  - architecture
related_skills:
  - ac_feedback_loop_method
  - signal_tracing
related_knowledge:
  - simulators/ngspice
  - simulators/ngspice/testbench-patterns
  - blocks/base-cells/differential-pair/cm-range
---

# Two-Stage OTA 标准测试套件

## Iron Law

任何 two-stage OTA 设计必须跑下列 P0 全集才算"验证完成"。**缺任一项 = 未验证**。

**testbench 激励 IRON LAW（DC 与 AC 必须一致）**：

1. **DC OP**（默认）→ **closed-loop**：Rfb=1G/10Meg + Cfb=1F，VINP 接 Vcm + AC 1，VINN 由 Rfb 跟随
2. **AC gain/GBW/PM** → **closed-loop Method C**：与 DC 同一 testbench 激励（同一 Rfb/Cfb），仅切换 `.op` ↔ `.ac`
3. **DC 与 AC 共用同一组 Vinp/Ibias/Rfb/Cfb 激励** —— 调好 DC 工作点的目的就是给 AC 一个正确的小信号模型；DC 用 open-loop、AC 用 closed-loop 混用 → 两者 OP 不同 → AC 测出的 gain/PM 与实际部署状态无关，**毫无意义**
4. **Open-loop DC（VINP=VINN 强制）仅作 sanity 备用模板**：用于 mismatch=0 理想拓扑下的 device region 验证；high-gain (≥60dB) two-stage open-loop 时，stage1/stage2 mismatch 被开环增益放大就飘 rail，这是物理规律不是 sizing bug
5. **Slew rate / Settling（OTA-T4 / T6）大信号 transient** 需要 open-loop 激励（closed-loop 的 Rfb 把 vout 拉回静态点会盖住 slew/settling）；但 transient 起始 OP 必须用 closed-loop 模板的设计参数收敛

详细模式对比 + 跨电路通用规则见横切章 `simulators/ngspice/testbench-patterns`。

---

## P0 必测项（不通过不得发布）

| 测试 ID | 测试名 | testbench 激励 | 关键测量 | Pass Criterion |
|---|---|---|---|---|
| **OTA-T1** | DC OP @ Vcm_in nominal | **closed-loop**（Rfb=1G/10Meg + Cfb=1F） | 全 device region / Vds_margin / bias chain | 全 SAT，Vds_margin > 50mV，vx 不在 rail |
| **OTA-T2** | AC Gain / GBW / PM | **closed-loop Method C**（与 T1 共用激励，切 `.ac`） | dc_gain, GBW, PM | 满足 spec target；PM ≥ 60° 默认 |
| **OTA-T3** | PSRR | closed-loop + VDD AC 注入 | PSRR_DC, PSRR @1kHz/100kHz | spec target；@HF 通常受 ESR 限制 |
| **OTA-T4** | Slew rate | open-loop + Tran 大信号阶跃 | SR+ / SR− | spec target；通常 = I_stage2 / CL |
| **OTA-T5** | ICMR (Input CM range) | DC sweep VINP=VINN（open-loop 形式）| 输出范围 / 增益保持 | 在 spec ICMR 范围内 device 全 SAT |
| **OTA-T6** | Settling time | open-loop + Tran 小信号阶跃 | 0.1% / 1% settling | spec target；与 GBW 关联 |
| **OTA-T1b** | DC OP sanity（可选）| open-loop（VINP=VINN 强制）| 与 T1 对照看 mismatch | 用于诊断：T1 fail 但 T1b pass → Rfb/mirror match；两者都 fail → sizing |

---

## OTA-T1: DC OP @ Vcm_in nominal（closed-loop，主推）

### testbench 关键配置（与 T2 共用激励）

```spice
* OTA-T1 DC OP — closed-loop（DC closed via Rfb + Cfb，与 T2 同一 testbench）
* high-gain two-stage 必须用闭环 DC，open-loop 时 mismatch 被开环增益放大就飞 rail
Vcm  vcm  0   DC <Vcm_in>
Vinp vinp vcm DC 0 AC 1            $ AC 1 仅 T2 用，DC 模式下不影响
Rfb  vout vinn 1G                  $ DC 闭环 (fc≈0.16nHz)；high-gain 时可降至 10Meg/100Meg
Cfb  vinn 0   1                    $ Cfb=1F 让 vinn AC 接地（T2 用）
X1 vinp vinn vout ibias vdd vss two_stage_ota
.op
```

### Pass criterion

| 检查项 | 标准 |
|---|---|
| 全 device region | 全 SAT（cutoff / triode 任一 = FAIL） |
| Vds_margin = Vds − Vdsat | > 50 mV（10× corner 余量） |
| vx (Stage1 真输出) | 不在 rail；典型 0.4-0.6V（PMOS-input + NMOS-mirror） |
| vout (Stage2 输出) | 不在 rail；典型 ≈ VDD/2 |
| vinn vs Vcm | 误差 < 50mV（Rfb 收敛紧）；偏离大 → Rfb 太大或 stage1 imbalance |
| Itail 实测 vs 设计 | 误差 < 5% |

### 常见 FAIL 原因

| 症状 | 根因 | 修复 |
|---|---|---|
| vinn 偏离 Vcm > 50mV | Rfb 太大让 DC loop 太软 / stage1 mirror imbalance | Rfb 降至 10Meg-100Meg；同时验 MN3/MN4 W·m match |
| MPTAIL Vsd < Vdsat | tail headroom 不够，Vov_diff 太大 | 减 W_diff / 加 L_tail / 改 input pair 极性 |
| vx ≈ 0V（钉到 VSS） | input pair sub-threshold，gm 灾难 | 检查 input pair 极性 self-check（cm-range L2）|
| Itail 漂大 | bias chain 镜像比例算错 | 见 architecture Pitfall 3（mirror 用 W·m 比） |
| vout 飘 rail（closed-loop 下也飘）| stage1/stage2 上下电流真不匹配 / sizing 问题 | 看 m_MP6 vs m_MN6；详见 troubleshooting 模式 9 决策树 |

### OTA-T1b: DC OP sanity（open-loop 备用）

**仅作诊断对照**（不作主验证），定位"closed-loop 下 vout 飘 rail"的根因：

```spice
* OTA-T1b DC OP sanity — open-loop（mismatch=0 sanity 检查）
VINP vinp 0 DC <Vcm_in>            $ 直接 DC 强制
VINN vinn 0 DC <Vcm_in>
* NO Rfb, NO Cfb — 仅作 sanity，不是主测
.op
```

诊断逻辑：
- T1 fail（closed-loop） + T1b pass（open-loop） → Rfb 量级 / Cfb / stage1 mirror imbalance
- T1 fail + T1b fail → 真 sizing 问题（tail headroom / 极性 / 上下电流匹配）
- T1 pass + T1b fail（vout 飘 rail）→ **预期常见**，high-gain open-loop 物理本就不可靠

---

## OTA-T2: AC Gain / GBW / PM（Method C closed-loop）

### testbench 关键配置

```spice
* OTA-T2 AC PM/GBW — Method C: DC closed via Rfb=1G+Cfb=1F (fc≈0.16nHz),
*                              AC open at all freq of interest
Vcm  vcm  0   DC <Vcm_in>
Vinp vinp vcm AC 1                  $ AC 注入在 vinp ↔ vcm
Rfb  vout vinn 1G                   $ DC 闭环（fc≈0.16nHz）
Cfb  vinn 0   1                     $ AC 全开
X1 vinp vinn vout ibias vdd vss two_stage_ota
CL vout 0 <CL>
.ac dec 50 1 1G

.control
  set units = degrees               $ ⭐ vp() 返回度数（不加默认弧度）
  run
  setplot ac1
  let gain_db   = db(abs(v(vout)/v(vinp)))
  let phase_deg = vp(vout) - vp(vinp)
  meas ac dc_gain      find gain_db    at=1
  meas ac gbw_hz       when gain_db=0  cross=1
  meas ac phase_at_ugf find phase_deg  when gain_db=0 cross=1
  meas ac phase_dc     find phase_deg  at=1
  * Anchor-difference PM 公式（universal，不依赖拓扑反相数）:
  meas ac pm_deg       param='180 - (phase_dc - phase_at_ugf)'
.endc
```

### Pass criterion

| 检查项 | 标准 |
|---|---|
| dc_gain | ≥ spec target |
| GBW (UGF) | ≥ spec target |
| PM | ≥ 60° 默认（spec 严苛时 ≥ 70°） |
| 单调性 sanity | gain 高频单调下降，无 peaking（≥ 5dB peak = oscillation 风险） |

### 常见 FAIL 原因

| 症状 | 根因 | 修复 |
|---|---|---|
| PM = 178° (实际应 ~3°) | 漏 `set units = degrees`（vp() 默认弧度） | 加 `set units = degrees` |
| dc_gain ≈ 0 dB | DC OP 不收敛或 input pair 失衡 | 先跑 OTA-T1 验 DC OP 通过 |
| GBW < spec / PM 紧 | gm6 < 12 × gm1 (PM IRON LAW 违) | 加 W_stage2_n 或减 Cc |
| 高频 peaking ≥ 5dB | RHP zero 没消（Rz ≠ 1/gm6）| 调 Rz ≈ 1/gm6 |
| dc_gain 比设计低 30dB+ | input pair 跑亚阈值 (PMOS ceiling 违) | 见 cm-range L2 self-check |

---

## OTA-T3: PSRR（closed-loop + VDD AC 注入）

### testbench 关键配置

```spice
* OTA-T3 PSRR — VDD AC 注入，closed-loop 同 T2
Vdd vdd 0 DC <VDD> AC 1             $ ⭐ AC 注入在 VDD（不是 vinp）
Vcm vcm 0 DC <Vcm_in>
Vinp vinp vcm DC 0                  $ vinp 不注入 AC
Rfb  vout vinn 1G
Cfb  vinn 0   1
.ac dec 50 1 100MEG

.control
  setplot ac1
  let psrr_db = -db(abs(v(vout)/v(vdd)))    $ PSRR = 1 / (Vout/Vdd)
  meas ac psrr_dc    find psrr_db at=1
  meas ac psrr_1k    find psrr_db at=1k
  meas ac psrr_100k  find psrr_db at=100k
.endc
```

### Pass criterion

PSRR 频段曲线应单调下降（DC 最高 → 高频退化）。具体目标按应用：
- LDO EA 应用：PSRR @ 1kHz > 50dB
- ADC reference：PSRR @ DC > 60dB

---

## OTA-T4: Slew rate（open-loop + 大信号 Tran）

### testbench 关键配置

```spice
* OTA-T4 Slew rate — 大信号阶跃，open-loop
VINP vinp 0 PULSE(<Vcm-100mV> <Vcm+100mV> 100ns 1ns 1ns 1us 2us)
VINN vinn 0 DC <Vcm_in>             $ vinn 不变
X1 vinp vinn vout ibias vdd vss two_stage_ota
CL vout 0 <CL>
.tran 10n 5u

.control
  meas tran sr_pos deriv v(vout) at=200n
  meas tran sr_neg deriv v(vout) at=1.2u
.endc
```

**Pass criterion**：SR ≥ I_stage2 / CL（理论上限）。spec 通常 5-50 V/µs。

---

## OTA-T5: ICMR（DC sweep VINP=VINN）

### testbench 关键配置

```spice
* OTA-T5 ICMR — sweep Vcm，看 input pair / tail device region
VINP vinp 0 DC <Vcm_in>
VINN vinn 0 DC <Vcm_in>
.dc VINP <Vcm_min> <Vcm_max> 0.05
* meas region of MP1/MP2/MPTAIL (input pair) at each Vcm
```

**Pass criterion**：spec ICMR 范围内 input pair + tail 全 SAT。
**违规根因**：input pair 极性错（cm-range ceiling/floor 违 → ICMR 范围崩）。

---

## OTA-T6: Settling time（open-loop + 小信号 Tran）

testbench 类似 T4 但小信号阶跃（10mV）+ measure 0.1% / 1% settling time。
理论上限 settling time ≈ 5 / GBW（一阶近似）。

---

## 测试套件执行顺序

```
1. OTA-T1（DC OP）       ← 必先过，不过别跑后续（仿真无意义）
2. OTA-T2（AC PM/GBW）   ← 评 spec
3. OTA-T3（PSRR）        ← LDO EA / ADC 应用必跑
4. OTA-T4（Slew）        ← 大信号驱动应用必跑
5. OTA-T5（ICMR）        ← rail-to-rail 应用必跑
6. OTA-T6（Settling）    ← ADC SHA / 高速应用必跑
```

OTA-T1 fail 时**绝对不要**跑 T2-T6（DC OP 错的网表跑 AC 全是垃圾结果，浪费 turn）。

## When NOT to skip

- "AC 测出 PM=65° spec 满足，DC 不用看了" — **错**。AC `.ac` 在 T1 的 closed-loop OP 上跑，
  你必须**先单独 `.op`** 看每个 device 的 region 和 Vds_margin。`.ac` 自己不会
  报告 device 进 triode（只看小信号导纳，triode 区一样有 gm）。
- "我已经手工算了 DC OP 节点电压" — **不算**。仿真才是 truth。

## Related

- `simulators/ngspice/testbench-patterns`（横切章：testbench 模式选择 IRON LAW）
- `simulators/ngspice/common-errors`（vp() 度数 / .meas 语法等通用陷阱）
- `architecture.md`（拓扑层级化决策 + 已知陷阱表）
- `troubleshooting.md`（DC OP triode 灾难症状 → 决策树）
- `ac-stability.md`（PM 不够时的 Cc/Rz 调整）
- skill `ac_feedback_loop_method`（Method C 通用断环原理）
