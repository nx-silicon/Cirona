---
chapter: ac-stability
parent: telescopic-ota
summary: |
  Telescopic OTA 极点分布特征（主极点 vout + cascode source 极点 + mirror node
  极点）+ 单级 cascode 不需 Miller 补偿（关键事实）+ PM/GBW/CL 之间因果。
  与 FC 极点分布对照学习。
tokens: ~1100
prerequisite_chapters:
  - architecture
related_skills:
  - ac_feedback_loop_method
related_knowledge:
  - simulators/ngspice
  - blocks/folded-cascode-ota
  - blocks/two-stage-ota
---

# Telescopic OTA AC Stability

> 通用 AC 断环方法（Method C：Rfb=1G + Cfb=1F）见 `skill: ac-feedback-loop-method`。
> 本章节给的是 **Telescopic OTA 极点分布特征**与**单级 cascode 特定的补偿哲学**。

## 极点分布（Telescopic 单级 + cascode 特征）

Telescopic 是单级 OTA + cascode（双侧 Rout 高）。与 FC 类似但极点位置略有差异。

### 主极点：vout 节点

```
f_p1 ≈ 1 / (2π · Rout · CL)
其中 Rout = Rout_p ‖ Rout_n
      Rout_p = gm_pcasp · ro_load · ro_pcasp        ≈ 10-50 MΩ
      Rout_n = gm_ncasc · ro_diff · ro_ncasc        ≈ 10-50 MΩ
```

**典型位置**：CL = 1pF / Rout = 20MΩ → f_p1 ≈ 8 kHz（与 FC 同量级，cascode 把 Rout 提到 ~10× 单级）。

> **Telescopic Rout_n vs FC**：Telescopic 的 Rout_n 包含 ro_diff（input pair
> 在 stack 中），FC 的 Rout_n 包含 ro_nmirror（input pair 在独立 branch）。
> 两者相当。

### 次极点：cascode source（ncasc / nload）

```
f_p2 ≈ gm_cascode / (2π · C_cascode_source)
其中 C_cascode_source = Cdb_MM1 + Cgs_MMcasc + Cdb_diff + Cgd_MMcasc
```

**典型位置**：C_cascode_source 较 fold node 小（少一组 fold device），
f_p2 ≈ 200-500 MHz（Telescopic 比 FC 略高）。

> **Telescopic vs FC 次极点**：
> - **FC**：fold node 是大寄生节点（fold device + cascode device 都接），
>   f_p2 ≈ 100-300 MHz
> - **Telescopic**：cascode source 节点寄生小（只有 input pair drain + cascode），
>   f_p2 ≈ 200-500 MHz
> - **结论**：**Telescopic 的 PM 通常比 FC 容易**（次极点更远）

### 三极点：mirror node（vout_n）

```
f_p3 ≈ gm_load / (2π · C_mirror_node)
其中 C_mirror_node = Cgs_MM3 + Cgs_MM4 + Cdb_pcasp + ...
```

**典型位置**：通常 > 500 MHz，不影响 PM。

### 关键事实：Telescopic 是 single-pole-dominant 系统

主极点 f_p1 远低于次极点 f_p2（典型 f_p2 / f_p1 > 1000，因 cascode 把 Rout 提 100×）。
**这是 Telescopic 不需要外加补偿的物理本质**：

```
GBW = gm_MM1 / (2π · CL) ≈ 30-120 MHz
f_p2 ≈ 200-500 MHz
GBW / f_p2 ≈ 30-50%  →  PM 60-70°
```

⚠️ **不要给 Telescopic 加 Miller 补偿**——它本来就是单极点主导，加 Miller 反而把
主极点推得更低，BW 严重缩水，且引入 RHP zero。Miller 补偿是**两级 OTA** 的事
（见 `blocks/two-stage-ota/ac-stability`）。

## PM 计算（单极点系统）

```
phase(f) = -arctan(f / f_p1) - arctan(f / f_p2) - ...
PM = 180° + phase(GBW)

如果 GBW < f_p2 / 3：
  PM ≈ 90° - arctan(GBW / f_p2)
  GBW = f_p2/10  →  PM ≈ 84°
  GBW = f_p2/3   →  PM ≈ 72°
  GBW = f_p2     →  PM ≈ 45°
```

> Telescopic PM 设计起点：保证 `GBW < f_p2 / 3`。f_p2 由 cascode source 节点
> cap 决定 → sizing 时控制 W_diff + W_cascode 不要过大。

## CL 对 PM 的影响

CL ↑ → f_p1 ↓ → GBW ↓ → PM ↑（更稳）。
CL ↓ → f_p1 ↑ → GBW ↑ → 接近 f_p2 → PM ↓（不稳）。

**Telescopic 设计 CL 范围**（与 FC 同）：
- CL = 0.5 pF 起：GBW 接近 f_p2，PM 紧（< 50°）
- CL = 1-10 pF：sweet spot，PM 60-80°
- CL > 10 pF：BW 太低，Telescopic 失去 high-speed 优势

## 失稳模式（PM < 50°）

### 模式 1: GBW 太接近 cascode source 极点

**症状**：tran 仿真有 ringing，AC PM < 45°。

**根因路径**：
```
GBW = gm_MM1 / (2π · CL) 
f_p2 = gm_ncasc / (2π · C_cascode_source)

GBW / f_p2 = (gm_MM1 / gm_ncasc) · (C_cascode_source / CL)
```

通常 gm_MM1 / gm_ncasc ≈ 1（同密度 cascode 设计），所以要 GBW / f_p2 < 1/3
→ C_cascode_source / CL < 1/3。

**修复路径**：
1. **CL ↑**（最直接）—— 把 GBW 推低 → PM 改善
2. **W_diff ↓**（增 Vdsat 但减 cascode source cap）—— f_p2 ↑ → PM 改善
3. **W_cascode ↓ 但 m_cascode ↑**（保 ro，减 Cgs）—— f_p2 ↑（**Telescopic 推荐路径**）
4. **L_diff ↑** —— ro_MM1 ↑ → Rout_n ↑ → gain ↑（**Telescopic 特有路径**：
   Rout_n 包含 ro_diff，所以 L_diff 直接进 gain）

### 模式 2: bias 支路密度失配（V3 实战教训）

**症状**：DC OP 显示 vbnc / vbpc 落点错（vbnc 偏低 / vbpc 偏高）→ MM1 / MM3
进 triode → AC gain 仅 3-10 dB（bias triode 让所有 device 工作点漂移）。

**根因**：bias 支路（MMbp_nc / MMbn_pc）m 倍数与主支路（MMtail / MMbias）
不匹配 → bias 支路单管电流密度 ≠ 主支路单管电流密度 → MMbnc_top 的 Vgs ≠
MMcasc 的 Vgs → vbnc 落点错。

**修复**：见 `sizing-typical.md` 同密度铁律——`m_MMbp_nc = m_load × m_tail / (2 × m_bias)`。

### 模式 3: ngspice vp() 当度数 → PM 假象 178°

**症状**：testbench 漏 `set units = degrees` → vp() 返回 radians → PM 数字
看似 178° 实际 3°。

**修复**：testbench 必含 `set units = degrees`。详见 `simulators/ngspice/measurements`。

### 模式 4: tail 节点 zero / pole（差分→共模）

Telescopic OTA tail 节点（MM1, MM2 source）也会引入 pole-zero pair（差分到共模信号
转换路径）。**通常远高于 GBW**，差分应用下不影响 PM。

## CMFB 极点（fully-differential 变体）

**仅 fd_cmfb variant 适用**：CMFB 闭环引入额外极点。**CMFB 闭环 PM 必须独立验证**。

详见 `blocks/base-cells/cmfb`。

## ngspice testbench（Method C 断环）

参见 `reference-design.md` 的 `tb_ac_gain_bw.sp` 模板。**Iron Law**：
- `set units = degrees`（不写 PM 数字 178° 假象）
- Rfb = 1G + Cfb = 1F（DC 闭环 + AC 开环）
- AC source 接 vinp DC bias + AC 1
- `.meas ac` 用 `dc_gain` / `ugf` / `pm` 三件套
- **加 CL 显式**（PM 强烈依赖 CL）

具体 .meas 写法 + 工艺标 .lib 见 `simulators/ngspice/measurements`。

## 不在本章范围

- **通用 AC 断环原理（Method C）** → `skill: ac-feedback-loop-method`
- **ngspice .meas / .ac 语法** → `simulators/ngspice/analyses`
- **不同 OTA 拓扑的极点对比** → `blocks/folded-cascode-ota/ac-stability`（fold node）/ `two-stage-ota/ac-stability`（Miller）
- **Vds-Vdsat 触发的 PM 假象** → `bias-headroom.md`（device 不 sat 时 PM 数值无意义）
- **wide-swing 同密度失配引发的 bias triode** → `bias-headroom.md` + `sizing-typical.md`

## Related

- `skill: ac-feedback-loop-method` 通用断环 + Method C 推导
- `blocks/folded-cascode-ota/ac-stability` FC 对照（fold node 极点）
- `blocks/two-stage-ota/ac-stability` Miller 补偿对照
- `blocks/base-cells/cascode` cascode source 节点极点物理
- `simulators/ngspice/measurements` .meas 语法
