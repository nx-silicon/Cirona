---
chapter: troubleshooting
parent: ldo
summary: |
  LDO 4 类典型症状对照：不稳定 / DC offset / 启动失败 / PSRR 偏低。
  每条按"症状 → 物理因果 → 修复方向"对照，并指向相关 skill / chapter。
tokens: ~700
prerequisite_chapters:
  - architecture
  - ac-stability
  - psrr
related_skills:
  - circuit-method/signal-tracing
  - circuit-method/ac-feedback-loop-method
  - meta-cognitive/systematic-debugging
---

# LDO 故障诊断

> ⚠️ **使用规则**：本章是事实对照表。**思维过程**用 skill
> `meta-cognitive/systematic-debugging` + `circuit-method/signal-tracing`。
> LDO debug 第一步永远是 dc_snapshot 拿 EA tail / pass FET / 反馈分压器
> 的 region + 数值，再判断症状类别。

---

## 症状 1：不稳定 / 振荡

**表现**：
- AC 测得 PM < 30° 或负
- Tran 仿真 vout 振荡（典型 100k-10M Hz）
- PCB 实测 vout 抖动

**可能原因**：

| 原因 | 验证 | 修复 |
|---|---|---|
| 主极点 / 次极点过近（< 1 decade） | AC sweep 看 fp_main / fp_EA 距离 | Cload ↑ 降 fp_main 或 Miller Cc 推 fp_EA |
| Cload ESR 不当（纯陶瓷 ESR 太小）| ESR 数值检查 | 加 ESR 1-100mΩ，或换 buffered LDO |
| EA gain 过高 | dc_snapshot 看 EA gain | 减 EA gain（牺牲 PSRR） |
| Iload 角端 PM 不达 spec | 全 Iload PM sweep | 调补偿适配 worst load corner |
| compensation Cc 太小 | Cc 值检查 | Cc ↑（与 Cload / EA 协同设计）|

详见 `chapter=ac-stability`。

---

## 症状 2：DC offset 大（vout ≠ Vref × R 比例 > spec）

**表现**：dc_snapshot Vout 偏离 spec > 5-10 mV。

**可能原因**：

| 原因 | 验证 | 修复 |
|---|---|---|
| EA input pair mismatch | MC mismatch 仿（100 次）看 σ(Vos) | EA input pair W·L ↑（Pelgrom）|
| **EA polarity 错（tail triode）** | dc_snapshot M_tail.Vds | 改 EA polarity（Vref 决定，见 architecture） |
| 反馈分压器 R mismatch | layout 检查 R1/R2 matching | common-centroid layout / R 总和 ↑ |
| pass FET 在 triode（dropout 边缘）| dc_snapshot M_pass.Vds | 减 Iload 或加 Vin headroom |
| EA tail current 偏离设计 | bias chain 追溯 | bias generator 链问题（见 `blocks/base-cells/bias-generator`） |
| Vref 本身偏移（bandgap 错）| Vref 节点电压 | bandgap troubleshooting（不在本 LDO 章）|

**核心判别**：dc_snapshot 看 EA tail M_tail 是否 saturation——这是 LDO #1 silent killer，详见 `blocks/base-cells/differential-pair/troubleshooting.md` § "症状 1: tail device 进 triode"。

---

## 症状 3：启动失败（上电后 vout 一直 0 或不上）

**表现**：power-up 后 vout = 0 / 不到 spec / 上得很慢。

**可能原因**：

| 原因 | 验证 | 修复 |
|---|---|---|
| pass FET 偏置不到（vg_pass 太接近 vdd）| dc_snapshot vg_pass | EA 输出 DC 检查；EA bias 是否上了 |
| 反馈环初始 stuck | tran 启动仿真看 vout 曲线 | startup helper / soft-start 电路 |
| bandgap 没启动 → Vref=0 | Vref 节点电压 | bandgap startup helper（`blocks/bandgap`）|
| EA tail current 没起来 | bias chain DC OP | bias generator startup（β-multiplier 双稳态）|
| Cload 大 + 软启动 RC 长 | 启动时间常数 | 接受启动时间 / 加 startup boost 电路 |

**关键启动顺序**（典型 LDO 上电）：
1. vdd 上升 → bias generator startup helper 把 bias chain 拉起
2. bandgap 启动给 Vref
3. EA bias chain 全 saturation
4. EA 输出推 vg_pass → pass FET 开
5. vout 上升直到 vfb = Vref × β

任一步阻塞 → vout 不上。debug 用 tran 仿 0-100µs 看每个节点电压上升曲线。

---

## 症状 4：PSRR 偏低（< spec）

**表现**：PSRR @ DC < 50 dB 或形状异常（DC 低 / 高频高 → categorical failure）。

**可能原因**：

| 原因 | 验证 | 修复 |
|---|---|---|
| **EA gain 不够**（5T 拓扑 → 30dB 上限） | open-loop AC gain_dc | 升级到双级 / cascode EA |
| Loop gain T₀ < 50 dB | open-loop AC gain_dc | 见上 |
| 反馈分压器分压系数 β 过小 | β = R2/(R1+R2) | β 不能改太多（决定 Vout） |
| 高频段 Cload 过小 | Cload 数值 | Cload ↑（高频 PSRR 改善）|
| **PSRR 形状倒置（DC 低 / 高频高）** | 看 PSRR vs freq 频谱图 | **categorical failure**：loop 在 DC 失效，重新检查 EA 拓扑 / sizing |

详见 `chapter=psrr`。

---

## 症状 5：Iquiescent（Iq）超 spec

**表现**：no-load 时 Iq（EA + bias chain 总电流）> spec。

**可能原因**：

| 原因 | 修复 |
|---|---|
| EA 双级 EA tail bias 过大 | tail bias ↓（牺牲 SR / GBW） |
| bias chain branches 多（cascoded → 4 branches）| 简化 bias chain（如 simple variant）|
| 反馈分压器 R 太小（漏电流大）| R ↑（典型 100k-1M）|
| Vref ladder 漏电 | bandgap Iq 单算 |

---

## 症状 6：负载瞬态过冲过大

→ 见 `chapter=overshoot`（不在本 troubleshooting 章重复）。

---

## 通用诊断流程（用 skill）

```
看 LDO 异常 →
  Step 1: dc_snapshot 拿全节点 + 全 device region
    - vout, vfb, vinp/vinn, vg_pass, vbias_chain
    - M_pass region, M_tail region, M_input_pair region
  Step 2: state expectation
    - vout ≈ Vref × (R1+R2)/R2
    - 全 device 在 saturation
    - PSRR shape 单调下降
  Step 3: identify deviation 分类
    - vout 偏离 → DC offset 类（症状 2）
    - vout 振荡 → 不稳定（症状 1）
    - vout 不上 → 启动失败（症状 3）
    - PSRR 不达 → PSRR 类（症状 4）
  Step 4: trace upstream（用 signal-tracing skill）
  Step 5: verify cheapest（dc_snapshot 看上游而不是改 EA 重仿）
```

完整 mental model 见 skill `meta-cognitive/systematic-debugging`。

## 不在本章范围

- **EA polarity 决策（NMOS / PMOS）**——见 `chapter=architecture` § "EA 输入对极性"
- **AC 断点 / Rfb / Cfb 配置**——见 `chapter=ac-stability`
- **PSRR 频段特性详解**——见 `chapter=psrr`
- **负载瞬态过冲设计 / 验证**——见 `chapter=overshoot`
- **bandgap startup**——见 `blocks/bandgap/troubleshooting.md`
- **bias generator startup helper**——见 `blocks/base-cells/bias-generator/startup-helper.md`
