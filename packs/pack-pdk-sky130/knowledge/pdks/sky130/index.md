---
type: knowledge
domain: pdk
name: sky130
version: 1.0.0
summary: |
  SkyWater SKY130 130nm 开源 PDK (Apache 2.0) 使用参考。Core 器件
  sky130_fd_pr__nfet_01v8 / pfet_01v8 1.8V，5+ Vth 变种 (lvt/hvt)，
  5V IO 器件 (g5v0d10v5)，5 corners (tt/ff/ss/sf/fs)。**关键陷阱**：
  models/all.spice 顶部有 `.option scale=1.0u`，所以 W/L 数值默认按
  µm 解释 (W=5 表示 5µm，写 W=5u 反而是 5e-12 整管废了)。

chapters:
  - name: usage-essentials
    summary: W/L 单位陷阱 + X-prefix subckt 写法 + corner 选择 + 模型名速查
    tokens: ~700

trigger:
  explicit:
    project_pdk: sky130
  implicit:
    keywords:
      - sky130
      - SkyWater
      - 130nm
      - "0.13 um"

related:
  knowledge:
    - simulators/ngspice
  tools:
    - describe_pdk
    - simulate
    - generate_testbench

hierarchy: pdk
applicable_pdks: [sky130]
applicable_simulators: [ngspice]
---

# SKY130 PDK 速查

完整设计经验沉淀在 `usage-essentials.md`。下面是 30 秒入门要点：

## ⚠️ 一号陷阱：W/L 默认 µm

`backend/pdk/sky130/models/all.spice` 顶部有 `.option scale=1.0u`。这意味着所有
传给 sky130 器件的 W/L 数值都会**自动乘以 1µm**。所以：

| 写法 | 实际尺寸 | 对错 |
|------|---------|------|
| `W=5 L=0.15` | W=5µm, L=0.15µm = 150nm | ✅ 标准用法 |
| `W=5u L=0.15u` | W=5e-12, L=1.5e-13 | ❌ **整管废了**（µ 又乘 µ）|
| `W=5e-6 L=0.15e-6` | W=5e-12, L=1.5e-13 | ❌ 同样错 |

**Iron Law: 用 sky130 写 W/L 时纯数字, 不加 u/m/e-6 后缀**。

## ⚠️ 二号陷阱：X-prefix 不是 M

sky130 器件是 `.subckt` wrapper，调用要用 X-prefix:

```spice
* ✅ 正确
XM1 vout vin vss vss sky130_fd_pr__nfet_01v8 W=1.5 L=0.15 nf=1

* ❌ 错误（M 是 BSIM primitive，sky130 已经包了 .subckt）
M1 vout vin vss vss sky130_fd_pr__nfet_01v8 W=1.5 L=0.15
```

## 核心器件名速查

| 用途 | 模型名 | VDD | Vth (typ) |
|------|--------|-----|-----------|
| NMOS core | `sky130_fd_pr__nfet_01v8` | 1.8V | 0.48V |
| NMOS LVT | `sky130_fd_pr__nfet_01v8_lvt` | 1.8V | 0.35V |
| PMOS core | `sky130_fd_pr__pfet_01v8` | 1.8V | -0.51V |
| PMOS HVT | `sky130_fd_pr__pfet_01v8_hvt` | 1.8V | -0.58V |
| PMOS LVT | `sky130_fd_pr__pfet_01v8_lvt` | 1.8V | -0.42V |
| NMOS 5V IO | `sky130_fd_pr__nfet_g5v0d10v5` | 5V | ~0.7V |
| PMOS 5V IO | `sky130_fd_pr__pfet_g5v0d10v5` | 5V | ~-0.7V |

**注意**：模型名长且 `__` 双下划线分段，不要拼错（拼错了 ngspice 会
silently 用 default model 给错误结果）。

## .lib 写法

```spice
.lib '../../pdk/sky130/sky130_tt_wrapper.lib' tt
```

或直接 include 顶层：

```spice
.include '../../pdk/sky130/models/all.spice'
.lib '../../pdk/sky130/models/corners/tt.spice' tt
```

## Corner 列表

`tt` (typical), `ff` (fast/fast), `ss` (slow/slow), `sf` (slow N / fast P),
`fs` (fast N / slow P). 全部小写。

额外: `ll` / `hh` / `mc` (Monte Carlo)。

## Mismatch 开关

```spice
.param mc_mm_switch=1   * 开 mismatch
.param mc_pr_switch=0   * 关 process variation (单独评估 mismatch 时)
```

## License

Apache 2.0 - https://github.com/google/skywater-pdk
