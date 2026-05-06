---
type: knowledge
domain: circuit
name: bias-generator
version: 1.0
summary: |
  偏置生成（bias generator）：为模拟电路提供 PVT-stable 参考电流 / 参考电压树。
  覆盖 basic mirror tree / β-multiplier / replica / level-shifter-bias / startup-helper 五大变体。

chapters:
  - name: basic-mirror-tree
    summary: 基础镜像偏置树 —— Iref 复制到多支路 / 简单电流源 / vbpc/vbnc 自洽
    tokens: ~700
  - name: beta-multiplier
    summary: β-multiplier 自偏置 —— PTAT 输出 / 双稳态分析 / 必须配 startup
    tokens: ~700
  - name: replica
    summary: Replica 偏置 —— 复制目标支路工作点 / 反馈钉住 / 与主 OTA 互动
    tokens: ~600
  - name: level-shifter-bias
    summary: 电平移位偏置 —— Vgs stack / floating Vbe / cascode bias 生成
    tokens: ~600
  - name: startup-helper
    summary: 启动辅助 —— β-multiplier 双稳态 stuck-at-zero / strong kick + 自禁用
    tokens: ~600
  - name: troubleshooting
    summary: bias chain 启动失败 / Iref 漂 PVT / 内部节点 stuck / 噪声耦合
    tokens: ~500
  - name: sizing-reasoning
    summary: |
      Wide-swing cascode bias 的 padding device 等价铁律 — Vds_padding_lower
      = Vds_被偏置 cascode 下管 + padding 链 sizing TB 模板 + FC-OTA M7
      padding worked example (含 Vov negative 实战陷阱与 R4 架构兜底)
    tokens: ~1700

trigger:
  explicit:
    user_selected_pack: bias-generator
  implicit:
    keywords:
      - bias generator
      - 偏置生成
      - 偏置树
      - bias tree
      - beta multiplier
      - PTAT
      - replica bias
      - startup
      - 启动电路
    circuit_dependency_of:
      - blocks/ldo
      - blocks/5t-ota
      - blocks/ota-fc
      - blocks/telescopic-ota
      - blocks/bandgap
      - blocks/comparator-latch

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
    - circuit-method/bias-tree-reasoning
  knowledge:
    - blocks/base-cells/current-mirror
    - blocks/base-cells/cascode
    - blocks/bandgap
  tools:
    - simulate
    - dc_snapshot
    - op_point_check

hierarchy: base-cell
applicable_pdks: any
applicable_simulators: any
authors: ["cirona team"]
---

# 偏置生成（Bias Generator）

## Quick Facts

- **核心作用**：从 PVT-stable 参考（bandgap 输出 / 外部 Iref）生成模拟电路所需的电流偏置 / 电压偏置树
- **典型输出**：vbpc / vbnc（PMOS / NMOS cascode bias）/ vb_tail（OTA tail bias）/ 多个 Iref（5T / FC / telescopic 各级）
- **五大变体**：
  - `basic-mirror-tree`：从 Iref 启动镜像出多支路；简单 + 直接 + Iref 必须独立提供
  - `β-multiplier`：自偏置 + PTAT 特性 + **必须配 startup**（双稳态有 stuck-at-zero 风险）
  - `replica`：复制目标支路工作点 + 反馈钉住 → 跟踪 PVT 优于普通镜像
  - `level-shifter-bias`：用 Vgs stack 生成各级 cascode bias / floating Vbe
  - `startup-helper`：仅在 β-multiplier 类自偏置中需要 → kick + 自禁用
- **PVT tracking 关键**：bias chain 中的镜像管必须与目标支路同型 + 同 L → V_th(L) 漂移同方向
- **Iq 设计原则**：bias chain 自身 Iq < 主电路 Iq 的 5-10%（不能让 bias 喧宾夺主）
- **stuck-at-zero 风险**：β-multiplier 自偏置有零电流稳态点 → **没 startup 必死**
- **bias tree 噪声**：每条镜像支路引入 thermal + flicker noise，**关键支路（如 OTA tail）需大 W·L 减低 1/f**

## Cheatsheet（五变体决策）

| 变体 | Iref 来源 | PVT tracking | startup 需求 | 复杂度 | 应用 |
|---|---|---|---|---|---|
| basic mirror tree | **外部 Iref**（bandgap）| 一般（看镜像 L 选择）| 无 | 低 | 标准选择 / 当 bandgap 已存在 |
| β-multiplier | **自给**（自偏置 PTAT）| 优（自然 PTAT）| **必需**（双稳态）| 中 | 独立无 bandgap 系统 |
| replica | 目标支路实测 | **极优**（复制实际状态）| 看实现 | 高 | 高精度 LDO / OTA |
| level-shifter-bias | 上级 bias | 跟随上级 | 通常无 | 中 | 生成 cascode bias |
| startup-helper | N/A | N/A | N/A | 低 | 配套 β-multiplier 等 |

## When to load this knowledge

- 设计 OTA / LDO / ADC 等需要多 bias 节点的电路
- bandgap 输出 Iref 后的偏置分发设计
- β-multiplier 自偏置 + startup 设计
- bias chain 启动失败 / PVT 漂移 / Iq 异常 → debug

## When NOT to load

- bandgap reference 自身设计（vBE / PTAT 推导）→ `blocks/bandgap`
- 单纯电流镜（不是分发树）→ `blocks/base-cells/current-mirror`
- 数字 LDO / digital regulator → 数字 IP knowledge

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `basic-mirror-tree` | 标准 Iref 分发 / 简单偏置 | ~700 | ✅ |
| `beta-multiplier` | 自偏置 PTAT / 无 bandgap 系统 | ~700 | ✅ |
| `replica` | 高精度 LDO / OTA 复制偏置 | ~600 | ✅ |
| `level-shifter-bias` | cascode bias 生成 / Vgs stack | ~600 | ✅ |
| `startup-helper` | β-multiplier 配套 startup | ~600 | ✅ |
| `troubleshooting` | bias chain 故障诊断 | ~500 | ✅ |
| `sizing-reasoning` | wide-swing padding device W/L 反推 / cascode 下管 Vds 不达标 | ~1700 | ✅ |

## Related

- Skill `circuit-method/bias-tree-reasoning` —— 沿 bias chain 推因果（"vbpc 是谁决定的"）
- Skill `circuit-method/device-sizing` —— bias 镜像 sizing 规则（同型同 L tracking）
- Knowledge `blocks/base-cells/current-mirror` —— bias tree 是镜像的级联应用
- Knowledge `blocks/bandgap` —— 上游 Iref 提供者（待建）

## 不属于本 knowledge 范围（明确划界）

- bandgap reference 设计（vBE / PTAT / Brokaw / Banba）→ `blocks/bandgap`（待建）
- 高精度 voltage reference 校准 → 系统 + 校准 knowledge
- LDO 反馈环（含 EA + pass FET）→ `blocks/ldo`
- 完整 OTA 设计（含主 bias 配置）→ `blocks/ota-*/`
- 数字 regulator → 数字 IP knowledge
