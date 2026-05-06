---
type: knowledge
domain: circuit
name: source-follower
version: 1.0
summary: |
  Source-follower（共漏 / SF）：低输出阻抗 buffer。Av ≈ 1（< 1 因 body effect）。
  常作 LDO output buffer / level shifter / 大电流驱动级。

chapters:
  - name: basic
    summary: SF 物理 + Av 表达 + body effect + Rout=1/gm + 应用对照
    tokens: ~600
  - name: level-shift
    summary: SF 作 level shifter / bias chain 偏移 / PMOS SF 消 body effect / multi-stack / 信号路径慎用
    tokens: ~500
  - name: troubleshooting
    summary: dropout 边缘行为 / body effect Av 偏离 1 / 大电流驱动饱和
    tokens: ~400

trigger:
  explicit:
    user_selected_pack: source-follower
  implicit:
    keywords:
      - source follower
      - 共漏
      - SF
      - level shifter
      - output buffer
    circuit_dependency_of:
      - blocks/ldo
      - blocks/two-stage-ota

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/region-inspection
  knowledge:
    - blocks/base-cells/current-mirror     # SF 的 tail / sink 用 mirror
    - blocks/base-cells/common-source
  tools:
    - simulate
    - dc_snapshot

hierarchy: base-cell
authors: ["cirona team"]
---

# Source-Follower（共漏放大器）

## Quick Facts

- **核心机制**：单管 NMOS/PMOS，gate=输入 / source=输出 / drain=接 vdd(NMOS) 或 vss(PMOS)
- **Av ≈ 1**（电压跟随）—— 实际 Av_real = gm/(gm+gmb+1/Rload) < 1
- **body effect 让 Av < 1**：gmb 是 body transconductance，**约 gm/5**（NMOS 在 vsource 不接 vss 时严重）
- **Rout = 1/gm**（小，~kΩ）—— 这是 SF 最大优势，作 buffer 驱动低阻负载
- **Vsg / Vgs 始终 ≈ Vth + Vov**（不变）→ 输入到输出有 **Vth 偏移**（这是 SF 的 dropout）
- **应用**：LDO output buffer / 两级 OTA 输出级 / level shifter / 大电流驱动

## Cheatsheet

| 量 | 公式 / 范围 | 备注 |
|---|---|---|
| Av | gm / (gm + gmb + 1/Rload) ≈ 0.7-0.95 | body effect 主导误差 |
| Rout | 1 / (gm + gmb) | typical 1-100 kΩ（小） |
| dropout（Vin-Vout）| Vth_eff(VSB) + Vov | NMOS SF：VSB > 0 让 Vth_eff > Vth0；dropout 比 Vth0+Vov 还要大 50-200 mV |
| input range | depends，limited by Vth + Vov + tail headroom | NMOS SF: Vin > Vth + Vov_tail（low）|
| f_unity | gm / (2π·Cload) | 速度好（Rout 小）|
| body bias 影响 | source 不接 vss → vsb > 0 → Vth_eff 增 | 消除需 deep n-well + isolated p-well + body 接 source（标准三阱 NMOS 不适用；PMOS 在 n-well 工艺中本就可短接）|

## When to load

- 设计 LDO output buffer（驱动外部 Cload + Iload）
- 设计 OTA / EA 输出级（低 Rout）
- level shifter 设计（vin 高，vout 低 Vth_drop）

## When NOT to load

- 需要电压增益 → 用 `blocks/base-cells/common-source`
- 差分输入 → 用 `blocks/base-cells/differential-pair`
- 需要高 Rout → 用 `blocks/base-cells/cascode` 或 CS

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `basic` | SF 基础 sizing + body effect | ~600 | ✅ Week 2 |
| `level-shift` | bias chain Vth 偏移 / cascode bias 链 / NMOS pass LDO 驱动 | ~500 | ✅ Week 4 |
| `troubleshooting` | dropout / body effect / 大电流驱动 | ~400 | ✅ Week 2 |

## Related

- **Skill `circuit-method/device-sizing`** —— gm 反推 W
- **Knowledge `blocks/base-cells/current-mirror`** —— SF 的 tail current source / sink
- **Knowledge `blocks/base-cells/common-source`** —— 对照（CS 高 Rout 高增益 vs SF 低 Rout 低增益）

## 不属于本 knowledge 范围

- **PMOS pass FET as LDO output**（不是 SF，是 source 接 vdd 的特殊配置）—— 见 `blocks/ldo/architecture.md`
- **class AB output stage**（SF + 互补对）—— 见 `blocks/base-cells/output-stage`
- **完整 LDO 设计** —— 见 `blocks/ldo/`
