---
type: knowledge
domain: pdk
name: vpdk55nm
version: 0.1.0
summary: |
  Virtual 55nm CMOS PDK 设计参考（占位框架 — 详细数据由 AI 在 55nm
  项目跑设计过程中沉淀）。核心 device nch/pch 1.2V，Lmin=60nm，5 corners。

chapters: []   # 占位单文件 — 内容随 AI 实际使用沉淀

trigger:
  explicit:
    project_pdk: vpdk55nm
  implicit:
    keywords:
      - vpdk55nm
      - 55nm
      - "0.055 um"

related:
  knowledge:
    - simulators/ngspice
  tools:
    - describe_pdk
    - simulate
    - generate_testbench

hierarchy: pdk
applicable_pdks: [vpdk55nm]
applicable_simulators: [ngspice, hspice, spectre]
authors: ["cirona team"]
---

# vpdk55nm 设计参考（占位框架）

> ⚠️ **占位内容** — 这是 AI 学到的 vpdk55nm 工艺使用经验的起点框架。
> 详细 Vth0 / μCox / vsat / 失配系数等 BSIM4 参数典型值，需要 AI 在
> 55nm 项目中实际跑设计 / 仿真过程中验证后再沉淀写入本文件。

## Quick Facts (占位 — 待沉淀)

### 核心器件模型名（待项目实测确认）

| 设备 | 模型名 | VDD | Lmin | 备注 |
|---|---|---|---|---|
| NMOS core | `nch` | 1.2 V | 60 nm | core 设备主用 |
| PMOS core | `pch` | 1.2 V | 60 nm | core 设备主用 |
| NMOS IO | `nch_18` | 1.8 V | 180 nm | IO / level shifter |
| PMOS IO | `pch_18` | 1.8 V | 180 nm | IO |

> 上述命名约定与 vpdk180nm 一致（core 用裸名，IO 用后缀），项目跑设计时
> 验证后由 agent 通过 `memory.save` 锁定为 stable fact。

### lib 文件 / corner

```spice
.lib '../pdk/vpdk55nm/vpdk55nm_corners.lib' tt
```

可用 corners（依据用户 sar_adc_10b 项目 io_runner trace 2026-04-30）：

- `tt` — typical-typical（设计 corner）
- `ff` — fast-fast
- `ss` — slow-slow
- `fnsp` — NMOS fast / PMOS slow
- `snfp` — NMOS slow / PMOS fast

### Vth0 (TT 27°C — 实测/官方)

| 设备 | Vth0 typ |
|---|---|
| nch | ~ 0.32 V |
| pch | ~ −0.35 V |

> 待 AI 在 55nm 项目实际跑 DC sweep / op_point_check 后沉淀精确值。

## 待沉淀的事实

下列项目随 AI 在 55nm 设计过程中通过 simulate + dc_snapshot
+ 物理审查 hooks 沉淀：

- [ ] gm/Id 曲线在 vov 0~0.3V 区间的拟合系数
- [ ] short-channel ro 量级（L=60nm/120nm/240nm 各档）
- [ ] AVT0 失配系数（影响 StrongARM offset σ）
- [ ] flicker noise KF / AF 典型值
- [ ] 最高 fT 区间对应 Vov / current density

## 与 vpdk180nm 的主要差异（待补充）

- Lmin 60nm vs 180nm — 短沟道效应显著，long-channel 公式 ro ≈ VA·L/Id
  会高估 2-5×（参考 short-channel ro pitfall）
- VDD 1.2V vs 1.8V — headroom 紧张，cascode 层数受限
- Vth 更低 → off-state subthreshold 漏电更显著
