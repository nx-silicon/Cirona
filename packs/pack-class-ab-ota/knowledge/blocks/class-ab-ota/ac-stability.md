---
chapter: ac-stability
parent: class-ab-ota
summary: |
  Class-AB OTA AC 稳定性 — Miller pole splitting + RHP zero + nulling Rz
  （同 class-A 2-stage）+ class-AB 特有的 nonlinear pole（output stage gm
  随 vout 摆动变化）+ load-dependent stability + Cc/CL ≈ 1 设计起点。
  Miller 补偿原理引用 base-cell。
tokens: ~1500
prerequisite_chapters:
  - architecture
related_skills:
  - circuit-method/ac-feedback-loop-method
related_knowledge:
  - blocks/base-cells/miller-compensation
  - blocks/two-stage-ota
---

# Class-AB OTA AC Stability

> 通用 AC 断环方法（Method C：Rfb=1G + Cfb=1F）见 `skill: ac-feedback-loop-method`。
> Miller 补偿原理（pole splitting + RHP zero + nulling Rz）见
> `blocks/base-cells/miller-compensation` + `blocks/two-stage-ota/ac-stability`。
> 本章节给的是 **class-AB 拓扑特有**的：(1) Miller 补偿差异（Cc/CL 比例大）；
> (2) class-AB nonlinear pole（gm_AB 随 vout swing 变化）；(3) load-dependent
> stability；(4) 失稳模式。

## 极点分布（class-AB 是 2-stage class-A + 推挽特殊）

class-AB OTA 与 class-A 2-stage 共享 Miller 补偿的基本框架：

### 主极点 + 次极点（同 class-A 2-stage）

```
f_p1' ≈ 1 / (2π · R_stage1_out · Cc · A_AB)   ← Miller 推主极点 ↓
f_p2' = gm_AB / (2π · CL)                      ← 次极点 (push-pull gm)

GBW = gm_M1 / (2π · Cc)
```

详见 `blocks/two-stage-ota/ac-stability`。

### Class-AB 特有：Output stage gm 是 push-pull 双管

```
quiescent state: gm_AB = gm_MP_out + gm_MN_out (并联)
  设计 IQ ≈ 100 µA per device → gm ≈ 1-2 mS each → gm_AB ≈ 2-4 mS

dynamic state（信号 swing）：
  vout ↑ → MP_ab_out 推大电流 (gm_p ↑)，MN_ab_out 减导通 (gm_n ↓)
  vout ↓ → 反向
  → gm_AB(vout) 是 vout 的非线性函数
```

**关键事实**：**class-AB 的 next pole f_p2' 也随 vout swing 变化**——
quiescent 时较高（gm_AB 大），swing 大时较低（一边管 gm 主导）。
**PM 在不同 output level 下不同**——必须验证 worst case。

### Class-A vs Class-AB 对比

| 项 | Class-A 2-stage | Class-AB |
|---|---|---|
| Stage1 极点 | 同 | 同 |
| Stage2 gm（quiescent）| gm_MN6 (单管) ≈ 1 mS | gm_MP_out + gm_MN_out (并联) ≈ 2 mS |
| Stage2 gm（dynamic）| 几乎不变（class-A 静态电流恒）| 大幅变化（push-pull）|
| Cc/CL 起点 | 0.25-0.30 | **0.5-1.0** |
| RHP zero | f_z = gm_MN6 / (2π · Cc) | f_z 类似但 gm 是 push-pull 等效 |
| Nulling Rz | Rz = 1/gm_MN6 | Rz = 1/gm_MN_out (固定，但 gm 跨 swing 变 → 抵消不全) |

> **Cc/CL 起点为何 class-AB 大**：output stage 寄生 cap（output devices Cgd /
> Cdb）随 W·m 大幅增加，影响 next pole；同时 dynamic gm 变化让 PM 不稳定 →
> 大 Cc 留 margin。**V4 reference Cc/CL = 1（5pF/5pF）是 class-AB 标准起点**。

## ⭐ 范例 1：dynamic gm 变化引发的 PM 不稳

### 症状
quiescent state（vout = VCM）：tb_ac_gain_bw 测 PM = 60° OK；
但 tb_slew 大信号 step 时 vout 接近 rail 处出现 ringing。

### 物理因果链
```
quiescent gm_AB = gm_p + gm_n ≈ 2 mS → f_p2' = gm/CL = 2mS/5pF = 64 MHz
  GBW = 200µS / 5pF = 6.4 MHz
  f_p2' / GBW = 10 → PM ≈ 84°（看似很稳）

dynamic state（vout 接近 VDD）：
  MP_ab_out 推 5 mA → gm_p ≈ √(2·µp·Cox·W·m/L · 5mA) ≈ 5 mS
  MN_ab_out 接近 cutoff → gm_n ≈ 0
  gm_AB(dynamic) ≈ 5 mS（单管主导）→ f_p2' = 5mS/5pF = 160 MHz
  
反向：vout 接近 GND → gm_n 主导 → 同样情况

但实际 ringing 出现的位置：
  vout 在 transition 中段（VCM 附近），两管同 active：
  gm_AB 在 IQ_quiescent 主导 → 与 quiescent 相同
  
ringing 实际原因：dynamic transition 时 output stage parasitic cap 等效
  C_eff(vout swing) 变化 → 主极点 + 次极点位置都漂
```

### 修复路径
| 路径 | 怎么做 | 效果 |
|---|---|---|
| 增 Cc（5 → 8 pF）| 主极点 ↓ → GBW ↓ → PM 余量 ↑ | 简单粗暴 |
| 优化 Rz（实测 dynamic gm 平均）| Rz 适应 dynamic → 大 swing 时 RHP zero 抵消改善 | 复杂；需 sweep tb |
| 加 second 补偿 cap（output cap）| 特殊技巧 — feed-forward zero | 高级，不常规 |

### 不要做
- ❌ **盲减 Cc 想 GBW 高**：Cc 减 → PM 大幅退化 → 大信号 swing 时 ringing 严重
- ❌ **大幅增 Cc（> 2 × CL）**：GBW 损失太大，class-AB 优势减
- ❌ **靠减 output W·m 减 ringing**：max drive 同步降，违反 spec

## ⭐ 范例 2：Load-dependent stability

### 症状
spec：drive CL = 5 pF。tb_ac_gain_bw 验 PM = 60° OK。
但实际 PCB / package 加 CL = 50 pF → PM < 30° 振荡。

### 物理因果链
```
PM > 60° 要求 gm_AB / CL > 3 × GBW
  → CL ↑ 10× → 同 gm_AB → f_p2' ↓ 10× → 与 GBW 比例缩 10×
  → PM 直接退化

class-AB load-driving 极限：
  CL_max = gm_AB / (3 × 2π × GBW)
        = 2mS / (3 × 2π × 6.4MHz) = 17 nF ⚠️ 这是 quiescent 极限
  实际 dynamic 时 gm_AB 大 → CL_max 大；但 quiescent state 是设计基线
```

### 修复路径
| 路径 | 怎么做 | 副作用 |
|---|---|---|
| 增 Cc 同步增大 | Cc / CL ratio 保 0.5-1 | GBW 同步降 |
| 减 GBW（spec 允许时）| GBW 自动避撞 next pole | 速度损失 |
| Output W·m ↑（gm_AB ↑）| f_p2' 高 → CL 余量 ↑ | parasitic ↑ → Cc 必须 ↑ |
| 加 LDO buffer（驱动大 CL 用 buffer）| 系统级解决 | 复杂度 ↑ |

### 边界判断
**class-AB OTA 不擅长驱动 > 50 nF 大 CL**——这种应用应换 LDO + buffer 配置。
class-AB OPAMP 设计极限通常 1-100 pF 范围。

## ⭐ 范例 3：RHP zero 跨 dynamic gm 不稳

### 症状
tb_ac_gain_bw quiescent 测 PM = 60°；但跨 dynamic state（output rail 附近）
PM 退化 10-20°；THD 中频带（fin = GBW/10）测 -55 dB OK，但接近 GBW 时 -45 dB。

### 物理因果链
```
RHP zero: f_z = gm_AB / (2π · Cc) (类比 class-A)
  quiescent gm_AB = 2 mS → f_z = 64 MHz
  dynamic (push-pull worst): gm_AB = 5 mS → f_z = 160 MHz
  → RHP zero 位置在 dynamic 状态变化

Rz = 1/gm_AB（quiescent value）：
  quiescent 时 Rz · gm = 1 → 零点 → ∞ ✓
  dynamic 时 Rz · gm ≠ 1 → 零点 在 RHP 有限位置 → PM 退化

完全消零跨 dynamic 不可能（gm 跨 swing 变化）→ class-AB 永远有 dynamic PM
变化（这是 class-AB 与 class-A 的 stability tradeoff）
```

### 修复路径
| 路径 | 怎么做 |
|---|---|
| Rz 选 quiescent gm 起点 + 实测优化 | 跨 swing 折中 |
| 加 feed-forward path | 高级补偿（不常规）|
| 减 spec THD（接受 -50 dB）| 边界放松 |

> **R2 铁律**：class-AB 永远有 dynamic gm 变化 → PM / RHP zero 跨 swing
> 不完美。**接受这个 trade-off** —— spec 留 margin 而不追完美。

## 失稳模式总结

### 模式 1: Cc 太小 → quiescent PM 不够
修复：Cc / CL ≥ 0.5（起点 0.5-1.0）

### 模式 2: Rz 偏离 quiescent 1/gm → RHP zero 主导
修复：Rz = 1/gm_AB(quiescent)；用实测 gm 不是 sizing 估算

### 模式 3: Dynamic gm 变化 → PM 跨 swing 不稳
修复：留 margin（quiescent PM ≥ 70°）；或减 Cc/CL ratio 留 dynamic margin

### 模式 4: Load CL 大于设计 → next pole 撞 GBW
修复：sizing-time 标 CL_max；overshoot 时 Cc / GBW 同步 scale

### 模式 5: Stage1 v1_out 偏 → static gm_AB 偏 → PM 数值假象
修复：先验 Stage1 mirror（见 bias-headroom 范例 4）

### 模式 6: ngspice vp() 当度数 → PM 错 57×
修复：testbench 必含 `set units = degrees`

## ngspice testbench 关键

### tb_ac_gain_bw.sp（quiescent PM）
同 2-stage class-A Method C 模板。期望 quiescent PM ≥ 60°（留 dynamic margin）。

### tb_ac_dynamic.sp（dynamic PM 跨 vout swing）
扫 vout DC 工作点（例如 vout = 0.4V / 0.9V / 1.4V），每个工作点跑 AC，看 PM 漂。

### tb_slew_ringing.sp（大信号 ringing）
大 step 测 settling，看 vout 接近 rail 时是否 ringing。

## 不在本章范围

- **通用 AC 断环原理（Method C）** → `skill: ac-feedback-loop-method`
- **Miller 补偿数学推导（pole splitting + RHP zero + Rz nulling）** → `blocks/base-cells/miller-compensation` + `blocks/two-stage-ota/ac-stability`
- **Class-A 2-stage Miller 补偿对照** → `blocks/two-stage-ota/ac-stability`
- **Vds-Vdsat 触发的 PM 假象** → `bias-headroom.md`（device 不 sat 时 PM 数值无意义）
- **Output stage Class-A vs Class-B vs Class-AB 物理** → `blocks/base-cells/output-stage`

## Related

- `skill: ac-feedback-loop-method` 通用断环 + Method C 推导
- `blocks/base-cells/miller-compensation` ⭐ pole splitting / RHP zero / nulling Rz
- `blocks/two-stage-ota/ac-stability` 2-stage class-A 对照（理解 class-AB 增量）
- `bias-headroom.md` Stage1 跨级耦合 + IQ 失控
- `simulators/ngspice/measurements` .meas 语法
