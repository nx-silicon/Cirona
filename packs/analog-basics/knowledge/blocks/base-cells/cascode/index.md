---
type: knowledge
domain: circuit
name: cascode
version: 1.0
summary: |
  Cascode（共栅堆叠）：上管 common-gate 屏蔽下管 Vds 漂移，
  把单管 ro 量级 Rout 提升到 gm·ro² 量级。基础变体 + gain-boosted 变体。

chapters:
  - name: basic
    summary: 基础 cascode 物理 + sizing + bias 决定下管 Vds 因果链
    tokens: ~700
  - name: gain-boosted
    summary: 内嵌 local OTA 把内节点 Vx 钉到目标值，Rout 再提升 A_local 倍 / Av ≥ 100 dB 用
    tokens: ~700
  - name: troubleshooting
    summary: 下管 triode / Rout 不达预期 / output swing 不足 三类症状对照
    tokens: ~500
  - name: sizing-reasoning
    summary: R1 KVL 链 Vds_M_low=Vbc-Vgs_casc 反推具体化 + cascode 链单独 sizing TB 模板 + folded-cascode OTA M7 worked example（pre-sim 通用 sizing 流程 Step 2-3 入口）
    tokens: ~1300

trigger:
  explicit:
    user_selected_pack: cascode
  implicit:
    keywords:
      - cascode
      - 共栅堆叠
      - 增益增强
      - high-Rout
      - gm*ro^2
    circuit_dependency_of:
      - blocks/ldo
      - blocks/ota-fc
      - blocks/telescopic-ota
      - blocks/base-cells/current-mirror   # cascoded variant 用此知识

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
    - circuit-method/bias-tree-reasoning
  knowledge:
    - blocks/base-cells/current-mirror     # cascoded mirror 用本 cell 的 cascode 块
    - blocks/base-cells/bias-generator     # cascode bias 由此 block 生成
    - blocks/base-cells/common-gate-stage  # common-gate 是 cascode 上管的另一应用
  tools:
    - sizing/design_current_mirror         # cascode variant 直接产生 cascode 镜像 sizing
    - simulate
    - dc_snapshot
    - op_point_check

hierarchy: base-cell
applicable_pdks: any
applicable_simulators: any
authors: ["cirona team"]
---

# Cascode（共栅堆叠）

## Quick Facts

- **核心机制**：上管 M_casc（common-gate 配置）屏蔽下管 M_lower 的 Vds 漂移，让下管看起来是"理想电流源"
- **Rout 提升**：单管 ro_lower → 堆叠后 gm_casc × ro_casc × ro_lower（典型 100-1000×）
- **代价**：output swing 减小 = Vds_sat_lower + Vds_sat_casc（两个 Vov 堆叠）
- **关键物理**：**M_lower.Vds = Vbias_casc − Vgs_casc**——不是 M_lower 自己决定的，**这是 LDO/OTA cascode 设计最常踩的物理坑**
- **下管 triode 修复方向**：调上游 bias generator 的 padding device 把 Vbias_casc 顶上去（不是改 M_lower 的 W！）
- **与 cascoded current mirror 区别**：本 cell 是"通用 cascode 块"（增益增强模式），cascoded mirror 是把它内嵌到镜像结构中
- **与 common_gate_stage 区别**：本 cell 上管是为下管"屏蔽 Vds"，common_gate_stage 是为输入信号"提供低 Rin / 弱 Miller"

## Cheatsheet（基础 cascode 关键数值）

| 量 | 公式 / 范围 | 备注 |
|---|---|---|
| Rout | gm_casc × ro_casc × ro_lower | typical 10-100 MΩ |
| 单管 ro | VA·L / Id | VA ≈ 10 V/µm（NMOS）, 8 V/µm（PMOS） |
| Vds_lower | **Vbias_casc − Vgs_casc** | **不是 M_lower 自决** |
| Vgs_casc | Vth + Vov_casc ≈ 0.5–0.7 V | 工艺常数 |
| Vds_sat_lower | Vov_lower ≈ 100–250 mV | gm/Id 决定 |
| Vbias_casc 目标 | Vov_lower + Vgs_casc + 50mV margin | 让 M_lower 安全 sat |
| output swing 损失 | 2×Vov_sat ≈ 200–500 mV | 两 device 堆叠代价 |

## When to load this knowledge

- 设计 OTA / LDO / current source 时需要高输出阻抗（gm·ro² 量级）
- 看到 dc_snapshot 显示 cascode 底部管 M_lower 在 triode（典型 LDO/OTA debug 场景）
- 选 active load topology 时考虑 cascode load
- 评估 cascoded current mirror 的 cascode bias 设计

## When NOT to load

- 简单 single-stage 不需要高 Rout → `blocks/base-cells/common-source` 即可
- 需要更高 Rout（GΩ 量级 + 钉死内节点）→ `chapter=gain-boosted`
- 上管作为输入级（不是屏蔽下管）→ `blocks/base-cells/common-gate-stage`
- cascoded current mirror 的镜像精度问题 → `blocks/base-cells/current-mirror/cascoded.md`

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `basic` | 基础 cascode sizing / bias 设计 | ~700 | ✅ Week 2 |
| `gain-boosted` | 需要 GΩ Rout / Av ≥ 100 dB / 高精度 ADC EA | ~700 | ✅ Week 4 |
| `troubleshooting` | debug 下管 triode / Rout 偏低 / swing 紧张 | ~500 | ✅ Week 2 |
| `sizing-reasoning` | pre-sim 通用 sizing 流程 Step 2-3（R1 KVL Vds_lower 反推 + cascode 链 TB + FC-OTA M7 worked example） | ~1300 | ✅ W6+ Sizing |

## Related

- **Skill `circuit-method/signal-tracing`** —— 下管 triode 时反推 Vbias_casc 来源（不是改 M_lower）
- **Skill `circuit-method/bias-tree-reasoning`** —— Vbias_casc 由谁生成 / 如何匹配下管
- **Skill `circuit-method/device-sizing`** —— cascode 上管 / 下管 sizing 配比
- **Knowledge `blocks/base-cells/current-mirror/cascoded.md`** —— cascode 应用于镜像结构
- **Knowledge `blocks/base-cells/bias-generator`** —— Vbias_casc 的物理来源（padding device + cascode device 匹配）
- **Tool `sizing/design_current_mirror`**（variant=cascode）—— 直接产 cascode 镜像 sizing
- **Tool `dc_snapshot` + `op_point_check`** —— 验证 M_lower 是否真在 saturation

## 不属于本 knowledge 范围（明确划界）

- **cascoded current mirror 镜像精度**——见 `blocks/base-cells/current-mirror/cascoded.md`
- **gain-boosted 内嵌 OTA 设计**——见 `chapter=gain-boosted`
- **folded-cascode OTA 完整拓扑**——见 `blocks/ota-fc/`
- **telescopic OTA 拓扑**——见 `blocks/telescopic-ota/`
- **common-gate 作为输入级**（TIA / LNA）——见 `blocks/base-cells/common-gate-stage`
- **wide-swing cascode bias 生成**——见 `blocks/base-cells/bias-generator`
