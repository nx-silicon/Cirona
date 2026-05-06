---
chapter: sizing-reasoning
parent: differential-pair
summary: |
  R1 KVL 链 Vds_M_tail = Vincm - Vgs_M_input 在 differential-pair tail 的具体化反推
  + R2 镜像铁律：M_tail 是 mirror output, 减 Vdsat 必须改 mirror reference 管 W/L
  + diff-pair + tail mirror 联仿 sizing TB + 5T-OTA NMOS-input worked example。
  pre-sim sizing 通用 sizing 流程 Step 2-3 列 Vds 链 + Step 4 选旋钮时 LLM read 这章。
tokens: ~1500
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/device-sizing
  - circuit-method/bias-tree-reasoning
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/current-mirror
  - blocks/base-cells/cascode
  - blocks/base-cells/bias-generator
---

# differential-pair — sizing reasoning（R1 KVL Vds_tail 反推 + R2 镜像铁律 + TB + worked example）

> Chapter 用途：当 LLM 在 pre-sim sizing 通用 sizing 流程（L0）Step 2-3 列 Vds 链 +
> Step 4 选旋钮时遇到 differential-pair（含 tail current source）结构，应
> read 这一章，得到 R1 KVL 链反推到 Vincm/Vgs_input 的具体化 + R2 镜像铁律
> 的 tail-mirror 应用 + diff-pair sizing TB 模板 + 5T-OTA 输入级 worked example。

## R1 KVL 链反推 — differential-pair tail 实例化

差分对结构：input pair（M1 / M2，gate 接 vinp / vinn，source 共连 ntail）+
tail current source（M_tail，gate 接 Vbias_tail，source 接 VSS）。M_tail 通常
是 current-mirror 的 output 管，由参考管 M_REF 镜像出 Itail。

**KVL 链**（NMOS-input pair）：
- `Vds_M_tail = V(ntail) = Vincm - Vgs_M_input`
- → Vds_M_tail **由 Vincm 和 input pair 的 Vgs 共同决定**，不是由 M_tail 自己决定

**用户原话**："比如输入差分对管下面的尾电流管 Mtail，假如进线性区了 ...
由输入对管的 vinp / vinn 决定，vinp - vgs_输入管 = tail 管的 vds"

PMOS-input pair 同理但极性反向：`Vds_M_tail = Vgs_M_input - (VDD - Vincm)`，
M_tail 是 PMOS 接 VDD。

**铁律**：当 M_tail 进 triode（Vds_M_tail < Vdsat_M_tail），不要先动 M_tail
W/L，先沿 KVL 链反推：

1. **路径 A**：升 Vincm。**输入约束**——Vincm 是输入信号共模，由系统层
   决定，通常**不可调**（除非整体偏置链重设计）
2. **路径 B**：降 Vgs_M_input → 改 input pair Vov。input pair 的 (Vov, gm/Id)
   由 spec（gm_input / 噪声 / matching）锁住，**谨慎**——降 Vov 牺牲 ICMR 余量
3. **路径 C**（**最常用**，**触发 R2 镜像铁律**）：降 Vdsat_M_tail。但 M_tail
   是 mirror output 管，**不能直接调 M_tail W/L**（盲改会让 Itail 偏离 spec），
   必须改 mirror reference 管 M_REF 的 (W, L) → Vov_M_REF 降 → 镜像传到
   Vov_M_tail 降 → Vdsat_M_tail 降
4. **兜底**：触发 R4 架构层换架构 — NMOS-input → PMOS-input pair（如果 Vincm
   偏低）/ 加 wide-swing tail（牺牲 head room 换 ro_tail）

**反例**（v9 / FC-OTA 实证 LLM 易犯）：看到 dc_snapshot 显示 M_tail triode
就直接放大 M_tail 的 W → 表面 Vdsat 降，但 mirror ratio 跟着崩，Itail 偏离
spec → input pair gm 跟着漂 → 整条 bias tree 崩。正确做法是**改 mirror
reference 管**（R2 铁律）。

## Sizing TB Template — diff-pair + tail mirror 联仿

当不知道某 diff-pair 在某 (Vincm, Itail, M_input.W/L, M_REF.W/L) 下 Vds_M_tail
是多少时，搭独立 TB 实测：

```spice
* tb_diff_pair_with_tail.sp
.include "<pdk_path>/vpdk180nm.lib"

V_DD vdd 0 1.8
V_INCM vincm 0 1.2       $ 输入共模 (sweep 看 Vds_M_tail 响应)
V_DIFF vdiff 0 0         $ 差模置零, 看 OP
V_INP vinp 0 V_INCM+V_DIFF/2
V_INN vinn 0 V_INCM-V_DIFF/2
$ 简化: vinp=vinn=vincm
V_BIAS_REF iref 0 0 DC 100u

X_REF iref iref 0 0 nch_18 W=4u L=0.18u m=1            $ mirror reference, diode-connected
X_TAIL ntail iref 0 0 nch_18 W=4u L=0.18u m=1          $ M_tail (mirror output)
X_M1 vd1 vincm ntail 0 nch_18 W=8u L=0.18u m=1
X_M2 vd2 vincm ntail 0 nch_18 W=8u L=0.18u m=1

* 简化: load 用电流源 (实战中替换为 PMOS mirror load)
I_LOAD vdd vd1 DC 50u
I_LOAD2 vdd vd2 DC 50u

.dc V_INCM 0.6 1.5 0.05
.print dc V(ntail) @m.x_tail.m1[vds] @m.x_tail.m1[vdsat] @m.x_tail.m1[region]
.end
```

**用法**：
- sweep V_INCM 看 V(ntail)（即 Vds_M_tail）怎么动
- 找最小 V_INCM 让 Vds_M_tail > Vdsat_M_tail + 50mV margin（ICMR 下限）
- 如果当前 Vincm 已固定（系统层决定）但 M_tail 仍 triode：等比改 X_REF 的 W
  （M_REF 和 X_TAIL 同步等比变，保 mirror ratio 不变）→ 再 sweep 看 Vdsat
- PMOS-input pair 把 nch_18 换 pch_18，tail 接 vdd，rails 对调

LLM 自己 read 这个模板 → 改 V_INCM sweep 范围 / target Itail / device size
三处即可，不需要从零写 SPICE。

## Worked Example — 5T-OTA NMOS-input pair + tail mirror

**Spec**：
- gm_input = 500 µS（input pair 单管）
- Iload = 50 µA per branch → Itail = 100 µA
- Vincm = 1.2V（系统层固定）
- L_input = 0.18 µm（速度优先）
- L_tail = 0.5 µm（matching + 1/f noise）

**Derivation**：
1. **input pair**：(gm=500µS, Id=50µA) → gm/Id = 10 → Vov_M_input ≈ 0.2V
2. (Id=50µA, Vov_M_input=0.2V) → 查 vpdk180nm gm/Id 表：W_M_input ≈ 8 µm
3. **KVL chain**: Vds_M_tail = Vincm - Vgs_M_input
4. Vgs_M_input = Vth + Vov ≈ 0.45 + 0.2 = 0.65V
5. Vds_M_tail = 1.2 - 0.65 = **0.55V**
6. **M_tail spec**：Itail = 100µA, target Vov_M_tail = 0.15V（留 Vds margin
   = 0.55 - 0.15 = 0.40V，足够 sat），L_tail = 0.5 µm（matching 优先）
7. (Id=100µA, Vov=0.15V) → 查 gm/Id 表：W_M_tail ≈ 12 µm
8. **R2 镜像铁律 — M_tail 是 mirror output 管**：
   - mirror ratio Itail / Iref = 1（spec 决定）→ M_REF 也设 W = 12 µm,
     L = 0.5 µm, Iref = 100 µA（diode-connected, 1:1 mirror）
   - 这样 Vov_M_REF = Vov_M_tail = 0.15V，传到 M_tail 的 Vdsat 也 = 0.15V
9. **如果实测 M_tail 进 triode**（Vds < Vdsat）：**不要直接调 M_tail W**
   （会破坏 Itail spec）！正确做法：
   - 改 M_REF：W ↑（如 12 → 18 µm，对应等比改 M_tail W → 18µm 保 ratio=1）
   - → Vov_M_REF ↓（0.15 → 0.12V）→ 镜像传到 Vov_M_tail ↓ → Vdsat_M_tail ↓
   - **关键**：M_REF 和 M_tail 必须**同步等比变**，否则 mirror ratio 漂移
10. **触发 cross-cell**：M_REF 的 sizing 同时遵循 current-mirror cell 的 R2
    铁律 → 跳到 `<base-cells>/current-mirror/sizing-reasoning.md`

**Cross-check**：
- Vds_M_tail (0.55V) - Vdsat_M_tail (0.15V) = 0.40V > 50mV ✓
- 对 5T-OTA：DC gain ≈ gm_input · (ro_input ‖ ro_load)；如果接 PMOS mirror
  load 单端取出，gain ≈ gm_input · ro_combined，typical 30-50 dB
- 改完 sizing 跑 dc_snapshot 验证 region all saturation（input pair + M_tail
  + load 全 sat）
- 如果 M_tail 实测 triode → 沿 KVL 链反推：Vincm 固定不能动 → 路径 C 改 M_REF
  W 等比变 → Vov_M_tail 降 → Vdsat_M_tail 降 → Vds margin 回正

## Cross-references

- L0 Sizing Framework Step 2 (R1 KVL 链 Vds_M_tail = Vincm - Vgs_M_input)
  + Step 4 (R2 镜像铁律 选旋钮)
- `<base-cells>/current-mirror/sizing-reasoning.md`（M_tail 是 mirror output —
  改 W 必须 M_REF 同步等比变；R2 铁律源头）
- `<base-cells>/cascode/sizing-reasoning.md`（如 5T 升级到 telescopic / FC-OTA
  时 input pair 上叠 cascode；diff-pair output 接 cascode 上管）
- `<base-cells>/bias-generator/sizing-reasoning.md`（M_REF 的 Iref 来源 —
  通常由 bias-tree 提供）
