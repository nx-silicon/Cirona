---
type: knowledge
domain: circuit
name: current-mirror
version: 1.0
summary: |
  电流镜（current mirror）：基础 / cascode / wide-swing / regulated cascode
  四变体的物理 / sizing / matching / 输出阻抗 / compliance 对照。

chapters:
  - name: basic
    summary: 基础电流镜（simple mirror）—— 物理 / sizing / matching / Pelgrom / mirror ratio
    tokens: ~700
  - name: cascoded
    summary: cascode 镜像变体 —— 输出阻抗 ↑ / compliance 代价 / cascode bias 选择
    tokens: ~750
  - name: wide-swing
    summary: wide-swing 变体 —— Vbc=Vth+2Vov 让 M_out.Vds=Vov / compliance 省 1×Vth headroom / 同 Rout / 低 Vdd 用
    tokens: ~700
  - name: regulated            # Week 3 写
    summary: regulated cascode —— gain-boost 思路 / Rout × Av 量级 / 稳定性代价
    tokens: ~600
    status: pending
  - name: troubleshooting
    summary: 4 变体共享问题 —— 输出 triode / 比例偏移 / 电源敏感 / 启动失败
    tokens: ~500
  - name: sizing-reasoning
    summary: R2 镜像铁律具体化 + 单管 sizing TB 模板 + 50µA NMOS reference worked example（pre-sim 通用 sizing 流程 Step 4 入口）
    tokens: ~1400

trigger:
  explicit:
    user_selected_pack: current-mirror
  implicit:
    keywords:
      - 电流镜
      - current mirror
      - bias chain
      - active load
      - mirror
    circuit_dependency_of:
      - blocks/ldo
      - blocks/5t-ota
      - blocks/ota-fc
      - blocks/bandgap

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
    - circuit-method/bias-tree-reasoning
  knowledge:
    - blocks/base-cells/cascode      # cascode 节点对镜像底部 Vds 的影响
    - devices/bsim4
  tools:
    - sizing/design_current_mirror
    - generate/generate_current_mirror_netlist
    - extract/extract_mirror_metrics
    - simulate
    - dc_snapshot
    - op_point_check

hierarchy: base-cell
applicable_pdks: any
applicable_simulators: any
authors: ["cirona team"]
---

# 电流镜（Current Mirror）

## Quick Facts

- **核心作用**：参考支路建立 device 工作点，复制到一/多个输出支路
- **物理基础**：M_ref 是 diode-connected（Vds=Vgs，**永远 saturation**），M_out 与 M_ref 共 Vgs → 同 region 时 Iout/Iref ≈ (W/L)_out / (W/L)_ref
- **mirror ratio 用 m 不要改单管 W**：m=4 比 W=4×Wref 的 matching 好得多（systematic + Pelgrom 收益）
- **L 是 matching 主参数**：σ(ΔVth) ∝ 1/√(WL)；2-4×Lmin 是 LDO / OTA 镜像的常见取值
- **Vds 调制误差** ≈ λ·ΔVds：典型 L 下 200mV 差 ≈ 1%；Lmin / 强 CLM 下 ≈ 2%
- **四变体速查**：`basic`（Rout ≈ ro）/ `cascoded`（gm·ro²）/ `wide-swing`（同 cascoded 但低 compliance）/ `regulated`（(gm·ro)²·ro）—— 详见各 chapter

## When to load this knowledge

- 设计 LDO / OTA / bandgap 时需要 bias mirror（系统级电路依赖此 cell）
- 看到 dc_snapshot 显示某 mirror 输出偏离 Iref 比例
- 选 OTA 拓扑时要决定用什么类型的 active load
- 评估 bias chain 结构

## When NOT to load

- 用户问的是高速开关（current steering pair / DAC unit cell）→ 用 `blocks/base-cells/differential-pair` 的 `current-steering` chapter
- 用户问的是反馈分压器 / 电压基准 → 用 `blocks/bandgap`
- 单管 active load 而非镜像 → 用 `blocks/base-cells/active-load`

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `basic` | 选 simple mirror / 做 first-pass sizing | ~700 | ✅ Week 2 |
| `cascoded` | 需要高 Rout / OTA 输出级 / LDO bias 镜像 | ~750 | ✅ |
| `wide-swing` | low-Vdd / compliance 紧张 / LDO Case C / rail-to-rail OTA | ~700 | ✅ Week 4 |
| `regulated` | 需要 GΩ Rout（高精度 ADC / LDO）| ~600 | ⏳ Week 3 |
| `troubleshooting` | debug 输出 triode / 比例偏 / supply 敏感 / 启动失败 | ~500 | ✅ Week 2 |
| `sizing-reasoning` | pre-sim 通用 sizing 流程 Step 4 选旋钮（R2 镜像铁律 + TB 模板 + worked example） | ~1400 | ✅ W6+ Sizing |

## Related

- **Skill `circuit-method/device-sizing`** —— mirror sizing 必须有 derivation chain
- **Skill `circuit-method/signal-tracing`** —— 输出 triode / 比例偏时反推上游决定因素
- **Skill `circuit-method/bias-tree-reasoning`** —— mirror 在更大 bias 链中的角色
- **Knowledge `blocks/base-cells/cascode`** —— cascoded mirror 的底部管 Vds = Vbc - Vgs_cascode 因果（关键物理审查）
- **Tool `sizing/design_current_mirror`** —— 参数化 sizing（输入 spec → 输出 W/L/m + SPICE subckt + derivation）
- **Tool `extract/extract_mirror_metrics`** —— 仿真 log → Rout / mirror ratio / matching / σ 等 KPI
- **Tool `dc_snapshot` + `op_point_check`** —— 验证 mirror DC 状态

## 不属于本 knowledge 范围（明确划界）

- cascode bias 生成 → `blocks/base-cells/bias-generator` + `blocks/base-cells/cascode`
- active load 对比（diode/mirror/cascode-load）→ `blocks/base-cells/active-load`
- gm/Id sizing 方法学 → skill `circuit-method/device-sizing`
- bias chain 整体设计 → `blocks/base-cells/bias-generator`
- LDO pass FET（不是 mirror，是 PMOS SF + EA）→ `blocks/ldo/architecture.md`
