---
type: knowledge
domain: circuit
name: bandgap
version: 1.0
summary: |
  Bandgap reference 系统级设计知识：4 种主流拓扑（PNP first-order Brokaw /
  CMOS sub-1V Banba/DRO / curvature-corrected second-order / chopper-stabilized）
  选择 + zero-TC 条件 + sizing pitfalls + Brokaw 标准 reference netlist + startup
  行为专章。物理推导（β-multiplier 双稳态 / startup-helper 拓扑）见
  `blocks/base-cells/bias-generator/`，本 knowledge 关注系统级拓扑选型与 PNP
  first-order 完整设计闭环。

chapters:
  - name: architecture
    summary: 4 拓扑变体（PNP first-order / CMOS sub-1V / curvature-corrected / chopper）+ zero-TC 条件 R2/R1≈12 for N=8 推导 + 7 sizing pitfalls
    tokens: ~1700
  - name: sizing-typical
    summary: spec → device 因果 + ⭐ 4-step recipe（N → I_PTAT → R1 → R2 zero-TC 比例 → R_OUT → mirror）+ OTA / startup / compensation 平行 sizing + @vpdk180nm 起点表 + ⭐ PDK 实测 dVbe/dT 操作步骤（v6 实证）
    tokens: ~1500
  - name: startup
    summary: ⭐ 灵魂章 — Two DC operating solutions（zero-current latch / biased）+ R_START + MN_SENS + MN_KICK helper + tb_startup .ic/uic 模板 + 6 类 startup failure modes（含 v6 大电容破启动）
    tokens: ~1200
  - name: loop-stability
    summary: 外环 AC 稳定性 — yg / mirror / na/nb / vref 多极点分布 + OTA Miller + 外环 Ccomp **双重补偿铁律** + tb_psrr / tb_loop_ac 模板 + 3 失稳调整范例 + PSRR 上限随偏置拓扑变（v6 实证 37dB）
    tokens: ~1500
  - name: troubleshooting
    summary: 13 类失败模式（Vref polarity / OTA lock / TC / PSRR / startup / 外环 ringing / mismatch / OTA oversize / NMOS-input tail / Cac 方向反）+ 推荐诊断顺序 + 根因表
    tokens: ~1800
  - name: reference-design
    summary: Verified PNP first-order Brokaw bandgap reference + standard cir/tb 路径 + sizing 起点 + OTA polarity 实战教训（V3 efb0fa3）+ ⭐ Step 0 spec 可行性自检
    tokens: ~1200
  - name: physical-constraints
    summary: ⭐ 横切补丁（v6 实战盲区）— 片内 C/R 量级铁律 / AC 接地方向哲学 / 工艺常数实测必备清单 / 启动时间 vs 电容耦合
    tokens: ~600

trigger:
  explicit:
    user_selected_pack: bandgap
  implicit:
    keywords:
      - bandgap
      - 带隙
      - 带隙基准
      - 基准源
      - 电压基准
      - bandgap reference
      - BGR
      - band gap
      - voltage reference
      - Vref
      - PTAT
      - CTAT
      - Brokaw
      - Banba
      - sub-1V bandgap
      - 子 1V 带隙
      - 亚 1V 带隙
      - 低压带隙
    keywords_debug:
      - startup failure
      - 启动失败
      - 上电不启动
      - 起不来
      - stuck at zero
      - zero-current latch
      - 零电流锁死
      - Vref out of range
      - Vref 漂
      - TC out of spec
      - TC 不达标
      - 温漂过大
      - PSRR 偏低 (bandgap)
      - OTA lock failure
      - na nb 不锁
      - Vref 振荡
    circuit_dependency_of:
      - blocks/ldo                 # Vref 来源
      - blocks/pmic                # 电源管理
      - systems/sar-adc            # 内部 Vref
      - systems/adc-pipeline

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
    - meta-cognitive/systematic-debugging
    - meta-cognitive/verification-before-completion
  knowledge:
    - blocks/base-cells/bias-generator       # startup-helper + beta-multiplier 物理推导
    - blocks/base-cells/differential-pair    # OTA input pair
    - blocks/base-cells/current-mirror       # PMOS mirror leg matching
    - blocks/base-cells/cascode              # PSRR > 70 dB 的 mirror cascode 升级
    - blocks/5t-ota                          # bandgap loop 内 5T-OTA
    - simulators/ngspice
    - pdks/vpdk180nm                         # PNP primitive 来源
  tools:
    - simulate
    - dc_snapshot
    - op_point_check
    - causal_trace
    - expectation_compare

hierarchy: block
applicable_pdks: any                          # 拓扑跨工艺；PNP 可用性见下
applicable_simulators: [ngspice, hspice, spectre]
authors: ["cirona team"]
---

# Bandgap Reference 设计知识

## Quick Facts

- Bandgap = PTAT (ΔVbe/R) + CTAT (Vbe/R) 求和 → ~1.2V 与温度无关 reference
- **zero-TC 条件**（PNP first-order）：`R2/R1 ≈ Vbe_slope / (ln(N)·k/q)` ≈ 12 for N=8（推导见 architecture）
- **拓扑两轴**：BJT vs CMOS-only（PNP 可用性）+ first-order vs curvature-corrected（TC budget）
- **PNP first-order 默认**（vpdk180nm 1:8 PNP + 2-stage PMOS-input OTA + Miller comp + startup branch / Vref ≈ 1.19V）
- **CMOS sub-1V Banba/DRO**（VDD < 1.6V）/ **Curvature-corrected**（TC < 20 ppm/°C）/ **Chopper**（TC < 10 ppm/°C）三种升级方向
- **关键陷阱：双稳态解** — DC `op` 跳到非零解但 silicon 可能 stuck 在 zero-current → **必须 tb_startup tran + uic 验证**
- **关键陷阱：OTA polarity** — 正负输入接错 → DC latch 错误分支不报错，只看 Vref 绝对值能发现（V3 efb0fa3 教训）
- **PNP 可用性**：vpdk180nm/130nm 有 vertical PNP；< 65nm 通常无 BJT 必切 CMOS sub-1V

## ⭐ Spec Ceiling Table（拓扑能力上限 — 设计前必查）

> **Iron Law**：开始 sizing 前，**必须**对账目标 spec 与本表。任何 spec 超过对应拓扑的 ceiling →
> 不能靠 trim/sizing 救，必须 **declare hypothesis（说明假设）或换拓扑**。
> Demo 01 v6 在 R_BIAS+NMOS-diode 偏置下追逐 60dB PSRR（拓扑上限 37dB），浪费 50+ turn。

| Spec | first-order Brokaw (non-cascoded) | + cascoded mirror | beta-multiplier 自偏置 | curvature-corrected | chopper-stabilized |
|---|---|---|---|---|---|
| **Vref @ 27°C** | 1.15 - 1.25 V | 同 | 同 | 同 | 同 |
| **TC（first-order 物理上限）** | 30 - 80 ppm/°C | 同 | 同 | **< 20 ppm/°C** | **< 10 ppm/°C** |
| **PSRR @ DC**（R_BIAS+NMOS-diode OTA, v6 实证）| **37 - 45 dB** | 45 - 55 dB | 60 - 70 dB | 60 - 70 dB | 70 - 80 dB |
| **PSRR @ 1kHz** | 同 DC ±5 dB | 同 | 同 | 同 | 同 |
| **PSRR @ 1MHz** | 30 - 50 dB | 40 - 55 dB | 50 - 65 dB | 50 - 65 dB | 60 - 70 dB |
| **VDD min** | 1.5 V | 1.5 V | 1.5 V | 1.8 V | 1.8 V |
| **Iq** | 25 - 40 µA | 30 - 50 µA | 30 - 50 µA | 30 - 60 µA | 50 - 100 µA |
| **CMOS Banba（VDD < 1.6V）**| Vref 0.6 - 0.8 V / TC 50-150 ppm/°C | — | — | — | — |

**spec → 必选拓扑路径**：
```
spec PSRR ≤ 40 dB         → first-order baseline OK（R_BIAS+NMOS-diode OTA）
spec PSRR 40-50 dB        → + PMOS mirror cascode
spec PSRR 50-65 dB        → 改 beta-multiplier 自偏置 OTA（架构重设计）
spec PSRR > 65 dB         → 上述 + cascoded everywhere；> 70 dB 必须 post-LDO 二级
spec TC < 20 ppm/°C       → 必须 curvature-corrected（first-order 物理上限 30 ppm/°C）
spec TC < 10 ppm/°C       → 必须 chopper-stabilized
spec VDD < 1.5V           → 改 CMOS Banba/DRO（PNP Brokaw VDD min 1.5V）
spec VDD < 1.0V           → 不在 bandgap 范围（用 charge-pump sub-bandgap）
```

**详细机理与设计选项**：见 `loop-stability.md` § R2 铁律 / `physical-constraints.md` § 6。

---

## Cheatsheet（典型 spec @ vpdk180nm，VDD=1.8V，PNP first-order）

| Spec | 典型范围 | 影响因素 |
|---|---|---|
| Vref @ 27°C | 1.15 – 1.25 V | (I_PTAT + I_CTAT) × R_OUT |
| TC（first-order） | 30 – 80 ppm/°C with resistor TC / curvature controlled；V3 baseline 346 ppm/°C | R2/R1 比例 + resistor TC + BJT curvature |
| PSRR @ DC | 35 – 45 dB（V3 non-cascoded baseline）/ 60 – 70+ dB（high-ro / cascoded variant）| supply feedthrough through PMOS mirror, reduced by mirror ro × OTA loop gain |
| PSRR @ 1 MHz | 30 – 50 dB | OTA dominant pole |
| Iq | 25 – 40 µA | 3 mirror legs + OTA bias + startup |
| Startup t_90 | < 50 µs @ 1 µs VDD ramp | W_KICK / R_START |
| Line reg | 1 – 5 mV/V @ 1.5–1.9V | OTA gain × mirror ro |
| PNP area ratio N | 4 – 24（默认 8）| ΔVbe = VT·ln(N) |

| 拓扑 | Vref @ 27°C | VDD min | 典型 TC | 是否需 BJT |
|---|---|---|---|---|
| **PNP first-order Brokaw** | 1.19 V | 1.5 V | 30–80 ppm/°C | ✅（vertical PNP）|
| **CMOS sub-1V Banba/DRO** | 0.6 – 0.8 V | 1.0 V | 50–150 ppm/°C | ❌ |
| **Curvature-corrected** | 1.20 V | 1.8 V | < 20 ppm/°C | ✅ |
| **Chopper-stabilized** | 1.20 V | 1.8 V | < 10 ppm/°C | ✅ |

## When to load this knowledge

- 用户提到"做带隙" / "bandgap" / "Vref" / "voltage reference" / "BGR"
- 设计 LDO / PMIC / ADC 需要内部 Vref（bandgap 是子模块）
- 调试 startup failure / Vref 漂 / TC 不达标 / PSRR 偏低 / OTA 不锁
- 用户提到 PNP 1:8 / Brokaw / PTAT/CTAT / zero-TC

## When NOT to load

- 用户问的是 LDO / PMIC 主体（仅子模块 Vref 时才借 bandgap knowledge）→ 用 `blocks/ldo`
- VDD < 1.0V → 必须 sub-bandgap charge-pump 或专门 ULP 拓扑（超出本 knowledge）
- 工艺无 BJT 且 VDD ≥ 1.8V → 仍可用 CMOS sub-1V 但 first-order 拓扑限制（见 `chapter=architecture` § CMOS sub-1V）

## Chapter Index

| Chapter | 何时加载 | Mandatory by stage | tokens | 状态 |
|---|---|---|---|---|
| `architecture` | 选拓扑 / 评估 4 变体 / OTA polarity 选型 | 架构必读 | ~1700 | ✅ |
| `sizing-typical` | 4-step recipe + 起点表 + PDK 实测 dVbe/dT | sizing 阶段必读 | ~1500 | ✅ |
| **`startup`** ⭐ | **任何 bandgap 设计必读**（双稳态解物理 + tb_startup .ic/uic 必备 + 6 modes）| **DC + tran 阶段都必读** | ~1200 | ✅ |
| `loop-stability` | 外环 AC PM / Miller + Ccomp 双重补偿 / PSRR / PSRR 上限随偏置拓扑变 | tran ringing / PSRR debug 必读 | ~1500 | ✅ |
| `troubleshooting` | Vref / TC / PSRR / startup / ringing 任一 FAIL（13 modes 含 Cac 方向反）| Debug 必读 | ~1800 | ✅ |
| **`reference-design`** | **写 bandgap .cir 之前必读 + Step 0 spec 自检** | 网表生成阶段必读 | ~1200 | ✅ |
| **`physical-constraints`** ⭐ | **改电容/改 PSRR 前必读**（片内 C 上限 / AC 接地 / 工艺常数实测）| spec 自检 + 改 C/R 前必读 | ~600 | ✅ |

### Stage-driven mandatory loading

| 阶段 | 必读 chapters |
|---|---|
| 架构筛选 | `architecture` + 子模块 `blocks/5t-ota` |
| **Sizing**（4-step recipe）| `sizing-typical` + `architecture` § zero-TC + **`pdks/<project_pdk>/index`** |
| **网表 + DC OP** | **`reference-design`** + **`pdks/<project_pdk>/index`** + **`simulators/ngspice/index`** |
| **Startup tran**（必做）| **`startup`** + `blocks/base-cells/bias-generator/startup-helper` + `simulators/ngspice/analyses` |
| TC sweep / PSRR AC | `reference-design` § tb_tc_sweep / tb_psrr + `loop-stability` |
| **Debug（任何 FAIL）** | `troubleshooting` 推荐诊断顺序 + 对应失败模式 |

> ⚠️ **强制约定（bandgap 特有）**：
> 1. **DC `op` 不能证明 startup**——必须跑 `tb_startup.sp` with `.ic` + `tran ... uic`
> 2. **OTA polarity 必查**：Vref ≈ 1.2V 不代表 polarity 对——需查 `V(na) ≈ V(nb)` lock-error < 1 mV
> 3. **双重补偿铁律**：OTA 内 Miller + 外环 yg cap Ccomp 必须同时配（`loop-stability.md`）
> 4. 加载本 knowledge 时**默认同时加载** `blocks/base-cells/bias-generator/startup-helper`

## Related

- **`blocks/base-cells/bias-generator`** — startup 物理 + β-multiplier 双稳态 source of truth
- **`blocks/base-cells/differential-pair`** — OTA input pair（PMOS @ Vbe ≈ 0.65V CM）
- **`blocks/base-cells/current-mirror`** — 3-leg matching；cascoded variant for PSRR > 70 dB
- **`blocks/5t-ota`** — bandgap loop 内 OTA 设计
- **Skill `bias-tree-reasoning` / `signal-tracing`** — 自偏置环路 + 反推

## 不属于本 knowledge 范围

- **β-multiplier 双稳态物理 + startup-helper 拓扑细节** → `blocks/base-cells/bias-generator/{beta-multiplier, startup-helper}`
- **OTA 5T sizing** → `blocks/5t-ota`；**Miller 补偿原理** → `blocks/base-cells/miller-compensation`
- **chopper / curvature-corrected 详细电路** → 不在本 first-order 范围
- **VDD < 1.0V ULP bandgap** + **完整 PMIC** → 专门 knowledge / W8+
- **Resistor TC modeling**（poly-R ±500 ppm/°C）→ PDK reference
