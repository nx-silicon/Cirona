---
chapter: troubleshooting
parent: three-stage-ota
summary: |
  Three-stage opamp 系统级失败模式 + 物理因果链 + 根因可能性表。涵盖 gain
  ceiling 不达 / NMC PM 紧 / RHP zero 不消 / 跨级 cascade 失锁 / Stage1 v1_out
  跑 rail / Stage2 v2_out 失锁 / cross-corner 退化 / 大 CL 失稳。
tokens: ~1500
prerequisite_chapters:
  - architecture
  - bias-headroom
  - ac-stability
related_skills:
  - meta-cognitive/systematic-debugging
  - circuit-method/signal-tracing
  - circuit-method/device-sizing
---

# Three-Stage Opamp Troubleshooting

> 通用诊断顺序见 `skill: systematic-debugging`（4-phase）+ `skill: signal-tracing`
> （信号反推）。本章节给的是 **3-stage 拓扑特有**的失败模式 + 物理因果链 +
> 根因可能性表。**device 不 saturation 触发的失败**（cascade 失锁 / Stage1
> 跑 rail）见 `bias-headroom.md`；**NMC PM / Cc / Rc 失稳** 见 `ac-stability.md`。

## 诊断顺序（**3-stage 推荐顺序**）

```
1. tb_dc_op 看各 stage 静态点
   - v1_out / v2_out / vout 跑 rail → 见模式 1, 2, 3（cascade）
   - 静态 OK → 进步骤 2
   ↓
2. tb_ac_gain_bw 测 quiescent gain
   - gain < spec → 见模式 4（gain 分配）
   - gain OK → 进步骤 3
   ↓
3. tb_ac_gain_bw 测 quiescent PM
   - PM < 50° → 见模式 5（NMC Cc/Rc）
   - PM OK → 进步骤 4
   ↓
4. cross-corner 跑全 sweep
   - PVT PM 退化 > 15° → 见模式 6
   ↓
5. Load step + 大 CL test
   - dynamic ringing → 见模式 7
```

## 失败模式 1：Stage1 v1_out 跑 rail

> 同 2-stage 跨级耦合根因。

详见 `bias-headroom.md` 范例 1 + `blocks/two-stage-ota/bias-headroom` 范例 1。
简短：

| 根因 | 修复 |
|---|---|
| MP1 / MP2 W/L typo | 严格 W/L/m 匹配 |
| MN1 / MN2 W/L typo | 严格匹配 |
| MP1 不 diode-connected | MP1.G = MP1.D = v1_n |
| MP2.G ≠ v1_n | MP2.G = v1_n |

---

## 失败模式 2：Stage2 v2_out 失锁

> **3-stage 特有**（中间级独有）。

详见 `bias-headroom.md` 范例 2。简短根因表：

| 根因 | 修复 |
|---|---|
| Stage1 v1_out 偏 → Stage2 KCL 不平衡 | 见模式 1 |
| MP3 mirror ratio 错（m_MP3 / m_MP_bias）| 校 m 比例 |
| MN3 W·m 偏离设计 | 校 W·m_MN3 |

> **R2 铁律**：Stage2 v2_out 失锁时**先验 Stage1 v1_out**——根因 80% 在前级。

---

## 失败模式 3：Stage3 vout 偏

详见 `bias-headroom.md` 范例 3。简短：

| 根因 | 修复 |
|---|---|
| Stage2 v2_out 偏（cascade）| 见模式 2 |
| MN4 mirror ratio 错（m_MN4 / m_MN_bias）| 校 m 比例 |
| MP4 W·m 偏离设计 | 校 W·m_MP4 |

---

## 失败模式 4：Total gain < spec（gain ceiling 不达 100 dB）

详见 `ac-stability.md` 范例 3。简短：

| 根因 | 修复 |
|---|---|
| Stage1 L 短（ro 低）| L_diff_stage1 ↑（典型 1 → 2µm 起点）|
| Stage2 L 短 | L_cs2 ↑（典型 0.5 → 1µm 起点）|
| Stage3 L 短 | L_cs3 ↑（trade-off：drive 下降）|
| 任一 stage gain 严重低（< 25 dB）| 看 op_point_check 的 gm × ro，找最弱 stage |
| 单 stage 进 triode | 见 `bias-headroom.md` |

### 边界判断
3-stage 物理上限 ~130 dB。gain ≥ 130 dB 必须 cascode in stage1（gain-boosted
3-stage 不在本章）。

---

## 失败模式 5：Quiescent PM < 50°

详见 `ac-stability.md` 范例 1+2。简短根因表：

| 根因 | 修复 |
|---|---|
| Cc1 太小（< 0.5×CL）| Cc1 ↑（30% 步长）|
| Cc2 太大（接近 Cc1）| Cc2 ↓ → inner pole 推得更远 |
| Rc1 / Rc2 偏离 1/gm（RHP zero 不消）| 实测 gm 后调 Rc |
| f_p2' 太接近 GBW（gm_combined 太小）| Stage2 / Stage3 m_cs ↑ |
| ngspice vp() 弧度（PM 错 57×）| `set units = degrees` |

---

## 失败模式 6：Cross-corner PM 退化

**症状**：TT @ 27°C PM = 60° OK；FF / SS / -40 / 125°C 任一 corner PM < 50°。

### 物理因果链
```
跨 corner gm 漂 (FF gm ↑, SS gm ↓) → f_p2' / f_p3' 漂
→ NMC pole splitting 比例漂
→ PM 余量减
```

### 修复路径
| 路径 | 怎么做 |
|---|---|
| quiescent PM 设 70°+ margin | 跨 corner 跌 10°仍 > 60° |
| Cc1 ↑（trade GBW）| GBW 减但 PM 余量大 |
| Stage gm 加 m（trade power）| gm_combined ↑ → f_p2' / f_p3' 都 ↑ |
| Cross-corner sweep 设计-time 验证 | sizing-time 排查 |

> **3-stage 跨 corner 比 2-stage 严格**——3 个极点都跨 corner 漂，必须 sweep。

---

## 失败模式 7：大 CL 失稳

**症状**：spec CL = 5 pF。tb_ac_gain_bw OK；但实际 PCB CL = 50 pF → PM < 30°。

### 物理因果链
```
CL ↑ → f_p3' = gm_MP4 / CL ↓ → 与 GBW 距离缩
3-stage 比 2-stage 更敏感（多极点）
```

### 修复
| 路径 | 怎么做 |
|---|---|
| Cc1 ↑（同步 CL ratio）| 保 GBW / f_p2' 比例 |
| 增 W·m_MP4（gm_MP4 ↑）| f_p3' 提 |
| 加 LDO buffer（驱动大 CL 串联）| 系统级 |

---

## 失败模式 8：DC latch（loop sign 反）

**症状**：DC `op` 显示 vout latch to rail；不是 systematic offset，而是
loop 反向稳定。

### 物理因果链
```
3-stage 反相极性叠加：
  Stage1 (5T): 非反相
  Stage2 (NMOS-CS): 反相
  Stage3 (PMOS-CS): 反相
  总：+−− = +
  
loop sign：vout 接 vinn → 负反馈
  vout ↑ → vinn ↑ → vinp 相对低 → Stage1 平衡 → vout ↓（锁定）

如果误用 vinp 接 vout：
  vout ↑ → vinp ↑ → Stage1 v1_out ↑ → ... → vout ↑ (正反馈)
  → DC latch
```

### 修复
- 写 3-stage 网表前画小信号 loop sign 验证
- 反复验证：feedback path 接 vinn（不是 vinp）

---

## 失败模式 9：NMC nulling resistor 接错

**症状**：tb_ac_gain_bw 测 quiescent PM 不稳定（每次跑结果不同）；THD 异常。

### 物理因果链
```
NMC Rc1 / Rc2 各自必须接到 vout 端：
  Rc1: vout ↔ vout_comp1 (intermediate node)
  Cc1: v1_out ↔ vout_comp1
  → 等效 Rc1 + Cc1 串联，Cc1 input side 在 v1_out，Rc1 output side 在 vout

错接（Rc1 一端不在 vout）：
  → RHP zero 位置不对 → PM 不稳
```

### 修复
检查网表 Rc1 / Rc2 一端**必须**接 vout；详见 `reference-design.md` connectivity rules。

---

## When to load this chapter

- 跨级 cascade 任一 stage 静态点偏
- gain ceiling / PM / cross-corner 任一不达标
- agent 调 sizing 撞壁

## Related

- **device 不 saturation + 跨级耦合** → `bias-headroom.md`
- **NMC AC PM + RHP zero + Cc/Rc** → `ac-stability.md`
- **设计推进顺序 + sizing 起点** → `sizing-typical.md`
- **拓扑选型** → `architecture.md`
- **2-stage 对照** → `blocks/two-stage-ota/troubleshooting`
- **通用诊断方法** → `skill: systematic-debugging` / `signal-tracing`
