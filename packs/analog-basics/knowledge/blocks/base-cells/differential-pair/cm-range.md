---
chapter: cm-range
parent: differential-pair
summary: |
  Differential pair common-mode range IRON LAW — PMOS pair Vcm ceiling +
  NMOS pair Vcm floor + 双向决策树 + 跨 PDK 数据 (vpdk180/55/7) + Demo 04
  实证违反代价（gm ×1/83）。横切章：所有用 diff pair 的 PACK
  (LDO / ota-* / comparator) 在 architecture.md 中 reference 本章，不重复抄公式。
tokens: ~700
prerequisite_chapters: []
related_skills:
  - architecture_decomposition
related_knowledge:
  - blocks/ldo/architecture
  - blocks/two-stage-ota/architecture
  - blocks/folded-cascode-ota/architecture
  - blocks/base-cells/differential-pair/basic
  - pdks/vpdk180nm
  - pdks/vpdk55nm
---

# Differential Pair Common-Mode Range — IRON LAW

> **横切章**：本章是 diff-pair input pair 极性选择的物理约束 **single source of truth**。所有用 diff pair 的 PACK（LDO / ota-* / comparator）应在 architecture.md / reference-design.md reference 本章，**不重复抄公式**。

## Iron Law

**写 diff pair 网表前必须做 Vcm range self-check**。违反 → input pair sub-threshold（PMOS ceiling 违）或 tail triode（NMOS floor 违）→ AC / DC 性能崩，**调参救不了**（拓扑外冲突）。

**Demo 04 实证（违反代价）**：vpdk55nm，Vcm_in=0.9V，VDD=1.2V，agent 选 PMOS-input pair 漏检 ceiling = VDD − \|Vth_p\| − Vdsat_tail = 0.75V。Vcm_in 0.9V > 0.75V，违 150mV → M1/M2 sub-threshold → ID 60nA vs 设计 5µA → gm ×1/83 → AC 全垮（PSRR 25dB vs 50dB target），浪费 15+ turn。

## 双向公式

### PMOS-input pair (tail at top, S=VDD)

```
Vcm_max (ceiling) = VDD − |Vth_p| − Vdsat_tail
                ≈ VDD − |Vth_p| − 0.1           (Vdsat_tail 典型 0.1V)

违反症状: MP1/MP2 sub-threshold (Vsg < |Vth_p|)
          → ID drop 50-100×
          → gm drop 50-100×
          → 闭环 gain ↓ 30-40dB
          → AC 性能（PSRR / GBW / overshoot）全垮
```

### NMOS-input pair (tail at bottom, S=VSS)

```
Vcm_min (floor) = Vth_n + Vdsat_tail
              ≈ Vth_n + 0.1                     (Vdsat_tail 典型 0.1V)

违反症状: tail Vds < Vdsat → triode
          → Itail 不再恒定（随 Vcm 漂）
          → CMRR 崩
          → DC OP 漂 / 仿真"成功"但 vout 错
```

**Note**：上述是 **input pair self-check**（不考虑 mirror load 一侧）。若还需考虑 mirror load headroom，再减 Vds_load（典型 0.1V）。

## 决策规则

| Vcm_in 位置 | 必选 input pair | 物理 |
|---|---|---|
| Vcm_in ≥ PMOS ceiling | **NMOS-input pair** | PMOS pair sub-threshold 灾难 |
| Vcm_in ≤ NMOS floor | **PMOS-input pair** | NMOS tail triode |
| floor < Vcm_in < ceiling（健康区）| 看 noise / 1/f 取舍（PMOS 噪声低 1.5-3×）| 双向都 OK |
| 同时违（Vcm_in 跨 VDD/2 大范围）| **rail-to-rail（PMOS+NMOS 并联）或 folded-cascode tail** | 单极性都不行，必须升级 |

## 跨 PDK 数据（vpdk 系列）

| PDK | VDD | \|Vth_p\| | Vth_n | PMOS pair Vcm ceiling | NMOS pair Vcm floor | 健康区间宽度 |
|---|---|---|---|---|---|---|
| vpdk180nm | 1.8 V | 0.45 V | 0.40 V | **1.25 V** | 0.50 V | 0.75 V |
| vpdk55nm  | 1.2 V | 0.35 V | 0.30 V | **0.75 V** | 0.40 V | 0.35 V |
| vpdk7nm   | 0.8 V | 0.25 V | 0.25 V | **0.45 V** | 0.35 V | 0.10 V |

注：
- Vdsat_tail 取 0.1V（典型，按 sizing 可收紧到 0.05-0.15V）
- 健康区间 = ceiling − floor，反映该 PDK 选 input pair 的灵活度
- **vpdk7nm 健康区间仅 0.10V**，强烈建议 rail-to-rail 或 FC tail 拓扑（单极性几乎都不安全）

## 应用场景的 Vcm_in 来源

| 应用 | Vcm_in 来源 | 典型值范围 |
|---|---|---|
| LDO EA | Vfb（feedback node，可能经分压器降压）| ≈ Vref 或 Vout × R2/(R1+R2) |
| ADC sample-and-hold | Vref / Vsig（输入信号 + Vref 偏置）| 中间电平 ~VDD/2 |
| Two-stage OTA Stage1 | input source 工作点 | 视应用，常 ~VDD/2 |
| Comparator | Vref + Vin（差分）| 视应用 |
| 通用差分接收器 | input source 工作点 | 视应用 |

## Step 0 Self-Check Protocol

```
写 diff pair 网表前 / 进 sizing 前必做：

1. 查 PDK constants:
   VDD = ?
   |Vth_p| = ?  (查 PDK reference, 或 dc_snapshot 实测 PMOS Vth)
   Vth_n = ?    (同上)

2. 计算 ceiling / floor:
   PMOS ceiling = VDD − |Vth_p| − 0.1
   NMOS floor   = Vth_n + 0.1

3. 算 Vcm_in（来源 = LDO EA Vfb / ADC SHA Vref / 等）

4. 对照决策表 → 选 input pair 极性

5. 在 Step 0 报告里写明:
   "Vcm_in=?V, ceiling=?V, floor=?V → 选 ?-pair (理由: ?)"
```

## 仿真后判别（违反 → 反查）

| 症状 | 根因 | 修复方向 |
|---|---|---|
| dc_snapshot 看 NMOS tail Vds < Vdsat (margin 负) | **NMOS floor 违** | 换 PMOS pair OR 升 Vcm_in |
| inspect_device 看 MP1 gm < 1/10 设计期望 | **PMOS ceiling 违**（sub-threshold）| 换 NMOS pair OR 降 Vcm_in（加分压器，如 LDO Vfb 用 R1+R2 分压）|
| AC PSRR / GBW 比设计低 25-40dB | 多半是 PMOS ceiling 违（gm 损 50-100×）| 同上 |
| Iload 大时 vout 失控（30mA 不规制）| LDO 场景：EA 跨级 OL，gm 不够 | PMOS ceiling 违 / NMOS floor 违 二者必有其一 |

## Iron Law 总结

1. **每个 PDK 重算**：跨 PDK（vpdk180nm → 55nm → 7nm）\|Vth\| 和 VDD 都变，**绝对 Vcm_in 阈值（如 0.8V / 1.0V）失效**，必须每 PDK 重算 ceiling/floor
2. **数值代入证据**：Step 0 报告必须写明数值代入过程，不能只写"选 PMOS pair"。证据格式："Vcm_in=0.9V, PMOS ceiling=0.75V (vpdk55nm), 违 → 改选 NMOS pair"
3. **不能靠 sizing 救**：违反 ceiling/floor 是**拓扑外冲突**，调 W/L 不能修，必须换极性 OR 改 Vcm_in（加分压器降 / 升 ref）
4. **同时违 = 必 rail-to-rail / FC**：单极性 pair 都不安全时（健康区间为负或极窄），必须升级到 rail-to-rail（PMOS+NMOS 并联）或 folded-cascode tail 拓扑
5. **Vdsat_tail 取 0.1V 是保守起点**：tail device 实际 Vdsat 由 sizing 决定，可在 0.05-0.15V 之间。设计 critical 时应仿真后用实际 Vdsat 重算 ceiling/floor。

## Related

- L1 skill `architecture_decomposition`（架构层级化决策方法论入口）
- `blocks/ldo/architecture.md` § "EA 输入对极性 — IRON LAW"（LDO 应用 instance）
- `blocks/two-stage-ota/architecture.md` § "Stage1 Input Pair 极性 — IRON LAW"（2-stage OTA 应用 instance）
- `blocks/folded-cascode-ota/architecture.md`（FC OTA tail 选择，rail-to-rail 应用）
- `blocks/base-cells/differential-pair/basic.md` § "极性选择"（diff pair 基础物理）
- `blocks/base-cells/differential-pair/troubleshooting.md`（CM range 仿真 debug）
- `pdks/vpdk180nm` / `pdks/vpdk55nm`（\|Vth\| / VDD 实测值）
