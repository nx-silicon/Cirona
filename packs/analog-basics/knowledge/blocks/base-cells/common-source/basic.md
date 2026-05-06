---
chapter: basic
parent: common-source
summary: |
  基础 CS 放大器：物理 / Av 计算 / Miller cap 因果 / 主极点位置 / sizing
tokens: ~600
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/active-load
---

# 基础 Common-Source

## 拓扑结构

```
        Vload (active load 或 Rload 或 cascode load)
          │
          ▼
        ┌─┴─┐
   vin──│M  │──vout
        └─┬─┘
          │
        vss (NMOS) 或 vdd (PMOS)
```

## 物理 + 因果

### Av（小信号增益）
```
Av = -gm × (ro ‖ Rload)
```

| Rload 类型 | Av 量级 | 备注 |
|---|---|---|
| 电阻 R | -gm·R，5-20 dB | R 面积 / noise 限制；适合宽带 |
| diode load | -gm/gm_load ≈ -1 | 低增益、宽带 |
| current mirror load (active) | -gm·(ro‖ro_load) ≈ -gm·ro/2，30-50 dB | 高增益、BW 受限 |
| cascode load | 显著提升（用 cascode cell 包装）| 60+ dB |

### Miller cap（BW 主限制）

```
C_in_eq = Cgs + Cgd × (1 + |Av|)
```

**因果**：Cgd 跨过反相放大级 → 倍增成 Cgd·(1+Av)。Av=50dB（316×）时 Cgd 倍增 ≈ 317 倍。

→ CS 输入端 RC 时间常数被 Miller 倍增放大。这就是 Miller compensation 的物理基础（在 Cgd 上故意串个 Cc 做主极点 splitting）。

详见 `blocks/base-cells/miller-compensation/`。

### 主极点（输出节点）

```
fp_main = 1 / (2π × Rout × C_load_total)
       Rout = ro ‖ Rload
       C_load_total = C_load_external + Cgd_drain + (1+1/|Av|)·Cgd_M（feedback path）
```

**典型 OTA 第二级**：CL=1pF + Cgd Miller 倍增 → 主极点 100 kHz - 10 MHz 量级。

## Sizing Guideline

按 spec 反推：

```
Spec: 二级 EA 输出级，Av_target=25dB, Id=20µA, vdd=1.8V, CL=1pF
```

- |Av| = 10^(25/20) ≈ 17.8 V/V
- 推导关系：gm = |Av| / Rout，gm/Id = |Av| / (Rout · Id)
- 取 Rload = 1 MΩ：gm = 17.8 / 1M = 17.8 µS → gm/Id = 17.8 / 20 = 0.89 V⁻¹ → **极弱反型方向**（gm/Id < 5 通常不可用，1/f noise / 速度 / 匹配都差）
- 增大 Rload（让 gm 可减小）→ gm/Id 进一步降，方向**反了**：
   - Rload = 5 MΩ → gm = 3.56 µS → gm/Id = 0.18 → 更糟（不是改善）
- 正确改善路径：**降 Id**（gm 同样保 17.8 µS，gm/Id 上升）；或**降 |Av| 目标 + 拆级**（用 cascode 或 active load 把单级负担降到 ~15 dB / 级）
- **结论**：单管 R-load CS 在 Id 固定时做 25 dB 困难（受 R 面积/噪声/Vov 限制）。**改用 active load**（Rout = ro_drv ‖ ro_load）：
- 假设 active load ro_load = 5MΩ, ro_drive = 1MΩ → Rout = 1MΩ × 5MΩ / 6MΩ ≈ 833 kΩ
- gm = 17.8 µS / 0.833 = 21 µS → gm/Id = 21u/20u = 1.05 → 仍很弱反型
- **真要 25dB** → gm/Id ≥ 8 → gm ≥ 160 µS → 加 Id 或加 ro
- 提高 Id 到 50µA：gm = 8 × 50 = 400µS → Av = 400u × 833k = 333 → 50dB（远超）
- 真实选择：Id=20µA, gm/Id=10, gm=200µS, Vov=200mV
  - W/L = 2·Id/(μn·Cox·Vov²) = 2·20/(270·0.04) ≈ 3.7
  - L = 1µm, W = 3.7µm
  - Av = 200u × 833k = 167 = 44 dB（足够 25dB spec）

详见 skill `circuit-method/device-sizing`。

## 验证清单

- [ ] dc_snapshot 显示 M 在 saturation（Vds > Vov + 50mV）
- [ ] Av at DC 与公式 -gm·(ro‖Rload) 一致
- [ ] f_3dB 与 1/(2π·Rout·CL_total) 一致
- [ ] 大信号 swing：Vout 从 Vov 到 (VDD - Vov_load) 范围线性

## 常见误区

| 心里想 | 现实 |
|---|---|
| "CS 增益越高越好" | Av ↑ → Miller cap ↑ → BW ↓ → 不一定能用 |
| "single-stage CS 能搞定 50+ dB" | 单管 ro 限制 → 必须 active load 或 cascode |
| "电阻负载就用 1MΩ"  | 1MΩ poly 占面积大 + 4kTR 噪声大 → active load 通常更好 |
| "Cgd 不重要" | Av 大时 Miller 倍增让 Cgd 主导输入 cap |
