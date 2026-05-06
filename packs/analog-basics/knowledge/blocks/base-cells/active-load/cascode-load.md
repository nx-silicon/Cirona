---
chapter: cascode-load
parent: active-load
summary: |
  Cascode 作 load —— mirror-load 上叠 cascode 管屏蔽 Vds 调制 /
  R_load = gm_casc · ro² / Av 再 ↑ 5-20× / 多 1×Vdsat headroom 代价
tokens: ~600
prerequisite_chapters: []
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/cascode
  - blocks/base-cells/current-mirror
---

# Cascode Load

## 拓扑（mirror load + 上叠 cascode 管）

```
        VDD ─────────┬─────────┐
                     │         │
                ┌────┴───┐ ┌───┴────┐
                │ M3a    │ │ M4a    │ ← bottom mirror（基础 mirror）
                │ (PMOS) │ │ (PMOS) │
                └────┬───┘ └───┬────┘
                     ●         ●  ← 内部节点 V_internal
                ┌────┴───┐ ┌───┴────┐
        Vbcp ──→│ M3b    │ │ M4b    │ ← top cascode（屏蔽 Vds 变化）
                │ (PMOS  │ │ (PMOS  │
                │ casc)  │ │ casc)  │
                └────┬───┘ └───┬────┘
                     ●         ●─── Vout
                          ⋮
                  (差分对 M1/M2 + I_tail 在下方)
```

**核心机制**（cascode 的本质应用）：
- M3a/M4a 是 mirror（提供电流复制）—— PMOS source 接 VDD，drain 接 V_internal
- M3b/M4b 是 cascode（屏蔽 V_internal 受 Vout 变化影响）—— PMOS source 接 V_internal，drain 接 Vout，gate=Vbcp
- → mirror M4a 的漏端节点 **V_internal = Vbcp + |Vgs_M4b|** —— 该节点由 cascode 管 + Vbcp 共同决定，与 Vout 解耦
- → 因 V_internal 与 Vout 解耦，mirror M4a 的 |Vds| = VDD - V_internal 几乎不受 Vout 摆幅影响 → 镜像比例误差大幅降低
- 同时 → Rout = gm_M4b · ro_M4b · ro_M4a → 增益放大

## 小信号公式

### Rout = gm_casc × ro_casc × ro_mirror

```
Rout = gm_M4b × ro_M4b × ro_M4a
     ≈ (gm·ro)² level（1-100 MΩ）
```

### Av = gm_drv × Rout（与 input pair 同侧 cascode 平衡）

```
Av = gm_M1 × (Rout_load ‖ Rout_drv)
```

| 工艺 / sizing | Av 典型 |
|---|---|
| 180nm 4×Lmin / Vov 200mV | 60-80 dB（增 5-20× vs mirror only）|
| 65nm 4×Lmin | 40-60 dB |

## Headroom 代价（关键约束）

每多一层 cascode → 多 1×Vdsat headroom。

```
V_out_max（PMOS cascode load）= VDD - 2×|Vdsat_p|  （vs mirror only：VDD - |Vdsat_p|）
```

@ VDD = 1.8V / Vdsat = 0.15V → mirror only swing = 1.65V；cascode 后 = 1.5V（损 150mV）。

@ VDD = 1V（低压工艺） → mirror only 0.85V；cascode 后 0.7V → 损 18% swing。

**因果**：低压工艺（< 1.2V VDD）下 cascode-load 头压不够 → 通常用 wide-swing cascode 或回退到 mirror-load + L 加大。

## Cascode bias（Vbcp）选择

> ⚠️ **关键物理审查点**：cascode 底部管（M4a）的 |Vds| = VDD - V_internal = VDD - (Vbcp + |Vgs_M4b|)。
> 这是网络决定的，**不是 M4a 自己**。如果 Vbcp 设得不合适（太高 → V_internal 顶到 VDD）→ M4a |Vds| 过小撞 triode。
> 修复方向：**调 padding device sizing 调 Vbcp**，**不**调 M4a 的 W/L。
> （详细 cascode bias 物理见 `blocks/base-cells/cascode/troubleshooting.md`）

| Vbcp 选择 | M4a 的 |Vds| 结果 |
|---|---|
| Vbcp 太高（如 VDD - small Vov_M4b）| V_internal 贴 VDD → \|Vds_M4a\| ≈ 100 mV < \|Vov_M4a\| → **triode** |
| Vbcp 合适（VDD - \|Vov_M4b\| - \|Vgs_M4b\| - 100mV margin 区间）| \|Vds_M4a\| ≈ 200 mV > \|Vov_M4a\|，安全 sat |
| Vbcp 太低 | 浪费 headroom（M4b 上的 \|Vds\| 过大），但安全 |

## sizing 关系

| 量 | 推荐范围 | 因果 |
|---|---|---|
| W_M4a (mirror)| 与 M3a 同（mirror tracking）| 镜像比例靠 m 比例不靠 W ratio |
| L_M4a | 4-8 × Lmin | matching + ro |
| W_M4b (cascode top)| 与 M4a 同或略大 | gm·ro 决定屏蔽效果；W 大 → gm 大、Vov 小（headroom 改善），但 Cgs/Cgd 增大 → 内部极点降 / 速度损 |
| L_M4b | 与 M4a 同（4-8 × Lmin）| 与底部管 ro 量级匹配 |
| Vbcp | VDD - Vov - Vgs - 100 mV | bias 头压预留 |
| 整体 swing | VDD - 2×Vdsat | 比 mirror-only 损 1×Vdsat |

## sizing 范例（telescopic OTA cascode load）

> 📌 **@ vpdk180nm**：以下数值用 vpdk180nm BSIM 工艺常数（μp·Cox ≈ 67 µA/V²、|Vth_p| ≈ 0.5 V、long-channel L ≥ 1µm 时 VA ≈ 10 V/µm 让 ro = VA·L/Id 公式接近实测）。**换工艺需重算 ro 数值**——short-channel 工艺（L < 0.5µm）的 VA_eff 通常比 10 V/µm 小 2-5×，公式估值偏高，需 BSIM 实测；公式形式（Rout = gm·ro·ro）跨工艺通用。

设计目标：Av = 80 dB / Itail = 20 µA / VDD = 1.8 V / 摆幅 ≥ 1.4 V

```
mirror M4a sizing: 同 mirror-load 范例（Vov=0.2V, L=1.5µm, W≈1.5µm）

cascode M4b sizing:
  Vov_M4b = 0.15V（保 swing）
  gm_M4b 由 gm/Id = 12 @ Id=10µA → gm = 12 × 10 µA/V = 120 µS
  L_M4b = 1.5 µm（与底部 mirror 同 L）
  W_M4b 由 gm/Id 表 → ~1 µm

Vbcp 计算（PMOS cascode）:
  |Vgs_M4b| = |Vth_p| + |Vov_M4b| = 0.5 + 0.15 = 0.65 V
  目标让 |Vds_M4a| ≥ |Vov_M4a| + 100mV margin = 0.3 V → V_internal ≤ VDD - 0.3 = 1.5 V
  V_internal = Vbcp + |Vgs_M4b| = Vbcp + 0.65 → Vbcp ≤ 1.5 - 0.65 = 0.85 V
  取 Vbcp = 0.85 V

Rout 验证:
  ro_M4a ≈ VA·L/Id = 10·1.5/10µ = 1.5 MΩ @ Id=10µA / L=1.5µm（vpdk180nm long-channel 估）
  ro_M4b ≈ 1.5 MΩ
  gm_M4b·ro_M4b·ro_M4a = 120µ × 1.5M × 1.5M = 270 MΩ → 显著大于 mirror only ~1.5 MΩ
  （BSIM 实测可能再降 20-50%，仍远高于 mirror only）

Av:
  Rout_drv（NMOS cascode 同侧）≈ 同量级（NMOS μn 大但 L 同，ro 量级相近，~1-2 MΩ → cascode 后 ~200 MΩ）
  Rout_total = Rout_load ‖ Rout_drv ≈ 100 MΩ
  Av = gm_M1 × Rout ≈ 133 µS × 100 MΩ ≈ 1.3e4 V/V → 82 dB（理论上限）
  实际限制：ro 二阶 / 寄生 / cascode 非理想 → 实测 OTA 增益 70-80 dB ✓ spec 80 dB（边界）

swing:
  V_out_max = VDD - 2×Vov_p ≈ 1.8 - 2×0.18 = 1.44V ✓ spec
  V_out_min = VSS + 2×Vov_n ≈ 0.36V → 1.08V swing PP
```

## 验证清单

- [ ] dc_snapshot：M4a / M4b 都 saturation（**关键**：M4a 的 Vds 由 Vbcp 决定不是 M4a 自己；用 skill `signal-tracing` 反推 Vbcp）
- [ ] dc_snapshot：Vbcp 在合理范围（不撞 rail）
- [ ] AC：Av 显著高于 mirror-only（5-20×）
- [ ] AC：BW 比 mirror-only 略低（高 Rout × Cload 极点更低）
- [ ] PVT corner：Vbcp 漂 < 30 mV / M4a.Vds 仍 > Vov + margin

## 常见误区

| 心里想 | 现实 |
|---|---|
| "M4a triode → 增 M4a 的 L 修" | **物理错误**：\|Vds_M4a\| 不是 M4a 自决的，由 V_internal = Vbcp + \|Vgs_M4b\| 决定（\|Vds_M4a\| = VDD - V_internal）；改 Vbcp 或偏置生成，不改 M4a |
| "cascode-load 摆幅与 mirror 一样" | 错——多 1×Vdsat headroom 代价（相对 mirror）|
| "Vbcp 用固定 V_REF 给" | PVT 漂 → Vov 漂 → M4a.Vds 漂；用 padding device 跟踪偏置 |
| "cascode 总比 mirror 好" | 摆幅紧张 / 低压工艺时 mirror + 长 L 更优 |

## 不在本章范围

- mirror-load（不带 cascode）→ chapter `mirror-load`
- diode-load → chapter `diode-load`
- 故障 debug → chapter `troubleshooting`
- cascode bias 生成（padding device）/ cascode 物理详细 → `blocks/base-cells/cascode/`
- wide-swing cascode（低压工艺替代）→ `blocks/base-cells/cascode/wide-swing.md`（待写）
- telescopic OTA 整体 → `blocks/telescopic-ota/`
