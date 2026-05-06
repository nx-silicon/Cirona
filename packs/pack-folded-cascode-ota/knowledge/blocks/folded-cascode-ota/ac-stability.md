---
chapter: ac-stability
parent: folded-cascode-ota
summary: |
  FC-OTA 极点分布特征（主极点 vout + fold node 极点 + cascode source 极点）
  + 单级 cascode 不需 Miller 补偿（关键事实）+ PM/GBW/CL 之间因果。
  通用断环方法见 ac-feedback-loop-method skill。
tokens: ~1100
prerequisite_chapters:
  - architecture
related_skills:
  - ac_feedback_loop_method
related_knowledge:
  - simulators/ngspice
  - blocks/5t-ota
  - blocks/two-stage-ota
---

# FC-OTA AC Stability

> 通用 AC 断环方法（Method C：Rfb=1G + Cfb=1F）见 `skill: ac-feedback-loop-method`。
> 本章节给的是 **FC-OTA 极点分布特征**与**单级 cascode 特定的补偿哲学**。

## 极点分布（FC-OTA 单级 + cascode 特征）

FC 是单级 OTA + cascode（双侧 Rout 高）。单级 OTA 的极点分布：

### 主极点：vout 节点

```
f_p1 ≈ 1 / (2π · Rout · CL)
其中 Rout = Rout_p ‖ Rout_n
      Rout_p = gm_pcasc · ro_pfold · ro_pcasc  ≈ 10-50 MΩ
      Rout_n = gm_ncasc · ro_nmirror · ro_ncasc ≈ 10-50 MΩ
```

**典型位置**：CL = 1pF / Rout = 20MΩ → f_p1 ≈ 8 kHz（远低于 5T 的 100 kHz，
因为 cascode 把 Rout 提了 ~100×）。

### 次极点：fold node（vmid_left1 / vmid_right1）

```
f_p2 ≈ gm_pcasc / (2π · C_fold_node)
其中 C_fold_node = Cdb_MN1 + Cgs_MP2 + Cdb_MP1 + Cgd_MP2
```

**典型位置**：W_fold = 24µm × m=2 + W_pcasc = 8.9µm × m=6 → C_fold_node
≈ 100-200 fF → f_p2 ≈ 100-300 MHz。

> **FC-OTA 关键节点**：fold junction (`vmid_left1` / `vmid_right1`) 是
> 大寄生节点（fold device + cascode device 都接这里）。**降低 fold 节点
> 寄生 cap 是改善 PM 的主要手段**。

### 三极点：cascode source（vmid_left2 / vmid_right2）

```
f_p3 ≈ gm_ncasc / (2π · C_cascode_source)
```

**典型位置**：通常 > 500 MHz（cascode source 节点寄生小），不影响 PM。

### 关键事实：FC-OTA 是 single-pole-dominant 系统

主极点 f_p1 远低于次极点 f_p2（典型 f_p2 / f_p1 > 1000，因 cascode 把 Rout 提 100×）。
**这是 FC-OTA 不需要外加补偿的物理本质**：

```
GBW = gm_M1 / (2π · CL) ≈ 30-100 MHz
f_p2 ≈ 100-300 MHz
GBW / f_p2 ≈ 30-50%  →  PM 60-70°
```

⚠️ **不要给 FC-OTA 加 Miller 补偿**——它本来就是单极点主导，加 Miller 反而把
主极点推得更低，BW 严重缩水，且引入 RHP zero。Miller 补偿是**两级 OTA** 的事
（见 `blocks/two-stage-ota/ac-stability`）。

## PM 计算（单极点系统 + fold 极点）

```
phase(f) = -arctan(f / f_p1) - arctan(f / f_p2) - ...
PM = 180° + phase(GBW)

如果 GBW < f_p2 / 3：
  PM ≈ 90° - arctan(GBW / f_p2)
  GBW = f_p2/10  →  PM ≈ 84°
  GBW = f_p2/3   →  PM ≈ 72°
  GBW = f_p2     →  PM ≈ 45°
```

> FC 的 PM 设计起点：保证 `GBW < f_p2 / 3`。f_p2 由 fold node cap 决定 →
> sizing 时控制 W_fold + W_pcasc 不要过大。

## CL 对 PM 的影响

CL ↑ → f_p1 ↓ → GBW ↓ → PM ↑（更稳）。
CL ↓ → f_p1 ↑ → GBW ↑ → 接近 f_p2 → PM ↓（不稳）。

**FC-OTA 设计 CL 范围**：
- CL = 0.5 pF 起：GBW 接近 f_p2，PM 紧（< 50°）
- CL = 1-10 pF：sweet spot，PM 60-80°
- CL > 10 pF：BW 太低，FC 失去 high-speed 优势 → 用 2-stage 更省 power

## 失稳模式（PM < 50°）

### 模式 1: GBW 太接近 fold node 极点

**症状**：tran 仿真有 ringing，AC PM < 45°。

**根因路径**：
```
GBW = gm_M1 / (2π · CL) 
f_p2 = gm_pcasc / (2π · C_fold)

GBW / f_p2 = (gm_M1 / gm_pcasc) · (C_fold / CL)
```

通常 gm_M1 / gm_pcasc ≈ 0.5-1（fold device W 通常较 input pair 大），
所以要 GBW / f_p2 < 1/3 → C_fold / CL < 1/3。

**修复路径**：
1. **CL ↑**（最直接）—— 把 GBW 推低 → PM 改善
2. **W_fold ↓**（增 Vdsat 但减 fold node cap）—— f_p2 ↑ → PM 改善
3. **W_pcasc ↓ 但 m_pcasc ↑**（保 ro，减 Cgs）—— f_p2 ↑（**FC 推荐路径**）
4. **L_load ↑** —— 不太直接影响 f_p2，但 ro_pfold ↑ → gain ↑，可让
   W_fold 缩得更激进

### 模式 2: m_tail 与 m_fold 不同步导致 fold_ratio 异常

**症状**：DC OP PASS 但 GBW << target / PM 不稳。

**根因**：m_fold 没跟 m_tail 同步 → fold_ratio < 1.5 → cascode branch 接近 cutoff
→ ro_cascode 异常 → Rout 异常 → GBW / PM 都漂移。

**修复**：见 `sizing-typical.md` fold_ratio 耦合规则——**改 m_tail 必须同步 m_fold**。

### 模式 3: ngspice vp() 当度数 → PM 假象 178°

**症状**：testbench 漏 `set units = degrees` → vp() 返回 radians → PM 数字
看似 178° 实际 3°。

**修复**：testbench 必含 `set units = degrees`。详见 `simulators/ngspice/measurements`。

### 模式 4: tail 节点 zero / pole（差分→共模）

FC-OTA tail 节点（M1, M2 source）也会引入 pole-zero pair（差分到共模信号
转换路径）。**通常远高于 GBW**，差分应用下不影响 PM。但 single-ended-input
应用要注意（见 `blocks/base-cells/differential-pair/basic`）。

## CMFB 极点（fully-differential 变体）

**仅 fd_cmfb variant 适用**：CMFB 闭环引入额外极点（CMFB OTA 的 GBW + 共模
节点 cap）。**CMFB 闭环 PM 必须独立验证**——不能只看主信号 PM。

详见 `blocks/base-cells/cmfb`。

## ngspice testbench（Method C 断环）

参见 `reference-design.md` 的 `tb_ac_gain_bw.sp` 模板。**Iron Law**：
- `set units = degrees`（不写 PM 数字 178° 假象）
- Rfb = 1G + Cfb = 1F（DC 闭环 + AC 开环）
- AC source 接 vinp DC bias + AC 1
- `.meas ac` 用 `dc_gain` / `gbw_hz` / `pm_deg` 三件套

具体 .meas 写法 + 工艺标 .lib 见 `simulators/ngspice/measurements`。

## 不在本章范围

- **通用 AC 断环原理（Method C）** → `skill: ac-feedback-loop-method`
- **ngspice .meas / .ac 语法** → `simulators/ngspice/analyses`
- **不同 OTA 拓扑的极点对比** → `blocks/5t-ota/ac-stability` / `two-stage-ota/ac-stability`（多极点 + Miller）
- **Vds-Vdsat 触发的 PM 假象** → `bias-headroom.md`（device 不 sat 时 PM 数值无意义）

## Related

- `skill: ac-feedback-loop-method` 通用断环 + Method C 推导
- `blocks/two-stage-ota/ac-stability` Miller 补偿 / RHP zero（对照学习）
- `blocks/base-cells/cascode` cascode source 节点极点物理
- `simulators/ngspice/measurements` .meas 语法
