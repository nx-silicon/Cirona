---
chapter: startup
parent: bandgap
summary: |
  Bandgap 启动专章 — Two DC operating solutions（zero-current latch /
  biased solution）物理 + DC `op` 为什么不能证明 startup + R_START + MN_SENS +
  MN_KICK helper 拓扑 + tb_startup .ic/uic 必备模板 + W_KICK / R_START sizing
  规则 + 5 类 startup-related failure modes（V3 failure_playbook codify）。
  base-cell `bias-generator/startup-helper` 是物理推导 source of truth；本章
  专注 PNP bandgap 系统级 startup 决策与验证。
tokens: ~1200
prerequisite_chapters:
  - reference-design
related_skills:
  - circuit-method/signal-tracing
  - meta-cognitive/verification-before-completion
related_knowledge:
  - blocks/base-cells/bias-generator    # startup-helper + beta-multiplier
---

# Bandgap Startup

## 核心物理：Two DC operating solutions

Bandgap 是**自偏置**反馈环路（OTA 比较 na/nb，3-leg PMOS mirror 由 OTA 输出 yg 驱动）。这类电路的 DC equation 通常至少有两个自洽 operating solutions：

| 解 | 物理 | 是否符合设计目标 |
|---|---|---|
| **正常工作点**（biased solution）| mirror leg 流 ~7 µA / Vref ≈ 1.19V / na ≈ nb ≈ Vbe | ✅ |
| **零电流稳态**（zero-current latch）| 全 PMOS cutoff（yg = VDD）/ 全 PNP 无电流 / Vref = 0 / na = nb = 0 | ❌ stuck-at-zero |

**两解都自洽**：zero-current 下 KCL/KVL 也满足；但这不是 OTA 主动"锁住"，而是 self-biased OTA 与 mirror 都没有建立偏置，差分误差无法把环路推出零电流分支。real silicon 上电从零电压开始时，若没有足够 leakage、mismatch、noise 或 startup helper 提供扰动，可能停在 zero-current latch 或启动不可靠。

## ⚠️ 为什么 DC `op` 不能证明 startup

**关键 fact**：ngspice / SPICE 的 DC solver 在 multi-solution 系统中可能因 gmin / source stepping、初值、`.nodeset` 或模型连续化而收敛到 non-zero 解。`.op` 报告 Vref = 1.19V 只说明存在一个 DC operating point，**不能证明上电轨迹会从 0V 进入该工作点**。

```
ngspice .op   → Vref = 1.19V ✅（solver 收敛到非零工作点）
startup tran  → 从 0V 初值 + VDD ramp 验证是否 escape zero-current
```

**Iron Law**：bandgap 必跑 `tb_startup.sp` with `.ic` (zero initial condition) + `tran ... uic` (use initial conditions, skip pre-DC) + VDD ramp。**只跑 DC `op` 不能 sign-off bandgap**。

## Startup helper 拓扑

PNP bandgap 标准 startup helper 三件套（V3 reference cir 用此结构）：

```
                    VDD
                     │
                  R_START
                  500 kΩ
                     │
                     ●─── v_sens
                     │
              [MN_SENS]            [MN_KICK]
              G=vref               G=v_sens
              D=v_sens             D=yg          ← 拉 yg 低 → 启动 mirror
              S=vss                S=vss
                     │                  │
                    vss                vss
```

**机制 4 阶段**（参考 base-cell `bias-generator/startup-helper`）：

| 阶段 | 状态 | yg / Vref / v_sens |
|---|---|---|
| T=0 上电 | 全 cutoff | yg=VDD（mirror off）/ Vref=0 / v_sens=VDD-µ（R_START 微弱 pull-up）|
| T=0+ MN_KICK 启动 | v_sens 高 → MN_KICK on → 拉 yg 低 | yg ↓ to ~1.1V / Vref 仍 0 / v_sens 高 |
| T=10-100µs mirror conducting | yg 低 → 3 PMOS mirror 导通 → Vref 上升 | yg ≈ 1.05V / Vref ↑ to ~1.0V / v_sens 仍 高 |
| T=200µs 自禁用（settle）| Vref > Vth_n（≈ 0.5V）→ MN_SENS on → v_sens 拉到 vss → MN_KICK off | yg ≈ 1.05V（OTA 控制）/ Vref ≈ 1.19V / **v_sens ≈ 0V → MN_KICK 完全 off** |

**自禁用 critical**：MN_KICK 在正常工作后必须完全 off，否则持续从 yg 漏电流到 vss → PSRR 退化（详见 § Failure mode 3）。

## tb_startup.sp 必备模板

```spice
.lib '../../pdk/vpdk180nm/vpdk180nm_corners.lib' TT
.include './bandgap.cir'

* VDD ramp 0→1.8V over 1 µs, then hold (PW big enough for full simulation)
VDD vdd 0 PULSE(0 1.8 0 1u 1u 10 20)
VSS vss 0 0
Xdut vdd vss vref bandgap

.control
  set noaskquit
  set units = degrees
  tran 100n 200u uic              $ ⚠️ uic = use initial conditions (skip pre-DC)
  meas tran vref_final    find v(vref) at=190u
  meas tran vref_max      max  v(vref) from=0   to=200u
  meas tran vref_settled  min  v(vref) from=50u to=200u
  meas tran yg_min        min  v(xdut.yg) from=0 to=200u
  meas tran t_vref_90     when v(vref)=1.07 rise=1
  print vref_final vref_max vref_settled yg_min t_vref_90
.endc
.end
```

**关键 SPICE 卡**：
- `PULSE(0 1.8 0 1u 1u 10 20)` — VDD 1µs 上升边沿，10s pulse width（一次性 ramp，不重复）
- `tran 100n 200u uic` — `uic` 强制 ngspice **跳过 pre-DC 求解**，按 `.ic` 或 0 V 初始电压跑 transient
- 不加 `uic` → ngspice 先做 DC `op` → 可能收敛到非零工作点 → tran 起点已经在正常状态 → **可能 mask 掉 startup bug**（V3 PACK failure_playbook 实战教训）

**期望 startup 结果**（V3 verified）：
- `t_vref_90` < 50 µs（Vref 达 90% target ≈ 1.07V）
- `vref_settled` ≈ 1.19V（settle 后稳态）
- `yg_min` < 1.1V（mid-startup MN_KICK 拉 yg 低的最低点）
- `vref_max` < 1.79V（无 startup overshoot）

## W_KICK / R_START sizing 规则

| 参数 | 默认 | 太小 | 太大 |
|---|---|---|---|
| `W_KICK` | 5 µm | stuck-at-zero（拉 yg 不动）| **startup oscillation**（kick 太强 → yg 反复 over-pull → 振荡）|
| `R_START` | 500 kΩ | v_sens 拉不低 → MN_KICK 部分导通 → PSRR / Iq 退化 | startup 慢 / v_sens ramp 慢 |
| `L_SENS / L_KICK` | 1 µm | matching 差 / Vth 漂大 | parasitic 大 / startup 响应慢 |
| `W_SENS` | 5 µm | detector 弱 → 自禁用阈值漂 | parasitic 大 |

**sizing guardrail**：`W_KICK` 只需把 `yg` 拉到 PMOS mirror 能导通的范围；过大时表现为 overshoot 或 relaxation-like startup ringing。`R_START` 是 weak pull-up，不能强到让 `MN_SENS` 在正常工作时仍无法把 `v_sens` 拉低。`200 kΩ` 只能作为 vpdk180nm 起点下限，最终以 DC / PVT `V(v_sens) < 0.1V` 与 PSRR 无退化为准。

## 6类 startup-related failure modes

按 V3 failure_playbook codify：

### Mode 1: stuck-at-zero（kick 太弱）

**症状**：tb_startup tran 后 Vref < 0.1V，yg 始终 ≈ VDD

**根因**：`W_KICK` 太小，无法在零电流稳态下把 yg 拉低到 `VDD - Vsg_MP`（~1.1V）

**修复**：先加 `W_KICK` 到 10-20 µm；TRAN 验证 t<10µs 时 `V(yg) < 1.1V`

### Mode 2: startup oscillation（kick 太强）

**症状**：tb_startup tran 中 Vref 振荡（mid-µs 周期），不收敛到 1.19V

**根因**：`W_KICK` 过大让 yg 被 over-pulled 到 vss → mirror 过 conducting → Vref overshoot → MN_SENS over-on → MN_KICK 突 off → yg 弹回 VDD → mirror 全 off → Vref 跌 → 循环

**修复**：减 `W_KICK`（20µ → 10µ → 5µ）；如同时遇 outer loop oscillation（mid-MHz） → 见 `chapter=architecture` Pitfall 6（OTA Miller comp + Ccomp 2pF）

### Mode 3: MN_SENS 持续导通（R_START 太小）

**症状**：DC op 中 `V(v_sens)` ≈ 0.7V（不是接近 0V）；PSRR 退化 5-10 dB

**根因**：`R_START` 太小（或 `MN_SENS` 太弱）→ 正常工作时 `MN_SENS` 虽然 on，但 pull-down 阻抗仍不足以压过 R_START pull-up → `v_sens` 停在中间电压 → `MN_KICK` 部分导通 → yg 到 vss 出现 DC 泄漏 → PSRR / Iq 退化

**修复**：增 `R_START` 到 500 kΩ - 2 MΩ，或增大 `MN_SENS`；DC op 验证 `V(v_sens) < 0.1V`（**MN_KICK off**，且 MN_SENS pull-down margin 足够）

### Mode 4: 没有 .ic / uic（DC 假阳性）

**症状**：DC `op` 显示 Vref = 1.19V 完美；real silicon 测出 stuck-at-zero（开发期没暴露 → bring-up 才暴露）

**根因**：tb_startup 没有 `tran ... uic`，ngspice 先解 DC `op`，可能收敛到非零工作点，然后 tran 从 already-on 状态起 → mask startup bug

**修复**：tb_startup 必含 `tran 100n 200u uic` 关键字；可选加 `.ic v(xdut.yg)=1.8 v(vref)=0 v(xdut.na)=0 v(xdut.nb)=0` 显式 force 零初值

### Mode 5: VDD ramp 太快导致 false-fail

**症状**：tb_startup tran VDD 上升 < 100 ns 就稳到 1.8V → Vref 没 startup 起来；但实际 silicon VDD 经 LDO/regulator 上升慢，startup 正常

**根因**：超快 VDD edge 把 startup 卡在 nonlinear region 没充足时间让 MN_KICK 工作

**修复**：tb_startup VDD ramp 时间 ≥ 1 µs（典型 silicon VDD 上升时间），不要追求 step-up

### Mode 6: 大电容引入破坏启动（PSRR 改进的最常见副作用）

> ⭐ **Demo 01 v6 实证教训** — 为改善 PSRR 加 Cac=100nF 到偏置节点 → 启动时间常数 10ms，远超 200µs 仿真窗口，stuck-at-zero。浪费 ~30 turn。

**症状**：加大电容（≥ 1nF）后 tb_startup tran 失败 / Vref ramp 不到位 / DC OP 假阳性但 tran 起不来

**物理因果**：

```
失效路径：大电容 C 连接到偏置节点 X（X 接 VDD 或 VSS）

上电瞬间（VDD 0 → 1.8V，约 1µs）：
  C 耦合作用：X 跟随 VDD 从 0 爬升 → X ≈ VDD

等 VDD 稳定后，X 需要从 VDD 下降到 DC 工作点（例 vbpc_p ≈ 0.57V）：
  放电时间常数：τ = C / gm_diode

@ C = 100nF, gm_diode ≈ 10 µA/V → 1/gm = 100kΩ：
  τ = 100nF × 100kΩ = 10 ms  ← 远超 200µs 仿真窗口！

在 τ 期间所有依赖 X 的器件都处于错误偏置点：
- Cac on vbpc_p → vbpc_p ≈ VDD → MP1C/2C/3C 的 Vsg=0 → cascode 全关
- Cbp_vdd on bp → bp ≈ VDD → M_TAIL Vsg=0，M_LOAD Vsg=0 → OTA 解偏置
```

**启动安全准则**：

```
任何偏置节点的电容必须满足：C / gm_load << t_startup_budget

@ t_startup = 100µs, gm ≈ 10µA/V:
  C << 100µs × 10µA/V = 1nF

安全范围：C < 10pF（给 10× margin）
  ↑ 与片内电容上限 ~50pF 自然吻合（physical-constraints.md § 1）
```

**修复优先级**：
1. **首选**：电容值减到 < 10pF（同时也满足片内可行性）
2. 次选：把电容连到 VSS 而非 VDD（避免上电跟踪 VDD —— 见 troubleshooting.md Mode 13）
3. 末选：拒绝该 PSRR 改进路径，回头改拓扑（cascoded mirror / beta-multiplier 自偏置）

**Iron Law**：**任何 ≥ 1pF 的电容改动后必须跑 tb_startup tran 验证**，不验等于没改。

## 验证清单

- [ ] tb_startup.sp 含 `tran ... uic`（避 Failure mode 4）
- [ ] VDD ramp ≥ 1 µs（避 Failure mode 5）
- [ ] tb_startup tran 后 `vref_settled > 0.95 × Vref_target`
- [ ] `t_vref_90 < 50 µs`（典型 spec）
- [ ] `vref_max < 1.5 × Vref_target`（无大 overshoot）
- [ ] DC op 验证 `V(v_sens) < 0.1V`（MN_KICK 完全 off，避 Failure mode 3）
- [ ] PSRR 测试有跑（避 Mode 3 漏电流隐患）
- [ ] PVT corner（FF/SS/-40/125°C）跑 tb_startup（startup margin 全 corner 检查）

## 常见 startup 误区

| 心里想 | 现实 |
|---|---|
| "DC `op` Vref = 1.19V 就 OK" | DC solver 可能收敛到 non-zero 解；real silicon 仍可能 stuck 或启动不可靠，必须跑 startup tran |
| "加大 W_KICK 总能修 startup fail" | W_KICK 过大引起 startup oscillation（Mode 2）|
| "R_START 越小 startup 越快" | R_START < 200 kΩ 让 MN_SENS 持续导通，DC PSRR 退化（Mode 3）|
| "tb_startup 跑 DC ramp 几 ns 就行" | 超快 VDD edge 让 startup 卡在 nonlinear（Mode 5）|
| "self-biased OTA 内部 R_BIAS+M_BIAS 也 startup" | 自偏置 OTA 同样有 zero-current latch；OTA 自己也需 startup pumper（V3 用 R_BIAS = 2 MΩ 通过 leakage / sub-Vth current 慢启动）|

## 不在本章范围

- **β-multiplier 双稳态物理推导**（数学证明 zero-current 稳态条件）→ `blocks/base-cells/bias-generator/beta-multiplier`
- **startup-helper 拓扑物理细节**（M_kick 弱 PMOS / detector NMOS / 自禁用机制）→ `blocks/base-cells/bias-generator/startup-helper`
- **PNP first-order Brokaw 完整网表 + 4 testbench**（dc/startup/tc/psrr）→ `chapter=reference-design`
- **OTA polarity / oversize / 外环 oscillation pitfall** → `chapter=architecture`
- **CMOS sub-1V Banba startup**（不同 helper 拓扑）→ 另起 sub-1V variant chapter（W7+ 视需要）
- **Chopper-stabilized startup**（chopper clock + bandgap 复合 startup 序列）→ 高精度 reference 专门 knowledge
- **Resistor TC sweep / curvature 补偿** → `chapter=architecture` § zero-TC 条件 + 主机侧分析脚本
