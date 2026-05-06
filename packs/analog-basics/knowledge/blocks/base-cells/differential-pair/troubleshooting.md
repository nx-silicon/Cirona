---
chapter: troubleshooting
parent: differential-pair
summary: |
  diff pair 4 类典型症状对照：tail triode（极性错）/ Vos 偏大 / CMRR 崩 /
  输入 CM 范围不够。每条按"症状 → 物理因果 → 修复方向"对照。
tokens: ~500
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/signal-tracing
  - circuit-method/causal-chain-debug
  - meta-cognitive/systematic-debugging
---

# Differential Pair 故障诊断

> ⚠️ **使用规则**：本章是事实对照表。**思维过程**用 skill
> `circuit-method/signal-tracing` 沿信号路径反推。
> Diff pair debug 第一步看 tail device region——很多问题都是 polarity 选错引起。

---

## 症状 1：tail device 进 triode（dc_snapshot M_tail 的 Vds < Vdsat）

**这是 LDO/OTA debug 的 #1 silent killer。**

**物理因果**：
- NMOS input pair：tail 在底，**Vds_tail = vcm - Vgs_diff = vcm - (Vth + Vov_diff)**
- vcm 太低 → Vds_tail 太低 → triode
- triode 时 tail current 不再恒定 → diff pair 平衡破坏 → CMRR 崩 / Itail 漂

**典型场景**：
- Vref = 0.6V（bandgap 输出）
- 用 NMOS input pair（Pack default）
- Vds_tail = 0.6 - 0.65 = -0.05 V → tail 直接撞地

**修复方向**：

| 方向 | 做法 | 适用 |
|---|---|---|
| **改极性** | NMOS → PMOS（vcm 低用 PMOS）| Vref < 0.8V 推荐 |
| 折叠 cascode | tail 从两侧 rail 取 bias（不堆叠）| Vref 0.8-1.0V 中间 |
| 调 vcm 预设 | 加 level shifter 把 vcm 抬高 | 不能改极性时（少见）|

**❌ 不要做的事**：
- 调 tail 的 W/L（不影响 Vds_tail）
- 调 input pair 的 W/L（也不影响）
- 用理想电压源 force vcm（PVT 角不真实）

完整决策见 `blocks/ldo/architecture.md` § "EA 输入对极性（由 Vref 决定）"。

---

## 症状 2：Vos 偏大（MC 仿 σ_3sigma > spec）

**物理事实**：σ_1sigma(Vos) = Avt / √(W·L)。

**修复方向**（按效果）：

| 修复 | 因果 | 代价 |
|---|---|---|
| L ↑（典型 1µm → 2µm）| W·L 倍增 → σ ↓ √2 倍 | gm 略降（gm ∝ √(W/L)）|
| W ↑（典型 5µm → 10µm）| W·L 倍增 → σ ↓ √2 倍 | Cgs 倍增 → BW 降 |
| 同时 W↑ + L↑（保持 W/L）| W·L 4 倍 → σ ↓ 2 倍 | 面积 + Cgs 都倍增 |
| common-centroid layout | 系统性失配消除 | layout 工作量 |

**Pelgrom 公式定数关系**：要让 σ ↓ 2 倍 → W·L 必须 4 倍。

**❌ 不要做的事**：
- 拍脑袋"再加大一点 W" 不算 W·L → 可能仍不够
- 仅靠 layout 不改 W·L → layout 改善有限（system mismatch < random mismatch）

详细 Pelgrom 系数见 `pdks/<工艺>/`。

---

## 症状 3：CMRR 崩（< 50 dB）

**可能原因**：

| 原因 | 验证 | 修复 |
|---|---|---|
| tail triode（症状 1）| dc_snapshot M_tail.Vds | 改极性（症状 1） |
| ro_tail 偏低（single-device tail）| 算 ro = VA·L/Id | 升级 cascoded tail（gm·ro²）|
| input pair mismatch | MC 仿 σ(Vos) | 增 W·L（症状 2）|
| layout 不对称 | layout review | common-centroid + dummy device |
| Vcm 接近 input range 边界 | DC sweep Vcm | 把 spec Vcm 限制到中间区域 |

**核心判别**：
- 静态 CMRR 差（DC）→ ro_tail 偏小或 layout 失配
- 高频 CMRR 差（AC）→ tail node 寄生 cap 不够 / parasitic mismatch

---

## 症状 4：input CM 范围不够（spec 要的 vcm 范围不能覆盖）

**物理边界**（**不能突破**）：
- NMOS input：Vcm_min = Vov_tail + Vth_n + Vov_diff
- NMOS input + PMOS load：Vcm_max = VDD - Vov_load
- PMOS input + NMOS load：Vcm_min = Vov_load
- PMOS input：Vcm_max = VDD - Vov_tail - Vth_p - Vov_diff

**收窄 Vcm range 的设计错误**：
- Vov_tail 太大（tail 用 strong inversion）→ 减 vcm 范围
- Vov_diff 太大 → 减 vcm 范围
- Vov_load 太大 → 减 vcm 范围

**修复方向**：

| 方向 | 做法 | 代价 |
|---|---|---|
| 选 weaker inversion | gm/Id ↑（10 → 15）→ Vov ↓ | noise 改善（Vov 小）/ BW 降 |
| **rail-to-rail input**（双对差分对） | NMOS + PMOS 并联输入 | 复杂度 / power 增 |
| 折叠 cascode | tail 不堆叠 | 设计复杂度 |
| 改 spec | 减 Vcm 范围 | 减 spec 是技术债 |

---

## 通用诊断流程

```
看 diff pair 异常 →
  Step 1: dc_snapshot 拿 M1/M2/M_tail 的 region + Vov + Id
  Step 2: state expectation
    - M_tail.Vds > Vov_tail + 50mV
    - M1/M2 同 region 同 Vov ±5%
    - M1/M2.Id ≈ Itail/2
  Step 3: identify deviation
    - tail triode → 症状 1 → 改极性或 cascoded tail
    - M1/M2 不平衡 → mismatch 或 input vcm 偏离
    - Itail 偏离设计 → bias generator 链问题
  Step 4: trace upstream（用 signal-tracing skill）
  Step 5: verify cheapest（dc_snapshot 看上游而不是改 W 重仿）
```

完整 mental model 见 skill `circuit-method/signal-tracing`。

## 不在本章范围

- **active load 自身 troubleshooting**——见 `blocks/base-cells/current-mirror/troubleshooting.md`
- **tail current source 不准确 / matching**——同上
- **cascoded tail / regulated tail 设计**——见 `blocks/base-cells/cascode`
- **bias generator 链问题**——见 `blocks/base-cells/bias-generator`
- **完整 OTA debug**（不止 input pair）——见 `blocks/ota-*` 各自 troubleshooting
- **comparator metastability** —— 见 `blocks/base-cells/comparator-latch`
- **比较器 input-referred noise**——见 `blocks/comparator/input-noise.md`（Week 3）
