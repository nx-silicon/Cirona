---
type: knowledge
domain: circuit
name: common-source
version: 1.0
summary: |
  Common-source（共源单管放大器）：基础 CS + source-degenerated 线性化变体。
  模拟电路最基础的电压放大单元。
chapters:
  - name: basic
    summary: 基础 CS 放大器（电阻负载 / active load）+ Av / 主极点 / Miller 因果
    tokens: ~600
  - name: source-degenerated
    summary: 源极退化线性化（gm_eff = gm/(1+gm·Rs)）单管 gm cell
    tokens: ~500
    status: pending
  - name: troubleshooting
    summary: 增益不达标 / Miller 主极点漂移 / 大信号失真 三类对照
    tokens: ~400

trigger:
  explicit:
    user_selected_pack: common-source
  implicit:
    keywords:
      - common source
      - 共源
      - 单管放大器
      - CS amplifier
    circuit_dependency_of:
      - blocks/ldo
      - blocks/two-stage-ota
      - blocks/lna

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
  knowledge:
    - blocks/base-cells/active-load
    - blocks/base-cells/resistive-load
    - blocks/base-cells/miller-compensation
    - blocks/base-cells/cascode
  tools:
    - simulate
    - dc_snapshot
    - op_point_check

hierarchy: base-cell
authors: ["cirona team"]
---

# Common-Source（共源单管放大器）

## Quick Facts

- **核心机制**：单管 NMOS/PMOS，gate=输入 / drain=输出 / source=接 vss(NMOS) 或 vdd(PMOS)
- **Av 公式**：Av = -gm × (ro ‖ Rload)
  - 电阻负载（Rload=R）：Av ≈ -gm·R
  - active load（Rload=ro_load）：Av ≈ -gm·(ro ‖ ro_load) = -gm·ro/2 量级
  - cascode load：Av 大幅提升（用 cascode cell 包装）
- **没有 cascode → Rout = ro 量级**（vs cascode 的 gm·ro²）
- **Miller capacitance Cgd × (1+|Av|)** 在**输入端**形成大等效 cap：Cin ≈ Cgs + Cgd·(1+|Av|)
- **输出端等效 cap**：Cout ≈ Cload + Cgd·(1+1/|Av|)（Miller 倍增在输入端，输出端只回看小项）
- **主极点**（典型）：输出节点 fp1 = 1/(2π·Rout·Cout)；驱动源 Rs 大时输入极点 fp_in = 1/(2π·Rs·Cin) 也可能成主
- **应用**：LDO EA 第二级（双级 EA）/ 两级 OTA 第二级 / LNA / TIA 后级

## Cheatsheet

| 量 | 公式 / 范围 | 备注 |
|---|---|---|
| Av (with active load) | -gm × (ro ‖ ro_load) | typical 30-50 dB |
| Av (with R load) | -gm × R | 受 R 面积 + 噪声限制，typical 5-20 dB |
| Rout | ro ‖ Rload | active load 时 ≈ ro |
| f_3dB（小信号）| 1/(2π·Rout·Cload) | 主极点 |
| C_in_eq（Miller） | Cgs + Cgd × (1+|Av|) | Av 越大输入端 cap 越大 |
| Vds_min | Vov | sat 边界 |
| Vds_max | VDD - Vov_load - margin | swing 上限 |

## When to load

- 设计 LDO / OTA 的第二级单管放大器
- 设计 LNA / TIA 的后级电压放大
- 评估单管 CS vs cascode 的 trade-off

## When NOT to load

- 需要高 Rout（GΩ 量级）→ 用 `blocks/base-cells/cascode`
- 差分输入 → 用 `blocks/base-cells/differential-pair`
- 输出 buffer（低 Rout）→ 用 `blocks/base-cells/source-follower`

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `basic` | 基础 CS 放大器 sizing | ~600 | ✅ Week 2 |
| `source-degenerated` | 单端 gm cell 线性化 | ~500 | ⏳ Week 3 |
| `troubleshooting` | 增益不达标 / Miller 主极点 / 大信号失真 | ~400 | ✅ Week 2 |

## Related

- **Skill `circuit-method/device-sizing`** —— gm/Id sizing CS 输出级
- **Knowledge `blocks/base-cells/active-load`** —— CS load 的三种选择对照
- **Knowledge `blocks/base-cells/miller-compensation`** —— Cgd Miller 倍增 + 补偿
- **Knowledge `blocks/base-cells/cascode`** —— CS 上加 cascode 大幅提升 Av

## 不属于本 knowledge 范围

- **active load 内部物理**——见 `blocks/base-cells/active-load`
- **cascoded CS（高增益）**——见 `blocks/base-cells/cascode`
- **Miller 补偿在多级运放中应用**——见 `blocks/base-cells/miller-compensation`
- **完整 OTA / LDO 设计**——见 `blocks/ota-*` / `blocks/ldo`
