---
chapter: wide-swing
parent: current-mirror
summary: |
  Wide-swing cascode mirror —— 用专门 cascode bias（first-order: Vbc = Vth + 2·Vov；
  含 body effect 时用 cascode 管的 effective Vth）让 M_out.Vds ≈ Vov，
  compliance 从常规 cascoded 的 ~Vth+2Vov 改善到 ~2Vov /
  低 Vdd 工艺（<1.2V）+ LDO Case C 高 PSRR + rail-to-rail OTA load 用
tokens: ~600
prerequisite_chapters:
  - basic
  - cascoded
related_skills:
  - circuit-method/device-sizing
  - circuit-method/bias-tree-reasoning
related_knowledge:
  - blocks/base-cells/cascode
  - blocks/base-cells/bias-generator
---

# Wide-Swing Cascode Mirror

## 核心命题：保 cascode Rout，省 cascode 的 Vth headroom

**与基础 cascoded mirror 对比**：

| 维度 | basic cascoded | wide-swing cascoded |
|---|---|---|
| Rout | gm·ro² | gm·ro²（**同**）|
| Vbc 设计 | 常规 diode-stack/basic bias 常使底管 Vds ≈ Vth+Vov | Vth_c,eff + Vov_c + Vov_main；忽略 body effect 且两管 Vov 相同时约 Vth + 2·Vov |
| M_out.Vds | ≈ Vth+Vov：饱和但浪费一个 Vth headroom | Vov（恰好 Vds_sat）|
| **实际可用 V_out_min** | 约 Vth + 2·Vov ≈ 500-800 mV | **约 2·Vov**，再加 body-effect / mismatch / PVT margin（first-order 200-400 mV）|
| 偏置生成 | 简单 diode-stack，但 headroom 浪费 | 专门 bias，目标让 `Vx = Vbc - Vgs_cascode ≈ Vov_main` |

**关键洞察**：cascode stack 的网络下限是 `Vout_min = Vx + Vdsat_cascode`，其中 Vx 是 M_out 漏极=cascode 源极的电压。常规 cascoded bias 往往让 `Vx ≈ Vth + Vov`（M_out.Vds 过大），所以实用 `Vout_min ≈ Vth + 2·Vov`。wide-swing 直接设计 `Vbc`，令：

```
Vx = Vbc - Vgs_M_out_c
   ≈ (Vth_c,eff + Vov_c + Vov_main) - (Vth_c,eff + Vov_c)
   = Vov_main
```

**body effect 注意**：bulk 接 VSS 的 NMOS cascode，source 抬升到 Vx ≈ Vov_main 时 VSB ≈ Vov_main，会让 Vth_c,eff 比 nominal Vth 抬升 30-70 mV（取决于 γ）。设计 wide-swing bias 时必须把这个增量计入 Vbc 目标或 PVT margin，否则 M_out.Vds 可能低于 Vov 进入 triode。若忽略 body effect 且 `Vov_c = Vov_main`，可简写为 `Vbc ≈ Vth + 2·Vov`（first-order）。

## Wide-swing bias 生成（关键设计）

```
       VDD ──────┬───────── M_ref / M_out 主路 (mirror)
                 │
              ┌──┴──┐
              │M_pad│   pad device，sizing 让 Vds_pad = Vov_main
              └──┬──┘
                 │ Vbc = Vth_pad + Vov_pad ?  ← 错!
                 ●
                 │
              ┌──┴──┐
              │M_dig│   diode-connected，sizing 让 Vgs_dig = Vth + 2·Vov
              └──┬──┘
                 │
              I_ref（同主路 Iref）
                 │
                vss
```

**正确生成**（两类常见实现，**避免混用**——混用会把 Vbc 错算成过大值）：

| 方式 | 实现 | 物理 |
|---|---|---|
| **A. 单 diode bias MOS** | bias MOS diode-connected，sizing 让其 Vov_bias = 2·Vov_main（同电流下让 W/L 减为主管的 1/4）| Vgs_bias = Vth_eff + 2·Vov_main 直接产生 Vbc。diode-connected MOS 因 `Vds=Vgs`，强反型下天然 saturation 不会 triode |
| **B. Vgs_main + Vov padding** | tracking 一个 Vgs_main（diode-connected 标准 MOS 同 Vov） + 串叠 一个 Vov_main 电压 drop（如 short-channel 高 Vov device 偏置在 saturation） | Vbc = Vgs_main + Vov_main = Vth + 2·Vov_main |

**注意**：方式 B 的"padding"**不是**第二个完整 Vgs（即不再串一个 diode-connected 标准 MOS），否则会多出一个 Vth 让 Vbc ≈ Vth + Vth + 2·Vov 偏置过深。详细 sizing 见 `blocks/base-cells/bias-generator/wide-swing-bias.md`（chapter pending）。

**PVT tracking**：两类实现都要让 padding/diode 的 Vov tracking 主管 Vov（同 Iref + 同 Vov_main 设计），这样 Vbc 在 PVT 角下漂移 < 50 mV。

## sizing 关系

| 量 | 推荐 | 因果 |
|---|---|---|
| M_ref / M_out / M_ref_c / M_out_c | 同 unit W/L/m（与 basic cascoded 同）| 镜像比例靠 m，不靠 W ratio |
| Vov_main | 100-200 mV | 太小弱反型 / 太大 compliance 损失大 |
| Vbc | Vth_c,eff + Vov_c + Vov_main | first-order 等 Vov 时 ≈ Vth + 2·Vov_main；bulk 接 VSS 时加 body-effect margin（30-70 mV）|
| L_main / L_cascode | 4-8 × Lmin | matching + ro |
| compliance V_out_min | 2 × Vov_main | spec |

## sizing 范例（LDO bias 镜像 1:5，target compliance V_out_min ≤ 0.4 V）

> 📌 **@ vpdk180nm**（μn·Cox ≈ 270 µA/V²、Vth_n ≈ 0.35 V 等数值参考 `pdks/vpdk180nm/index.md`）。换工艺需重算所有数值；公式形式（Vbc = Vth + 2·Vov / compliance = 2·Vov / Rout = gm·ro²）跨工艺通用。short-channel L 用 long-channel 公式 VA·L/Id 偏高 2-5×，必须 simulate 验证。

```
设计目标：Iref = 10 µA → Iout = 50 µA（5× mirror），V_out_min ≤ 0.4 V

Vov 选择:
  V_out_min = 2·Vov ≤ 0.4 V → Vov ≤ 0.2 V
  取 Vov = 0.15 V（留 50 mV margin / 平衡 noise）

主路 sizing（NMOS mirror）:
  M_ref: Id=10µA, Vov=0.15V
    W/L = 2·Id/(μn·Cox·Vov²) = 2×10µ/(270µ × 0.0225) ≈ 3.3
    L = 0.5 µm（生产风格），W = 1.65 µm，m=1
  M_out: 同 unit，m=5 → Iout = 50 µA
  M_ref_c / M_out_c (cascode): 同 unit W/L（与 mirror 同 Vov），m=1 / m=5

Vbc 目标:
  first-order: Vbc = Vth + 2·Vov = 0.35 + 2×0.15 = 0.65 V
  含 body effect: cascode NMOS bulk 接 VSS 时 VSB ≈ Vov ≈ 0.15V，Vth_c,eff 抬升 ~30-50mV
  → bias 目标加 body-effect margin: Vbc ≈ 0.68-0.70 V（具体 simulate 校准）
  由 wide-swing bias chain 生成（见 `bias-generator/wide-swing-bias.md`）

compliance 验证:
  M_out.Vds 目标 = Vov = 0.15 V （而非 basic cascoded 的 0.5 V）
  V_out_min first-order = 2·Vov = 0.30 V
  含 body-effect/mismatch margin 后按 0.35-0.40 V budget 验证（spec 0.4V ✓ 仍留 margin）

Iq 预算:
  wide-swing bias chain 通常额外消耗一个 bias branch 电流（如 10 µA）
  LDO Iq budget 不能只算 mirror reference 的 10 µA，要加 wide-swing branch（~10-20 µA）
  → 实际系统 Iq = Iref_main + I_bias_chain + ...，对低 Iq spec（<50 µA）影响显著

Rout 验证:
  ro_M_out @ Id=50µA L=0.5µm（vpdk180nm long-channel 估）
    ≈ VA·L/Id = 10×0.5/50µ = 0.1 MΩ（实测可能 0.15-0.3 MΩ，BSIM 验）
  gm_M_out_c = (gm/Id)·Id ≈ 13×50µ = 650 µS
  Rout_cascoded ≈ gm·ro·ro ≈ 650µ × 0.2M × 0.2M = 26 MΩ（中位估）
  vs basic mirror Rout ≈ 0.2 MΩ → cascode 提升 ~130×（量级合理）
```

## 验证清单

- [ ] dc_snapshot：M_ref / M_out / M_ref_c / M_out_c 全 saturation；bias chain 中 diode-connected MOS 也 saturation（不要把 Vds=Vgs 的 diode device 误判为 triode）
- [ ] dc_snapshot：M_out.Vds ≈ Vov（不是 Vth + Vov，**这是 wide-swing 的标志**）
- [ ] dc_snapshot：Vbc ≈ Vth_c,eff + Vov_c + Vov_main（含 body effect；wide-swing bias 工作正常的标志）
- [ ] DC sweep（扫 Vout）：Vout 从 V_out_min ≈ 2·Vov+margin 到 VDD，Iout 变化 < 1%（compliance 实测）
- [ ] PVT corner：Vbc tracking（漂 < 50mV），M_out.Vds 在 Vov ± 50mV 范围
- [ ] **关键**：与 basic cascoded mirror 对比 V_out_min 实测（应低 ~Vth ≈ 350 mV）
- [ ] Iq 验证：simulate 测 wide-swing bias chain 的 branch current，加入总 Iq budget

## 常见误区

| 心里想 | 现实 |
|---|---|
| "wide-swing 比 cascoded Rout 高" | **同**——两者 Rout = gm·ro²。wide-swing 只省 compliance，不动 Rout |
| "用 basic cascoded 的 bias chain 给 wide-swing" | basic bias 的问题是底管 Vds 不是目标 Vov，而是约 Vth+Vov 量级，浪费一个 Vth 的 headroom；wide-swing 必须专门产生 Vbc ≈ Vth + 2·Vov 才让底管 Vds 等于 Vov |
| "wide-swing cascode 管 Vov 应小" | cascode 管 Vov 通常 = mirror 管 Vov（同 Id 同 W/L）。物理上 M_out.Vds = Vbc - Vgs_cascode，由 Vbc 设计决定：若 Vbc 跟踪 Vth_c,eff + Vov_c + Vov_main，Vov_c 偏小不会破坏 M_out.Vds ≈ Vov_main；若 Vbc 固定按 first-order Vth+2·Vov_main 不重新跟踪，Vov_c 偏小会让 Vx 变大浪费 headroom + 增大 cascode 管面积/电容（trade-off 不利但不"破坏稳定"） |
| "wide-swing 是高级设计，永远比 cascoded 好" | bias chain 复杂 + 多用一些功耗。当 Vdd 充裕（≥ 1.5V）/ V_out_min 不紧张时，basic cascoded 更优 |
| "wide-swing 的 cascode 管也可省 Vth" | 不能——cascode 管 Vds 受 Vout 调制，wide-swing 只优化 mirror 管 M_out 的 Vds，cascode 管 M_out_c 仍需 Vov + 一定 Vds margin |
| "PMOS OTA load 直接复制 NMOS mirror sizing" | 不能直接复制。PMOS mirror/load 公式按绝对值翻转（Vth_p / Vov_p / VSG / VSD）；PMOS 作为 OTA load 时 L 常因 noise / matching / gds 取更长（2-4× NMOS L）|

## 不在本章范围

- 基础 cascoded mirror 物理 / sizing → `chapter=cascoded`
- regulated cascode（gain-boost mirror）→ `chapter=regulated`（pending）
- wide-swing bias chain 详细 sizing → `blocks/base-cells/bias-generator/wide-swing-bias.md`（pending）
- 基础 cascode 物理 / Vbias_cascode 通用计算 → `blocks/base-cells/cascode/basic.md`
- 故障 debug → `chapter=troubleshooting`
- LDO Case C 双级 EA + 高 PSRR 整体 → `blocks/ldo/architecture.md`
