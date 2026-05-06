---
chapter: troubleshooting
parent: class-ab-ota
summary: |
  Class-AB OTA 系统级失败模式 + 物理因果链 + 根因可能性表（不写流程，
  诊断顺序由通用 systematic-debugging skill 提供）。涵盖 IQ 失控 / crossover
  distortion / max output current 不达标 / PM dynamic 失稳 / output triode /
  Stage1 跨级耦合 / load-dependent stability 等。
tokens: ~1700
prerequisite_chapters:
  - architecture
  - bias-headroom
  - ac-stability
related_skills:
  - meta-cognitive/systematic-debugging
  - circuit-method/signal-tracing
  - circuit-method/device-sizing
---

# Class-AB OTA Troubleshooting

> 通用诊断顺序见 `skill: systematic-debugging`（4-phase）+ `skill: signal-tracing`
> （信号反推）。本章节给的是 **class-AB OTA 拓扑特有**的失败模式 + 物理
> 因果链 + 根因可能性表。**device 不 saturation 触发的失败**（如 IQ 失控 /
> v1_out 跑 rail）见 `bias-headroom.md`；**AC PM / Cc / Rz 失稳** 见
> `ac-stability.md`。本章合并系统级根因表 + 推荐诊断顺序。

## 诊断顺序（**class-AB 推荐顺序**）

> 这是 class-AB 系统级**推荐诊断顺序**——class-AB 误差源多（IQ / crossover /
> max drive / PM dynamic / 跨级耦合），盲目调任一项救不了别的。**按 IQ →
> crossover → max drive → PM (quiescent + dynamic) → 跨级耦合 顺序排查**。

```
1. tb_dc_op 看 IQ_quiescent
   - IQ 失控 (10× 偏) → 见模式 1（floating bias 链失配）
   - IQ 太小 (< 30 µA) → 见模式 2（crossover risk）
   - IQ OK → 进步骤 2
   ↓
2. tb_dynamic FFT 测 THD-3
   - THD > -50 dB → 见模式 2（crossover）
   - THD OK → 进步骤 3
   ↓
3. tb_drive 测 max output current
   - I_max 不达标 → 见模式 3（output W·m / L 错）
   - I_max OK → 进步骤 4
   ↓
4. tb_ac_gain_bw 测 quiescent PM
   - PM < 50° → 见模式 4（Cc/Rz）
   - PM OK → 进步骤 5
   ↓
5. tb_slew 大信号 ringing 看 dynamic PM
   - ringing → 见模式 5（dynamic gm 失稳）
   - 无 ringing → 进步骤 6
   ↓
6. cross-corner 跑全 sweep
   - PVT IQ 漂大 → 见模式 6（floating bias PVT 不对称）
```

## 失败模式 1：IQ 失控（floating bias 链失配）

详见 `bias-headroom.md` 范例 1。简短根因表：

| 根因 | 验证 | 修复 |
|---|---|---|
| **MN_ab_bias2/3 与 MN_bias W/L 不匹配**（最常见 sizing 错）| diff W_MN_bias 与 W_MN_ab_bias2 | 严格相同 W/L（m 不同 OK）|
| **MP_ab_bias1/2 W/L 不一致** | diff PMOS bias 链 | 严格统一 |
| **vmid_p_ab / vmid_n_ab generator stacked diode 接错** | 网表 connectivity | 见 reference-design connectivity rules |
| **Stage1 v1_out 偏（mirror imbalance）** | inspect_node('v1_out') | 见 `blocks/two-stage-ota/bias-headroom` 范例 1 |
| **Output W·m 偏离设计** | diff W·m vs sizing target | 校 W·m / 同步 PMOS NMOS 比例 |

### Anti-pattern
- ❌ **直接调 W_MP_ab_out 想"对准" IQ**：output W·m 不锁 IQ；IQ 由 floating bias 锁
- ❌ **加 ibias 想"提" IQ**：ibias 改变会全链漂，不一定 IQ ↑
- ❌ **跳过 Stage1 验证直接调 Stage2**：v1_out 偏是常见根因

---

## 失败模式 2：Crossover distortion（IQ 太小 / dead zone）

详见 `bias-headroom.md` 范例 2。

### 症状
tb_dynamic FFT 测 THD-3 > -50 dB；tran 阶跃响应在 vout = VCM 附近非线性扭曲；
IQ 实测 < 30 µA。

### 根因可能性表

| 根因 | 修复 |
|---|---|
| IQ_quiescent 设计起点过低 | 增 IQ 到 ≥ 50 µA per device（调 floating bias 之差）|
| **Output W·m 不足导致 gm 小**（quiescent 不够强）| W·m ↑（同步 PMOS NMOS）|
| Output L 选大 → fT 低 → 信号过零 transit 慢 | L = Lmin 或 0.5 µm |
| Spec THD 太严苛 | 接受 -50 dB or 升级 fully-differential class-AB |

### Anti-pattern
- ❌ **靠 input swing 大平均掉 distortion**：crossover 是非线性，averaging 不消
- ❌ **加滤波器在 output 后**：滤波改 frequency response，不消 nonlinearity

---

## 失败模式 3：Max output current 不达标

**症状**：tb_drive 测 vout = VCM ± 0.5V 时 I_out_max 实测 < spec（如 spec 5 mA，实测 1 mA）。

### 物理因果链

```
I_out_max ≈ µ·Cox · W·m / L · (Vov_max)² / 2
Vov_max ≤ v1_out 摆幅（限于 Stage1 swing）≈ 0.6V (typical)
要 I_out = 5 mA @ Vov_max=0.6V:
  W·m / L ≥ 5e-3 × 2 / (4·µ·Cox · 0.36) ≈ 50 µm/µm
  L=Lmin=0.18µm → W·m ≥ 9 µm → 接近 W=200µm × m=10
```

### 根因可能性表

| 根因 | 验证 | 修复 |
|---|---|---|
| **W·m_output 不足**（最常见 sizing）| 算 W·m / L vs spec | W·m ↑（PMOS+NMOS 同步比例 μn/μp）|
| **L_output > Lmin**（drive 不优）| 看 L_ab_out | L = Lmin 或 0.5µm |
| Stage1 v1_out 摆幅不足（不能拉到 rail）| tb_drive 看 v1_out swing | 增 stage1 m_diff（GBW + drive 双优）|
| Output PMOS / NMOS 比例错（W_p / W_n ≠ μn/μp）| diff W_p vs W_n | W_p ≈ 2 × W_n（vpdk180nm μn/μp ≈ 2.5）|

---

## 失败模式 4：Quiescent PM < 50°

详见 `ac-stability.md` 模式 1。

### 根因可能性表

| 根因 | 修复 |
|---|---|
| Cc 太小（Cc/CL < 0.5）| Cc ↑ 30% 步长 |
| Rz 偏离 1/gm_AB（quiescent gm）| Rz = 1/gm_AB；用实测 gm |
| gm_AB 太小（output W·m 不够）| 增 W·m_output |
| Stage1 mirror 不平衡 → gm_AB 实际值不准 | 见模式 7（跨级耦合）|

---

## 失败模式 5：Dynamic PM 失稳（大信号 ringing）

详见 `ac-stability.md` 范例 1。

### 根因可能性表

| 根因 | 修复 |
|---|---|
| Cc/CL 比例不够（dynamic gm 变化太大）| Cc 增大 30-50% 留 dynamic margin |
| Rz 不能跨 swing 完全消零 | 接受 dynamic PM 变化；spec 留 margin |
| Output stage parasitic cap 大于设计 | 减 W·m or 用 cascoded class-AB variant |

---

## 失败模式 6：Cross-corner IQ 漂大

**症状**：TT @ 27°C IQ ≈ 100 µA OK；FF / SS / -40 / 125°C 任一 corner IQ 漂 50-100%。

### 物理因果链
```
IQ ∝ (Vov_static)² → Vov 受 Vth 跨 corner 漂
floating bias 链 ↔ Stage1 偏置 ↔ ibias 协同 PVT 漂
```

### 根因可能性表

| 根因 | corner | 修复 |
|---|---|---|
| floating bias 链不对称 PVT | FF/SS | 整链 W/L 比例严格匹配 |
| Stage1 vbias_n 漂 | FF（Vth ↓ → Id ↑）| 加 cascode in stage1 / R-trim |
| Output Vth 漂 → Vov 漂 | -40 / 125°C | 接受 IQ 漂 50% 设 margin |
| ibias 自身漂（bandgap reference 不准）| 跨 PVT | 看 bandgap troubleshooting |

> **SS @ 125°C** 通常是 class-AB 最严 corner（高温 + 慢 PMOS → IQ 上 trend；
> 但 dynamic 时 max drive 下降）。**必须跨 corner 验证 IQ + max drive**。

---

## 失败模式 7：Stage1 跨级耦合（v1_out 偏）

详见 `bias-headroom.md` 范例 4。简短：

| 根因 | 修复 |
|---|---|
| Stage1 NMOS mirror typo（MN1 vs MN2）| 严格 W/L/m 匹配 |
| Stage1 PMOS pair typo（MP1 vs MP2）| 严格匹配 |
| MP1 不 diode-connected | MP1.G = MP1.D = v1_n |
| MP2.G 接错 | MP2.G = v1_n (mirror master) |

⚠️ **跨级耦合铁律**：v1_out 偏时**先验 Stage1 mirror，不要直接调 Stage2**。

---

## 失败模式 8：Load-dependent stability（CL > 设计）

详见 `ac-stability.md` 范例 2。

### 修复
- spec 时标 CL_max；超 CL 用 LDO buffer 串联
- Cc 大幅增（同步 CL 比例缩 0.5-1）

---

## 失败模式 9：Output PMOS / NMOS triode（rail-to-rail 极限）

详见 `bias-headroom.md` 范例 3。简短：

| 根因 | 修复 |
|---|---|
| vout 接近 VDD → \|Vds_MP_out\| < Vdsat | 减 \|Vov_MP_out\|（W·m ↑）；接受 swing 限制 |
| vout 接近 GND → Vds_MN_out < Vdsat | 减 Vov_MN_out；接受 swing 限制 |

> **物理边界**：纯 rail-to-rail 不可能（必须保 cascode bias）；典型极限 VDD - 50-100 mV。

---

## 失败模式 10：Asymmetric SR+ vs SR-

**症状**：tb_slew 测 SR+ ≠ SR-（差 30%+）；output 单边响应慢。

### 物理因果链
```
SR+ = I_MP_out_max / CL（PMOS 推电流）
SR- = I_MN_out_max / CL（NMOS 拉电流）

要 SR+ = SR- → I_MP_out_max = I_MN_out_max
→ µp·W_p·m_p / L_p = µn·W_n·m_n / L_n (同 Vov_max)
→ W_p / W_n ≈ μn / μp ≈ 2.5 (vpdk180nm)
```

### 修复
W_p / W_n 比例校正（V4 reference 2:1 = 200µm:100µm）。

---

## When to load this chapter

- IQ / crossover / max drive / PM 任一不达标
- 看到 tb_dc_op / tb_dynamic / tb_drive / tb_slew 异常
- agent 调 sizing 撞壁（多次试都没收敛）
- cross-corner 仿真发现退化

## Related

- **device 不 saturation** → `bias-headroom.md`（IQ 失控 + crossover + Stage1 跨级）
- **AC PM + Miller + dynamic gm 失稳** → `ac-stability.md`
- **设计推进顺序 + sizing 起点** → `sizing-typical.md`
- **拓扑选型** → `architecture.md`（spec > class-AB 范围时换拓扑）
- **Class-A 2-stage 对照** → `blocks/two-stage-ota/troubleshooting`
- **Stage1 5T troubleshooting** → `blocks/5t-ota/troubleshooting`
- **通用诊断方法** → `skill: systematic-debugging` / `signal-tracing`
