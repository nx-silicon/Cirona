---
chapter: overshoot
parent: ldo
summary: |
  LDO 负载瞬态过冲分析：物理因果链（ΔIload × tresponse / Cload）+
  EA slew rate 限制 + Cload 大小 trade-off + 补偿调整
tokens: ~600
prerequisite_chapters:
  - architecture
  - ac-stability
related_skills:
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/miller-compensation
---

# LDO 负载瞬态过冲

## 物理因果链

负载阶跃（如 1mA → 50mA in 1µs 边）→ Iload 突增 → Cload 上电荷被快速抽走 → vout 暂时 droop（下冲）→ EA 检测 vfb 偏低 → EA 输出推高 vg_pass → pass FET 流通更多 Iload → vout 恢复。

**过冲 / 下冲幅度**：
```
Δvout ≈ ΔIload × tresponse / Cload
```

其中 `tresponse` 是 EA + pass FET 反馈环响应时间（取决于 loop bandwidth 和 slew rate）。

## 关键变量与 trade-off

| 变量 | 影响 | 因果 |
|---|---|---|
| **Cload** | 过冲幅度 ∝ 1/Cload | Cload 大 → 抗扰动能力强；面积大 / 启动慢 |
| **EA slew rate** | tresponse ∝ 1/SR | SR 大（EA bias 大）→ vg_pass 转换快 → tresponse 短 |
| **GBW（loop bandwidth）** | 小信号 tresponse ∝ 1/GBW | GBW 高 → 响应快；但太高与 fp_EA 接近 → PM 崩 |
| **pass FET gm（depend on Iload）** | 影响 fp_main 和恢复速度 | 大 Iload 时 gm 大 → 恢复快但 PM 变 |
| **ESR** | 控制 Cload 极点-零点关系 | 适当 ESR 给瞬态减阻尼振荡 |

## 典型瞬态 testbench（ngspice）

```spice
.option compat=ps
.lib    "../../pdk/vpdk180nm/vpdk180nm_corners.lib" tt
.include "../design/your_ldo.cir"

Vdd vdd 0 DC 1.8
Vref  vref 0 DC 0.9
Ibias vdd ibias 5u
* X_ldo: 5 ports = (vdd vss vout ibias vref) — 跟 .subckt 定义一致；
* vfb 是 subckt 内部 R-divider 中点节点，不暴露成 port
X_ldo vdd vss vout ibias vref  ldo_pmos_2stage
Resr  vout   vout_cap  0.1
Cload vout_cap vss       1u

* 负载阶跃：t=0-5µs 1mA / t=5µs-15µs 50mA / t=15µs+ 1mA
Iload vout vss PWL(0 1m  5u 1m  5.001u 50m  15u 50m  15.001u 1m)

.tran 10n 30u
.ic v(vout)=1.2

.control
  run
  setplot tran1
  meas tran vout_min       min v(vout) from=5u  to=10u
  meas tran vout_max       max v(vout) from=15u to=20u
  meas tran vout_dc        find v(vout) at=14u    $ steady-state heavy load
  meas tran undershoot_mv  param='1000 * (vout_dc - vout_min)'
  meas tran overshoot_mv   param='1000 * (vout_max - vout_dc)'
  echo "Undershoot=$&undershoot_mv mV, Overshoot=$&overshoot_mv mV"
.endc
.end
```

## EA Slew Rate 估算

```
SR_EA ≈ I_EA_tail / Cgs_pass
```

pass FET W ~ 1400µm → Cgs_pass ~ 2-5 pF；EA tail current ~ 20-50 µA → SR ~ 5-25 V/µs。

→ **slew rate 通常是负载瞬态响应的瓶颈**（小信号 GBW 算的 tresponse 是 worst case 下限）。

## 修复方向（按效果与代价）

| 修复 | 因果 | 代价 |
|---|---|---|
| Cload ↑（如 1µF → 10µF）| 直接减 Δvout 比例 | 面积 / 启动时间 / 成本 |
| EA bias ↑（增 SR）| tresponse ↓ | Iq ↑ |
| GBW ↑（增 EA gm）| 小信号 tresponse ↓ | PM ↓ |
| ESR 调整（对应 Cload）| 阻尼振荡 / 减 ringing | ESR 与 Cload 物料绑 |
| 加 boost cap（vfb-vout 之间）| 高频前馈 | 复杂 / 噪声 |

## 验证清单

- [ ] 负载阶跃（1mA ↔ 50mA）vout undershoot < spec（典型 50-100 mV）
- [ ] 负载阶跃 vout 恢复时间 < spec（典型 1-10 µs）
- [ ] 阶跃后 vout 无 ringing（PM > 60° 时通常 OK）
- [ ] vdd 阶跃（startup）vout 无 overshoot（启动平滑）
- [ ] 全 Iload corner（min / typ / max）瞬态都满足 spec

## 常见误区

| 心里想 | 现实 |
|---|---|
| "Cload 越大越好" | 启动慢 / 面积大 / 主极点低（与 GBW 抗争）|
| "瞬态过冲只看 EA gain" | slew rate 通常是瓶颈，gain 改善小信号但救不了 SR 限制 |
| "spec 100mV 过冲随便就达标" | 边角 Iload 跳动幅度 + corner + slew 综合，不验证全 corner 不算达标 |
| "Tran 仿真 1µs 看不到 ringing" | 仿真时间至少覆盖 5×τ_loop（典型 10-50µs）|

## 不在本章范围

- **EA slew rate 优化设计**（OTA bias 调整）→ `blocks/two-stage-ota`
- **Class AB output stage**（push-pull 大电流驱动）→ `blocks/base-cells/output-stage`
- **PSRR**（小信号扰动 vs 大信号瞬态分析）→ `chapter=psrr`
- **AC 稳定性 / PM**（小信号）→ `chapter=ac-stability`
- **完整 LDO troubleshooting** → `chapter=troubleshooting`
