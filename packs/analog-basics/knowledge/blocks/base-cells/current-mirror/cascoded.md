---
chapter: cascoded
parent: current-mirror
summary: |
  Cascoded current mirror —— 在 basic mirror 上叠一层 cascode 管屏蔽
  Vds 调制 / Rout 提升到 gm·ro² 量级 / 代价 2×Vdsat headroom
tokens: ~750
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/device-sizing
  - circuit-method/bias-tree-reasoning
  - circuit-method/signal-tracing
related_knowledge:
  - blocks/base-cells/cascode
  - blocks/base-cells/bias-generator
---

# Cascoded Current Mirror

## 拓扑（basic mirror + 上叠 cascode）

```
            VDD
             │
    Iref ────┤
             │ (or ↓ 流出，看 NMOS/PMOS)
        ┌────┴────┐         ┌──────────┐
        │ M_ref_c │ ◄ Vbc ► │ M_out_c  │   ← cascode 层
        │  diode  │         │   gate=Vbc│
        └────┬────┘         └────┬─────┘
             ●─── Vx_ref         ●─── Vx_out
        ┌────┴────┐         ┌────┴─────┐
        │ M_ref   │ ◄─Vg──► │ M_out    │   ← basic mirror 层
        │  diode  │         │ gate=Vg  │
        └────┬────┘         └────┬─────┘
             VSS                Iout → load
```

**关键节点**：
- `Vg` = M_ref 的 Vgs（diode-connected M_ref 自洽建立）
- `Vbc` = cascode bias，由独立支路生成（见 `bias-generator/level-shifter-bias.md` 的 wide-swing pad）
- `Vx_out` = M_out 的 drain = `Vbc - Vgs_M_out_c` —— **由网络决定，不是 M_out 自己决定**

## 核心机制

cascode 层的作用是**屏蔽 M_out.Vds 受 Vout 摆动影响**：
- 不带 cascode：M_out.Vds = Vout - VSS（NMOS 镜像）→ Vout 摆 → M_out.Vds 摆 → ro 调制 → Iout 偏离 Iref
- 带 cascode：M_out.Vds = Vx_out - VSS = (Vbc - Vgs_M_out_c) - VSS —— 与 Vout 解耦
- Vout 摆动只反映在 M_out_c.Vds 上，M_out_c 通过 gm·ro 衰减影响传到 M_out.Vds 上的部分（提升 Rout 一个 gm·ro 因子）

## 小信号公式

```
Rout = gm_M_out_c · ro_M_out_c · ro_M_out
     ≈ (gm·ro) × ro_M_out
     量级：5-30 MΩ（vpdk180nm，Id = 10 µA，2×Lmin）vs basic mirror ~ 0.3 MΩ
     （short-channel L 用公式 VA·L/Id 偏低，实测 ro 在 0.2-0.5 MΩ 量级；以下表用 BSIM 实测估）
```

| 工艺 / sizing | basic Rout | cascoded Rout |
|---|---|---|
| **vpdk180nm** 2×Lmin / Vov 200mV / Id 10µA | ~ 0.3 MΩ | ~ 5-15 MΩ |
| 65nm 4×Lmin（参考，未在本 PoC 验证）| ~ 0.5-1 MΩ | ~ 10-30 MΩ |

## Compliance（输出摆幅约束）

```
V_out_min = 2 × Vds_sat ≈ 2 × Vov ≈ 200-400 mV  (vs basic ~ 100-200 mV)
```

低压工艺（VDD < 1.2 V）下 2×Vdsat 可能占用过多 headroom → 选 **wide-swing cascode**（chapter `wide-swing`），让 M_out.Vds = Vov（不是 Vgs，省一个 Vth 的 headroom）。

## Cascode bias（Vbc）的生成

⚠️ **关键物理**：M_out.Vds = Vbc - Vgs_M_out_c。Vbc 选择决定 M_out 是否进 saturation：

| Vbc 选择 | M_out.Vds 结果 |
|---|---|
| Vbc 太低（如 Vth + Vov）| M_out.Vds = Vth + Vov - Vgs ≈ 0 V → triode |
| Vbc 合适（Vth + 2·Vov）| M_out.Vds = Vov + 100mV margin → safe sat（这是 wide-swing 目标） |
| Vbc 太高 | 浪费 headroom（M_out_c 上的 Vds 过大）但安全 |

**生成方法**：用 padding diode 链（`bias-generator/level-shifter-bias.md`）让 Vbc = Vth + 2·Vov_main。详见该 chapter。

## Sizing 关系

| 量 | 推荐范围 | 因果 |
|---|---|---|
| W_M_ref_c / W_M_out_c | 与底层 M_ref / M_out 同（matching tracking）| Vds_sat 一致 → 内节点 Vx 一致 |
| L cascode | = L mirror（4-8 × Lmin）| ro 量级匹配，避免一管成 Rout 瓶颈 |
| Vbc | Vth + 2·Vov_main（wide-swing 目标）| 让 M_out.Vds = Vov，最小 headroom |
| 镜像比 N | 用 m=N（**两层 cascode 管也用 m**）| matching 远好于 W ratio |

## sizing 范例（LDO bias 镜像 1:10）

> 📌 **@ vpdk180nm**：以下数值用 vpdk180nm BSIM 工艺常数（μn·Cox ≈ 270 µA/V²、Vth_n ≈ 0.35 V）。**ro 数值需 BSIM 实测**——L = 0.36µm（2×Lmin）属 short-channel，VA_eff 比 long-channel 公式（VA=10 V/µm）小 2-5×，所以 ro 实测在 0.1-0.5 MΩ 量级而不是公式预测的 1+ MΩ；以下取 0.2 MΩ 中位估算供 sizing 参考，**生产 sizing 必须 simulate 验证**。换工艺重新仿真。

```
设计目标：Iref = 5 µA → Iout = 50 µA（10× mirror），vpdk180nm，2×Lmin

basic mirror 层:
  M_ref: W=2µm L=0.36µm m=1，Vov=0.15V，Vgs=Vth+0.15=0.65V
  M_out: 同 unit，m=10 → Iout = 50 µA

cascode 层:
  M_ref_c: 同 unit W=2µm L=0.36µm m=1（diode-connected 在 cascode bias 支路）
  M_out_c: 同 unit，m=10
  Vbc = Vth + 2×0.15 = 0.80V（由 padding 链生成，见 bias-generator）

Rout 验证:
  ro_M_out ≈ 0.2 MΩ @ Id=50µA L=0.36µm（short-channel BSIM 实测中位估，公式 VA·L/Id=72kΩ 偏低 / 实测稍高）
  ro_M_out_c ≈ 0.2 MΩ
  gm_M_out_c ≈ 12 × 50µ = 600 µS
  Rout_cascoded = gm·ro·ro = 600µ × 0.2M × 0.2M = 24 MΩ（理论）
  vs basic mirror Rout = ro_M_out ≈ 0.2 MΩ → cascode 提升约 100×
  实际 ~ 10-50 MΩ（BSIM 二阶 + Vbc 非理想 + 工艺角偏差），spec 必须 simulate 验证
```

## 验证清单

- [ ] dc_snapshot：M_ref / M_out / M_ref_c / M_out_c 全 saturation
- [ ] dc_snapshot：M_out.Vds 由 Vbc - Vgs_M_out_c 决定（用 skill `signal-tracing` 反推 Vbc 来源）
- [ ] dc_snapshot：内节点 Vx 在两支路对称（误差 < 5 mV）
- [ ] DC sweep：Vout 从 V_out_min 到 VDD，Iout 变化 < 1%（vs basic mirror 5-20%）
- [ ] PVT corner：Iout 漂 < ±10%，比例稳定 < 2%

## 常见误区（self-check）

| 心里想 | 现实 |
|---|---|
| "M_out triode → 减 W_M_out 修" | M_out.Vds 由 Vbc 决定，不是 W_M_out 决定；改 Vbc 或 padding sizing |
| "Vbc 接 VDD 简单稳" | Vbc 太高浪费 headroom，太低让 M_out triode；必须 Vth + 2·Vov |
| "镜像比靠 W 比" | matching 烂，必须用 m 比例 + 同 unit W·L |
| "cascode 多多益善" | 双 cascode 收益递减但 headroom 损 2× → > 100 dB Rout 需求才考虑 |
| "Vbc 加理想电压源仿真即可" | PVT 角下 Vbc 必须用真实 padding 链跟踪，理想源仿真"假阳性"sat |

## 不在本章范围

- basic（无 cascode）→ chapter `basic`
- wide-swing（同 cascoded 但低 compliance）→ chapter `wide-swing`
- regulated（gm-boost 进一步提 Rout）→ chapter `regulated`
- cascode bias 生成（padding 链）→ `bias-generator/level-shifter-bias.md`
- 通用 cascode 物理（不限 mirror 场景）→ `blocks/base-cells/cascode/`
- 故障 debug → chapter `troubleshooting`
