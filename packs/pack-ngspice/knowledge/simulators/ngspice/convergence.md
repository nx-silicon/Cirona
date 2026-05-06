---
chapter: convergence
parent: ngspice
summary: |
  ngspice 不收敛 / 矩阵奇异 / DC OP 漂移诊断 + .options 调整因果链
tokens: ~800
prerequisite_chapters:
  - analyses
related_skills:
  - meta-cognitive/systematic-debugging
  - circuit-method/signal-tracing
  - circuit-method/causal-chain-debug
---

# ngspice 收敛问题

## 不收敛的三种症状（对照诊断方向）

| 症状 | 表现 | 物理含义 | 优先怀疑 |
|---|---|---|---|
| `singular matrix` | DC OP 立即报错 | 雅可比矩阵奇异（某行/列全零）| 浮节点 / 漏掉 .nodeset / 全容性回路 |
| `no convergence in <n> iterations` | 跑很久后报错 | 牛顿迭代不收敛到 reltol/abstol | 强非线性（开关 / 钳位）/ 高阻节点初值远 |
| `convergence without sense` | 报"成功"，但 DC OP 漂到轨 / NaN | 数值收敛但物理无意义 | 反馈环未闭合 / DC bias 路径断 / 极端 sizing |

**关键观察**：第 3 类是最危险的——ngspice 不报错但结果错。AC 跑出来 gain = -148 dB / 相位乱跳就是这个症状传染到 AC。

## 收敛的物理基础（先理解为什么会失败）

ngspice 用**修改牛顿法**求解非线性方程组：

1. **初值**：上次时间步 / DC OP 解（首次用 `.nodeset` 或全零）
2. **线性化**：每个非线性器件围绕当前点做雅可比展开
3. **迭代**：解线性方程组 → 更新 → 检查 reltol/abstol → 不行再来
4. **失败条件**：超 itl1/itl4 / 矩阵奇异 / 残差不下降

**失败 → 先问**：是 (a) **初值不好** 还是 (b) **方程本身病态**？两者修法完全不同——前者改 `.nodeset` / 节点 `.ic`，后者改电路 / 加 gmin。

## 矩阵奇异（singular matrix）—— 几乎都是电路问题

### 浮节点（floating node）

**原因**：某节点没有任何 DC 路径到 ground / 已知电压（如电容回路两端都是浮的）

**判别**：
- ngspice log 通常给出 "Node X has no DC path to ground"
- 手工确认：从 vss 出发，能否沿电阻 / DC 电压源 / DC 电流源到达每个 vdd 上方的节点？

**修复方向**（按破坏性升序）：
- 加一个 1G 大电阻接 ground（不影响 AC，但 DC 解出来）—— 临时调试用
- 改电路：补缺的 bias 路径 / 检查反馈是否真的闭合
- 加 `.nodeset v(node)=<估值>` —— 给牛顿法一个起点，但**节点必须有 DC 路径**否则只是延后失败

### 全容性回路 / 全感性割集

**原因**：纯 C 串联无电阻 / 纯 L 并联无电阻——KCL 在 DC 退化

**修复**：加微小串联电阻（µΩ 量级即可，不影响 AC 频段）

### 漏掉 vss 接地

**原因**：把 `vss` 当成全局节点忘了 `Vvss vss 0 0`

**判别**：网表里搜 `vss`，确认有一行 `Vvss vss 0 0` 或 `.global vss` + `vss 0 0` 起源

## 牛顿迭代不收敛 —— 优先调 .options

### 默认值 vs 病态情况

| 选项 | 默认 | 含义 | 调整后果 |
|---|---|---|---|
| `gmin` | 1e-12 | 每节点对地的最小漏导 | 增大 → 破奇异矩阵但稍偏离物理（gmin 越大模型越不准） |
| `reltol` | 1e-3 | 牛顿相对误差阈值 | 放宽 → 更容易"收敛"但精度下降 |
| `abstol` | 1e-12 (A) | 电流绝对误差 | 放宽到 1e-9 → 微小电流通路不强求精度 |
| `vntol` | 1e-6 (V) | 电压绝对误差 | 放宽到 1e-3 → 适合大电压电路（power） |
| `itl1` | 100 | DC OP 牛顿迭代上限 | 增到 300 → 给强非线性更多机会 |
| `itl4` | 10 | Tran 单步迭代上限 | 增到 40 → 开关电路 / 钳位回路必备 |
| `method` | trap | Tran 数值积分方法 | 改 `gear` → 数值阻尼大，振荡 / 容性回路稳定 |

### .options 调整候选（按"破坏性"升序）

不收敛时**不要一次全改**——破坏性大的会让结果不可信。下表按破坏性升序列候选项，独立尝试，无效再叠加：

| 破坏性 | 选项 | 适用场景 | 物理影响 |
|---|---|---|---|
| 极低 | `.options gmin=1e-9` | 矩阵奇异 / 高阻节点初值远 | 等效每节点 1 GΩ 到地；高阻 / 低电流节点（如 cascode 内节点 / EA 输出 µA 级）影响可达 mV-10mV 级，必须比对 gmin=1e-12 与 1e-9 的 OP / 关键 spec 差异 |
| 低 | `.options itl1=300 itl4=40` | 强非线性 / 牛顿迭代不收敛 | 仅多迭代，结果不偏 |
| 中 | `.options abstol=1e-9 vntol=1e-3` | 大电压 / 大电流电路（power）| 微小电流 / 电压通路精度下降 |
| 高 | `.options reltol=0.01` | 前面全无效时最后试 | 精度从 0.1% 降到 1%，关键测量不可信 |
| 高（仅 Tran）| `.options method=gear` | 容性回路 / SC 振荡掩蔽 | 数值阻尼大，会让真 ringing 看起来稳，掩盖稳定性问题 |

### Tran 模拟用 `.ic` 设置初值

```spice
.ic v(vout)=0.9 v(vbias)=0.7
.tran 1n 100u
```

**因果**：`.ic` 强制 t=0 时节点电压（其余节点由 DC OP 推算）。和 `.nodeset` 区别：`.nodeset` 仅作牛顿法初值（解出来后被覆盖），`.ic` 在 Tran 里持续作用至 t=0+。

## DC OP 收敛但物理无意义（最危险类）

### 反馈环未闭合 → DC 漂到轨

**典型**：开环 OTA testbench `.op` 报 vout = 1.8V（轨）/ 0V（地）

**因果**：
- 开环 OTA 的 vout 没有 DC 反馈到 `vinn` → DC bias 由噪声 / 数值误差决定 → 牛顿法解出某个**任意**点
- 这个点常是轨（数值梯度趋稳）
- AC 在这个点做线性化 → 模型完全错 → gain_db = -148 dB / 相位乱

**修复**（V3 实测验证有效）：
```spice
* DC 闭环（Rfb=1G 让 vinn 跟随 vout DC）
* AC 开环（Cfb=1F 让高频 vinn 接地）
Rfb vout vinn 1e9
Cfb vinn 0   1
```
工作频率：DC ≈ 0、AC 断开点 ≈ 1/(2π·Rfb·Cfb) ≈ 0.16 nHz —— 实际仿真起点 1 Hz 远高于此 → AC 完全开环、DC 完全闭环。

**何时不能用这一招**（边界）：
- DC sweep（`Rfb` 直接路径会拖动 vout 跟 vinn）→ 需要专门的 DC sweep 测试
- 大 swing 的 Tran（Cfb=1F 会让初始大信号瞬态被 Cfb "记住"几个 µs）

更系统化的断环方法见 skill `circuit-method/ac-feedback-loop-method`（断点选择 / 反馈分压器后断 / LDO 与 OTA 的差别）。

### bias 路径断 → 节点 stuck

**症状**：DC OP 报某节点电压 0V 或轨值，但电路设计上不应该

**判别（沿信号路径反推）**：
- 不合理节点的 bias **是谁决定的**？
- 上游器件是否在它声称的 region？
- 偏置 reference 是否真的"上电"了？（参考 `circuit-method/signal-tracing` 的 Step 4 Trace upstream）

**典型例子**：bandgap reference 没启动 → Vref = 0V → 整个 LDO bias chain 全 stuck → DC OP 报"成功"但全部错。修复要看 bandgap startup 电路（startup helper / forced kick）—— 见 `blocks/bandgap/troubleshooting.md`。

## .nodeset / .ic / .options 三者的边界

| 工具 | 何时生效 | 改谁 | 误用 |
|---|---|---|---|
| `.nodeset` | DC OP / DC sweep 初值 | 牛顿迭代起点 | 给浮节点 `.nodeset` 不会让矩阵不奇异，治标不治本 |
| `.ic` | Tran t=0 初值 | DC OP 跳过、直接用 .ic 启动 | 跳过 DC OP 后 AC 拿不到正确 bias，要加 `uic`/`useinitcond` |
| `.options` | 全局求解器行为 | 数值容差 + gmin + itl | 大幅放松 reltol/abstol 后结果"收敛但错" |

## 验证清单（修完之后）

- [ ] DC OP 报"无 error"
- [ ] `print v(vout) v(<关键节点>)` 数值合理（不在轨上、与 expectation 一致）
- [ ] 改 `.options gmin=1e-9` vs `gmin=1e-12` 解相同（如果不同 = gmin 影响物理 = 需要回查电路）
- [ ] AC 跑出来 gain_dc 与手算一致（否则 DC 解错了，AC 必然错）
- [ ] 删掉所有 `.nodeset` / `.options` 后还能收敛（最终交付的 testbench 不依赖数值救济）

## 常见误区（self-check）

| 你心里想 | 实际情况 |
|---|---|
| "调 gmin / reltol 总能让它收敛" | 数值救济掩盖电路问题；先查电路 |
| "DC 收敛了 AC 就没问题" | DC 漂到轨时 AC 做的线性化是错的 |
| "加 .nodeset 总比改电路简单" | .nodeset 给浮节点没用；.nodeset 让 bias 走偏轨道反而更难 debug |
| "method=gear 数值更稳所以一直用" | gear 数值阻尼大，会让真正的 ringing 看起来收敛得太快，掩盖稳定性问题 |
| "ngspice 不报错就是结果对" | 第 3 类症状最危险，必须用 expectation_compare 工具或手算对照 |

## 不在本章范围

- **AC 断环具体配置**（不同电路 Rfb/Cfb 选择 / 断点位置）→ skill `circuit-method/ac-feedback-loop-method`
- **bandgap startup debug**（启动失败的物理诊断）→ `blocks/bandgap/troubleshooting.md`
- **PSRR / noise 测量出错**（不是收敛问题，是测量配置问题）→ `chapter=measurements` + 各电路 knowledge
- **VCO startup transient**（大信号 oscillator 不振荡）→ `blocks/vco/troubleshooting.md`（待写）
