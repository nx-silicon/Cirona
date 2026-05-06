---
chapter: gain-boosted
parent: cascode
summary: |
  Gain-boosted cascode：内嵌 local OTA 把内节点 Vx 钉到目标值，
  Rout 由 gm·ro² 量级再提升 A_local 倍到 (gm·ro)²·ro / 用于 Av ≥ 100 dB 高精度场景
tokens: ~700
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/device-sizing
  - circuit-method/ac-feedback-loop-method
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/bias-generator
  - blocks/base-cells/differential-pair
---

# Gain-boosted Cascode

## 拓扑（基础 cascode + 内嵌 local OTA）

```
            Vout
              │
            ┌─┴─┐
       Vy─→│M_casc│      ← cascode 上管，gate 由 local OTA 输出驱动
            └─┬─┘
              │ Vx (内节点，被 local OTA 钉住)
              │           ┌─────────────┐
              ●──────────→│  −          │
                          │  local OTA  ├──→ Vy
              ●──────────→│  +          │
              │           └─────────────┘
              │           参考点 V_ref ≈ Vov_lower + margin
            ┌─┴─┐
            │M_lower│
            └─┬─┘
            Vss / 下方电流源
```

**核心机制**（基础 cascode 的"feedback 加强版"）：
- local OTA 比较 Vx 与 V_ref（设计目标的 Vds_lower）
- 偏差 → local OTA 输出 Vy 调节 M_casc 的 Vgs
- → M_casc 的 Vds 自适应吸收 Vout 摆动 → Vx **几乎绝对不动**
- → M_lower 看到 ∂Vds/∂Vout ≈ 0 / (1+A_local) → 等效 ro_lower 被放大 (1+A_local) 倍

**与基础 cascode 的区别**：
- 基础 cascode 屏蔽因子 = (1 + gm_casc·ro_casc) ≈ gm·ro（~100×）
- gain-boosted cascode 屏蔽因子 = (1 + gm_casc·ro_casc)·(1 + A_local) ≈ gm·ro·A_local（~10000×）
- → Rout 公式：`Rout ≈ gm_casc · ro_casc · ro_lower · A_local`

## 小信号公式

### Rout 提升

```
Rout_basic       ≈ gm_casc · ro_casc · ro_lower      （量级 10-100 MΩ）
Rout_gain_boost  ≈ gm_casc · ro_casc · ro_lower · A_local
                 ≈ Rout_basic · A_local              （量级 1-100 GΩ）
```

A_local（local OTA 增益）典型 30-50 dB（30-300×）。**不需要更高**——local OTA 太高 gain 反而稳定性恶化（见下）。

### Av 应用（telescopic OTA gain-boosted 双侧）

```
Av_total = gm_M1 · (Rout_load ‖ Rout_drv)
        ≈ gm_M1 · 0.5·Rout_per_side
```

| 工艺 / 配置 | Av 典型 |
|---|---|
| 180nm / 主路 4×Lmin / A_local = 35 dB | 100-110 dB |
| 65nm / 同 sizing | 80-90 dB |

**典型应用**：高精度 ADC / 数据转换器 EA / 仪表放大器——任何 Av ≥ 100 dB 场景。低于 80 dB 用基础 cascode 即可，不必上 gain-boosted（local OTA 是面积 + 功耗 + 复杂度代价）。

## 稳定性（关键约束 ⚠️）

Gain-boosted 是**双环路系统**：local 环（OTA → M_casc → Vx → OTA 输入）+ main 环（主级 OTA 反馈）。

**Iron rule**：local 环 GBW 必须 **远高于** main 环 GBW（典型 5-10×），否则 local 环未稳定时 main 环已开始动作，互相干扰 → 主路 PM 崩。

| 量 | 推荐 | 因果 |
|---|---|---|
| GBW_local / GBW_main | 5-10× | local 必须比 main "快" |
| local OTA PM | ≥ 60° | 自身稳定（避免 ringing 进 main 环）|
| local OTA gain A_local | 30-50 dB | 太高 → GBW 受限于内部极点 → 难满足 5×GBW_main |

**因果链**：local OTA gain ↑ → local 环 GBW 受 OTA 自身极点限制 → GBW_local 反而下降 → 不再 ≫ GBW_main → 主路稳定性恶化。**不要为了 Rout 拼命堆 A_local**。

## Local OTA 拓扑选择

| local OTA 拓扑 | 适用 | 不选的理由 |
|---|---|---|
| **5T 单端 OTA**（默认）| 大部分场景 | gain 30-40 dB / GBW 几 MHz / 简单 | （首选）|
| FC（单端）| GBW 紧张时 | swing 大 / GBW 高 | 面积 / 功耗 ↑ |
| Telescopic（单端）| 极高精度 | gain 60+ dB | swing 紧 / 复杂 |
| 全差分 | 想消 systematic offset | matching 完美 | 双倍面积，gain-boosted 收益有限 |

**绝大多数 gain-boosted cascode 用 5T 单端**。

## Body Effect 提醒

cascode 高位管 M_casc：source = Vx ≠ ground/VDD（VSB > 0）。

```
Vth_eff(M_casc) = Vth0 + γ(√(2ΦF + VSB) - √(2ΦF))   # body effect
```

@ 180nm γ ≈ 0.4 V^0.5：VSB = 0.25 V（典型 Vx）→ Vth 升 ~80 mV → Vov_casc 减 80 mV → gm_casc / Rout 都受影响。

local OTA 设计时**必须把 body effect 算进去**：`V_ref` 的本质是 `M_lower.Vds` 目标，主要由 `Vov_lower + PVT/sat margin` 决定（而非直接加 body effect 漂移）；`M_casc` 的 body effect 主要体现在所需 Vy、local OTA 输出摆幅和 headroom 上——**两个分开看**，不要把 M_casc 的 body 漂硬塞进 V_ref 公式。

## sizing 关系

| 量 | 推荐范围 | 因果 |
|---|---|---|
| M_lower W/L / Vov | 同基础 cascode | 主级电流 + transconductance |
| M_casc W/L | 与 M_lower 同（first-pass） | 同 Id / 同 Vov 起点；可后调 |
| L_M_casc | 4-8 × Lmin | matching + ro_casc 量级 |
| **A_local（local OTA gain）** | **30-50 dB** | 太低没收益 / 太高稳定性差 |
| **GBW_local** | **5-10 × GBW_main** | 双环路稳定性硬约束 |
| local OTA Iq | per-booster ≈ 5-15% × 对应支路电流；telescopic 4 个 booster 合计常 15-30% × main total | per-booster 与 total budget 分开看 |
| V_ref（local OTA 输入参考）| Vov_lower + 50-100 mV PVT/sat margin | 让 M_lower 安全 sat；M_casc body 影响放在 Vy/headroom 检查段单独算 |
| local OTA PM | ≥ 60° | 防 ringing |

## sizing 范例（telescopic OTA gain-boosted load，target Av = 100 dB）

> 📌 **@ vpdk180nm**（μn/p·Cox / Vth / VA / γ 数值参考 `pdks/vpdk180nm/index.md`）。换工艺需重算所有数值；公式形式（Rout = gm·ro·ro·A_local 等）跨工艺通用。

设计目标：Av_total = 100 dB / Itail_main = 20 µA / VDD = 1.8 V / GBW_main = 5 MHz

```
主路（M_lower / M_casc）sizing: 同基础 cascode 范例（详见 basic.md）
  Id_per_side = 10 µA
  M_lower / M_casc 同 W/L: W ≈ 2 µm, L = 1 µm, Vov = 0.2 V, gm = 100 µS
  ro_casc = ro_lower = VA·L/Id = 10 × 1 / 10µ = 1 MΩ
  Rout_basic = gm_casc·ro_casc·ro_lower = 100µ × 1M × 1M = 100 MΩ
  基础 cascode 双侧并联：Rout_eff_basic ≈ 50 MΩ → Av_basic ≈ 130µS × 50MΩ ≈ 6500 ≈ 76 dB

A_local 选择:
  目标 Rout_per_side = Rout_basic × A_local = 100 MΩ × A_local
  双侧并联 Rout_eff = 50 MΩ × A_local
  Av_total ≈ gm_M1 × Rout_eff = 130µS × 50MΩ × A_local = 6500 × A_local
  100 dB = 1e5 V/V → A_local 需要 ≈ 1e5 / 6500 ≈ 15.4 → 24 dB
  考虑 ro 二阶 / Cgd / 寄生折损 5-15 dB → 选 A_local = 35-40 dB（留 10-15 dB margin）

local OTA（5T 单端）spec:
  - A_local = 35 dB（约 60×）
  - GBW_local ≥ 5 × GBW_main = 25 MHz
  - PM_local ≥ 60°
  - Iq_local = 1-2 µA per booster（telescopic 双侧 NMOS/PMOS cascode 共 4 个 booster
    → 4-8 µA total，约 main 路 20 µA 的 20-40%；功耗紧时降 per-booster 或减少 boost 覆盖）

V_ref 设计（M_lower.Vds 目标）:
  Vov_lower = 0.2 V
  PVT + sat margin ≈ 50-100 mV
  → V_ref ≈ 0.25-0.30 V（让 Vx ≥ Vov_lower + margin，M_lower 安全 sat）
  V_ref 由 bias_generator 的 padding device 跟踪生成（不用理想源）

M_casc body effect / Vy headroom 检查（独立步骤）:
  M_casc source = Vx ≈ 0.25 V → VSB ≈ 0.25 V
  Vth_eff_M_casc 抬 ≈ 50 mV（@ 180nm γ）→ Vgs_M_casc 需相应抬
  → 验证 local OTA 输出 Vy 仍在合理范围（NMOS cascode：Vy ≤ VDD - margin；
    PMOS cascode：Vy ≥ VSS + margin），不撞 rail 即 OK

验证 Rout（A_local = 60，约 35.6 dB）:
  Rout_per_side = 100 MΩ × 60 = 6 GΩ
  双侧并联（telescopic load + drv 同对）→ Rout_eff ≈ 3 GΩ
  Av_total = 130 µS × 3 GΩ ≈ 4e5 V/V → 112 dB（理论上限）
  实际 ro 二阶 / Cgd / 寄生 → 100-110 dB（仍达 spec，留 10 dB margin）

swing:
  V_out_max = VDD - 2×|Vov_p| ≈ 1.8 - 0.4 = 1.4V
  V_out_min = 2×Vov_n ≈ 0.4V → swing PP 1.0V（够典型 ADC 输入）
```

## 验证清单

- [ ] dc_snapshot：M_lower / M_casc 都 saturation；Vx ≈ V_ref（local OTA 锁定证据）
- [ ] dc_snapshot：local OTA 输出 Vy 在对应 cascode gate 合理范围（NMOS 侧查 NMOS gate / PMOS 侧查 PMOS gate；不撞 rail）
- [ ] AC（main）：Av_total ≥ spec（100 dB 级），PM_main ≥ 45°
- [ ] **AC（local 单独断环测）**：A_local 30-50 dB，GBW_local ≥ 5×GBW_main，PM_local ≥ 60°
- [ ] **Tran**：阶跃输入下输出无 ringing（双环互锁失败的典型症状）
- [ ] PVT corner：V_ref 漂 < 50 mV / M_lower.Vds 仍 ≥ Vov_lower + margin
- [ ] noise：local OTA 噪声经 (1/A_local) 衰减后对总 input-referred noise 影响 < 5%

## 常见误区（self-check）

| 心里想 | 现实 |
|---|---|
| "local OTA gain 越高越好" | 高 gain → GBW 受内部极点限制 → 难满足 5×GBW_main → 主路稳定性反而恶化 |
| "local OTA 自身稳定就行，不用断环测" | local 环 PM 必须 ≥ 60°；< 45° 时 ringing 注入主环 → 主环看似稳定实际 oscillation 边缘 |
| "V_ref = Vov_lower 就够" | PVT + sat margin 没算 → 角下 Vx < Vov_lower → M_lower triode 主增益崩；M_casc body effect 单独查 Vy headroom，不直接堆进 V_ref |
| "gain-boosted 一定比双 cascode 好" | 双 cascode 简单（无环路稳定性问题），gain-boosted 能扩 Rout 但 +local OTA 面积 / 功耗 / 设计复杂度。**Av < 90 dB 选双 cascode；Av ≥ 100 dB 选 gain-boosted** |
| "local OTA 用全差分更好" | 单端足够（gain-boosted 是给 cascode 内节点钉电压，不需差分输出）；全差分双倍面积无收益 |
| "改 local OTA W/L 直接调 A_local" | A_local 由 local OTA 拓扑 + sizing 共同决定；想改 A_local 优先调 Itail_local 或 L_input_pair，不是单改 W |

## 不在本章范围

- 基础 cascode 物理 / 因果链 / 简单 sizing → `chapter=basic`
- cascode 故障 debug → `chapter=troubleshooting`
- local OTA（5T / FC / Telescopic）拓扑细节 → `blocks/5t-ota/` / `blocks/ota-fc/` / `blocks/telescopic-ota/`
- 5T-OTA sizing → `blocks/5t-ota/sizing-typical.md`（local OTA 用 5T 时复用）
- Vbias_casc 与 V_ref 的物理生成 → `blocks/base-cells/bias-generator/`
- 主环 AC 断环方法 → skill `circuit-method/ac-feedback-loop-method`
- wide-swing cascode（不同设计目标，与 gain-boosted 互补不重叠）→ `chapter=wide-swing`（pending）
