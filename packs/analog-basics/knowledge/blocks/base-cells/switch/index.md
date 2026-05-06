---
type: knowledge
domain: circuit
name: switch
version: 1.0
summary: |
  采样开关（switch）：MOS 时钟控开关，用于 SC 电路 / S&H / ADC 前端 / 离散时间模拟。
  三大变体：nmos-only（最简，受 Vth 限）/ transmission-gate（双向 rail-to-rail）/
  bootstrapped（线性 Ron 跨摆幅）。覆盖 charge injection / clock feedthrough / Ron 非线性。

chapters:
  - name: nmos-only
    summary: 单 NMOS 开关 —— Ron 公式 / Vth 限制 / charge injection / 适用场景
    tokens: ~600
  - name: transmission-gate
    summary: 传输门（NMOS+PMOS 并联）—— rail-to-rail 摆幅 / 复合 Ron / charge cancellation
    tokens: ~600
  - name: bootstrapped
    summary: Bootstrap 开关 —— gate 跟 source 抬高 / Ron 线性度优 / 可靠性 + 复杂度
    tokens: ~700
  - name: troubleshooting
    summary: charge injection 失配 / clock feedthrough / Ron 非线性 / 时序错误 / aperture jitter
    tokens: ~600

trigger:
  explicit:
    user_selected_pack: switch
  implicit:
    keywords:
      - sampling switch
      - 采样开关
      - transmission gate
      - 传输门
      - bootstrapped switch
      - charge injection
      - 电荷注入
      - clock feedthrough
      - aperture
    circuit_dependency_of:
      - blocks/cmfb         # SC CMFB
      - blocks/comparator-latch
      - systems/sar-adc
      - systems/adc-pipeline

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
  knowledge:
    - blocks/base-cells/cmfb         # SC CMFB 用 switch
  tools:
    - simulate
    - dc_snapshot

hierarchy: base-cell
applicable_pdks: any
applicable_simulators: any
authors: ["cirona team"]
---

# 采样开关（Sampling Switch）

## Quick Facts

- **核心作用**：用 MOS 在 ON 阶段把模拟信号连到采样电容，在 OFF 阶段把样值锁住；不只是逻辑通断，是**线性 + 时间精确 + 电荷守恒** 的模拟接口
- **Ron 公式**：NMOS `Ron = 1/(μn·Cox·(W/L)·(Vgs - Vth - Vds/2))`，仅在 Vds 小时近似 1/(μn·Cox·(W/L)·Vov)
- **Ron 随 V_in 变化**（NMOS only）：V_in 上升 → Vgs = Vclk - V_in 减小 → Ron 升高 → **线性度差**
- **三变体核心区分**：
  - `nmos-only`：最简，受 Vth 限（V_in > Vclk - Vth 时 Ron 暴涨甚至关断）
  - `transmission-gate`：N+P 并联补偿，rail-to-rail；但 charge injection 仍存在
  - `bootstrapped`：clock 高电平随 V_in 抬高 → Vgs ≈ V_clk_amplitude 恒定 → **Ron 线性**
- **charge injection**：开关关断时通道电荷 ½·Cox·W·L·(Vclk - Vth - V_in) 被注入采样节点 → 偏置电压 ΔV = Q_inj / C_sample
- **clock feedthrough**：通过 Cgd / Cgs 把 clock 边沿耦合到采样节点；ΔV = (Cov / (Cov + C_sample)) × ΔV_clk
- **aperture jitter**：clock 边沿时间不确定 → 等效于"在错的时刻采样"→ SNR 上限 = 20·log(1/(2π·f_in·σ_jitter))；@ 1 GHz / σ=1 ps → SNR 上限 44 dB
- **底板优先关断（bottom-plate sampling）**：先关 sample-side switch（让 charge 走 ground 路径）再关其他，**显著减小 charge injection 误差**（5-10×）

## Cheatsheet（三变体对照）

| 维度 | nmos-only | transmission-gate | bootstrapped |
|---|---|---|---|
| 输入摆幅 | 受 Vth 限（V_in_max ≈ Vclk - Vth）| Rail-to-rail | Rail-to-rail |
| Ron @ V_in=Vcm | 中（Vov ≈ 0.5·Vclk - Vth）| 低（N+P 并联）| 极低 + 恒定 |
| Ron 线性度（vs V_in）| **差**（变化 5-10×）| 中（N+P 互补，但仍有 1-3× 变化） | **优**（< 20% 变化）|
| 静态/瞬态 charge | Q_n（注入或抽取）| Q_n - Q_p（部分抵消）| 同 nmos-only |
| 时钟数 | 1（CK）| 2（CK + CKB）| 1 + bootstrap cap + 复杂时序 |
| 面积 | 小 | 中（多 1 PMOS）| 大（bootstrap 帮助网络）|
| 栅氧应力风险 | 低 | 低 | **高**（gate 节点可达 Vin+VDD ≈ 2×VDD，主开关 Vgs ≈ VDD 但需逐管检查 Vgs/Vgd/Vgb 防超额；常配 cascode 保护栅氧）|
| 适用 | 数字 / 简单 SC | 通用 SC / 中精度 ADC | 高精度 ADC / 高速 / 高线性 |

## When to load this knowledge

- 设计 SC 电路（SC CMFB / SC integrator / SAR ADC）
- 选 switch 拓扑（nmos vs TG vs bootstrap）
- charge injection / clock feedthrough / aperture jitter 误差预算
- 看到 SNR / SFDR 不达标且 ADC 输入摆幅大 → 怀疑 switch 线性度

## When NOT to load

- 数字开关（CMOS inverter chain）→ 数字 IO knowledge（V4 不在范围）
- 模拟 multiplexer 选择（不是采样）→ 一般 SPDT switch knowledge
- DC 切换 / power switch → power management（V4 不在范围）

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `nmos-only` | 简单 SC / 数字 / 摆幅小 | ~600 | ✅ |
| `transmission-gate` | rail-to-rail 但不需极致线性 | ~600 | ✅ |
| `bootstrapped` | 高精度 ADC / 高速 / 大摆幅线性 | ~700 | ✅ |
| `troubleshooting` | charge inj / clock feed / Ron / aperture | ~600 | ✅ |

## Related

- Skill `circuit-method/device-sizing` —— W·L 决定 Ron + charge inj，对偶 trade-off
- Skill `circuit-method/signal-tracing` —— SNR / SFDR 不对先反推 Ron / charge inj / jitter 哪个主导
- Knowledge `blocks/base-cells/cmfb` —— SC CMFB 用 switch（`switched-capacitor.md` 章节）
- Tool `simulate` (transient + .pss/.pnoise) —— charge inj 误差需 tran 仿真验证

## 不属于本 knowledge 范围（明确划界）

- 完整 ADC 设计（含 SAR / pipeline 时序）→ `systems/sar-adc` / `systems/adc-pipeline`
- SC CMFB 完整设计 → `blocks/base-cells/cmfb/switched-capacitor.md`
- 时钟生成 / non-overlapping 时序 → 数字 + clock distribution knowledge
- bootstrap 可靠性（栅氧应力 / 寄生 BJT）→ device reliability knowledge
- 离散时间噪声分析（kT/C） → `blocks/base-cells/cmfb/switched-capacitor.md` § kT/C 段
