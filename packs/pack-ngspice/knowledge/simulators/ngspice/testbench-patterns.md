---
chapter: testbench-patterns
parent: ngspice
summary: |
  Testbench 模式选择 IRON LAW — 跨电路通用横切章。DC OP 必 open-loop /
  AC 测 PM 必 closed-loop Method C / PSRR 必 VDD AC 注入 / 大信号必 Tran。
  模式选错 = 仿真不收敛或收敛到错点，调 sizing 救不了（Demo 02 实证：
  闭环 Rfb=1G 套 .op → vinn 锁 rail → triode 灾难 7-10 turn）。所有 PACK
  在 reference-design.md / standard-tests.md 中 reference 本章。
tokens: ~1000
prerequisite_chapters: []
related_skills:
  - ac_feedback_loop_method
related_knowledge:
  - simulators/ngspice/analyses
  - simulators/ngspice/measurements
  - blocks/two-stage-ota/standard-tests
  - blocks/ldo/standard-tests
---

# Testbench 模式 — IRON LAW（跨电路横切）

> **横切章**：本章是 ngspice testbench 模式选择的 single source of truth。
> 所有 PACK 的 `reference-design.md` / `standard-tests.md` 应 reference 本章，
> **不重复抄**。模式选错的具体症状（vinn 钉 rail / triode 灾难）见各 PACK
> `troubleshooting.md`。

## Iron Law

```
仿真用途              | 必用模式             | 严禁
─────────────────────┼────────────────────┼────────────────────────
DC OP / region check | open-loop          | closed-loop（Rfb=1G）
                     | (强制 vin = Vcm)    | → vinn 锁 rail → triode 灾难
─────────────────────┼────────────────────┼────────────────────────
AC gain / GBW / PM   | closed-loop        | open-loop（vinp 直接 AC）
                     | (Method C, Rfb+Cfb)| → DC 不收敛
─────────────────────┼────────────────────┼────────────────────────
PSRR                 | closed-loop +      | open-loop
                     | VDD AC 注入         | → 测的不是 PSRR
─────────────────────┼────────────────────┼────────────────────────
大信号 Tran (slew)   | open-loop +        | closed-loop
                     | PULSE source       | → 看不到原始 slew，被 loop 平滑
─────────────────────┼────────────────────┼────────────────────────
ICMR / DC sweep Vcm  | open-loop          | closed-loop
─────────────────────┼────────────────────┼────────────────────────
Line / Load reg(LDO) | closed-loop        | open-loop
                     | (Iload 强制 / Vin   | → 测的不是 reg
                     |  ±10% 实闭环)       |
```

## 模式 1：DC OP open-loop（**最易错的一类**）

### 用途
- 验 device region（saturation / triode / cutoff）
- Vds_margin 检查
- bias chain Vgs / Itail 实测
- 先决条件：必先过 DC OP 才能跑后面任何 AC / Tran

### 关键配置

```spice
* DC OP — open-loop, 双输入强制 Vcm
VINP vinp 0 DC <Vcm_in>          $ ⭐ 直接 DC 强制
VINN vinn 0 DC <Vcm_in>          $ ⭐ 直接 DC 强制（不通过 Rfb）
* NO Rfb, NO Cfb, NO 反馈
X1 vinp vinn vout ibias vdd vss <subckt>
.op
```

### 严禁
**❌ 不要加 Rfb/Cfb 闭环**。Demo 02 实证：用 AC closed-loop testbench 跑 .op →
loop 把 vinn 锁到 rail（vinn≈VDD → input pair 一边关断 → vx≈0 → vout 锁 rail），
多个 device 进 triode，反复试 7-10 turn 才发现是 testbench 错（不是 sizing 错）。

### 适用电路
- OTA / OpAmp（差分输入）
- LDO EA 子模块（如果 EA 单独验）
- ADC sample-and-hold input pair
- comparator input stage

### LDO 整体 DC OP 例外
LDO 整体 DC OP **是闭环**（Iload 强制 + 内部 Vfb 反馈），但**不是用 Rfb=1G 假闭环**，
而是真实 R-divider 闭环（vfb = vout × R2/(R1+R2)）。Iload 由 Iload 电流源强制控制
工作点，不会锁死 rail。详见 `blocks/ldo/standard-tests.md` LDO-T1。

## 模式 2：AC gain / GBW / PM closed-loop Method C

### 用途
- 测 dc_gain（DC 闭环增益）
- 测 GBW（unity-gain frequency）
- 测 PM（phase margin）

### Method C 原理
`Rfb=1G + Cfb=1F` 让 fc = 1/(2π·Rfb·Cfb) ≈ 0.16 nHz。**DC 等效短路**（让 OP
收敛到 vcm）+ **AC 全开**（任何感兴趣 freq > 0.16nHz 时反馈支路开路 = open-loop
传函）。

详细推导见 skill `ac_feedback_loop_method`。

### 关键配置

```spice
* AC PM — Method C
Vcm  vcm  0   DC <Vcm_in>
Vinp vinp vcm AC 1                 $ AC 注入在 vinp ↔ vcm
Rfb  vout vinn 1G                  $ DC 闭环
Cfb  vinn 0   1                    $ AC 全开
X1 vinp vinn vout ibias vdd vss <subckt>
CL vout 0 <CL>
.ac dec 50 1 1G

.control
  set units = degrees              $ ⭐ vp() 度数
  run
  setplot ac1
  let gain_db   = db(abs(v(vout)/v(vinp)))
  let phase_deg = vp(vout) - vp(vinp)
  meas ac dc_gain      find gain_db    at=1
  meas ac gbw_hz       when gain_db=0  cross=1
  meas ac phase_at_ugf find phase_deg  when gain_db=0 cross=1
  meas ac phase_dc     find phase_deg  at=1
  * Anchor-difference PM 公式（universal）:
  meas ac pm_deg       param='180 - (phase_dc - phase_at_ugf)'
.endc
```

### 严禁
**❌ 不要漏 `set units = degrees`**：不加默认弧度，PM 算出 178° 实际 3°，错 57×。

**❌ 不要用 `meas ac pm_deg param='180 + phase_at_ugf'`** 旧公式：仅 Method C
非反相输出对，反相拓扑给 nonsense。Anchor-difference 公式 `180 − (phase_dc −
phase_at_ugf)` 是 universal。

## 模式 3：PSRR closed-loop + VDD AC 注入

### 关键配置（关键差异：AC 注入在 VDD）

```spice
Vdd vdd 0 DC <VDD> AC 1              $ ⭐ AC 注入在 VDD
Vcm vcm 0 DC <Vcm_in>
Vinp vinp vcm DC 0                   $ vinp 不注入 AC
Rfb  vout vinn 1G
Cfb  vinn 0   1
.ac dec 50 1 100MEG

.control
  setplot ac1
  let psrr_db = -db(abs(v(vout)/v(vdd)))
  meas ac psrr_dc    find psrr_db at=1
  meas ac psrr_1k    find psrr_db at=1k
  meas ac psrr_100k  find psrr_db at=100k
.endc
```

## 模式 4：大信号 Tran open-loop

### 用途
- 测 slew rate (SR+ / SR−)
- 测 settling time
- 验大信号摆幅

### 关键配置

```spice
* Slew rate — open-loop, 大信号阶跃
VINP vinp 0 PULSE(<Vcm-100mV> <Vcm+100mV> 100ns 1ns 1ns 1us 2us)
VINN vinn 0 DC <Vcm_in>             $ vinn 不变
X1 vinp vinn vout ibias vdd vss <subckt>
CL vout 0 <CL>
.tran 10n 5u
```

闭环跑 slew 看到的 = loop 平滑后的响应，不是器件原始 slew rate。

## 模式 5：ICMR DC sweep open-loop

```spice
VINP vinp 0 DC <Vcm_in>
VINN vinn 0 DC <Vcm_in>
.dc VINP <Vcm_min> <Vcm_max> 0.05
* sweep 范围内每个点跑 .op，看 device region
```

## 模式 6：Line / Load Reg（LDO 特定，真闭环）

跟模式 1 不同：LDO 的 line/load reg 是真 closed-loop 设计意图（不是 Rfb=1G 假闭环），
Iload 由实际电流源强制 + 内部 R-divider 反馈。详见 `blocks/ldo/standard-tests.md`
LDO-T3 / T4。

## Anti-pattern（最常错的两类）

### Anti-pattern A: 拿同一个 testbench 跑所有仿真

```spice
* 错：用 AC closed-loop template 跑 .op
Rfb vout vinn 1G
Cfb vinn 0 1
.op                                  $ ❌ 闭环锁 rail
.ac dec 50 1 1G                      $ ✅ AC 这步是对的
```

**修法**：拆成两个 testbench 文件（`tb_dc_op.sp` open-loop / `tb_ac_pm.sp`
closed-loop），各跑各的。**严禁混用**。

### Anti-pattern B: DC OP 失败时调 sizing 救

```
症状: DC OP triode_count > 1 + vinp/vinn 钉到 rail
agent 反应: "调 W_diff / 加 L_tail / 改 Vov_diff..."
现实: 调 W/L 救不了 testbench 模式错（vinn 锁 rail 跟 sizing 无关）
正解: 先看 vinp/vinn 是否在 Vcm_in 附近
      → 不在 → 100% testbench 闭环锁死 → 换 open-loop
      → 在   → 才考虑 sizing 问题
```

详见 `blocks/two-stage-ota/troubleshooting.md` 模式 9 决策树。

## 决策表速查

| 现象 | 模式选择 |
|---|---|
| 验 device region | 模式 1 (DC OP open-loop) |
| 评 spec gain/GBW/PM | 模式 2 (AC closed-loop Method C) |
| 评 PSRR | 模式 3 (closed-loop + VDD AC) |
| 评 slew rate / settling | 模式 4 (Tran open-loop 大信号) |
| 评 ICMR | 模式 5 (DC sweep open-loop) |
| LDO line/load reg | 模式 6 (LDO 特定真闭环) |

## Related

- skill `ac_feedback_loop_method`：Method C 通用断环原理
- `simulators/ngspice/measurements`：vp() 度数 / .meas 公式 / Anchor-difference PM
- `simulators/ngspice/common-errors`：14 条 testbench 常见错
- `blocks/two-stage-ota/standard-tests`：OTA-T1~T6 完整测试套件 instance
- `blocks/ldo/standard-tests`：LDO-T1~T7 完整测试套件 instance
- `blocks/two-stage-ota/troubleshooting` § 模式 9：DC OP triode 灾难决策树
