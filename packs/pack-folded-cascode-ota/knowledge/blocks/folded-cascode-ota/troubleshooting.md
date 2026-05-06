---
chapter: troubleshooting
parent: folded-cascode-ota
summary: |
  FC-OTA 系统级失败模式 + 物理因果链 + 根因可能性表（不写流程，
  诊断顺序由通用 systematic-debugging skill 提供）。涵盖 gain 低 /
  GBW 低 / PM 紧 / cascode triode / fold_ratio 异常 / mirror mismatch /
  output swing 等。
tokens: ~1700
prerequisite_chapters:
  - architecture
  - bias-headroom
related_skills:
  - systematic_debugging
  - signal_tracing
  - device_sizing
---

# FC-OTA Troubleshooting

> 通用诊断顺序见 `skill: systematic-debugging`（4-phase）+ `skill: signal-tracing`
> （信号反推）。本章节给的是 **FC-OTA 拓扑特有**的失败模式 + 物理因果链 +
> 根因可能性表。**device 不 saturation 触发的失败**（如 MN5_bottom triode）
> 见 `bias-headroom.md` —— 本章不重复 R1/R2 推理细节，只列根因表 + 链接回去。

## 失败模式 1：DC gain 低（< 60 dB）

**症状**：simulate AC 测出 gain < 60 dB（spec target 通常 60-80 dB）。

### 物理因果链
```
gain = gm_M1 × Rout
Rout = Rout_p ‖ Rout_n
Rout_p = gm_pcasc × ro_pfold × ro_pcasc
Rout_n = gm_ncasc × ro_nmirror × ro_ncasc
```

任一项弱 → gain 弱。**FC-OTA gain ceiling**：cascode 把 ro 提到 gm·ro × ro
量级，物理上 ≈ 80-90 dB。

### 根因可能性表

| 可能根因 | 验证（用什么观测）| 物理原因 | 修复方向 |
|---|---|---|---|
| **某 cascode device 不 sat**（最常见，致命）| `dc_snapshot` 看 region | triode → ro 几乎为 0 | 见 `bias-headroom.md` MN5/MN6/MP2 triode 范例 |
| **fold_ratio < 1.5**（cascode branch 缺电流）| 算 m_fold / m_tail | I_cascode → 0 → ro_cascode 异常 | 同步 m_fold = m_tail（见 sizing-typical fold_ratio 规则）|
| L_cascode 短 | `op_point_check` 看 ro_pcasc / ro_ncasc | ro ∝ L | L_cascode 0.36 → 0.5-1.0 µm |
| L_load 短 | `op_point_check` 看 ro_pfold | ro ∝ L | L_load 1 → 2 µm |
| L_diff 短 | `op_point_check` 看 ro_M1 | ro ∝ L | L_diff 0.5 → 1.0 µm |
| gm_M1 不足 | `op_point_check` 看 gm_M1 vs target | gm ∝ √(W/L · Id) | W_diff ↑ 或 m_diff ↑（注意 fold_ratio 同步）|
| **m_pcasc 不足（FC 推荐路径未用）**| 默认 m_pcasc=1 | ro_pcasc = ∝ m | m_pcasc → 6（V4 reference 默认）|

> **注意**：先确认所有 device sat 再相信 gain 数字。**触发 cascode triode 的
> gain 测量数值无意义**——这是 FC-OTA E2E v3 + ACP 4.3 Phase 0 实战教训。

### Anti-pattern（不要做）

- ❌ **增 ibias 想提 gain**：gm × ro 在 strong inversion 几乎不变（gm ↑ ro ↓ 抵消）；
  且改 ibias 会牵动所有 branch（fold_ratio / cascode bias 全漂）
- ❌ **W_load 盲增**：增 gm_pfold 但 ro_pfold 几乎不变（短 L 主导）；fold node
  cap ↑ → PM 变差
- ❌ **L_pad_n / L_pad_p 调来调去想救 gain**：padding 决定 cascode bias，
  不直接影响 gain；只在 cascode triode 时才动
- ❌ **加 second stage 想救 gain**：变成两级了，要重新 layout + Miller 补偿，
  不能算"FC 救活"

### 边界判断（spec 不可达时）

gain target > 90 dB → FC-OTA **物理不行**。直接换：
- `blocks/two-stage-ota`（gain 80-100 dB）
- gain-boosted FC variant（独立章节）

---

## 失败模式 2：GBW 远低于 target（gain / PM 看似正常）

**症状**：测得 GBW << gm_target / (2π · CL)，但 gain / PM 看似合理。

> 这是 FC-OTA 实战最常见的"deceptive failure"——dc_op 全过、AC PM 86°
> 看着稳，但 GBW 7 MHz vs target 50 MHz。

### 物理因果链
```
GBW = gm_M1 / (2π · CL)

GBW 低 ⇐ {gm_M1 低, CL 大}
gm_M1 低 ⇐ {Itail 小, gm/Id 太高（weak inversion）}
Itail 低 ⇐ {m_tail 没同步 sizing 结果, ibias 错}
```

### 根因可能性表

| 可能根因 | 验证 | 修复 |
|---|---|---|
| **m_tail 与 sizing 没同步**（最常见！）| `op_point_check` 看 Itail vs sizing 计算 | 同步 .cir 的 m_tail，并按 fold_ratio = 2 同步 m_fold |
| CL 写错（spec 1pF 但 testbench 10pF）| 看 testbench `.param CL` | 校 testbench |
| gm/Id 选太高（> 18，weak inversion）| `op_point_check` 看 gm/Id | gm/Id 12-15（更深 strong inversion）|
| input pair Vov 过小 | dc_snapshot Vov_M1 < 0.05V | 减 W_diff（让 Vov 升）|

> **V3 实战教训**（FC-OTA E2E v3 t40）：sizing 算 m_tail = 16 但模板默认 m_tail = 2，
> agent 没同步 → I_tail = 20µA（应 160µA）→ gm_M1 8× 偏低 → GBW 8× 偏低。

### Anti-pattern

- ❌ **加 compensation cap 想救 GBW**：FC 是单极点主导不需要补偿，加了反而把
  主极点更低，GBW 更糟
- ❌ **盲 ibias ↑**：要重 check 所有 device operating point（headroom 可能崩）+
  fold_ratio 也要重算
- ❌ **只增 m_tail 不同步 m_fold**：fold_ratio 崩（< 1）→ cascode 失效

---

## 失败模式 3：PM < 50°

**症状**：tran 仿真 ringing，AC PM 测得 < 50°。

### 物理因果链

见 `ac-stability.md` 模式 1（GBW 接近 fold node 极点）。本章只列根因表 + 修复路径。

### 根因可能性表

| 可能根因 | 验证 | 修复 |
|---|---|---|
| GBW 太接近 f_p2（fold node）| 算 GBW / f_p2 ≈ ? | CL ↑ 或 W_fold ↓（trade-off：Vov_pfold ↑）|
| W_pcasc 过大 → fold node cap 过大 | C_fold 估算 | m_pcasc ↑ + W_pcasc ↓（保 ro，减 cap）|
| **device 不 sat**（PM 数字假象）| `dc_snapshot` region | 见 `bias-headroom.md` |
| testbench `set units = degrees` 漏 | 看 PM 数值是否在 -180 ~ 180 度 | 加 `set units = degrees` |
| Miller 补偿误加（FC 不需要！）| 看是否有 Cc / Rz | 删除（FC 是单极点 OTA）|

### Anti-pattern

- ❌ **FC-OTA 加 Miller 补偿**：单级不需要，且会引入 RHP zero + 主极点下移
- ❌ **加 nulling resistor**：同上
- ❌ **dc_op 不通过时讨论 PM**：device 不 sat 时 PM 数值无意义

---

## 失败模式 4：MN5_bottom（NMOS mirror 主管）triode

> **FC-OTA E2E v3 + ACP 4.3 Phase 0 实战卡点**。

详见 `bias-headroom.md` 范例 1。简短根因表：

| 根因 | 修复 |
|---|---|
| Vds(MMN_vbcn_1)（padding）过小 → vbc_n 偏低 → vmid_left2 偏低 → MN5 Vds 不足 | L_pad_n ↑ 或 W_pad_n ↓（**首选，单选不混用**）|
| Vdsat_M5 自身过大（L_nmirror 太短）| L_nmirror ↑（同步双侧 MN5/MN7）|
| VDD 过低（< 1.2V）| 拓扑不可行 → 换 telescopic-low-voltage 或 2-stage |

⚠️ **不要混用** L_pad_n ↑ + W_pad_n ↓，两个方向相同会过度调（一步内 ≤ 50% 改动）。

---

## 失败模式 5：MN6_top（NMOS cascode）triode

> 与 MN5_bottom triode **镜像症状**。

详见 `bias-headroom.md` 范例 1 末尾"镜像症状"。简短根因表：

| 根因 | 修复 |
|---|---|
| vbc_n 推太高 → V(vmid_left2) 太高 → MN5 拿走太多 Vds 预算 → MN6 没空间 | L_pad_n ↓ 或 W_pad_n ↑（与 fix-A 相反方向）|

> **硬约束**：Vds(MN5) + Vds(MN6) = V(vd_left) ≈ const。padding 调整是
> 在 MN5 / MN6 之间**重新分配**，不能增总预算。**双侧 margin 都看，不要顾此失彼**。

---

## 失败模式 6：MP2_top / MP4_top（PMOS cascode）triode

详见 `bias-headroom.md` 范例 2。简短根因表：

| 根因 | 修复 |
|---|---|
| vbc_p 偏高 → V(vmid_left1) 接近 V(vd_left) → \|Vds_MP2\| 不足 | L_pad_p ↑ 或 W_pad_p ↓（PMOS 侧 padding）|
| W_pcasc 大 → \|Vov_pcasc\| ↓ → \|Vdsat_pcasc\| ↓ 但 cascode 寄生 cap ↑ → PM 紧 | m_pcasc ↑（保 ro，减 W）|

---

## 失败模式 7：output swing 不够

**症状**：tran 仿真大信号 clipping；AC 测纯纯线性但 spec 要求 swing > 1V @ VDD=1.8V。

### 物理因果链
```
Vout_max = VDD - |Vov_pfold| - |Vov_pcasc| - margin
Vout_min = Vov_nmirror + Vov_ncasc + margin
total_swing ≈ VDD - 1.0V = 0.8V @ VDD=1.8V
```

FC-OTA 物理上限 swing ≈ 0.6-0.8V @ VDD=1.8V。**接近 rail-to-rail 需要换 2-stage**。

### 修复路径

| 路径 | 怎么做 | 副作用 |
|---|---|---|
| 上行 swing | W_load ↑ → \|Vov_pfold\| ↓ + W_pcasc ↑ → \|Vov_pcasc\| ↓ | fold node cap ↑ → PM ↓ |
| 下行 swing | W_diff ↑ + W_nmirror ↑ + W_ncasc ↑（4 段都缩 Vov）| ro 全降 → gain ↓ |
| 接受限制 | 标 spec swing = 0.8V | 不能做更严苛 spec |

### Anti-pattern

- ❌ **L 缩短想换 swing**：会 kills gain（ro ↓）
- ❌ **VCM 偏向 VDD/2 之外**：另一边 swing 损失（FC 的 ICMR 宽，但 swing 仍对称）

---

## 失败模式 8：mirror mismatch（systematic offset）

**症状**：dc_snapshot 显示 V(vout) ≠ VCM 设计值，且 I(MN7) ≠ I(MN5)。

### 物理因果链
```
完美 mirror: I_MN5 = I_MN7 (W/L/m 同 + Vds 不影响)
实际: 
  - MN5/MN7 W/L/m 不严格同
  - MN3/MN4 W/L/m 不严格同（PMOS load 端）
  - V(vd_left) ≠ V(vout) → Vds 失配 → channel-length modulation
```

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| **MN5/MN7 sizing typo**（最常见）| diff MN5.W vs MN7.W | 严格统一 W/L/m |
| **MN5.G ≠ vd_left**（diode 路径错）| 网表检查 MN5 connection | MN5.G = vd_left（via cascode MN6）|
| **MP2/MP4 W/L 不同**（PMOS cascode mismatch）| diff MP2 vs MP4 | 严格统一 |
| L_nmirror 短 + Vds 失配 | dc_snapshot Vds 差 + L < 0.5µm | L_nmirror ↑（减 channel-length modulation）|

### Anti-pattern

- ❌ **加 second stage 救 mismatch**：第二级 offset 不能消除第一级 systematic offset
- ❌ **靠 layout common-centroid 救 sizing typo**：layout 救不了网表层 sizing 错误

---

## 失败模式 9：slew rate 慢

**症状**：tran 阶跃响应慢（小信号 GBW 正常但大信号 settling 慢）。

### 物理因果链
```
SR = I_max_charge / CL
正向 slew: I_pos = I_fold - 0 = I_fold（input pair 全推一边）
负向 slew: I_neg = I_tail（tail 完全 sink）
SR = min(I_fold, I_tail) / CL
```

### 根因可能性表

| 根因 | 修复 |
|---|---|
| I_tail 不够大 | m_tail ↑（同步 m_fold）|
| fold_ratio 紧（< 1.5）| m_fold ↑ |
| CL 大 | testbench 改 CL（如真实负载就不行）|

---

## When to load this chapter

- AC / DC 仿真后 spec 不达标（任一项）
- 看到 dc_snapshot 异常前先回 `bias-headroom.md` 验 headroom
- agent 在调 sizing 撞壁（多次试都没收敛）

## Related

- **device 不 saturation** → `bias-headroom.md`（KVL/R2 推理）
- **AC 极点分析** → `ac-stability.md`
- **sizing trade-off + fold_ratio 耦合** → `sizing-typical.md`
- **拓扑选型** → `architecture.md`（spec > FC 上限时换拓扑）
- **通用诊断方法** → `skill: systematic-debugging` / `signal-tracing`
