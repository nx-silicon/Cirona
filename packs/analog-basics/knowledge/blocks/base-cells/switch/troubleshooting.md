---
chapter: troubleshooting
parent: switch
summary: |
  Switch 五大故障：charge injection 误差超预算 / clock feedthrough 大 /
  Ron 跨摆幅变化大 / 时序错（race / 重叠）/ aperture jitter 影响 SNR
tokens: ~600
prerequisite_chapters:
  - nmos-only
  - bootstrapped
related_skills:
  - circuit-method/signal-tracing
  - meta-cognitive/systematic-debugging
related_knowledge: []
---

# Switch 故障诊断

> ⚠️ **使用规则**：本章是事实对照表。**思维过程**用 skill `circuit-method/signal-tracing`
> 沿信号路径反推（"ΔV_sample 是谁注入的？Ron 失配是哪管不对？"）。

---

## 症状 1：charge injection 误差超预算（典型 ΔV_sample > LSB）

**表现**：tran 仿真采样后 V_sample 与理想值差 5-50 mV（取决于 W·L 与 C_sample）。

**物理因果**：
- Q_ch = W·L·Cox·Vov（关断时通道电荷）
- α 比例（0.4-0.6）注入采样节点
- ΔV = α·Q_ch / C_sample

**诊断**：
1. 看 W·L 和 V_clk swing → 估 Q_ch
2. 看 C_sample 大小
3. 看是否用底板优先关断（bottom-plate sampling）
4. 看是否有 dummy switch 抵消

**修复方向**（按效果排序）：

| 方法 | 减幅 | 代价 |
|---|---|---|
| **底板优先关断**（bottom-plate sampling）| 5-10× | 时序设计复杂（多 phase） |
| Dummy switch 抵消（互补关断）| 2-5× | 双 W·L 面积 + dummy clock |
| 减 W·L（同时减 charge）| ∝ W·L | Ron 升 / 建立慢 |
| 增 C_sample | ∝ 1/C | 面积大 + kT/C 改善有限 |
| Bootstrap（让 charge 与 V_signal 无关）| 不减绝对值，但变成可校准 | 复杂 + 面积 |
| 后端数字校准 | 任意 | 设计复杂 + DSP 开销 |

**❌ 不要**：
- 单纯增 W → charge inj 反增
- 用理想电流源代替 → 仿真 OK 但实际不行

---

## 症状 2：clock feedthrough 影响 V_sample

**表现**：CK 边沿后 V_sample 出现 step / glitch 形误差（边沿瞬间留下与 V_signal 近似无关的 offset，不是 ramp 形）。

**物理因果**：CK swing × Cov / (Cov + C_sample) 直接耦合。

**诊断**：tran 看 V_sample 在 CK falling edge 后的 step（与 charge inj 区分：clock feedthrough 与 V_signal 无关，charge inj 与 V_signal 弱相关）。

**修复方向**：

| 根因 | 修复 |
|---|---|
| Cov 大（W 大 / L_overlap 大）| 减 W / layout 优化减 overlap |
| C_sample 小 | 增 C_sample（同时改善 charge inj）|
| CK swing 大 | 减时钟摆幅（牺牲 Vov / Ron）|
| 单端开关 | 用 transmission-gate（CK + CKB 抵消 60-80%）|

---

## 症状 3：Ron 跨摆幅变化大 → SFDR 不达标

**表现**：spec SFDR = 80 dB，实测 60 dB；frequency-domain 看到 HD2 / HD3 大。

**物理因果**：Ron(V_in) 是非线性函数 → 相当于在采样节点上加了非线性 R-C 网络 → 失真。

**诊断**：
1. .ac sweep DC bias 测 Ron(V_in)
2. 计算 Ron 跨摆幅变化比例：
   - nmos-only：5-10× → SFDR ~50-60 dB
   - TG：1.5-3× → SFDR ~70-80 dB
   - bootstrap：< 1.2× → SFDR ~85-95 dB

**修复方向**：从低线性度 → 高线性度按需切换：
- nmos-only → TG（提升 ~15 dB SFDR）
- TG → bootstrap（再提升 ~10-15 dB）

**❌ 不要**：增 W_M_sw 不能直接改善线性度；只是降 Ron 绝对值。

---

## 症状 4：时序错（race condition / 时钟重叠）

**表现**：
- 两个 phase 重叠 → 信号被短路
- 边沿 race → 不确定的电荷转移
- bootstrap helper 顺序错 → C_b 充不到位

**诊断**：tran 仿真细看时钟边沿（200 ps 分辨率）：
- non-overlap 间隔 < 100 ps → 边缘
- 多 phase race → 用 `.meas` 抓时钟事件

**修复**：
- 增 non-overlap 间隔到 ≥ 200 ps（typical 0.5-1 ns @ 100 MHz）
- bootstrap helper 用专门的 4-phase clock generator（precharge / discharge / sample / hold 严格分离）
- 加 deglitch buffer（防止边沿 ringing）

---

## 症状 5：aperture jitter 限制高频 SNR

**表现**：高频信号 SNR 不达标（低频 OK，> 10 MHz 下降）。

**物理因果**：
```
SNR_jitter = -20·log(2π · f_in · σ_jitter)

@ f_in = 1 GHz / σ_jitter = 1 ps → SNR ≤ 44 dB
@ f_in = 100 MHz / σ_jitter = 1 ps → SNR ≤ 64 dB
@ f_in = 100 MHz / σ_jitter = 100 fs → SNR ≤ 84 dB
```

**诊断**：
- 时钟源 jitter 实测（PLL output / crystal）
- clock distribution buffer chain jitter（每级累加 √N）
- M_sw 自身的 random switching delay

**修复**：
- 改善时钟源（低噪声 PLL / 低 jitter crystal）
- 短 clock distribution path（减 buffer chain）
- 选 high-Q time reference

---

## 关联 skill（诊断思维过程）

Switch 故障诊断框架：
- **沿信号路径反推**：用 skill `circuit-method/signal-tracing`（"ΔV_sample 是谁注入的？是 charge inj、feedthrough 还是 jitter？"）
- **根因优先**：用 skill `meta-cognitive/systematic-debugging`（不要先调 W，先确认根因在哪个误差源）

Switch 特定症状的"是谁决定"指引：
- ΔV_sample 大 → 区分 charge inj（V_signal 相关）vs feedthrough（V_signal 无关）vs ringing（时序）
- Ron 不对 → W·L 太小 / Vov 不对 / bootstrap 失效
- SFDR 不达标 → Ron 线性度（拓扑选择）vs charge inj 残差
- SNR 不达标 → jitter / kT/C / charge inj 哪个主导

## 通用原则

- 高精度 SC 必须用底板优先关断 + dummy switch + 后端校准三件套
- bootstrap 几乎是 ≥ 12-bit ADC 的标配
- 时钟生成 + non-overlap 时序在仿真中必须严格验证
- aperture jitter 是高频 SNR 的硬上限，**主要**由时钟源 / 分配链决定，但 clock buffer 噪声、边沿 slew、M_sw 随机开关延迟也有贡献（不是"完全与 switch 自身无关"）

## 不在本章范围

- nmos-only / TG / bootstrap 详细 → 对应 chapter
- kT/C noise 推导 → `blocks/base-cells/cmfb/switched-capacitor.md` § kT/C
- 完整 ADC 时序 → `systems/sar-adc` / `systems/adc-pipeline`
- 时钟源 / PLL jitter → `systems/pll`
- 栅氧可靠性 → device reliability knowledge
