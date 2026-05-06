---
chapter: architecture
parent: comparator
summary: |
  4 拓扑变体对比（StrongARM / dynamic-comparator / preamp+latch / continuous-time）
  + 选择决策树（speed / offset / kickback / power 四轴）+ sizing pitfalls 7 条
  （Vov 选取 / clock 边沿 / regen W/L / tail switch headroom / preamp gain / 滞回宽度
  / optional two-phase non-overlap）。物理推导（offset σ / τ_reg / metastability）见 base-cell。
tokens: ~1500
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/comparator-latch
  - blocks/base-cells/differential-pair
  - blocks/base-cells/cascode
  - blocks/base-cells/switch
---

# Comparator 架构

## 拓扑选择三轴

Comparator 拓扑由三个**独立**决策组合：

| 轴 | 选项 | 关键决策依据 |
|---|---|---|
| 时序方式 | clocked / continuous-time | 是否可用 clock；是否需要 sample 时刻确定 |
| 静态电流 | static / dynamic | Iq budget；功耗 vs 速度 trade-off |
| 输入隔离 | 直接 latch / preamp + latch | offset spec / 是否需要 kickback 隔离 |

三轴组合的常见落地：

| 组合 | 落地拓扑 | 应用 |
|---|---|---|
| clocked + dynamic + 直接 latch | **StrongARM** | ADC 主比较器 / SerDes RX slicer |
| clocked + dynamic + 无 regenerative latch（open-loop / charge-domain）| **Dynamic comparator** | 低功耗 flash ADC / 简化版 |
| clocked + dynamic + preamp | **Preamp + StrongARM** | 高精度 SAR / pipeline residue |
| continuous-time + static + 滞回反馈 | **Continuous-time hysteresis** | POR / 阈值检测 / 慢控制环 |

## 4 拓扑变体对比

| 拓扑 | DC offset σ | T_decide @ 1 mV input | kickback charge | static power | 关键限制 |
|---|---|---|---|---|---|
| **StrongARM** | 5 – 30 mV | 200 – 800 ps | Cgd_in × 0.5V ≈ 2–5 fC | 0（仅 CV²f）| input pair Vth 失配主导 offset；clock CV²f 在 GHz 可观 |
| **Dynamic comparator** | 10 – 50 mV | 300 ps – 1 ns | 中 | 0 | 无 cross-coupled regeneration，常需后级 buffer/latch；输入摆幅敏感 |
| **Preamp + StrongARM** | **1 – 5 mV** | 500 ps – 2 ns（含 preamp delay）| **0.05–0.3 fC**（preamp 隔离）| 10 – 100 µW（preamp Iq）| preamp gain 必须 ≥ 20–30 dB；preamp BW limit comparator speed |
| **Continuous-time + hysteresis** | 1 – 10 mV | 100 ns – 10 µs | < 0.1 fC | 1 – 100 µA | 速度上限 ~10 MHz；滞回宽度 V_hys ≥ 3–5σ_noise |

> **物理推导出处**：σ_OS / τ_reg / metastability 概率 / kickback 电荷推导见 `blocks/base-cells/comparator-latch/strongarm.md`。本表是应用层数值范围摘要，不重复推导。

## 拓扑选择决策（按 spec 反推）

| Spec 关键字 | 推荐拓扑 |
|---|---|
| ADC ≤ 8-bit / fclk ≥ 1 GHz | **StrongARM** |
| ADC 10–12 bit / σ_OS ≤ 5 mV / fclk ≤ 500 MHz | **Preamp + StrongARM** |
| ADC ≥ 14-bit / σ_OS ≤ 1 mV | preamp + StrongARM + 数字 trim 校准（超本章范围）|
| flash ADC ≤ 6-bit / 极简 | **Dynamic comparator** |
| POR / undervoltage detect / 慢阈值检测 | **Continuous-time + hysteresis** |
| SerDes RX slicer / fclk ≥ 5 GHz | **StrongARM**（input common-mode 注意） |
| PLL PFD 内 retiming | StrongARM 风格（PFD 通常在 `systems/pll`）|

**Iron Law**：选错家族（如用 continuous-time 做 1 GHz ADC）= 速度差 100×，sizing 救不回——必须 challenge 拓扑（[L0 Iron Law 6](../../../src/agent_engine/prompt_compiler.py#_IRON_LAWS_DEFAULT)）。

## ⚠️ Common sizing pitfalls

> 这一节是 comparator 系统级 sizing 决策的"避坑提示"。完整 input pair / regen pair sizing 范例（数值反推）见 `blocks/base-cells/comparator-latch/strongarm.md` § sizing 范例（10-bit / 100 MSPS SAR ADC 实战）。

### Pitfall 1: Input pair Vov 选大 → β 失配项与 Vth 项可比

**症状**：MC σ_OS 比 √AVT²/(WL) 估算大 ~30%，加大 W·L 改善缓慢

**因果**：`σ²_OS = σ²_Vth + (Vov/2)²·σ²(Δβ/β)`。
- Vov ≤ 0.15V → Vth 失配主导（Pelgrom 主项）
- Vov ≥ 0.25V → β 项与 Vth 项可比，**β fractional mismatch `σ(Δβ/β)=AB/√(WL)` 与 Vth 同 scale，但被 Vov/2 放大**

**修复**：input pair Vov 选 0.1–0.15V（甜蜜点：Vth 主导 / 速度仍 OK）。增 W·L 而不是增 Vov 来减 offset。

### Pitfall 2: Clock 上升沿不够陡 → aperture jitter 主导 SNR

**症状**：MC tran 测得 aperture jitter > spec；ADC SNDR 限于 jitter（不是 thermal noise）

**因果**：StrongARM evaluate phase 起点由 CK 上升过 Vth_M_tail 决定。CK 边沿 100 ps + 噪声 → 起点抖动 ~ noise/(dCK/dt) ≈ 1 ps 级。**外部时钟边沿 30 ps 看似 OK，但 clock buffer 链每级 +10–30 ps 边沿退化**。

**修复**：clock 路径最末级 buffer 边沿 ≤ 30 ps（实测 dCK/dt ≥ 60 V/ns @ 1.8V）。clock buffer chain 用大 W 强驱 + 短 fanout（≤ 4）。

### Pitfall 3: Regen pair W·L 选大 → 节点电容增更快，τ_reg 反而劣化

**症状**：放大 regen pair W 想减 τ_reg，结果 T_decide 反而变长

**因果**：`τ_reg = C_node / gm_regen`。
- `gm_regen ∝ sqrt((W/L)·Id)`（近似 square-law；最终以 OP 提取为准）
- `C_node` 随 gate / diffusion cap 增大；一阶可按 `W·L` 与 diffusion perimeter 同时估算
- 固定 L、Id 时，W↑ 让 gm 约增 `sqrt(W)`、C 约增 `W` → `τ_reg` 反而约随 `sqrt(W)` 变差
- 增 Id 会改善 `gm`，但不是简单 `/Id`；系统层只保留 `C/gm` 因果，数值推导见 base-cell

→ 单方向加 W 没用；速度优化要同时考虑 Id 与 L。

**修复**：regen pair W·L 0.2–1 µm² 范围（vpdk180nm，Lmin–2×Lmin）。需要更快 → 优先加 Id（增 tail W）+ 缩 L，不是单纯加 W。

### Pitfall 4: Tail switch R_on 太大 / tail node headroom 不足 → sampling gain 变慢

**症状**：evaluate 中段 `V(tail)` 偏高、`sp/sn` 放电斜率偏小；输出最终能 regen 但 metastability 概率反常高

**因果**：本 9-MOSFET StrongARM 的 `M_TAIL` 是 rail-driven clock switch，**不是 biased current source**。CK=VDD 时 `Vov_tail ≈ VDD - Vth_n`（约 1.3V），evaluate 中 `Vds_tail = V(tail)` 远小于 `Vov_tail` 是常态，**tail triode 本身不是失效判据**。

信号路径反推：在目标 evaluate 电流对应的 effective input overdrive 下，`V(tail) ≈ VCM - Vgs_in ≈ VCM - Vth_n - Vov_in`；例 VCM=0.9V、Vth_n=0.5V、Vov_in=0.15V → `V(tail) ≈ 0.25V`。这只是 operating-point estimate，实际 transient 由 tail `R_on`、input pair current 与 `sp/sn` 电容共同决定。若 tail switch 太弱（W 小或 clock 边沿慢），`R_on_tail` 增大 → `V(tail)` 抬高 / 放电电流受限 → input pair effective `Vgs` 与 `sp/sn` 放电斜率下降 → 初始差分变小 → metastability 概率上升。

**修复**：tail 用 switch 逻辑 sizing：降低 `R_on_tail`（增大 W，本 reference W=8µ 是起点）、保证 clock edge 足够陡，并检查 evaluate 中段 `V(tail)`、`sp/sn` 放电斜率、input pair region。若采用"clock-gated + biased current source"非本 reference 的拓扑变体，才检查 current-source saturation margin。

### Pitfall 5: Preamp + latch 前级 gain < 20 dB → kickback 优势消失

**症状**：σ_OS 测得没比纯 StrongARM 改善多少；kickback 仍可见

**因果**：preamp 的两个作用是 (a) 放大输入差分到 latch 阈值之上（gain）+ (b) 隔离 latch 内部摆动反向耦合到输入（reverse isolation）。
- gain < 20 dB → latch input 差分仍小，offset 由 latch σ_OS 主导
- 反向隔离不够 → kickback charge 仍流回输入（preamp 输出阻抗高 + Cgd 反耦合）

**修复**：preamp 选 5T-OTA 或 cascode-OTA，gain ≥ 30 dB，输入对 Vov ≤ 0.15V。preamp 输出加缓冲（source follower）减 latch 反向耦合。

### Pitfall 6: Continuous-time hysteresis V_hys 选窄 → 噪声多次过零振荡

**症状**：tran 慢扫输入过阈值，输出多次切换（每次切换间几 µs 抖动）；POR 信号多次毛刺

**因果**：hysteresis 比较器靠 positive feedback ratio β = R1/(R1+R2) 把单个比较点扩成 [V_th-βVDD, V_th+βVDD] 的滞回带。**V_hys < 3σ_noise 时输入噪声会让输出在带内振荡**。

**修复**：V_hys ≥ 5σ_input_noise（典型 input-referred noise 1–3 mV → V_hys ≥ 10–20 mV）。POR / 阈值检测取 V_hys = 50–100 mV 留 corner margin。

### Pitfall 7: Clock 边沿太慢 → reset PMOS 与 tail NMOS 边沿期同时导通的 short-through 区间过长

**症状**：tran 在 CK 上升 / 下降边沿期出现 100 mV+ 毛刺；CK 边沿期间从 VDD 经 M_RP/M_RN ↔ voutp/voutn ↔ M_DP/M_DN ↔ sp/sn ↔ M_INP/M_INN ↔ M_TAIL ↔ VSS 通路有短路电流（CV²f 实测比理论高 2–3×）

**因果**：本 reference 是单相 clk 拓扑——CK=0 reset / CK=VDD evaluate **物理互斥**（无 non-overlap 概念）。但 CK **边沿期间**（CK 从 0 向 VDD 上升，过 Vth_p_reset 与 Vth_n_tail 之间的窗口）M_RP/M_RN 还未完全关 + M_TAIL 已经开 → 同时导通的 short-through 通路。**边沿越慢窗口越宽，毛刺/CV²f 越严重**。

**修复**：让 CK 边沿足够陡（≤ 30 ps，dCK/dt ≥ 60 V/ns @ 1.8V，避 Pitfall 2）。**若系统需要显式两相 phi_pre/phi_eval non-overlap**（不属本单相 reference），应包一层 two-phase wrapper 或换 two-phase variant，由 wrapper 的 clock generator 保证 ≥ 100 ps non-overlap。

## 验证清单（架构选好后）

- [ ] 拓扑与应用 spec 匹配（参考 § 拓扑选择决策表）
- [ ] input pair 极性与共模 ICM 匹配（NMOS-input ICM 高、PMOS-input ICM 低）
- [ ] input pair Vov 0.1–0.15V（避 Pitfall 1）
- [ ] tail switch `R_on` / `V(tail)` / `sp/sn` 放电斜率满足 evaluate 预算（避 Pitfall 4）
- [ ] regen pair W·L 0.2–1 µm² + 调 Id / L 而非单 W（避 Pitfall 3）
- [ ] clock 边沿 ≤ 30 ps（避 Pitfall 2 + 7 short-through 窗口）；若用 two-phase wrapper 则另加 non-overlap ≥ 100 ps
- [ ] 若选 preamp + latch：preamp gain ≥ 20–30 dB（避 Pitfall 5）
- [ ] 若选 continuous-time hysteresis：V_hys ≥ 5σ_noise（避 Pitfall 6）
- [ ] 加载 `blocks/base-cells/comparator-latch/strongarm` 做 input pair / regen pair 详细 sizing
- [ ] 跑 `chapter=reference-design` § 验证清单（regen 时序 / kickback / metastability）

## 常见架构误区

| 心里想 | 现实 |
|---|---|
| "增 W 减 offset" | offset σ ∝ 1/√(W·L)；W=4× 才减一半，面积代价大；不如 Vov 选低位（避 Pitfall 1）|
| "Vov 大速度快" | 速度由 τ_reg = C/gm 决定（Pitfall 3）；Vov 大反而放大 β 项 offset |
| "preamp 越大越好" | preamp BW 限制 comparator speed；过 30 dB 边际收益小（Pitfall 5）|
| "continuous-time 没 metastability" | 错——慢速但仍存在；只是错误率被滞回带宽吃掉（Pitfall 6）|
| "单相 clk 不存在 short-through" | CK 边沿期 reset PMOS 还没关 + tail NMOS 已开，同时导通的窗口让 CV²f 翻倍（Pitfall 7）|
| "用 dynamic comparator 省功耗" | 仅在 fclk 低时省；high-fclk 下 CV²f 与 StrongARM 相当，offset 反而劣 |

## 不在本章范围

- **input pair / regen pair 详细 sizing 范例**（含 Pelgrom AVT 数值 + Worked example）→ `blocks/base-cells/comparator-latch/strongarm` § sizing 范例
- **offset σ / metastability / kickback 物理推导**（公式起点）→ `blocks/base-cells/comparator-latch/strongarm`
- **standard StrongARM 网表 + testbench**（cir / tb_dc_op / tb_tran）→ `chapter=reference-design`
- **5 类故障 debug**（offset / metastability / kickback / clock race / 电源耦合）→ `blocks/base-cells/comparator-latch/troubleshooting`
- **完整 ADC 时序 / SAR FSM** → `systems/sar-adc`（W8+）
- **Offset 数字校准**（DAC trim / DEM）→ ADC 系统 + 校准 knowledge
- **clock generation / non-overlap circuit 详细电路** → `blocks/base-cells/switch` + clock distribution knowledge
- **PLL PFD 风格触发器** → `systems/pll`（W9+）
