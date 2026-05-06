---
chapter: sizing-typical
parent: 5t-ota
summary: |
  5T-OTA 顶层 spec → device 约束的因果链 + 拓扑特定的设计推进顺序 +
  起点表（@vpdk180nm）+ trade-off 表。引用 device-sizing skill 做单 device
  推导，不重复。
tokens: ~1300
prerequisite_chapters:
  - architecture
related_skills:
  - device_sizing
related_knowledge:
  - blocks/base-cells/differential-pair
  - blocks/base-cells/current-mirror
---

# 5T-OTA Sizing Typical Ranges

> 通用 sizing 方法见 `skill: device-sizing` 通用 sizing 流程 + Iron Law: NO PARAMETER WITHOUT EXPLICIT DERIVATION。
> 单 device 物理推导见对应 base-cell（`differential-pair` / `current-mirror`）。
> 本章节给的是 **5T-OTA 拓扑特有**的：(1) spec → device 约束传递；(2) 设计推进顺序；(3) 起点表（@vpdk180nm）。

## 顶层 spec → device 约束（拓扑特定因果链）

| OTA spec | 决定的 device 量 | 关键公式 |
|---|---|---|
| GBW | gm_M1 | gm_M1 = 2π · GBW · CL |
| DC gain | ro_M2 ‖ ro_M4 | gain = gm_M1 · (ro_M2 ‖ ro_M4) |
| PM | mirror node cap / GBW | f_p2 ≈ gm_M3 / (2π · C_mirror_node)；要 GBW < f_p2 / 3 |
| Iq budget | I_tail = 2 · Id_per_side | spec 直接给 |
| Swing | M3/M4 Vov + M2/M5 Vov | Vout_max = VDD - Vov_M4；Vout_min = Vov_M2 + Vov_M5 |
| Noise（input-referred）| gm_M1 + gm_M3/gm_M1 | V²_n,in ≈ V²_n,M1 + (gm_M3/gm_M1)² · V²_n,M3 |

## 拓扑特定的设计推进顺序（**5T-OTA 专属**）

> 通用 sizing 流程见 device-sizing skill。本节给 **5T-OTA 拓扑特有**的步骤化推进——因为 5T 各 device sizing 有强耦合，乱序会反复推翻。

### Step 1: 由 spec 反算 input pair gm（GBW + noise 双约束）

```
gm_M1 = max(gm_GBW, gm_noise)
  - gm_GBW = 2π · GBW · CL
  - gm_noise = 8 · k · T · γ/ (V²_n,in_target )
取较大者作为 gm_M1 design target。
```

### Step 2: 选 input pair gm/Id → 确定 W_DIFF + Id_per_side

```
gm/Id = 12-15（5T-OTA noise 主导，倾向 weak inversion）
Id_per_side = gm_M1 / (gm/Id)
W_DIFF/L_DIFF 由 gm = √(2 µ_n Cox · W/L · Id) 反算
L_DIFF = 0.5µm（matching + ro_M2，参见 base-cells/differential-pair）
```

> **为什么这步先做**：input pair 决定 OTA 整体性能（gm + noise），下游所有 device 跟着 Id_per_side 走。

### Step 3: 选 PMOS load（M3/M4）—— 由 gain ceiling + 噪声决定

```
约束 1: gain target → ro_M4 = gain_target / gm_M1（约 100k-300k）
约束 2: 噪声 → gm_M3 << gm_M1（典型 gm_M3 ≈ gm_M1 / 3）→ Vov_M3 ≈ 2-3 × Vov_M1
约束 3: matching → L_LOAD ≥ 0.5-1.0 µm（PMOS load 必须比 input pair 长，matching + ro 双重收益）
```

> **5T-OTA 关键陷阱**：L_LOAD 复制 input pair L（0.5µm）会让 gain 上不去（ro_M4 不够）+ 噪声差。**PMOS load L > input pair L** 是 5T 起步铁律。

### Step 4: 设计 tail（M5）+ Mbias —— 通过 bias 偏置管，不直接调 M5

```
I_tail = 2 × Id_per_side
M5 用 Mbias 镜像（mirror ratio = m_tail : m_bias）
Vov_M5 选 0.2-0.3V（headroom + matching）
W_M5 / L_M5 由 Vov + I_tail 反算
Mbias W/L 设成与 M5 同（让 mirror Vov 对称）
```

> **R2 镜像约束铁律**（见 bias-headroom.md）：M5.W/L 不直接调，先调 Mbias。**这是 LLM 常忽略的物理约束**。

### Step 5: 验证 headroom + DC bias 落点

```
inspect_device(M1..M5)
  → 所有 device margin > 50mV（Vds - Vdsat > 50mV）
inspect_node('tail')
  → V(tail) 在合理范围（0.4-0.6V @VDD=1.8V）
inspect_node('out')
  → V(out) ≈ VCM 设计值
```

如有任意 device 不 sat → 回到 bias-headroom.md 范例 1（M5 triode）走 R1/R2 推理。

### Step 6: 验证 AC（gain / GBW / PM）

参见 `ac-stability.md` + `reference-design.md` 的 testbench 模板。  
通用方法见 `skill: ac-feedback-loop-method`（Method C 断环）。

### 推荐建议（不强制）

> 这 6 步是**建议顺序**，不是机械流程。如果 spec 让某些约束特别紧（如 power 严格），可以从 Step 4 倒推 Itail，再回 Step 1。**关键是约束耦合方向**：input pair gm → 决定下游所有 device 电流，所以从 Step 1-2 起步通常最快收敛。

## 起点表（@vpdk180nm，VDD=1.8V，ibias=10µA → Itail=20µA）

| Device | role | W | L | m | gm/Id | Vov | 关键约束 |
|---|---|---|---|---|---|---|---|
| M1, M2 | NMOS input pair | 10 µm | 0.5 µm | 1 | ~12 | 0.15 V | gm 主导，weak inversion 倾向 |
| M3, M4 | PMOS mirror load | 10 µm | **1.0 µm** ⭐ | 1 | ~8 | 0.30 V | L > input pair L（gain + 噪声）|
| M5 | NMOS tail | 20 µm | 0.5 µm | 2 | ~10 | 0.20 V | Itail = 2 × Id_per_side |
| Mbias | NMOS bias diode | 10 µm | 0.5 µm | 1 | — | — | mirror reference for M5 |

⚠️ **数值标 @vpdk180nm**：换工艺时 µ·Cox 不同，要重新算 W。公式跨工艺通用。

## Trade-off 表（4D：gain / BW / power / swing）

| 调整 | gain | BW | power | swing | 备注 |
|---|---|---|---|---|---|
| L_LOAD ↑（0.5→1.5µm）| ↑↑ | ↓（mirror 极点变低）| — | — | gain 优先时首选 |
| W_DIFF ↑ | ↑（gm ↑）| ↑（gm ↑）| —（同 Id）| ↓（Vov 减但 mirror cap ↑）| trade-off 多 |
| L_DIFF ↑ | ↑（ro_M2 ↑）| —（gm 同）| — | — | 仅 gain 提升 |
| W_LOAD ↑ | ↑（ro 微 ↑）| ↓↓（mirror cap ↑）| — | ↑↑（Vov ↓）| swing 优先时首选 |
| m_tail ↑（Itail ↑）| —（gm·ro 不变）| ↑↑（gm ↑）| ↑↑ | ↓（Vov ↑）| BW 优先时首选 |
| m_tail ↓（power 省） | — | ↓ | ↓ | ↑ | power-tight 场景 |

## 不在本章范围

- **gm/Id 通用 sizing 方法** → `skill: device-sizing`（通用 sizing 流程）
- **input pair / mirror 各自单 device 物理推导** → `blocks/base-cells/differential-pair` + `current-mirror`
- **Pelgrom matching 公式** → `skill: device-sizing` R1 / `blocks/base-cells/differential-pair`
- **何时用 5T 何时不用** → `architecture.md`（拓扑选择）
- **Vds-Vdsat 失稳处理** → `bias-headroom.md`（R1/R2 推理）

## Related

- `blocks/base-cells/differential-pair/sizing-reasoning` 输入对单 device sizing
- `blocks/base-cells/current-mirror/basic` mirror sizing
- `skill: device-sizing` 通用 sizing 流程 + R1-R4 铁律
- W6+ sizing-reasoning chapter（`current-mirror` / `cascode` / `differential-pair` / `bias-generator` / `output-stage` 5 cell sizing-reasoning）
