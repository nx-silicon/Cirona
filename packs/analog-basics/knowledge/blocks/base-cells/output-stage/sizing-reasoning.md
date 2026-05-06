---
chapter: sizing-reasoning
parent: output-stage
summary: |
  R4 架构-sizing 互锁铁律 — LDO Pass FET 实例化 (Vsg_pass 由前级 EA 输出范围
  决定; W 算超大不可行 → 回架构层换 EA 不死磕 W) + buffer 级 caveat (接法
  sanity check + 吃 Vgate 摆幅) + Pass FET sizing TB 模板 + 100mA LDO Pass
  worked example (vpdk180nm, VDD=1.8V)。pre-sim sizing 通用 sizing 流程 Step 6 R4
  架构兜底时, LLM 遇到 LDO Pass / 大电流输出级 read 这一章。
tokens: ~1700
prerequisite_chapters:
  - class-ab
  - push-pull
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/differential-pair
  - blocks/base-cells/source-follower
  - blocks/base-cells/bias-generator
  - blocks/ldo
---

# output-stage — sizing reasoning（R4 架构-sizing 互锁 + buffer caveat + TB + LDO Pass worked example）

> Chapter 用途：当 LLM 在 pre-sim sizing 通用 sizing 流程（L0）Step 6 触发 R4 架构层
> 兜底时（W 算出来巨大不可行），应 read 这一章，得到 LDO Pass FET 实例化
> 的"架构-sizing 互锁"链路 + buffer 级 caveat + 100mA LDO Pass worked
> example（vpdk180nm, VDD=1.8V）—— 知道**什么时候不死磕 W、什么时候回架构
> 层重新筛选 EA**。

## R4 架构-sizing 互锁铁律 — LDO Pass FET 实例化

**用户原话**："spec 提出要 100mA 的电流，那么很容易就可以根据 Vgs 算出需要
多大的 W/L；但是，vgs 的 s 是 vdd，但 g 由前一级，也就是 EA 的输出决定的；
也就是说有些 EA 的架构，输出根本就低不了，因此 vgs 就根本不够大。因此你
就有可能需要换一种 EA 的架构了。"

### LDO Pass FET 电路结构 + KVL 反推

LDO Pass FET 是 PMOS 接 VDD（source = VDD），drain = Vout，gate = EA 输出
（Vgate_EA）：

- `Vsg_pass = VDD − Vgate_EA`
- `Iload = (1/2) · µpCox · (W/L) · Vov_pass²`（饱和强反型经典近似）
- → `W ∝ Iload / Vov_pass²`，其中 `Vov_pass = Vsg_pass − |Vth_p|`

**架构-sizing 互锁链**（顺因果反推）：

```
spec Iload  →  required Vov_pass  →  required Vsg_pass
            →  required Vgate_EA = VDD − Vsg_pass
            →  EA 输出范围必须包含 Vgate_EA
            →  否则换 EA 架构 (R4 兜底)
```

**含义**：算 W_pass 之前**先算 Vsg_max EA 能给多少**。Vsg_max 由 EA 输出
最低能压到的电压决定，而不是任意拍脑袋。

### LLM 易犯的陷阱（v9 / v10 实证）

1. **拍脑袋直接套公式算 W**：spec Iload = 100mA → 套强反型公式给 W = 10000µm
   → 写完 .cir → 仿真发现 EA 根本驱动不到那个 Vgate_EA → 实际 Iload 不到 30mA
2. **没检查 EA 输出范围**：典型 NMOS-input single-stage OTA（5T-OTA），
   Vgate_EA 输出范围约 [Vth_n + Vov_tail, VDD − Vov_load] ≈ [0.6V, 1.6V]
   （VDD=1.8V）→ Vsg_pass max = 1.8 − 0.6 = 1.2V → Vov_pass max = 1.2 − 0.45
   = 0.75V（vpdk180nm）→ 限制了 W 下限
3. **不知道何时回架构层**：算出来 W 巨大 / Vsg_required 超出 EA 范围时，
   LLM 倾向继续硬调 W —— **此时无可行解**，必须触发 R4 兜底回 SDAS skill
   重新筛 EA 架构（NMOS-input → PMOS-input；single-stage → two-stage；加
   level shifter / buffer 级）

### R4 触发判据

当下面任一成立 → 不要再调 W，回架构层：

- `Vgate_EA_required < Vgate_EA_min`（EA 输出最低值打不到要求）
- `Vsg_pass_required > VDD − Vgate_EA_min`（可达 Vsg 不够）
- W_pass 算出来 > 50000µm 仍达不到 spec Iload（chip area / Iq leak / 寄生
  电容三爆）
- short-channel L 已经压到工艺最低（如 0.18µm），µpCox 增益已榨完

**铁律**：算 W_pass 之前**先算 Vsg_max = VDD − Vgate_EA_min（EA 输出下限）**；
如果 Vsg_max 不够给所需 Vov_pass → **不要硬调 W**，**回 SDAS skill 重新
筛 EA 架构**。

## Buffer 级 caveat — 接法 sanity check 与 Vgate 摆幅

LDO 设计常加 buffer 级在 EA → Pass 之间（提升驱动能力 / 隔离 EA 输出阻抗
对 Pass 输入电容的影响）。但 buffer 级**双刃剑** —— 用错可能让 Vgate_EA
摆幅打滑。

### 常见 buffer 拓扑 × Vgate 摆幅影响

| buffer 拓扑 | Vgate_pass 范围（相对 EA 输出） | Vsg_pass 影响 | 适用场景 |
|---|---|---|---|
| **NMOS source-follower** | EA 输出 − Vgs_buf ≈ EA 输出 − 0.6V | **Vsg_pass 上限被拉低**（dropout 吃 0.6V）| EA 输出范围下限不够低时拉低 |
| **PMOS source-follower** | EA 输出 + Vsg_buf ≈ EA 输出 + 0.6V | **Vsg_pass 下限被抬高**（Vgate 进不到 EA 范围下限）| 罕见 / 不推荐 LDO Pass driver |
| **Class-AB push-pull buffer** | 跟随 EA（无 DC level shift）+ 大瞬态驱动 | **Vsg_pass 摆幅 ≈ EA 输出摆幅** | 高瞬态 LDO（Iload 突变）|
| **NMOS common-source（反相）** | Vgate_pass = inv(EA 输出)，level shift 可调 | 可大可小 | 当 EA 是 PMOS-input（输出靠 VSS）时反相到 Vgate 靠 VDD |

### 接法 sanity check（LLM 易犯）

- **错把 NMOS source-follower 接到 PMOS Pass 的 Vgate** → buffer 输出范围
  比 EA 输出低 0.6V，Vgate_EA 上限被拉低，但**对 PMOS Pass 来说 Vgate 越
  低 Vsg 越大** → 这是好事（对 dropout 设计）；但**反过来需要 Vgate 高时**
  （Iload 小 / Pass cutoff 区）→ buffer 拉不上去，Pass 关不掉
- **buffer 级偏置链必须独立**：buffer 的 tail / load Iq 必须从 bias chain
  另开一支，不能跟 EA 共用（污染 EA 输出阻抗 / Iq）
- **buffer 级带宽不能比 EA 慢**：否则成为新主极点，破坏 LDO 环路稳定性
  → 跳到 `<base-cells>/miller-compensation` 重做补偿规划

### Trade-off

- buffer 提升驱动 + 隔离 EA / Pass 寄生 → 改善瞬态 + LDO PSRR
- 多消耗 dropout headroom（NMOS source-follower 吃 0.6V）+ 多 Iq + 多极点 →
  环路稳定性更难

**铁律**：加 buffer 之前先确认 EA 直接驱动 Pass 是否 Vsg 不够 / 瞬态不够；
不够才加 buffer，加完重新跑 R4 互锁链验算 Vgate_pass 范围。

## Sizing TB Template — Pass FET 单独 W 反推

当不知道 Pass FET 的 W 该取多少才能让 spec Iload 命中时，搭独立 Pass-only
TB 实测（**不带 EA / 反馈环**，纯 DC sweep W）：

```spice
* tb_pass_pmos_size.sp
.include "<pdk_path>/vpdk180nm.lib"

V_DD vdd 0 1.8
V_GATE g   0 0.8           $ EA 输出能给的最低值 (sweep 看 W vs Iload)
V_OUT vout 0 1.2           $ 设 Vds_pass = 0.6V (dropout = VDD - Vout = 0.6V)

* PMOS Pass: drain=vout, gate=g, source=vdd, bulk=vdd
X_PASS vout g vdd vdd pch_18 W=2000u L=0.18u m=1   $ initial guess

.op
.print dc V(g) V(vout) I(V_OUT)
+        @m.x_pass.m1[vds] @m.x_pass.m1[vdsat] @m.x_pass.m1[id]
+        @m.x_pass.m1[vov] @m.x_pass.m1[region]

* sweep W: 用 .step 或 .alter 多次跑, 找 |I(V_OUT)| 命中 target Iload (e.g. 100mA)
.end
```

**用法**：

- 给 V_GATE 一个 EA 能输出的下限（如 0.8V — 模拟 NMOS-input EA 输出最低）
- 跑 .op，看 `|I(V_OUT)|` → 这是 Iload 实测
- 调 W 多次（W = 2000µ → 5000µ → 10000µ → 20000µ → 50000µ）直到 Id 命中
  target Iload（如 100mA）；**注意：W = 50000µm 一般用 m=多 finger**（如
  W=2000µm × m=25），不是单根超长管
- 同时检查 region：必须 saturation；如果 triode → Vds 不够 / W 太大 / Iload
  跑爆 → 调 V_OUT（抬 Vout）或减小 W
- check Vov：实际 PDK 的 µpCox 比经典公式低 30-50%（PMOS 短沟道 mobility 退
  化），W 通常需要比公式估算大 1.5-2× 才命中 spec
- PMOS 换 NMOS Pass（少见）：rails 对调，X_PASS 的 source 接 0、drain 接
  vout、bulk 接 0；V_GATE 在 [VSS, VDD] 内

LLM 自己 read 这个模板 → 改 `pch_18 / W / L / m / V_GATE / V_OUT / target
Iload` 七处即可。**关键**：Pass FET 测 W 不带 EA，纯 DC + 强制 V_GATE → 隔
离 EA 驱动能力问题，先确定 Pass 自身可达。EA 范围验算另跑 EA-only TB。

## Worked Example — 100mA LDO Pass FET（vpdk180nm, VDD=1.8V）

**Spec**：

- Iload = 100 mA（用户原话）
- VDD = 1.8 V，Vout = 1.2 V → dropout = 0.6 V
- L = 0.18 µm（短沟道获大 µpCox · W/L 密度）
- EA 候选：**NMOS-input single-stage OTA**，Vgate_EA 输出范围 [0.6 V, 1.6 V]
  （Vth_n ≈ 0.45V + Vov_tail ≈ 0.15V → 下限 0.6V；VDD − Vov_load ≈ 1.65V →
  上限 ~1.6V）
- vpdk180nm：Vth_p ≈ 0.45V，µpCox ≈ 50 µA/V²

### Derivation 第一轮（NMOS-input EA 直接驱动 Pass）

1. Vgate_EA 下限 = 0.6V → `Vsg_pass max = 1.8 − 0.6 = 1.2V`
2. → `Vov_pass max = Vsg_pass − |Vth_p| = 1.2 − 0.45 = 0.75V`
3. 经典公式估 W：`W ≈ 2 · Iload · L / (µpCox · Vov_pass²)`
   `= 2 · 100mA · 0.18µm / (50µA/V² · 0.75²)`
   `= 36mA·µm / 28.1µA·V² · V² = 1281µm`（粗估）
4. **R3 实证**：搭上面 Pass-only TB，V_GATE = 0.6V → 调 W → 实测 W ≈ 8000-15000 µm
   命中 Id = 100mA（实际 µpCox 比经典公式低 30-50% + short-channel mobility
   退化 → W 比粗估大 6-12×）
5. 选 W = 10000µm（W = 1000µm × m = 10 finger，layout 友好）
6. **R4 互锁验算**：Vgate_EA = 0.6V 在 NMOS-input EA 输出范围下限内 ✓ →
   架构 OK，不必换 EA

### Derivation 第二轮（spec 升到 500mA — R4 触发）

1. spec 改 Iload = 500mA → 5× 上一轮 → W ≈ 50000-75000µm（m = 50-75 finger）
2. **R4 互锁验算**：
   - Vgate_EA 下限仍 0.6V → Vsg_pass max 仍 1.2V → Vov_pass max 仍 0.75V
   - 但 W = 50000-75000µm + L = 0.18µm → chip area 巨大 + Iq leak >>10µA +
     输入电容 C_iss ≈ Cox · W · L · 2/3 ≈ 几十 pF → 严重拖慢 EA 驱动 →
     LDO 瞬态 / 稳定性崩
3. **R4 兜底触发**：
   - **方案 A — 加 Class-AB buffer 级**：Vgate_EA 摆幅基本不变，但驱动能
     力大幅提升 → C_iss 不再是瓶颈；W 维持 50000-75000µm 但带 buffer 级
   - **方案 B — 换 EA 架构到 PMOS-input + level shifter**：让 EA 输出能压
     到 Vgate_EA = 0.4V → Vsg_pass max = 1.4V → Vov_pass max = 0.95V →
     W 可降到 ~30000µm（从 Iload·1/Vov² 反比例）
   - **方案 C — 多相 LDO 并联** / **集成 power-MOSFET**：跳出单 LDO，
     系统层方案
4. 选 A 还是 B 取决于：瞬态 spec（A 更好）/ 静态 dropout（B 更好）/ chip
   area（B 更省）/ 启动复杂度（A 更简单）→ 跳回 SDAS skill

### Cross-check（实战验证）

- 把 W = 10000µm 灌进 LDO 完整环路（含 EA + Pass + Cload + Rload），跑 .op：
  - Vout ≈ 1.2V ?（环路锁定到 Vref · feedback ratio）
  - Iload = V_RL / R_load ≈ 100mA ?
  - V_gate_EA ≈ 0.65V ?（在 EA 范围 [0.6V, 1.6V] 内 ✓）
  - Pass.region == saturation ?（Vds = 0.6V > Vdsat ≈ 0.30V ✓）
- 跑 .ac 看 LDO 环路 PM：Pass 输入电容 C_iss = (2/3) · Cox · W · L ≈ (2/3)
  · 8.5fF/µm² · 10000µm · 0.18µm ≈ 10pF → EA 输出阻抗 R_EA · 10pF 决定第二
  极点位置 → 必须 < 增益带宽（GBW）3-5×
- 如果第二极点逼近 GBW → 加 Miller / nested Miller 补偿，跳到 `<base-cells>/miller-compensation`

### 教训

- **Iq budget**：W = 10000µm 的 PMOS Pass，VDS = 0.6V 时漏电 ≈ 0.1-1µA（PVT
  worst case），加 bias chain ≈ 50µA → 总 Iq ≈ 100µA，对 LDO Iq spec
  10mA-100mA 来说 < 1% 占比 ✓
- **如果 spec 把 dropout 压到 0.3V**（Vout = 1.5V）→ Vds_pass 从 0.6V 降到
  0.3V → Pass 进 deep triode → 大信号 gm 严重下降 → R4 触发，必须重新选 LDO
  架构（如换 NMOS Pass + 上方 EA 输出超 VDD 的 charge-pump 方案）
- **不要为了"硬塞" Iload 拼命放大 W**：当 Vsg_pass max 已被 EA 输出范围
  顶住，W 越大边际收益越低（mobility roll-off + Cgs 拖慢动态）→ 触发 R4
- **LDO Pass + EA 设计是 sizing 与架构的紧耦合**：必须 spec → EA 选型 →
  Pass W **联动算**，不能孤立设计任一级

## Cross-references

- L0 Sizing Framework Step 6（R4 架构-sizing 互锁兜底 — 当 W 不可行时回
  SDAS skill）
- `<base-cells>/differential-pair/sizing-reasoning.md`（EA input pair 的
  Vincm / Vds_M_tail 反推 — EA 输出范围由 EA input pair 工作点决定）
- `<base-cells>/source-follower`（buffer 级常见拓扑 — buffer 接法 sanity
  check 章节涉及；T8 不创建该 sizing-reasoning chapter，前向引用）
- `<base-cells>/bias-generator/sizing-reasoning.md`（buffer 级 / EA tail
  bias 共用 bias chain 时 R2 镜像铁律）
- `<base-cells>/miller-compensation`（LDO 环路补偿 — Pass C_iss 大时第二
  极点位置）
- `<blocks>/ldo`（LDO 整体反馈环路 + 补偿策略 + EA 选型决策树）
- L0 SDAS skill（架构筛选 — R4 兜底必跳回 SDAS）
