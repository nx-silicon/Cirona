---
type: knowledge
domain: simulator
name: ngspice
version: 1.0
summary: |
  ngspice 仿真器知识：分析类型 / 收敛诊断 / 测量与输出 / 常见错误对照。
  事实+因果格式，章节按需加载。

chapters:
  - name: analyses
    summary: .op .dc .ac .tran .noise 分析卡 + setplot / 单位 / 跨 plot 陷阱
    tokens: ~700
  - name: convergence
    summary: 不收敛 / 矩阵奇异 / DC bias 漂移诊断 + .options 调整
    tokens: ~800
  - name: measurements
    summary: .control / let / meas / wrdata / print 体系 + vp() radians 转 deg / 跨 plot echo $&var / PM 公式两方法（OTA 用 anchor-difference / LDO 主极点 < 1Hz 用起点观察法）
    tokens: ~900
  - name: common-errors
    summary: 14 条 V3 实战踩坑 → 症状/原因/修复对照表
    tokens: ~900
  - name: testbench-patterns
    summary: ⭐ 横切章 — Testbench 激励 IRON LAW（DC 与 AC 必须用同一激励 / DC OP closed-loop 主推 + open-loop sanity 备用 / Method C / PSRR / 大信号 Tran / ICMR）+ 6 种模式速查决策表。所有 PACK reference 此章
    tokens: ~1100

trigger:
  explicit:
    project_simulator: ngspice
  implicit:
    keywords: ["ngspice", "ngspice_con", "仿真", "simulate", "AC sweep", "收敛"]
    tool_loaded:
      - simulate
      - generate_testbench

related:
  skills:
    - meta-cognitive/systematic-debugging
    - circuit-method/causal-chain-debug
    - circuit-method/ac-feedback-loop-method
  knowledge:
    - devices/bsim4
    - pdks/vpdk180nm
  tools:
    - simulate
    - generate_testbench
    - dc_snapshot
    - op_point_check

hierarchy: simulator
applicable_pdks: any
applicable_simulators: [ngspice]
authors: ["cirona team"]
---

# ngspice 仿真器知识

## Quick Facts

- 调用：Windows 用 `ngspice_con.exe -b -o <log> <tb.sp>`（`ngspice.exe` 是 GUI 变体会弹窗）；POSIX 用 `ngspice -b -o ...`
- 版本要求：ngspice 44.2+。早期版本 `compat=ps` / 跨 plot `setplot` / `trnoise` 行为不可靠
- `setplot ac1` 在混合 `.op + .ac` 后**必须**手动切换，否则 AC 矢量不可见（默认停在 `op1`）
- `vp(<node>)` 返回**弧度**不是度——是 ngspice 最常踩的坑
- `db(x)` 要求 `x > 0`；过零点会让 `.control` 块整段中断 → 用 `db(abs(x) + 1e-20)`
- `.meas` 必须在 `.control` 块内（`.meas` dot-card 形式跑不通 ACP testbench）
- 多次 `.op` 让变量活在不同 plot：`bare print/wrdata` 跨 plot 拿不到，必须用 `echo "$&var"` 内联展开
- `.option compat=ps` 第一行——没它 `{param}` 计算会静默错误

## SPICE 单位约定（必查）

- **量级符号**：`u`（µ）/ `m`（**milli！**）/ `k` / `meg`（**Mega 必须写 meg，不是 M——SPICE 历史坑**）/ `g`（giga）
- 时间 `1n` = 1 ns；电容 `1p` = 1 pF；电阻 `1k` / `1meg` / `1g`
- 数值用 e 表示法：`1e-6`，不要写 `0.000001`

> 详细分析卡 / `.options` / 测量语法见各 chapter（`analyses` / `convergence` / `measurements`）。

## When to load this knowledge

- 项目配置 `simulator=ngspice`（自动注入摘要）
- 工具 `simulate` 被加载（同上）
- 用户提到"仿真"/"AC sweep"/"收敛"等关键词
- agent 调试仿真错误 / 不收敛问题 / 测量结果异常

## Chapter Index

| Chapter | 何时加载 | tokens |
|---|---|---|
| `analyses` | 选哪种分析 / 写 testbench 时 | ~700 |
| `convergence` | 仿真不收敛 / 矩阵奇异 / DC OP 漂移 | ~800 |
| `measurements` | 写 .control / let / meas / wrdata 时 | ~600 |
| `common-errors` | 仿真报错 → 查症状对照修复 | ~900 |

## Related

- Skill: `meta-cognitive/systematic-debugging` —— 任何仿真异常先做根因分析
- Skill: `circuit-method/causal-chain-debug` —— 仿真结果偏离时沿物理因果反推
- Skill: `circuit-method/ac-feedback-loop-method` —— AC 断环测稳定性的通用思路（含 LDO / OTA 的具体断点 / Rfb / Cfb 配置见各 circuit knowledge）
- Knowledge: `devices/bsim4` —— 模型参数解读
- Knowledge: `pdks/vpdk180nm` —— vpdk 系列 PDK 配置（与 PTM 不同的 `.lib + corner` 加载方式）
- Tool: `simulate` —— 调用 ngspice 跑仿真
- Tool: `generate_testbench` —— 模板化 .sp 生成

## 不属于本 knowledge 范围（明确划界）

- 怎么设计某电路 → `blocks/<电路>/`
- AC 断点位置 → skill `circuit-method/ac-feedback-loop-method`
- 不稳定 / 信号追踪 → skill `meta-cognitive/systematic-debugging` + `circuit-method/signal-tracing`
- PVT corner 策略 → skill `circuit-method/monte-carlo-mismatch-method`
- PSRR / noise 物理建模 → 各电路 knowledge 章节

ngspice knowledge 只回答"ngspice 是什么 / 怎么调它的语法 / 它有哪些坑"。
