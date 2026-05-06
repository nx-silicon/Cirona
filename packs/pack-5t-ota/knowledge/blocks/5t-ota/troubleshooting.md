---
chapter: troubleshooting
parent: 5t-ota
summary: |
  5T-OTA 系统级失败模式 + 物理因果链 + 根因可能性表（不写流程，
  诊断顺序由通用 systematic-debugging skill 提供）。涵盖 gain 低 /
  GBW 低 / PM 紧 / mirror mismatch / output swing 等。
tokens: ~1400
prerequisite_chapters:
  - architecture
  - bias-headroom
related_skills:
  - systematic_debugging
  - signal_tracing
  - device_sizing
---

# 5T-OTA Troubleshooting

> 通用诊断顺序见 `skill: systematic-debugging`（4-phase）+ `skill: signal-tracing`（信号反推）。
> 本章节给的是 **5T-OTA 拓扑特有**的失败模式 + 物理因果链 + 根因可能性表。
> **device 不 saturation 触发的失败**（如 M5 triode）见 `bias-headroom.md` —— 本章不重复。

## 失败模式 1：DC gain 低（< 40 dB）

**症状**：simulate AC 测出 gain < 40 dB（spec target 通常 40-55 dB）。

### 物理因果链
```
gain = gm_M1 × (ro_M2 ‖ ro_M4)
        ↑          ↑       ↑
      input pair  input  PMOS load
                   pair   (M4)
                   (M2)
```

任一项弱 → gain 弱。**单级 OTA gain ceiling**：gm × ro ≈ 100-300（40-50 dB），物理上不能超过 ≈ 55 dB。

### 根因可能性表

| 可能根因 | 验证（用什么观测）| 物理原因 | 修复方向 |
|---|---|---|---|
| **L_LOAD 短**（最常见）| `op_point_check` 看 ro_M4 | ro ∝ L | L_LOAD 0.5→1.0-1.5µm |
| L_DIFF 短 | `op_point_check` 看 ro_M2 | ro ∝ L | L_DIFF 0.36→0.5µm |
| gm_M1 不足 | `op_point_check` 看 gm_M1 vs target | gm ∝ √(W/L · Id) | W_DIFF ↑ 或 m_diff ↑ |
| 双管 ro 都低 | ro_M2, ro_M4 < 200k | 短 channel 现象 | 双 L 都 ↑ |
| **某 device 不 sat**（罕见但致命）| `dc_snapshot` 看 region | triode → ro 几乎为 0 | 见 `bias-headroom.md` |

> **注意**：先确认所有 device sat 再相信 gain 数字。**触发 triode 的 gain 测量数值无意义**——这是 W6+ v11 实战教训。

### Anti-pattern（不要做）

- ❌ **增 ibias 想提 gain**：gm × ro 在 strong inversion 几乎不变（gm ↑ ro ↓ 抵消）；只是 power 多花了
- ❌ **W_LOAD 盲增**：增 gm_M3 但 ro_M4 几乎不变；mirror node cap ↑ → PM 变差
- ❌ **加 cascode 想提 gain**：5T 拓扑改成 cascode 是变种了，要进 architecture variant 评估

### 边界判断（spec 不可达时）

gain target > 55 dB → 5T-OTA **物理不行**。直接换：
- `blocks/folded-cascode-ota`（gain 60-80 dB）
- `blocks/two-stage-ota`（gain 60-90 dB）

---

## 失败模式 2：GBW 远低于 target

**症状**：测得 GBW <<  gm_target / (2π ·CL)，但 gain / PM 看似合理。

### 物理因果链
```
GBW = gm_M1 / (2π · CL)

GBW 低 ⇐ {gm_M1 低, CL 大}
gm_M1 低 ⇐ {Itail 小, gm/Id 太高（weak inversion）}
```

### 根因可能性表

| 可能根因 | 验证 | 修复 |
|---|---|---|
| CL 写错（spec 1pF 但 testbench 10pF） | 看 testbench `.param CL` | 校 testbench |
| `m_tail` 与 sizing 没同步（design_*.py 算 8 但 .cir 还 2）| `op_point_check` 看 Itail | 同步 .cir 的 m_tail |
| gm/Id 选太高（> 18，weak inversion）| `op_point_check` 看 gm/Id | gm/Id 12-15（更深 strong inversion）|
| input pair Vov 过小 | dc_snapshot Vov_M1 < 0.05V | 减 W_DIFF（让 Vov 升）|

### Anti-pattern

- ❌ **加 compensation cap 想救 GBW**：5T 单极点不需要补偿，加了反而让主极点更低，GBW 更糟
- ❌ **盲 ibias ↑**：要重 check 所有 device operating point（headroom 可能崩）

---

## 失败模式 3：PM < 50°

**症状**：tran 仿真 ringing，AC PM 测得 < 50°。

### 物理因果链

见 `ac-stability.md` 模式 1。本章只列根因表 + 修复路径。

### 根因可能性表

| 可能根因 | 验证 | 修复 |
|---|---|---|
| GBW 太接近 f_p2 | 算 GBW / f_p2 ≈ ? | CL ↑ 或 W_LOAD ↓ |
| W_LOAD 过大 → mirror cap 过大 | C_mirror_node 估算 | W_LOAD ↓（trade-off：Vov_M3 ↑ 影响 swing） |
| **device 不 sat**（PM 数字假象）| `dc_snapshot` region | 见 `bias-headroom.md` |
| testbench `set units = degrees` 漏 | 看 PM 数值是否在 -180 ~ 180 度 | 加 `set units = degrees` |

### Anti-pattern

- ❌ **5T-OTA 加 Miller 补偿**：单级不需要，且会引入 RHP zero + 主极点下移
- ❌ **加 nulling resistor**：同上

---

## 失败模式 4：output swing 不够

**症状**：tran 仿真大信号 clipping；AC 测纯纯线性但 spec 要求 rail-to-rail。

### 物理因果链
```
Vout_max = VDD - |Vov_M4| - margin
Vout_min = Vov_M2 + Vov_M5 + margin
total_swing = Vout_max - Vout_min ≈ VDD - 0.5V
```

5T-OTA 物理上限 swing ≈ VDD - 0.5V = 1.3V @ VDD=1.8V。**接近 rail-to-rail（VDD-0.1V）需要换 class-AB 输出级**。

### 修复路径

| 路径 | 怎么做 | 副作用 |
|---|---|---|
| 上行 swing | W_LOAD ↑ → \|Vov_M4\| ↓ → Vout_max ↑ | mirror cap ↑ → PM ↓ |
| 下行 swing | W_DIFF ↑ → Vov_M2 ↓ + W_TAIL ↑ → Vov_M5 ↓ | gm_M1 ↑（trade-off：Itail 同 → Id 同 → 实际 gm ↑） |
| 接受限制 | 标 spec swing = 1.0V | 不能做更严苛 spec |

### Anti-pattern

- ❌ **L_LOAD ↓ 想换 swing**：会 kills gain（ro ↓）
- ❌ **VCM 偏向 VDD/2 之外**：另一边 swing 损失

---

## 失败模式 5：M3/M4 mirror mismatch（systematic offset）

**症状**：dc_snapshot 显示 V(out) ≠ VCM 设计值，且 I_M3 ≠ I_M4 比预期偏大。

### 物理因果链
```
完美 mirror: I_M4 = I_M3 (W/L/m 同 + Vds 不影响)
实际: 
  - I_M4/I_M3 偏离来自：(1) sizing mismatch（W/L 不严格同）；
                       (2) Vds_M3 ≠ Vds_M4 → channel-length modulation
```

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| **M3/M4 W/L/m 不严格相同**（最常见 typo）| diff M3.W vs M4.W | 严格统一 sizing parameter |
| **M3.G ≠ M3.D**（diode-connect 错）| 网表检查 M3 connection | M3.G = M3.D = vd_l |
| **M4.G 接外部 vbp**（不是 vd_l）| 网表检查 M4 connection | M4.G = vd_l |
| Vds_M3 / Vds_M4 差距大 + L 短 | dc_snapshot 看 Vds_M3 / Vds_M4 | L_LOAD ↑（减 channel-length modulation）|

> ⚠️ **V3 LDO 实战教训 H-006**：M4.G 接外部 vbp 而不是 vd_l → mirror 完全失效，DC offset 大。**写 5T 网表时 M4.G 必须 = vd_l**（V4 reference-design.md 已强调）。

### Anti-pattern

- ❌ **加 cascode 救 mismatch**：cascode 减少 Vds 敏感但加 L_LOAD 同样有效，且少占 swing
- ❌ **靠 layout common-centroid 救 sizing typo**：layout 救不了网表层 sizing 错误

---

## 失败模式 6：输入对在 weak inversion 但 spec 不允许

**症状**：input pair gm/Id > 18（设计成 12 但 corner / temperature 漂出来），导致 fT 低，high-frequency 失稳。

### 修复

减小 W_DIFF 或加大 Itail（让 Vov_M1 重回 strong inversion）—— 但同时影响 gm 和 power。

通常通过 corner sweep 验证 gm/Id 在 corner 极端下不漂出 [10, 16] 范围。

---

## When to load this chapter

- AC / DC 仿真后 spec 不达标（任一项）
- 看到 dc_snapshot 异常前先回 `bias-headroom.md` 验 headroom
- agent 在调 sizing 撞壁（多次试都没收敛）

## Related

- **device 不 saturation** → `bias-headroom.md`（KVL/R2 推理）
- **AC 极点分析** → `ac-stability.md`
- **sizing trade-off** → `sizing-typical.md`
- **拓扑选型** → `architecture.md`（spec > 5T 上限时换拓扑）
- **通用诊断方法** → `skill: systematic-debugging` / `signal-tracing`
