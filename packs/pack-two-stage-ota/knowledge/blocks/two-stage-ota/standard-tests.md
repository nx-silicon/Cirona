---
chapter: standard-tests
parent: two-stage-ota
summary: |
  Two-stage OTA 标准测试套件（OTA-T1~T6）— DC OP open-loop / AC Method C
  closed-loop / PSRR / Slew rate / ICMR / Settling。每项明确 testbench 模式
  (open vs closed) + Pass criterion + 实战陷阱（Demo 02 实证：DC OP 用闭环
  testbench → vinn 锁死 rail → triode 灾难 7-10 turn）。
  Iron Law: testbench 模式选错 = 仿真不收敛 / 收敛到错点；不能调 sizing 救。
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

**testbench 模式 IRON LAW**：

1. **DC OP** → 必 **open-loop**（VINP=VINN=Vcm_in 强制，无 Rfb）
2. **AC gain/GBW/PM** → 必 **closed-loop Method C**（Rfb=1G + Cfb=1F + AC 注入）
3. **不要混用** —— Demo 02 实证：DeepSeek 用 Rfb=1G 闭环 testbench 跑 DC OP，闭环正反馈把 vinn 锁死到 rail（vinn≈VDD → MP2 关 → vx≈0V → MN6 关 → vout→VDD），多个 device 进 triode，浪费 7-10 turn 才发现是 testbench 模式错（不是 sizing 错）

详细模式对比 + 跨电路通用规则见横切章 `simulators/ngspice/testbench-patterns`。

---

## P0 必测项（不通过不得发布）

| 测试 ID | 测试名 | testbench 模式 | 关键测量 | Pass Criterion |
|---|---|---|---|---|
| **OTA-T1** | DC OP @ Vcm_in nominal | **open-loop** | 全 device region / Vds_margin / bias chain | 全 SAT，Vds_margin > 50mV，vx 不在 rail |
| **OTA-T2** | AC Gain / GBW / PM | **closed-loop Method C** | dc_gain, GBW, PM | 满足 spec target；PM ≥ 60° 默认 |
| **OTA-T3** | PSRR | closed-loop + VDD AC 注入 | PSRR_DC, PSRR @1kHz/100kHz | spec target；@HF 通常受 ESR 限制 |
| **OTA-T4** | Slew rate | open-loop + Tran 大信号阶跃 | SR+ / SR− | spec target；通常 = I_stage2 / CL |
| **OTA-T5** | ICMR (Input CM range) | DC sweep VINP=VINN | 输出范围 / 增益保持 | 在 spec ICMR 范围内 device 全 SAT |
| **OTA-T6** | Settling time | open-loop + Tran 小信号阶跃 | 0.1% / 1% settling | spec target；与 GBW 关联 |

---

## OTA-T1: DC OP @ Vcm_in nominal（open-loop）

### testbench 关键配置（必抄不可改）

```spice
* OTA-T1 DC OP — open-loop（VINP=VINN=Vcm 强制）
VINP vinp 0 DC <Vcm_in>            $ NOT vcm + AC source
VINN vinn 0 DC <Vcm_in>            $ NOT through Rfb
* NO Rfb, NO Cfb — 闭环会让 vinn 收敛到错误静态点
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
| Itail 实测 vs 设计 | 误差 < 5% |

### 常见 FAIL 原因

| 症状 | 根因 | 修复 |
|---|---|---|
| **vinp/vinn 钉到 VDD 或 VSS** | testbench 用了 Rfb=1G 闭环（Demo 02 实证）| **去掉 Rfb，VINP=VINN=Vcm 直接 DC 强制** |
| MPTAIL Vsd < Vdsat | tail headroom 不够，Vov_diff 太大 | 减 W_diff / 加 L_tail / 改 input pair 极性 |
| vx ≈ 0V（钉到 VSS） | input pair sub-threshold，gm 灾难 | 检查 input pair 极性 self-check（cm-range L2）|
| Itail 漂大 | bias chain 镜像比例算错 | 见 architecture Pitfall 3（mirror 用 W·m 比） |

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

- "仿真已通过 OTA-T2，DC OP 应该 OK 不用单跑" — **错**。AC closed-loop testbench
  让 OP 强制收敛到 vcm，可能掩盖 device region 错（triode/cutoff）。**T1 单独 open-loop 跑才能暴露**。
- "我已经手工算了 DC OP 节点电压" — **不算**。仿真才是 truth。

## Related

- `simulators/ngspice/testbench-patterns`（横切章：testbench 模式选择 IRON LAW）
- `simulators/ngspice/common-errors`（vp() 度数 / .meas 语法等通用陷阱）
- `architecture.md`（拓扑层级化决策 + 已知陷阱表）
- `troubleshooting.md`（DC OP triode 灾难症状 → 决策树）
- `ac-stability.md`（PM 不够时的 Cc/Rz 调整）
- skill `ac_feedback_loop_method`（Method C 通用断环原理）
