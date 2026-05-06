---
type: knowledge
domain: circuit
name: active-load
version: 1.0
summary: |
  有源负载（active load）：用饱和 MOSFET 替代大面积电阻提供高阻负载。
  三大变体：diode-load（低 Av 宽 BW）/ mirror-load（高 Av）/ cascode-load（最高 Av，最贵 headroom）。

chapters:
  - name: diode-load
    summary: Diode-connected 作 load —— Av = -gm_drv/gm_load / 永远 sat / 宽 BW / 低 Av
    tokens: ~600
  - name: mirror-load
    summary: Current-mirror 作 load —— Av = -gm·(ro_drv‖ro_load) / Av 20-80 / Vds 调制
    tokens: ~700
  - name: cascode-load
    summary: Cascode 作 load —— Av 再 ↑ 5-20×（gm·ro²）/ 多 1×Vdsat headroom 代价
    tokens: ~600
  - name: troubleshooting
    summary: 增益塌陷（load triode）/ 差分不对称（Vds 调制）/ BW 受限 / matching 失配
    tokens: ~600

trigger:
  explicit:
    user_selected_pack: active-load
  implicit:
    keywords:
      - active load
      - 有源负载
      - diode load
      - mirror load
      - cascode load
      - PMOS load
    circuit_dependency_of:
      - blocks/5t-ota
      - blocks/ota-fc
      - blocks/telescopic-ota
      - blocks/comparator

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
  knowledge:
    - blocks/base-cells/current-mirror
    - blocks/base-cells/cascode
    - blocks/base-cells/common-source
    - blocks/base-cells/differential-pair
    - blocks/base-cells/resistive-load
  tools:
    - simulate
    - dc_snapshot
    - op_point_check

hierarchy: base-cell
applicable_pdks: any
applicable_simulators: any
authors: ["cirona team"]
---

# 有源负载（Active Load）

## Quick Facts

- **核心价值**：MOS in saturation 提供 ro = 1/(λ·Id) 高阻负载，量级 50 kΩ - 5 MΩ；面积仅是同阻值电阻的几十分之一
- **三大变体（gain-BW-headroom 三角折衷）**：
  - `diode-load`：Vgs=Vds 短接 → R_load = 1/gm（低）；Av = -gm_drv/gm_load 典型 1-5；**宽 BW**；线性度好
  - `mirror-load`：bias 独立 → R_load = ro（高）；Av = -gm_drv·(ro_drv‖ro_load) 典型 20-80；BW 受限于高阻节点 RC
  - `cascode-load`：mirror 上叠 cascode → R_load = gm_casc·ro²；Av 再 ↑ 5-20×；**多 1×Vdsat headroom**
- **diode-connected 永远 saturation**（Vds=Vgs ≥ Vth+Vov，Vds_sat=Vov < Vds=Vth+Vov）—— 严禁写"diode load 易 triode"
- **mirror load 易 triode**：M_load.Vds = VDD - Vout，Vout 高摆幅时 Vds 小 → 撞 triode；这是 Vout 节点决定，不是 mirror 自身问题
- **Vov_load 推荐 0.1-0.2V**：太小 → matching 差 + 短沟道效应让 ro 反不升；太大 → swing 损 + ro 略降
- **PMOS load 的 L 通常 > input pair L**（5T-OTA 关键决策）：noise（gm3<<gm1，被 (gm3/gm1)² 衰减）/ matching（Pelgrom）/ gds 三重收益
- **差分应用 mirror load 失配**：σ(ΔVth) ∝ 1/√(WL)；两侧 mirror load 必须共 ref（不能各自独立 bias）

## Cheatsheet（三变体对照）

| 维度 | diode-load | mirror-load | cascode-load |
|---|---|---|---|
| 小信号 R_load | 1/gm（典型 100Ω - 10kΩ）| ro（50 kΩ - 500 kΩ）| gm·ro² （1-100 MΩ）|
| Av（@ CS gain stage）| -gm_drv/gm_load（1-5）| -gm·(ro_drv‖ro_load)（20-80）| 进一步 ↑ 5-20× |
| Headroom 代价 | 1×（Vds=Vgs）| 1×Vdsat（饱和约束）| 2×Vdsat（多一层 cascode）|
| BW（@ Cload pF 级）| 高（RC 小）| 中（高阻节点）| 低（更高阻 + 更多寄生）|
| 线性度 | 好（gm 线性）| 中（ro 非线性）| 中-差 |
| 典型应用 | 共栅级输入 / 简单 buffer | 5T-OTA 主负载 | telescopic OTA / 高精度 ADC |

## When to load this knowledge

- 选 OTA 拓扑负载方式（diode vs mirror vs cascode）
- 增益不达标 / 输出 swing 紧 → debug active load
- 5T-OTA / FC-OTA / telescopic 设计涉及 PMOS load sizing

## When NOT to load

- 电阻负载（线性、4kTR noise）→ `blocks/base-cells/resistive-load`
- 镜像作为电流源（不是 load）→ `blocks/base-cells/current-mirror`
- cascode 作为增益增强（不是 load）→ `blocks/base-cells/cascode`

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `diode-load` | 简单缓冲 / 宽 BW / 低增益场景 | ~600 | ✅ |
| `mirror-load` | 单级 OTA 主负载 / Av 20-80 范围 | ~700 | ✅ |
| `cascode-load` | 高增益（>60dB） / telescopic / 高精度 ADC | ~600 | ✅ |
| `troubleshooting` | 增益塌陷 / 差分不对称 / BW 慢 / matching | ~600 | ✅ |

## Related

- Skill `circuit-method/device-sizing` —— PMOS load L > input pair L 是 noise-driven 选择
- Skill `circuit-method/signal-tracing` —— 增益不达标先反推"是 ro 不够还是 load triode"
- Knowledge `blocks/base-cells/current-mirror` —— mirror-load 复用电流镜结构
- Knowledge `blocks/base-cells/cascode` —— cascode-load 复用 cascode 结构
- Tool `dc_snapshot` + `op_point_check` —— 验证 load saturation

## 不属于本 knowledge 范围（明确划界）

- 镜像作电流源（向负载灌电流）→ `blocks/base-cells/current-mirror`
- cascode 增益增强（CS+CG）→ `blocks/base-cells/cascode`
- 电阻负载 / TIA Rf → `blocks/base-cells/resistive-load`
- gm/Id 方法 → skill `circuit-method/device-sizing`
- 完整 5T-OTA / FC / telescopic 设计 → `blocks/ota-*/`
