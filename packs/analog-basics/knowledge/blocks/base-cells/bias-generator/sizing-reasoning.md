---
chapter: sizing-reasoning
parent: bias-generator
summary: |
  Wide-swing cascode bias 的 padding device 等价铁律 — padding_lower 的 Vds 等于
  被偏置 cascode 下管 Vds + padding 链 sizing TB 模板 + FC-OTA M7 padding
  worked example（含 Vov negative 实战陷阱与 R4 架构兜底）。pre-sim sizing
  通用 sizing 流程 Step 4 选旋钮 + Step 5 R3 实证 + Step 6 R4 架构兜底时, LLM 遇到
  cascode 下管 Vds 不达标 read 这一章。
tokens: ~1700
prerequisite_chapters:
  - basic-mirror-tree
  - level-shifter-bias
related_skills:
  - circuit-method/device-sizing
  - circuit-method/bias-tree-reasoning
related_knowledge:
  - blocks/base-cells/cascode
  - blocks/base-cells/current-mirror
---

# bias-generator — sizing reasoning（wide-swing padding 等价铁律 + TB + worked example）

> Chapter 用途：当 LLM 在 pre-sim sizing 通用 sizing 流程（L0）Step 4 选旋钮时遇到
> wide-swing cascode bias / padding device 设计，应 read 这一章，得到
> "padding device Vds = 被偏置 cascode 下管 Vds" 等价铁律 + padding 链
> sizing TB 模板 + FC-OTA M7 padding worked example（含 Vov negative
> 实战陷阱）。

## Wide-swing 偏置铁律 — padding device Vds 等价

bias-generator 提供整条 bias chain 的电压/电流参考（含 basic mirror tree /
β-multiplier / replica / level-shifter-bias / startup-helper）。本 chapter
重点 **wide-swing cascode bias 的 padding device 设计** —— 这是 cascode
链下管 Vds 的来源。

**用户原话**："M7 的 vds 就是 padding device 的 vds。要多少才合适？可以
简单搭建一个 testbench，灌 Iref 电流测试一下，就知道这个 padding device
的 W/L 要取多少，才能得到想要的 vds 了。"

### Wide-swing 结构 + KVL 反推

wide-swing cascode bias 用一对 padding device（padding_upper + padding_lower）
模拟 cascode 链结构，输出 Vbc_n 给被偏置 cascode 上管 (M_casc) 的 gate：

- `Vbc_n = Vds_padding_lower + Vgs_padding_upper`
- 被偏置 cascode 链 KVL：`Vds_M_low = Vbc_n - Vgs_M_casc`
- 联立两式：`Vds_M_low = Vds_padding_lower + (Vgs_padding_upper - Vgs_M_casc)`

**当 padding_upper 与 M_casc 同 Vov**（设计常用做法 — 要求 padding_upper Vov
设计成跟 cascode 上管 Vov 一致）：
- `Vgs_padding_upper ≈ Vgs_M_casc`
- → **`Vds_M_low ≈ Vds_padding_lower`** ← **核心等价铁律**

**含义**：要让被偏置 cascode 下管 Vds = X mV，让 padding_lower 的 Vds = X mV
即可，**padding_lower 是"镜像"这个目标 Vds**。

### 设计要点

- padding_lower 一般 diode-connected（drain 接 gate）→ `Vds_padding_lower
  = Vgs_padding_lower`
- → padding_lower W/L 通过 (Iref_chain, target_Vov_padding_lower) 反算，
  其中 `Vov_padding_lower = Vds_padding_lower - Vth = X - Vth`
- 注意：padding_lower 的 Vov **不一定** 跟 M_low 一样 —— 实际是 `Vov_padding_lower
  = (target_Vds_M_low) - Vth`，跟 M_low 的工作 Vov 没直接关系
- 常用做法：padding_lower Vov 略大让 Vds_M_low 留 margin

**铁律**：当 cascode 下管 Vds 不对，**先看 padding device W/L 是否对**，
不动 M_low / M_casc 本身。盲改 M_low W/L 会破坏 spec（gm/Id / Itail），
盲改 M_casc Vov 会破坏 PSRR / gain。

### 反例（v9 / FC-OTA 实证 LLM 易犯）

看到 dc_snapshot 显示 M_low triode 就直接放大 M_low 的 W → Vov 降 → Vdsat
降 → 表面"修复"。但 W 改完 Itail 链跟着崩（如果 M_low 是 mirror output —
违反 R2），整条 bias tree 偏移。**正确做法**：顺 KVL 链反推到 padding
device，调 padding_lower W 改 V_padding_lower → Vbc_n 跟着升 → Vds_M_low
跟着升。

## Sizing TB Template — wide-swing padding 链查 W

当不知道 padding_lower 该取多少 (W, L) 才能让被偏置 cascode 下管 Vds 命中
target 时，搭独立 wide-swing padding TB 实测：

```spice
* tb_wide_swing_padding.sp
.include "<pdk_path>/vpdk180nm.lib"

V_DD vdd 0 1.8
I_REF vdd iref DC 50u                    $ bias chain reference 电流

* padding 链:
*   padding_upper (cascode-like, gate=iref node, source=Vds_pad_l, drain=Vbc_n)
*   padding_lower (diode-connected, gate=drain=Vds_pad_l, source=0)
* 注意: gate-bias 拓扑随实现微调; 这里给最常见 textbook 接法
X_PAD_U vbc_n iref vds_pad_l 0 nch_18 W=4u L=0.18u m=1
X_PAD_L vds_pad_l vds_pad_l 0 0     nch_18 W=2u L=0.18u m=1   $ diode-connected

* test point: 测 V(vds_pad_l) → 等价于被偏置 cascode 下管将得到的 Vds
.op
.print dc V(vbc_n) V(vds_pad_l) @m.x_pad_l.m1[vds] @m.x_pad_l.m1[vdsat] @m.x_pad_l.m1[vgs] @m.x_pad_l.m1[region]
.print dc @m.x_pad_u.m1[vds] @m.x_pad_u.m1[vgs] @m.x_pad_u.m1[vov]

* sweep W_PAD_L 找 V(vds_pad_l) 命中目标 Vds_M_low (用 .step 或多次 .alter)
.end
```

**用法**：
- 灌 Iref，看 V(vds_pad_l) → 这就是被偏置 cascode 下管将得到的 Vds
- sweep `W_PAD_L` 从 0.5µ 到 8µ，看 V(vds_pad_l) 怎么变（W 越大 → Vov 越
  小 → Vgs 越接近 Vth → Vds_pad_l 越接近 Vth）
- 选 W_PAD_L 让 V(vds_pad_l) 等于被偏置 cascode 下管要 hit 的 Vds_M_low
- 同时检查 padding_lower 的 region：region 必须是 saturation；如果显示
  subthreshold/triode → padding_lower 进了弱反型 / triode，trigger 实战
  陷阱（见下面 worked example）
- PMOS wide-swing 把 nch_18 换 pch_18，rails 对调

LLM 自己 read 这个模板 → 改 W_PAD_L / target Iref / model 三处即可，不需要
从零写 SPICE。**关键**：先扫 W_PAD_L 找出 V(vds_pad_l) 跟 W 的关系，再选点。

## Worked Example — FC-OTA NMOS cascode 下管 padding 设计（含实战陷阱）

**Spec**（沿 T5 cascode chapter 的 FC-OTA M7 例子，bias chain reference
电流 Iref = 50 µA）：
- 被偏置：FC-OTA M7（cascode 下管尾电流），target Vds_M7 = 0.25V（Vdsat=0.18V，
  margin 0.07V）
- M_casc（cascode 上管）Vov_casc = 0.20V → Vgs_M_casc = Vth + Vov ≈ 0.45 + 0.20
  = 0.65V
- Iref bias chain = 50 µA（Itail M7 = 100µA, mirror 比 1:2 假设, 即 padding
  链流过 50µA，被偏置 cascode 链流过 100µA）

### Derivation 第一轮（target Vds_M7 = 0.25V）

1. target `Vbc_n = Vds_M7 + Vgs_M_casc = 0.25 + 0.65 = 0.90V`
2. wide-swing 反推：`Vbc_n = Vds_padding_lower + Vgs_padding_upper`
3. 假设 padding_upper 跟 M_casc 同 Vov（0.20V）→ `Vgs_padding_upper ≈ 0.65V`
4. → `Vds_padding_lower = Vbc_n - Vgs_padding_upper = 0.90 - 0.65 = 0.25V`
5. padding_lower diode-connected：`Vds_padding_lower = Vgs_padding_lower
   = 0.25V` → `Vov_padding_lower = Vgs - Vth ≈ 0.25 - 0.45 = -0.20V` ← **NEGATIVE!**

### 实战陷阱：Vov_padding_lower negative

**这是 sizing 的一个常见坑**：Vov 算出来 negative 表示 padding_lower 在
subthreshold（弱反型，工作在 Vgs < Vth），需要 W 极大才能流过 50µA；或者
target Vds_M7 = 0.25V 选得太低，wide-swing bias 在标准 Vth (~0.45V) 工艺
下根本不可达。

**三个救法**：

- **救法 1**：抬高 target Vds_M7 让 Vov_padding_lower 回正
  - target Vds_M7 = 0.30V → Vbc_n = 0.95V → Vds_padding_lower = 0.30V →
    Vov_padding_lower = 0.30 - 0.45 = -0.15V（仍 negative）
  - target Vds_M7 = 0.35V → Vds_padding_lower = 0.35V → Vov_padding_lower
    = -0.10V（仍 negative）
  - target Vds_M7 = 0.50V → Vds_padding_lower = 0.50V → Vov_padding_lower
    = 0.05V（中弱反型边界，W 大但可达）✓
- **救法 2**：换"low-Vth"工艺管子（Vth ≈ 0.30V）→ 同 target Vds_M7 = 0.25V
  → Vov_padding_lower = -0.05V（仍弱反型，但接近临界，W 可调到中反型）
- **救法 3**：放弃 wide-swing，用 simple cascode bias（牺牲摆幅 ≈ Vdsat
  vs ≈ Vgs ≈ Vth+Vov，约多耗 0.45V head room） — 触发 R4 架构层兜底

### Derivation 第二轮（救法 1 — 抬 target Vds_M7 到 0.50V）

6. **重选 target Vds_M7 = 0.50V** → `Vbc_n = 0.50 + 0.65 = 1.15V`
7. → `Vds_padding_lower = 0.50V` → `Vov_padding_lower = 0.05V`（中弱反型，W
   要大才能流 50µA）
8. **触发 R3 实证**：搭 wide_swing_padding TB，灌 Iref = 50µA，sweep `W_PAD_L`
   from 0.5µ to 8µ，找让 V(vds_pad_l) ≈ 0.50V 的 W_PAD_L
9. （TB 出来后）假设实测 W_PAD_L ≈ 1.0µ 命中 V(vds_pad_l) = 0.50V，且
   region == saturation ✓ → 选 W_PAD_L = 1.0µ, L = 0.5µm（matching）
10. **触发 cross-cell**：padding_lower W/L 同时遵循 current-mirror cell 的
    R2 铁律（如果它跟 mirror tree 共享 reference 管）→ 跳到 `<base-cells>/current-mirror/sizing-reasoning.md`

### Cross-check（实战验证）

- 把上面算出的 W_PAD_L = 1.0µ 灌进 FC-OTA 完整 bias chain，跑 dc_snapshot：
  - V(vbc_n) ≈ 1.15V ?
  - M7.Vds ≈ 0.50V ? > Vdsat (0.18V) + 50mV margin ✓
  - M_casc.region == saturation ?
  - padding_lower.region == saturation ? Vov ≈ 0.05V？
- 如果 Vds_M7 偏低于 0.50V → padding_upper 的 Vov 跟 M_casc 不一致（Vgs_padding_upper
  ≠ Vgs_M_casc）→ 调 padding_upper W/L
- 如果 padding_lower 实测 region == subthreshold（Vov 算出来更 negative）→
  返回救法 2 / 3

### 教训

- **target Vds_cascode 下管 = Vov_cascode 下管 + 50mV margin（如 0.25V）**
  时往往 padding_lower 进 subthreshold（NMOS Vth ≈ 0.45V 工艺下）
- 这是 R4 架构-sizing 互锁的实战体现：**wide-swing 不是免费的**，要求
  padding_lower 的 Vov ≥ 0.05V（即 target Vds ≥ Vth + 0.05V ≈ 0.50V）
- 如果系统 head room 不允许 cascode 下管 Vds = 0.50V，就要选 simple
  cascode（牺牲摆幅）或换 low-Vth 工艺
- **不要为了"硬塞"低 Vds_M_low 而拼命放大 W_PAD_L** —— W 几十 µm 也修不
  了 subthreshold 的 swing 损失

## Cross-references

- L0 Sizing Framework Step 4（R2 镜像铁律 — 如果 padding 链跟 mirror 共
  reference）+ Step 5（R3 实证 — 搭 padding TB）+ Step 6（R4 架构兜底 —
  wide-swing → simple cascode）
- `<base-cells>/cascode/sizing-reasoning.md`（被偏置的对象 — Vds_M_low =
  Vbc_n - Vgs_M_casc 的 KVL 链反推）
- `<base-cells>/current-mirror/sizing-reasoning.md`（bias chain 镜像 reference
  → padding 链通常由 mirror reference 管供电；R2 铁律源头）
- 上层 chapter `basic-mirror-tree`（bias chain 主干结构）+ `level-shifter-bias`
  （wide-swing 是 level-shifter-bias 的高级形式）
