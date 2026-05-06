---
chapter: psrr
parent: ldo
summary: |
  LDO PSRR 频段特性（DC 高、单调下降、高频 Cload 主导）+ EA gain 关系 +
  cascode/双级 EA 提升 PSRR 因果 + V3 实测的 PSRR-shape sanity check
tokens: ~700
prerequisite_chapters:
  - architecture
  - ac-stability
related_skills:
  - circuit-method/ac-feedback-loop-method
  - meta-cognitive/verification-before-completion
related_knowledge:
  - blocks/base-cells/cascode
  - simulators/ngspice
---

# LDO PSRR（Power Supply Rejection Ratio）

## 定义与典型 spec

```
PSRR_dB = 20 · log10(|ΔVdd / ΔVout|)
```

- **正值**：输出抑制（Vout 比 Vdd 扰动小）
- **典型 spec**：
  - PSRR @ DC：50-80 dB（高质量 LDO）
  - PSRR @ 1 kHz：50-70 dB
  - PSRR @ 100 kHz：30-50 dB
  - PSRR @ 1 MHz：20-40 dB（Cload + ESR 主导）

## 频段特性（事实 + 因果）

LDO PSRR 与 loop gain T(f) 强相关：

```
PSRR(f) ≈ T(f) + 1/β     （β = 反馈分压系数）
```

→ PSRR 与 loop gain 同**频域形状**，几乎一一对应。

| 频段 | PSRR 主导机制 | 典型表现 |
|---|---|---|
| DC – 主极点 fp_main | EA gain × 反馈环 | 高 PSRR（50-80 dB），由 T₀ 决定 |
| fp_main – fp_EA | T(f) 单极点滚降 | 每十倍频程 -20 dB |
| fp_EA – Cload Zero | T(f) 双极点 | 滚降可能加快 |
| Cload Zero 之后 | Cload(+ESR) 作 shunt 到 Vss | 高频 PSRR 重新升高（"bumpy"特性） |

**典型 PSRR 频谱形状**：
```
PSRR (dB)
  60 ┤■■■■■■■■■        ← T₀ 主导（DC – fp_main）
  50 ┤            ╲
  40 ┤             ╲    ← fp_main 后单极点滚降
  30 ┤              ╲
  20 ┤               ╲ ← fp_EA 后双极点
  10 ┤                ╲___━━━━     ← Cload 高频 shunt
   0 ┼────────────────────────────  freq (Hz)
       1   100  10k  100k  1M
```

## EA Gain ↔ PSRR 因果

```
T₀ (loop gain at DC) = A_EA × β × gm_pass × Rout_node
```

EA gain ↑ 直接让 T₀ ↑ → PSRR(@DC) ↑。

**这就是为什么 LDO 必须用双级 EA / cascode EA 不能用 5T-EA**：
- 5T gain ≈ 30 dB → T₀ 也只 30+something dB → PSRR(@DC) 30 dB（远低于 50 dB spec）
- 双级 EA（30 + 25 = 55 dB）→ T₀ 60-70 dB → PSRR 60+ dB（spec 达标）

详见 `chapter=architecture` § "EA 拓扑"。

## 提升 PSRR 的手段（按效果）

| 手段 | 因果 | 代价 |
|---|---|---|
| EA gain ↑（cascode / 双级） | T₀ ↑ → PSRR(@DC) ↑ | 复杂度 / Iq |
| 反馈分压器 R 大（增 β） | 1/β 项较小（与 T₀ 同方向）| Iq 下降；噪声 / matching 限制 |
| Cload ↑ | 高频段 shunt 路径 ↓ | 面积 / 启动慢 |
| 加 PSRR boost capacitor（vdd → vfb 之间）| feed-forward 抵消 | 复杂 / 仅特定频段 |
| 在 EA / pass gate 之间加 RC filter | 高频抑制 | 引入额外极点 / 稳定性影响 |

## PSRR shape sanity check（V3 实测的 free check）⭐

**V4 重要观察**（V3 ldo overview 反复强调）：

正常 LDO 的 PSRR 形状是**DC 最高、单调下降**（直到 Cload zero 处可能 bump-up）。

**异常形状**（categorical failure，不是数字议价）：

- ❌ PSRR @ 1 Hz = 19 dB / @ 10 MHz = 74 dB —— **倒置形状**
- 物理含义：loop 在 DC 没增益（EA 拓扑选错或 sizing 错），高频 Cload 作 shunt 反而看起来"PSRR 高"
- **判别**：PSRR 频谱图整体形状异常 → loop 失效，不是数字调可救

**这是 LDO 调试的免费 sanity check**——画 PSRR vs frequency 图看形状即可判别 loop 健康。

## 典型 PSRR testbench 配置（ngspice）

```spice
.option compat=ps
.lib    "../../pdk/vpdk180nm/vpdk180nm_corners.lib" tt
.include "../design/your_ldo.cir"

* Supply with AC 扰动
Vdd vdd 0  DC 1.8 AC 1                $ AC=1 给 PSRR sweep
Vss vss 0  0

* LDO instance + Iload
X_ldo vdd vss vref vfb vout  ldo_pmos_2stage
Iload vout vss DC 10m

* Cload + ESR
Cload vout vload_int 1u
Resr  vload_int vss 0.1

* AC（PSRR 用闭环 LDO）
.ac dec 50 1 100Meg

.control
  run
  setplot ac1
  let psrr_db = -db(abs(v(vout)) + 1e-20)    $ 注意符号：vdd=AC1，
                                              $ vout 越小则 PSRR 越大
  meas ac psrr_dc       find psrr_db at=1
  meas ac psrr_1k_hz    find psrr_db at=1k
  meas ac psrr_100k_hz  find psrr_db at=100k
  meas ac psrr_1m_hz    find psrr_db at=1Meg
  echo "PSRR(DC)=$&psrr_dc, @1kHz=$&psrr_1k_hz, @100kHz=$&psrr_100k_hz, @1MHz=$&psrr_1m_hz"
  wrdata ../simulation/tb_psrr/psrr.csv frequency psrr_db
.endc
.end
```

**注意**：PSRR 测试用**闭环** LDO（不是开环 loop gain）—— 闭环响应才是真实 vdd 扰动到 vout 的传递函数。开环 loop gain 测的是 unity-gain 截止，跟 PSRR 不同测试。

## 验证清单

- [ ] DC OP 显示 EA + pass FET 全 saturation（前置）
- [ ] Loop gain（开环测）DC > 50 dB（PSRR 物理上限）
- [ ] PSRR @DC > 50 dB（spec 通常）
- [ ] PSRR 频谱单调下降（DC 高，无倒置）
- [ ] PSRR @1MHz > 20 dB（Cload + ESR 担当下限）
- [ ] PVT corner（FF / SS）下 PSRR 仍 > spec − 5dB

## 常见误区（self-check）

| 心里想 | 现实 |
|---|---|
| "PSRR @1MHz 高就够了" | 看 DC PSRR 才反映 loop 健康；高频 PSRR 是 Cload shunt 现象 |
| "PSRR @DC 19dB / @10MHz 74dB 看着不错" | 形状异常 = loop 在 DC 失效，categorical failure |
| "改 EA gain 就能修任何 PSRR 问题" | 高频 PSRR 由 Cload + ESR 担当；EA 救不了 1MHz 以上 |
| "PSRR boost cap 就能补足 PSRR" | boost cap 仅补特定频段，需要精确设计 |
| "改 Cload 大小不影响 PSRR" | Cload ↑ → 高频 PSRR ↑（shunt 强）+ 主极点低（PM 改变）|

## 不在本章范围

- **EA 拓扑选择**（5T / cascode / 双级）→ `chapter=architecture`
- **AC 断点 / loop gain testbench**（不同于 PSRR 测试）→ `chapter=ac-stability`
- **Cload + ESR 模型与 PCB 实测对应**——layout 知识，V4 不在范围
- **PSRR boost / supply-aware EA 拓扑**（advanced LDO）—— V4 暂不范围
