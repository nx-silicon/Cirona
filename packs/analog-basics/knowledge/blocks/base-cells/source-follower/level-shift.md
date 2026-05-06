---
chapter: level-shift
parent: source-follower
summary: |
  SF 作 level shifter / bias chain：用 Vgs 把节点平移 Vth+Vov / PMOS SF 在 n-well 工艺
  中天然消 body effect / multi-stack 串联实现 N×Vth 偏移 / 信号路径慎用（SNR 损）
tokens: ~500
prerequisite_chapters:
  - basic
related_skills:
  - circuit-method/device-sizing
  - circuit-method/bias-tree-reasoning
related_knowledge:
  - blocks/base-cells/bias-generator
  - blocks/base-cells/current-mirror
---

# Source-Follower as Level Shifter

## 核心 use case：bias chain 电平偏移

SF 的 Vgs ≈ Vth + Vov ≈ 0.5-0.8V 是**可预测的固定偏移**。这让 SF 成为 bias chain 中**把高电压向下平移一个 Vth** 的标准 cell：

```
NMOS SF level shifter（典型用法）

   Vin (high) ──┬─── 来自上游 bias 节点
                │
              ┌─┴─┐
              │ M │   ← level-shift NMOS
              └─┬─┘
                │ Vout = Vin - Vgs ≈ Vin - (Vth_eff + Vov)
                ●─── 输出 to 下游（typically cascode bias gate）
                │
              ┌─┴─┐
              │I_sink│  来自 mirror，固定 Id → 固定 Vov
              └─┬─┘
                │
              vss
```

**典型应用**：
- **cascode bias 生成**：bias generator 主支路把 Vbcp（PMOS cascode bias）通过几级 SF 平移到 NMOS cascode bias Vbcn，每级损一个 Vth + Vov
- **NMOS pass LDO 驱动**：EA 输出（PMOS swing）→ SF 平移到 pass NMOS gate
- **DAC unit cell 的 switch driver**：高电平输入 → SF 移到 switch tube 安全驱动范围
- **OTA 输出级 (class A) buffer**：与基础 SF 重合，已在 `chapter=basic` 覆盖

## PMOS SF 是首选的 level shifter

NMOS SF 作 level shifter 时 **VSB > 0** → body effect 让 Vth_eff 比 Vth0 抬 50-200 mV @ 180nm γ ≈ 0.4 V^0.5（详见 `chapter=basic` body effect 段）。**PVT 角下 Vth_eff 漂 ±100 mV** → 偏移量不精确。

PMOS SF in **n-well 工艺**：n-well 可接 source（每个 PMOS 独立 n-well）→ VSB = 0 → **gmb = 0** → 偏移量纯 |Vth_p0| + |Vov| 可预测。

| 选择 | 偏移精度 | 工艺成本 |
|---|---|---|
| PMOS SF（n-well 接 source）| **高**（gmb = 0） | 标准 n-well 工艺免费 |
| NMOS SF（standard p-substrate）| 中（body effect 漂移）| 标准工艺 |
| NMOS SF in deep n-well（p-well 接 source）| 高（gmb = 0） | deep n-well mask 加成本 |

**bias chain 设计推荐**：能用 PMOS SF 的地方优先用 PMOS SF（节点电压方向匹配时）。

## Multi-stack：N 级串联 N×Vth 偏移

```
Vin (高) ──┬─ M1 ─┬─ M2 ─┬─ M3 ─ ... ── Vout (低，平移 N×(Vth+Vov))
                  │      │      │
                I_sink  I_sink  I_sink  （每级独立 sink，保证 Id 一致）
```

**每级偏移** = Vth_eff + Vov，假设每级同 sizing + 同 Id → 偏移量大致相同。

**精度限制**：
- 每级 Vth_eff 因 VSB 不同而不同（NMOS 越往下 VSB 越小 → Vth_eff 越小）
- N=3 级的总偏移**不严格** = 3×（首级 Vth+Vov），实测 ±10% 偏差
- bias generator 写 spec 时要 simulate 验证，不要按公式算总偏移就当真

**典型用法**：bias generator 中从 Vbpc → Vbnc → Vncs 跨电压域，需要 2-3 级 SF 链（详细生成见 `blocks/base-cells/bias-generator`）。

## 信号路径上的 level shifter ⚠️

**不要在信号路径用 SF 做 level shift**——理由：
- Av < 1（典型 0.7-0.95，body effect 主导损失）→ 电压衰减 = -20log10(Av)：Av=0.9 损 ~0.9 dB / Av=0.7 损 ~3.1 dB
- follower 自身输出噪声折算回输入端：电压噪声密度按 1/Av 放大，噪声功率 / PSD 按 1/Av² 放大；NF 还要算后级噪声
- Vth PVT 漂移直接出现在信号 DC 上 → systematic offset

**正确做法**：信号路径上需要平移用 capacitive level shift（电容耦合）或 DC-shift 的 amplifier（带 EA 反馈钉住 DC）。SF 的 level shift **专属 bias chain（无信号、固定 DC）场景**。

## sizing 关系（level-shift 用途）

| 量 | 推荐 | 因果 |
|---|---|---|
| Vov | 100-200 mV | 太小（< 50mV）→ 弱反型，gm/Id 高但偏移漂；太大（> 300mV）→ 偏移过大 |
| L | 1-2 × Lmin（typical 0.36-0.5 µm @ 180nm）| Lmin 给最差 matching；2×Lmin 是平衡点（bias chain 不需 ro 极高）|
| W/L | 由 Id 反推（gm 不重要，Vgs 才重要）| level shift 关心 Vgs 不关心 gm |
| Id (sink) | 1-10 µA per branch | 太小 noise 高；太大耗功 |
| matching | σ(ΔVth) ∝ 1/√(WL)：要 ±5 mV 精度需 WL ≥ 几个 µm² | bias 精度直接决定下游 cascode 安全 margin |

**与基础 SF 的 sizing 区别**：basic SF 关注 gm（Av / Rout / drive），level-shift SF 关注 Vgs（偏移精度）。**两个目标不在同 sizing 路径**。

## Sizing 范例（cascode bias 链一级 NMOS level shifter）

> 📌 **@ vpdk180nm**：以下数值用 vpdk180nm BSIM 工艺常数（μn·Cox ≈ 270 µA/V²、Vth_n0 ≈ 0.35 V、γ ≈ 0.4 V^0.5、2ΦF ≈ 0.7 V）。**换工艺需重算 Vth_eff / Vov / W**——参考 `pdks/<your-pdk>/index.md`；body effect 公式跨工艺通用，γ 数值不同（28nm 以下 γ 更小，body effect 影响减弱）。

设计目标：把 Vbpc=1.4V 平移到 Vbnc=0.85V（差 0.55V，目标一级搞定）

```
预算 Vth + Vov = 0.55 V → Vov = 0.55 - 0.4 = 0.15 V (假设 Vth_eff=0.4V，含 body effect)

sink Id = 5 µA（low Iq budget）

W/L 推算:
  W/L = 2·Id / (μn·Cox·Vov²) = 2×5µ / (270µ × 0.0225) ≈ 1.65
  L = 0.5 µm（生产风格 1.5×Lmin，matching + ro）
  W = 0.83 µm → 取 W=1 µm
  m = 1

验证 Vth_eff（PoC 阶段查 VSB）:
  M source ≈ 0.85V（vout）；body 接 vss → VSB = 0.85V
  Vth_eff = Vth0 + γ(√(2ΦF+VSB) - √(2ΦF))
         = 0.35 + 0.4×(√(0.7+0.85) - √0.7)
         ≈ 0.35 + 0.4×(1.245 - 0.837) ≈ 0.35 + 0.163 ≈ 0.51V
  → Vgs_actual = 0.51 + 0.15 = 0.66V
  → vout_actual = 1.4 - 0.66 = 0.74V （**比预期 0.85V 低 110 mV**！）

→ **必须 simulate 验证**：解析公式给的偏移精度只到 ±10-15%，PVT 角下更不准。
   生产 bias chain 一定用 SPICE 实测调整，不能按公式算定数 sizing。

替代方案（如精度要求高，⚠️ **方向要对**）：
  - 若电平方向需要 **up-shift**（vout > vin）→ 改用 PMOS SF（vout ≈ vin + |VSG|；n-well 接 source 消 body effect，偏移精确到 ±20mV）。本例是 down-shift，PMOS SF 不能直接替代
  - **本例 0.55V down-shift 不要用 2 级 NMOS SF 串联**——每级至少掉 (Vth+Vov) ≈ 0.6V，2 级 ≈ 1.2V 过度下移；多级仅适合需要更大 down-shift 的场景
  - 改用 **deep n-well NMOS**（p-well 接 source 消 body effect）让 Vth_eff = Vth0 → 偏移精确（mask 加成本）
  - **closed-loop bias servo**（EA 反馈钉 Vbnc 到目标值）—— bias_generator 中 advanced 用法，PVT 角下精度最高
```

## 验证清单

- [ ] dc_snapshot：每级 SF M 在 saturation
- [ ] dc_snapshot：每级 sink mirror 在 saturation（Vov_sink + 50 mV margin）
- [ ] PVT corner 扫：Vbnc 漂 < 50 mV @ ±10% Vdd / TT-FF-SS / -40°C-125°C
- [ ] **关键**：与目标偏移对照，必要时迭代调 W/L 或 Id（不要相信纯解析公式）
- [ ] 下游 cascode（M_lower）的 Vds 在 PVT 角全程 ≥ Vov + 50 mV margin（这是 bias chain 设计的最终验收 spec）

## 常见误区

| 心里想 | 现实 |
|---|---|
| "level-shift SF 的偏移量等于 Vth + Vov 公式" | body effect 让 Vth_eff 比 Vth0 高 50-200 mV @ NMOS / VSB>0；总偏移与公式偏 ±10-15% / PVT 更不准 → simulate 调 |
| "NMOS SF 和 PMOS SF 等价" | 标准 n-well 工艺中 PMOS SF 可消 body effect；NMOS SF 不行（除 deep n-well 工艺） |
| "level-shift 用 minimum L 给最大密度" | bias chain 不缺面积，用 1.5-2×Lmin 换 matching 收益（σ_Vth 减 √2 倍） |
| "stacked level shift 三级一定是 3×(Vth+Vov)" | 每级 VSB 不同 → Vth_eff 不同 → 总偏移 ±10% 偏差，不要算等效定值 |
| "信号路径上加个 SF 平移 DC 没事" | Av<1 带来 0.5-3 dB 电压衰减（Av=0.7→3.1 dB）+ 后级等效噪声放大 + DC offset 漂；信号路径用 cap level shift 或 EA 反馈，不用 SF |

## 不在本章范围

- 基础 SF 物理 / Av 公式 / Rout / dropout → `chapter=basic`
- SF 故障 debug / dropout 边缘行为 → `chapter=troubleshooting`
- 完整 bias generator 设计 / 多级 bias 链整体 → `blocks/base-cells/bias-generator`
- LDO output buffer（基础 SF 应用，已在 `chapter=basic` 覆盖）→ `chapter=basic`
- class AB output stage（SF + 互补对）→ `blocks/base-cells/output-stage`
- capacitive level shift / EA 反馈 DC shift → `blocks/ota-*` 章节中讨论
