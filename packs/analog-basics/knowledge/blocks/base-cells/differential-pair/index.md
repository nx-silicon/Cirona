---
type: knowledge
domain: circuit
name: differential-pair
version: 1.0
summary: |
  差分对（differential pair）：基础 NMOS/PMOS input pair + active-load 变体 +
  current-steering 大信号开关变体 + source-degenerated 线性化变体。

chapters:
  - name: basic
    summary: 基础 diff pair 物理 + sizing + Pelgrom Vos + CMRR / CM range（轻量介绍，深入见 cm-range）
    tokens: ~700
  - name: cm-range
    summary: ⭐ 横切章 — input pair 极性 IRON LAW + PMOS ceiling / NMOS floor 双向公式 + 跨 PDK 数据 (vpdk180/55/7) + Demo 04 实证（gm ×1/83 AC 全垮）+ Step 0 self-check protocol
    tokens: ~700
  - name: active-load
    summary: 含 PMOS mirror load 的 5T-OTA 输入级（PMOS load L 必须长的 noise 因果）+ LDO EA 经典配置
    tokens: ~800
  - name: current-steering
    summary: 大信号开关模式 —— ΔV>5·Vov 一管全开一管全关 / DAC 电流舵 / CML driver / Mixer 切换 / 不同于小信号 sizing 哲学
    tokens: ~600
  - name: sizing-reasoning
    summary: R1 KVL 链 Vds_M_tail = Vincm - Vgs_M_input 反推 + R2 镜像铁律 (M_tail 改 W 必须 M_REF 同步) + diff-pair + tail mirror 联仿 TB + 5T-OTA worked example
    tokens: ~1500
  - name: source-degenerated     # Week 3
    summary: 源极退化线性化（gm_eff = gm/(1+gm·Rs)）
    tokens: ~500
    status: pending
  - name: troubleshooting
    summary: tail triode / Vos 偏大 / CMRR 崩 / 输入 CM 范围不够
    tokens: ~500

trigger:
  explicit:
    user_selected_pack: differential-pair
  implicit:
    keywords:
      - 差分对
      - diff pair
      - differential
      - input pair
      - 输入对
    circuit_dependency_of:
      - blocks/ldo
      - blocks/5t-ota
      - blocks/ota-fc
      - blocks/comparator-latch

related:
  skills:
    - circuit-method/device-sizing
    - circuit-method/signal-tracing
    - circuit-method/region-inspection
  knowledge:
    - blocks/base-cells/current-mirror      # tail / mirror load 用 CM cell
    - blocks/base-cells/cascode             # cascoded diff pair 中 cascode 上叠
    - blocks/base-cells/bias-generator      # tail bias 来源
  tools:
    - sizing/design_diff_pair
    - extract/extract_diffpair_metrics
    - simulate
    - dc_snapshot
    - op_point_check

hierarchy: base-cell
applicable_pdks: any
applicable_simulators: any
authors: ["cirona team"]
---

# 差分对（Differential Pair）

## Quick Facts

- **核心机制**：两个匹配 device M1 / M2 共 source（接 tail current）+ 两路输入 vinp / vinn → 输出端电流差 = 输入电压差 × gm
- **gm per device** = (gm/Id) × Id_branch；total differential gm = gm_per_device（差分模式电流是 ±ΔId）
- **Vos（input-referred offset）** ≈ Avt / √(W·L)（Pelgrom，σ_1sigma）
- **CMRR** ∝ gm_diff / gm_cm；tail current source 的 ro_tail 越大 CMRR 越好
- **Input CM range**：NMOS input 限低端（tail 撞地），PMOS input 限高端（tail 撞 VDD）
- **输入对极性选择**（与 LDO Vref 范围对齐）：Vref ≥ 1.0V 用 NMOS / Vref ≤ 0.8V 用 PMOS / 中间用折叠
- **PMOS load L 必须长**（如果配 PMOS active load）—— noise / matching / gds 三重收益

## Cheatsheet（基础 diff pair 关键数值）

| 量 | 公式 / 范围 | 因果 |
|---|---|---|
| gm | (gm/Id) × Id_branch | typical 50-500 µS per device |
| Av_single（含 active load）| gm × (ro_diff ‖ ro_load) | typical 30-50 dB |
| Vos σ_1sigma | Avt/√(W·L) | Avt ≈ 5 mV·µm (NMOS) |
| Vos σ_3sigma | 3 × σ_1sigma | spec 通常 1-10 mV |
| input CM min（NMOS input）| Vov_tail + Vth + Vov_diff | tail headroom + Vgs_diff |
| input CM max（NMOS input，with PMOS load）| VDD - Vov_load | load 留 headroom |
| CMRR_db | 20·log(gm_diff / gm_cm) | typical 60-90 dB |
| f_unity（接 CL）| gm/(2π·CL) | OTA 速度 |

## When to load this knowledge

- 设计 OTA / EA / comparator preamp 的输入级
- 设计 LDO 误差放大器的输入差分对
- 设计 DAC / CML driver（current-steering 模式）→ chapter=current-steering
- debug input pair Vos / CMRR / CM range 问题

## When NOT to load

- single-ended 信号链（无差分）→ `blocks/base-cells/common-source`
- 已确定用 OTA-5T 完整结构 → 直接 `blocks/5t-ota`（含 diff pair 配 mirror load 的整合）
- comparator 的 latch 部分 → `blocks/base-cells/comparator-latch`

## Chapter Index

| Chapter | 何时加载 | tokens | 状态 |
|---|---|---|---|
| `basic` | 基础 NMOS/PMOS diff pair sizing | ~700 | ✅ Week 2 |
| `active-load` | 配 PMOS mirror load（5T-OTA 输入级）| ~600 | ⏳ Week 3 |
| `current-steering` | DAC unit cell / CML driver / Mixer 切换器 / 大信号开关模式 | ~600 | ✅ Week 4 |
| `sizing-reasoning` | pre-sim sizing Step 2-4：R1 KVL Vds_tail 反推 + R2 镜像铁律 (M_tail/M_REF 同步) + 5T-OTA TB | ~1500 | ✅ W6+ |
| `source-degenerated` | 源极退化线性化 | ~500 | ⏳ Week 3 |
| `troubleshooting` | debug Vos / CMRR / CM range / tail triode | ~500 | ✅ Week 2 |

## Related

- **Skill `circuit-method/device-sizing`** —— Pelgrom + gm/Id 推导 W/L
- **Skill `circuit-method/signal-tracing`** —— input pair tail triode 时反推 vcm 来源
- **Knowledge `blocks/base-cells/current-mirror`** —— tail current source / PMOS active load mirror
- **Knowledge `blocks/base-cells/cascode`** —— cascoded diff pair（tail cascode）
- **Knowledge `blocks/base-cells/bias-generator`** —— tail bias 生成
- **Tool `sizing/design_diff_pair`** —— 自动产 spec → W/L/m + SPICE subckt + derivation
- **Tool `extract/extract_diffpair_metrics`** —— 仿真 wrdata → gm/Vos/CM range KPI

## 不属于本 knowledge 范围（明确划界）

- **5T-OTA / cascode-OTA / 双级 OTA 完整设计**——见 `blocks/ota-*`
- **PMOS load 自身 sizing**（input pair 的 active load）——见 `blocks/base-cells/current-mirror`（PMOS load 是 mirror 拓扑）
- **tail current source**（独立 device）——见 `blocks/base-cells/current-mirror` 或 `blocks/base-cells/bias-generator`
- **比较器 metastability / kickback**（虽然 comparator preamp 用 diff pair）——见 `blocks/base-cells/comparator-latch`
- **fully-differential opamp 的 CMFB 部分**——见 `blocks/base-cells/cmfb`
