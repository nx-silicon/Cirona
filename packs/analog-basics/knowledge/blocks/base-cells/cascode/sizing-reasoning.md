---
chapter: sizing-reasoning
parent: cascode
summary: |
  R1 KVL 链 Vds_M_low = Vbc - Vgs_M_casc 在 cascode 的具体化反推 + cascode
  链单独 sizing TB 模板 + folded-cascode OTA M7 worked example。pre-sim
  sizing 通用 sizing 流程 Step 2-3 列 Vds 链 + Step 4 选旋钮时 LLM read 这章。
tokens: ~1300
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/device-sizing
  - circuit-method/bias-tree-reasoning
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/bias-generator
  - blocks/base-cells/current-mirror
---

# cascode — sizing reasoning（R1 KVL Vds_lower 反推 + TB + worked example）

> Chapter 用途：当 LLM 在 pre-sim sizing 通用 sizing 流程（L0）Step 2-3 列 Vds 链 +
> Step 4 选旋钮时遇到 cascode 结构，应 read 这一章，得到 R1 KVL 链反推
> 的具体化 + cascode 链 sizing TB 模板 + FC-OTA M7 worked example。

## R1 KVL 链反推 — cascode 实例化

cascode 结构：lower device M_low（gate 由信号驱动）+ upper device M_casc
（gate 接固定偏置 Vbc）。

**KVL 链**：
- `Vds_M_low = V(M_casc.S) = Vbc - Vgs_M_casc`
- → Vds_M_low **由 Vbc 决定**，不是由 M_low 自己决定

**铁律**：当 M_low 进 triode（Vds_M_low < Vdsat_M_low），不要先动 M_low
的 W/L，先沿 KVL 链反推：

1. **路径 A**：升 Vbc。Vbc 由 wide-swing bias 的 padding device 决定（见
   `<base-cells>/bias-generator/sizing-reasoning.md`）→ 改 padding device
   的 W/L 让 Vbc 升高
2. **路径 B**：降 Vgs_M_casc（即降 M_casc 的 Vov）。Vgs = Vth + Vov，Vov
   由 (Id, gm/Id) 决定 → 通常 cascode 设计参数受 PSRR / gain 约束不可
   随便动
3. **如果 Vbc 不能升（架构限制）**：触发 R4 架构层兜底 — 换成 simple cascode
   牺牲摆幅 / regulated cascode 添 boost 放大

**反例**（v9 / FC-OTA 实证 LLM 易犯）：看到 dc_snapshot 显示 M_low triode
就直接放大 M_low 的 W → Vov 降 → Vdsat 降 → 表面"修复"，但 W 改完 Iout 链
跟着崩，整条 bias tree 偏移，问题转移不消失。正确做法是顺 KVL 链反推到
Vbc 源头。

## Sizing TB Template — cascode 链单独仿真

当不知道某 cascode 结构在某 (Itail, Vbc, M_casc.W/L) 下 M_low 的 Vds 是多少
时，搭独立 TB 实测：

```spice
* tb_cascode_chain.sp
.include "<pdk_path>/vpdk180nm.lib"

V_DD vdd 0 1.8
V_BC vbc 0 0.95          $ target Vbc (sweep 看 Vds_M_low 响应)
V_DS_TOP top 0 1.4       $ cascode 上方 node (一般是 mirror PMOS source)
I_BIAS  0 g_low DC 50u   $ M_low 的 gate 由独立 Iref + diode 偏置

X_LOW  s_int g_low 0 0     nch_18 W=4.5u L=0.18u m=1
X_CASC top   vbc s_int 0   nch_18 W=2u   L=0.18u m=1

.dc V_BC 0.6 1.4 0.05
.print dc V(s_int) V(top) @m.x_low.m1[vds] @m.x_low.m1[vdsat] @m.x_low.m1[region]
.end
```

**用法**：
- sweep V_BC 看 V(s_int)（即 Vds_M_low）怎么动
- 找最小 V_BC 让 Vds_M_low > Vdsat_M_low + 50mV margin
- PMOS cascode 把 nch_18 换 pch_18，rails 对调，I_BIAS 反向

LLM 自己 read 这个模板 → 改 V_BC sweep 范围 / target Itail / device size
三处即可，不需要从零写 SPICE。

## Worked Example — folded-cascode OTA 中 M7（cascode 下管尾电流）

**Spec**：
- M7 是 cascode 下方尾电流管（NMOS，Itail = 100µA）
- target Vds_M7 = 0.25V（足够 sat）
- target Vdsat_M7 = 0.18V（gm/Id = 12，noise-friendly）
- L = 0.5 µm（noise + matching）

**Derivation**：
1. (Itail=100µA, Vov_M7=0.18V) → 查 gm/Id 表：W ≈ 8 µm
2. KVL chain: Vds_M7 = Vbc_n - Vgs_M_cascode
3. M_cascode 上管 Vgs = Vth + Vov_casc = 0.45 + 0.20 = 0.65V
4. 反推 Vbc_n 期望值: Vbc_n = Vds_M7 + Vgs_M_cascode = 0.25 + 0.65 = 0.90V
5. **触发 R3 实证**：搭上面 cascode TB，sweep Vbc 验证 Vbc=0.90V 时
   Vds_M7 = 0.25V ✓
6. **再触发 cross-cell**：Vbc=0.90V 是 wide-swing bias padding device
   的输出 → 跳到 `<base-cells>/bias-generator/sizing-reasoning.md` 设计
   padding device

**Cross-check**：
- Vds_M7 (0.25V) - Vdsat_M7 (0.18V) = 0.07V > 50mV ✓
- 改完 sizing 跑 dc_snapshot 验证 region == saturation
- 如果实测 Vds_M7 偏小 → 沿 KVL 链反推：要么 Vbc_n 不够（修 padding device），
  要么 Vgs_M_cascode 太大（M_cascode Vov 设计偏高，但通常被 PSRR 锁住不可动）

## Cross-references

- L0 Sizing Framework Step 2-3（R1 KVL 链 + Vds-Vdsat 约束）
- `<base-cells>/bias-generator/sizing-reasoning.md`（Vbc 来源 — padding device 设计）
- `<base-cells>/current-mirror/sizing-reasoning.md`（cascode 通常接 mirror PMOS 上方，mirror sizing 决定 cascode 顶部 node 电压）
