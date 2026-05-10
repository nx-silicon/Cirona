---
chapter: testbench-patterns
parent: ngspice
summary: |
  Testbench 激励选择 — 跨电路通用横切章。Iron Law: DC OP 与 AC 必须用同一激励
  (DC closed via Rfb=1G/10Meg + Cfb=1F → AC open at f > fc≈0.16nHz)；high-gain
  (≥60dB) 运放 open-loop DC 不可靠（mismatch 被开环增益放大就飘 rail），
  open-loop DC 仅作 sanity 备用模板。大信号 Tran (slew/settling) 与 ICMR DC sweep
  仍用 open-loop（loop 会盖住要测的现象）。所有 PACK 在 reference-design.md /
  standard-tests.md 中 reference 本章。
tokens: ~1100
prerequisite_chapters: []
related_skills:
  - ac_feedback_loop_method
related_knowledge:
  - simulators/ngspice/analyses
  - simulators/ngspice/measurements
  - blocks/two-stage-ota/standard-tests
  - blocks/ldo/standard-tests
---

# Testbench 激励模式 — IRON LAW（跨电路横切）

> **横切章**：本章是 ngspice testbench 激励选择的 single source of truth。
> 所有 PACK 的 `reference-design.md` / `standard-tests.md` 应 reference 本章，
> **不重复抄**。各模式失败时的具体症状与诊断流程见各 PACK `troubleshooting.md`。

## Iron Law

```
仿真用途              | 推荐激励            | 关键约束
─────────────────────┼────────────────────┼────────────────────────────
DC OP / region check | closed-loop (主推) | DC closed via Rfb=1G/10Meg
                     |                    | + Cfb=1F；与 AC 共用激励
─────────────────────┼────────────────────┼────────────────────────────
DC OP sanity (可选)  | open-loop          | 仅作 mismatch=0 对照诊断；
                     | (VINP=VINN 强制)   | 不作主测；high-gain (≥60dB)
                     |                    | 时常飘 rail 是物理规律
─────────────────────┼────────────────────┼────────────────────────────
AC gain / GBW / PM   | closed-loop        | Method C：与 DC 共用同一组
                     | (Method C)         | Vinp/Ibias/Rfb/Cfb 激励，仅
                     |                    | 切 .op ↔ .ac
─────────────────────┼────────────────────┼────────────────────────────
PSRR                 | closed-loop +      | AC 注入在 VDD（不是 vinp），
                     | VDD AC 注入         | 其他与 AC 测 PM 共用
─────────────────────┼────────────────────┼────────────────────────────
大信号 Tran (slew)   | open-loop +        | closed-loop 的 Rfb 会把 vout
                     | PULSE source       | 拉回静态点，slew 被盖住
─────────────────────┼────────────────────┼────────────────────────────
ICMR / DC sweep Vcm  | open-loop          | 本来就是 sweep VINP=VINN，
                     |                    | 不需要反馈
─────────────────────┼────────────────────┼────────────────────────────
Line / Load Reg(LDO) | closed-loop        | LDO 是真闭环架构（R-divider
                     | (真 R-divider)     | + Iload 强制），不是 Rfb=1G
                     |                    | 假闭环
```

## 核心铁律：DC 与 AC 必须用同一激励

**DC 工作点决定 small-signal 参数**（gm, gds, ro），AC 测出来的 gain/PM 必须基于
"AC 部署时实际收敛到的 OP"。如果 DC 用 open-loop（VINP=VINN 强制）、AC 用
closed-loop（Rfb shunt），两者 OP 不同 → AC 测的 gain/PM 与实际部署状态无关，
**毫无意义**。**调好 DC 工作点的目的就是给 AC 一个正确合理的小信号模型**。

## 模式 1：DC OP closed-loop（**主推**）

### 用途
- 验 device region（saturation / triode / cutoff）
- Vds_margin 检查
- bias chain Vgs / Itail 实测
- 先决条件：必先过 DC OP 才能跑后面任何 AC / Tran

### 关键配置（与模式 2 共用激励）

```spice
* DC OP — closed-loop（与 AC testbench 同一激励，仅切 .op）
Vcm  vcm  0   DC <Vcm_in>
Vinp vinp vcm DC 0 AC 1            $ AC 1 仅 .ac 用，.op 模式下不影响
Rfb  vout vinn 1G                  $ DC 闭环 (fc≈0.16nHz)
                                    $ high-gain (≥60dB) 时可降至 10Meg/100Meg 让 DC loop 更紧
Cfb  vinn 0   1                    $ Cfb=1F：AC 路径上 vinn 接地
X1 vinp vinn vout ibias vdd vss <subckt>
.op
```

### 物理原因
- High-gain 运放（80-100dB）open-loop 时，stage1/stage2 mismatch + 数值精度差异
  会被开环增益放大到 vout 飘 rail。即使 VINP=VINN 数学相等，实际仿真 vout 落点
  常常不可控。这是物理规律不是 sizing bug。
- closed-loop（Rfb shunt）把 OP 拉回 Vcm 附近：DC 等效短路 + AC 全开（fc≈0.16nHz）。

### 适用电路
- OTA / OpAmp（差分输入，所有 gain 等级）
- LDO EA 子模块（如果 EA 单独验）
- ADC sample-and-hold input pair
- comparator（如有差分输入静态）

### LDO 整体 DC OP 例外
LDO 整体 DC OP **天然就是闭环**（Iload 强制 + 内部 Vfb R-divider 反馈），不是
Rfb=1G 假闭环，是真实 R-divider。Iload 由 Iload 电流源强制控制工作点。详见
`blocks/ldo/standard-tests.md` LDO-T1。

## 模式 1b：DC OP sanity open-loop（**仅作诊断对照**）

### 用途（不是主测）
仅当模式 1 closed-loop 下 vout 飘 rail 时，用本模式做对照，定位是 sizing 问题
还是 Rfb 量级 / mirror match 问题。

### 关键配置

```spice
* DC OP sanity — open-loop, mismatch=0 理想拓扑下 region 验证
VINP vinp 0 DC <Vcm_in>            $ 直接 DC 强制
VINN vinn 0 DC <Vcm_in>
* NO Rfb, NO Cfb
.op
```

### 诊断对照逻辑

| 模式 1（closed）| 模式 1b（open）| 推断 |
|---|---|---|
| pass | pass | 设计健康 |
| fail | pass | Rfb 量级太大 / stage1 mirror imbalance / 上下电流匹配差 |
| fail | fail | 真 sizing 问题（tail headroom / 极性 / mirror W·m）|
| pass | fail | **预期常态**（high-gain open-loop 物理本就不可靠，不是 bug）|

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

### 关键配置（与模式 1 共用激励）

```spice
* AC PM — Method C（与 DC OP 同一激励，仅切 .ac）
Vcm  vcm  0   DC <Vcm_in>
Vinp vinp vcm AC 1                 $ AC 注入在 vinp ↔ vcm
Rfb  vout vinn 1G                  $ 同模式 1 的 Rfb
Cfb  vinn 0   1                    $ 同模式 1 的 Cfb
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

**❌ 不要用 `meas ac pm_deg param='180 + phase_at_gbw'`** 旧公式直接套：仅 forward
gain DC 起点 0° + UGF phase 在第三象限时对，反相拓扑（起点 180°）给 nonsense。

### PM 公式按主极点位置选（**两种方法**）

| 方法 | 公式 | 适用 | 何时用 |
|---|---|---|---|
| **B. anchor-difference** | `PM = 180 - (phase_dc - phase_at_ugf)` | 主极点 >> phase_dc 锚点频率（典型 >> 1Hz） | **OTA 默认**（5T/FC/Telescopic/two-stage 主极点都在 kHz~MHz） |
| **C. 起点观察法** | DC 起点 0° → `PM = 180 + phase_at_ugf`<br>DC 起点 180° → `PM = phase_at_ugf` | 主极点 < phase_dc 锚点频率 | **LDO 必用**（Cload 几 µF + R_load → fp1 ≈ 0.1-10Hz） |

**为什么 LDO 不能用方法 B**：

```
例: 主极点 fp1 = 0.5Hz
    .ac dec 50 1 1G 起跑 1Hz，phase_dc=at(1Hz) 已滞后 ~63° 远离真 DC phase
    anchor 公式低估真实滞后 63° → PM 算高 63°（看起来 stable 实际不稳）
```

**为什么 OTA 不需要方法 C**：

OTA 主极点 kHz~MHz，phase_dc=at(1Hz) 在所有极点之前，是干净 DC phase。
方法 B universal 且不需要拓扑学问（vinp/vinn 注入 + 内部反相数都对）。

**LDO 方法 C 的拓扑事实**：

PMOS-pass + EA(+)=vfb 标准 LDO：vinj 注入 vfb → EA out → vg_pass → PMOS 反相到
vout → vfb；forward gain (vout/vinj) DC 起点 = 180°，所以 `pm = phase_at_ugf`。
拓扑变体（NMOS-pass / EA polarity 反 / 非反相注入端）→ 起点 0°，用
`pm = 180 + phase_at_ugf`。**验证起点**：跑一次 `.ac dec 10 1u 1m` 看 phase 在
1µHz 处的真值（必为 0° 或 180°）。

详见 `simulators/ngspice/measurements` § AC PM 模板（两方法完整对照）+
`blocks/ldo/ac-stability` § Conv-3（LDO 起点观察法实战配置）。

## 模式 3：PSRR closed-loop + VDD AC 注入

### 关键配置（关键差异：AC 注入在 VDD）

```spice
Vdd vdd 0 DC <VDD> AC 1              $ ⭐ AC 注入在 VDD
Vcm vcm 0 DC <Vcm_in>
Vinp vinp vcm DC 0                   $ vinp 不注入 AC
Rfb  vout vinn 1G                    $ 同模式 1/2 的 Rfb（共用激励拓扑）
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

### 为什么 transient 用 open-loop
closed-loop 的 Rfb shunt 会把 vout 缓慢拉回静态点，**原始 slew rate 被 loop 平滑后
看不到**。slew/settling 测的是器件本身大信号驱动能力，必须开环。**起始 OP** 仍
应该用模式 1 closed-loop 的设计参数收敛（保 transient 起点真实），ngspice
`.tran uic=0`（默认）会自动从 .op 解算开始。

## 模式 5：ICMR DC sweep open-loop

```spice
VINP vinp 0 DC <Vcm_in>
VINN vinp 0 DC <Vcm_in>            $ 跟 VINP 同节点 / 同电压
.dc VINP <Vcm_min> <Vcm_max> 0.05
* sweep 范围内每个点跑 .op，看 device region
```

ICMR 本来就是 sweep Vcm 看 input pair 在不同 Vcm 下的 region，不需要反馈。

## 模式 6：Line / Load Reg（LDO 特定，真闭环）

跟模式 1 不同：LDO 的 line/load reg 是真 closed-loop 设计意图（不是 Rfb=1G 假闭环），
Iload 由实际电流源强制 + 内部 R-divider 反馈。详见 `blocks/ldo/standard-tests.md`
LDO-T3 / T4。

## Anti-pattern（最常错的两类）

### Anti-pattern A: DC 用 open-loop / AC 用 closed-loop 混用

```spice
* 错：DC 与 AC 激励不一致，OP 不同 → AC 结果毫无意义
* tb_dc_op.sp:
VINP vinp 0 DC 0.9                  $ open-loop 强制
VINN vinn 0 DC 0.9
.op

* tb_ac_pm.sp:
Vinp vinp vcm AC 1                  $ closed-loop Rfb shunt
Rfb vout vinn 1G
Cfb vinn 0 1
.ac ...                             $ ❌ 与 DC 跑出来的 OP 不同
```

**修法**：DC 与 AC 共用同一组 Vinp/Ibias/Rfb/Cfb 激励（模式 1 + 模式 2 同配置），
两个 testbench 文件仅在 `.op` 与 `.ac` 控制语句上有差异。**调好 DC 工作点的目的
就是给 AC 一个正确合理的小信号模型**。

### Anti-pattern B: 看到 vout 飘 rail 就归因为 testbench 模式错

```
症状: DC OP triode_count > 1 + vout 钉到 rail
误反应: "肯定 testbench 闭环锁死，换 open-loop / 调 sizing 都救不了"
现实: high-gain 运放 closed-loop 下 vout 飘 rail 多半是真 sizing 问题
      （stage1 mirror imbalance / 上下电流匹配差 / Rfb 太大 DC loop 太软）
正解: 看 vinn 是否在 Vcm 附近 (< 50mV 偏离)
      → 是 → 检查 stage1 mirror match / 上下电流配比 / sizing 范围
      → 否 → Rfb 降至 10Meg-100Meg 让 DC loop 更紧；同时验 mirror match
```

详见 `blocks/two-stage-ota/troubleshooting.md` 模式 9 决策树。

## 决策表速查

| 现象 | 模式选择 |
|---|---|
| 验 device region | 模式 1 (DC OP closed-loop) |
| DC OP closed-loop 飘 rail 想诊断 | 加跑模式 1b (open-loop sanity 对照) |
| 评 spec gain/GBW/PM | 模式 2 (AC closed-loop Method C，与模式 1 共用激励) |
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
- `blocks/two-stage-ota/troubleshooting` § 模式 9：DC OP 不收敛多根因决策树
