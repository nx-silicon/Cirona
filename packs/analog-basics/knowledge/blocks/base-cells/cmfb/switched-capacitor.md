---
chapter: switched-capacitor
parent: cmfb
summary: |
  开关电容 CMFB —— 时钟相位 / kT/C / 纹波 / 离散时间稳定性。
  适用 SC 放大器 / 离散时间积分器，零静态加载但相位敏感
tokens: ~750
prerequisite_chapters: []
related_skills:
  - circuit-method/ac-feedback-loop-method
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/switch
  - blocks/base-cells/differential-pair
---

# 开关电容 CMFB（SC CMFB）

## 拓扑结构（事实）

典型双相非交叠时钟（φ1 / φ2）实现：

```
        voutp ──┬─ S1p(φ2) ──┬── C_sense_p ──┬── S2(φ1) ── Vcm_ref
                │            │               │
              load          C_hold_p       node_ctrl_p
                │            │               │
                └─ S3(φ1) ───┘               └─→ vcmfb_ctrl ── 注入点

      （voutn 侧对称）
```

**核心机制**：
- **φ1（采样阶段）**：S2 闭合，C_sense 充电到 Vcm_ref；S3 把 C_hold 与 vcm_sense 节点连接
- **φ2（保持阶段）**：S1 闭合，C_sense 接到 vout，C_sense + C_hold 形成电容分压器，把 (vout − Vcm_ref) 转移到 vcmfb_ctrl
- **效果**：每周期把"vout 偏离 Vcm_ref 的差"以电荷形式注入控制节点 → 多周期累积调节共模

## 关键 sizing 参数（事实 + 因果）

| 参数 | 公式 / 范围 | 因果 |
|---|---|---|
| C_sense | kT / σ²_vcm（典型 100 fF - 2 pF）| kT/C 噪声决定共模精度下限：σ²_vcm = kT/C_sense |
| C_hold | 经验 ≥ 2 × C_sense（低纹波）；速度优先时 ≈ C_sense（接受较大纹波）| C_hold/C_sense ↓ → 每周期纹波幅度 ↑（不会发散，但稳态共模带 mV 级周期波动）|
| Ron_sw | < 1/(2π · fclk · 10 · C_sense)（典型 500 Ω - 5 kΩ）| 7τ 内 0.1% 建立精度 |
| fclk | ≥ 10 × BW_cmfb_target | Nyquist 裕量；fclk 太低 → 离散时间镜像 fold-back |
| A_eff | C_sense / (C_sense + C_hold + C_par) | 每周期有效增益（典型 0.3-0.5）|

**C_par**：底板寄生 + 控制节点寄生，应 ≤ 0.2 × C_sense；否则 A_eff 显著下降。

## 建立时间估算（因果链）

每周期校正 A_eff 比例的共模误差。从初始误差 ΔV_init 收敛到 1% 残差需要：
```
n = log(0.01) / log(1 - A_eff)
```

| A_eff | 1% 残差所需周期数 |
|---|---|
| 0.3 | 13 周期 |
| 0.4 | 9 周期 |
| 0.5 | 7 周期 |

例：fclk = 10 MHz / A_eff = 0.4 → 1% 建立 ≈ 9 周期 = 0.9 µs。

## 时钟相位约束（关键）

非交叠时钟必须保证：
- **φ1 / φ2 不重叠**（典型间隔 ≥ 1 ns @ 10 MHz）—— 重叠会让 S1/S2 同时导通 → vout 直接灌到 Vcm_ref，毁掉建立
- **底板切换顺序**：S2（参考侧）应**先于** S1（输出侧）断开 → 减少 charge injection 误差
- **时钟摆幅**：Vh ≥ Vth + Vov_sw + Vds_sat → Ron_sw 在规格内

## kT/C 噪声预算（事实）

每次采样在 C_sense 上保留 kT/C **采样 RMS 噪声**（不是连续谱密度）：
```
σ_vcm_sample = √(kT/C_sense)   单位：V_rms per sample
```
典型值（@ 室温 kT=4.14e-21 J）：
- C_sense = 100 fF → σ ≈ 203 µV_rms / sample
- C_sense = 1 pF → σ ≈ 64 µV_rms / sample

**因果**：精度需求 σ_vcm < 1 mV → C_sense ≥ 4 fF 即可（kT/C 限制松）。但 charge injection / clock feedthrough 通常成为更紧约束 → 实际 C_sense 取 100 fF - 2 pF（够大盖掉开关误差）。

## 离散时间稳定性

SC CMFB 等价于**离散时间一阶低通**：
```
H(z) = A_eff / (1 - (1 - A_eff) · z⁻¹)
```

- 极点 z = 1 - A_eff（在单位圆内 → 稳定）
- 但**与连续时间主 OTA 环路联合分析**时要做 z-domain → s-domain 映射
- 实操检查：仿真负载阶跃 + 时钟联合跑 → vcm_out 应单调收敛，**不应 ringing**

## EA / 比较器实现选择

SC CMFB 的"误差检测+放大"两种实现：
- **纯电容采样**（最简）：C_sense 直接采 vout，电荷转移到 vcmfb_ctrl，**无 EA 静态功耗**
- **采样 + EA 放大**：先 C_sense 采样，进入 EA 比较 → 输出驱动 vcmfb_ctrl，**EA 有静态 bias 但精度高**

| 选择 | 静态电流 | 精度 | 适用 |
|---|---|---|---|
| 纯电容 | ≈ 0（仅开关漏电）| 受 charge injection / 寄生限制（~10 mV） | 低功耗 SC 放大器 / 不需 < 1mV 共模精度 |
| 采样 + EA | I_ea bias（µA 级） | < 1 mV | 高精度积分器 / pipeline ADC 残差放大器 |

## Sizing 范例（pipeline ADC 残差 OTA 的 SC CMFB）

> 📌 **@ vpdk180nm**（μn/p·Cox / Vth / Cox 数值参考 `pdks/vpdk180nm/index.md`）。换工艺重算 C_s sizing；SC CMFB 拓扑跨工艺通用。

设计目标：
- 主 OTA GBW = 200 MHz / Itail = 200 µA
- 共模精度 < 5 mV / 3 个时钟周期内建立到 5%

**derivation chain**：
```
fclk: 100 MHz（采样率，与 ADC 同步）
BW_cmfb_target: 5 MHz（fclk / 20，远低于主 GBW 200MHz → 双环解耦）

C_sense: 取 200 fF
  - kT/C 噪声 σ = √(kT/C) = √(4.14e-21 / 200e-15) ≈ 144 µV → 远小于 5 mV 精度需求
  - 抗 charge injection 余量 ≥ 5×

C_hold: 400 fF（= 2 × C_sense）
A_eff = 200f / (200f + 400f + 50f par) ≈ 0.31

3 周期残差 = (1 - 0.31)³ = 0.33 = 33%（不足 5%）
→ 提到 5 周期：(0.69)⁵ = 16% （不足）
→ 提到 7 周期：(0.69)⁷ = 7%（不足）
→ 必须重设 C_sense / C_hold 比例

调整：把比例放宽到 C_hold = C_sense = 400 fF（A_eff ≈ 0.47，**接受更大纹波代价**）
3 周期 = (0.53)³ = 14.9%（仍不足）

→ 设计权衡：要么放宽建立时间到 5-7 周期 / 要么加 EA（先 sample 后比较，EA 增益直接消除残余）

最终方案：C_sense = C_hold = 400 fF + 7 周期建立（0.07 µs @ 100 MHz） + I_static = 0
**注意纹波代价**：C_hold = C_sense（不满足 ≥ 2×）→ 稳态会有 ~10 mV 周期纹波，需评估对下游电路的影响
```

→ Sizing 不止是套公式，还要做**时钟周期数 vs 静态功耗** trade-off。

## 验证清单

- [ ] dc_snapshot（在 φ1/φ2 各采样一次）：vcm_out 在 Vcm_ref ± 5 mV
- [ ] Tran 仿真至少 20 个时钟周期：vcm_out 单调收敛，无 ringing
- [ ] 时钟相位非重叠间隔 ≥ 1 ns（看 .meas）
- [ ] PVT corner（FF/SS）下 Ron_sw 仍满足 7τ 建立
- [ ] kT/C 噪声仿真：vcm_out 标准差与公式预测对照（误差 < 30%）

## 常见误区（self-check）

| 心里想 | 现实 |
|---|---|
| "fclk 越高越好" | fclk 高 → Ron_sw 要小 → 开关 W 大 → charge injection 大；通常 fclk = 10-50 × BW_cmfb 已够 |
| "C_hold 越大越稳" | C_hold ≫ C_sense → A_eff → 0 → 收敛极慢；2-3× 是平衡点 |
| "底板可以随便切" | 底板切换顺序错 → charge injection 不对称 → 共模残余偏移 mV 量级 |
| "SC CMFB 没静态功耗肯定省电" | 时钟驱动 + 开关 charge 损耗 = CV²f，高 fclk + 大 C 时不一定省 |
| "DC OP 一查正常就行" | DC OP 是稳态平均，掩盖了周期内纹波；必须看 tran 一个完整周期 |

## 不在本章范围

- **CT CMFB 实现**——见 chapter `continuous-time`
- **故障诊断**——见 chapter `troubleshooting`
- **开关 sizing 详细**（charge injection / clock feedthrough）——见 `blocks/base-cells/switch`
- **kT/C 噪声 RTL-level 推导**——见 `devices/bsim4` 或专门 noise knowledge
- **pipeline ADC 残差放大器整体设计**——见 `systems/adc-pipeline`
