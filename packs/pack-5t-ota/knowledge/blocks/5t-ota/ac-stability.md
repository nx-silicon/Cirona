---
chapter: ac-stability
parent: 5t-ota
summary: |
  5T-OTA 极点分布特征 + 单级 OTA 不需 Miller 补偿（关键事实）+
  PM/GBW/CL 之间因果 + 不同 CL 下 PM 变化。通用断环方法见
  ac-feedback-loop-method skill。
tokens: ~900
prerequisite_chapters:
  - architecture
related_skills:
  - ac_feedback_loop_method
related_knowledge:
  - simulators/ngspice
---

# 5T-OTA AC Stability

> 通用 AC 断环方法（Method C：Rfb=1G + Cfb=1F）见 `skill: ac-feedback-loop-method`。
> 本章节给的是 **5T-OTA 极点分布特征**与**单级 OTA 特定的补偿哲学**。

## 极点分布（5T-OTA 单级特征）

### 主极点：output 节点

```
f_p1 ≈ 1 / (2π · Rout · Cout)
其中 Rout = ro_M2 ‖ ro_M4 ≈ 100k-300k
      Cout = CL（外部）+ Cdb_M2 + Cdb_M4
```

**典型位置**：CL = 1pF / Rout = 200k → f_p1 ≈ 800 kHz。

### 次极点：mirror node（M3/M4 G 共节点）

```
f_p2 ≈ gm_M3 / (2π · C_mirror_node)
其中 C_mirror_node = Cgs_M3 + Cgs_M4 + Cdb_M1 + Cdb_M3
```

**典型位置**：W_LOAD = 10µm → C_mirror_node ≈ 50-100 fF → f_p2 ≈ 100-300 MHz。

### 关键事实：5T-OTA 是 single-pole-dominant 系统

主极点 f_p1 远低于次极点 f_p2（典型 f_p2 / f_p1 > 100）。**这是 5T-OTA 不需要外加补偿的物理本质**：

```
GBW = gm_M1 / (2π · CL) ≈ 5-50 MHz
f_p2 ≈ 100-300 MHz
GBW / f_p2 ≈ 5-30%  →  PM > 60° 几乎自动满足
```

⚠️ **不要给 5T-OTA 加 Miller 补偿**——它本来就是单极点主导，加 Miller 反而把主极点推得更低，BW 严重缩水，且引入 RHP zero。Miller 补偿是**两级 OTA** 的事（见 `blocks/two-stage-ota/ac-stability`）。

## PM 计算（单极点系统）

```
phase(f) = -arctan(f / f_p1) - arctan(f / f_p2) - ...
PM = 180° + phase(GBW)

如果 GBW < f_p2 / 3：
  phase(GBW) ≈ -90° - small
  PM ≈ 90° - arctan(GBW / f_p2)

  GBW = f_p2/10 → PM ≈ 84°
  GBW = f_p2/3  → PM ≈ 72°
  GBW = f_p2    → PM ≈ 45°
```

## CL 对 PM 的影响

CL ↑ → f_p1 ↓ → GBW ↓ → PM ↑（更稳）。  
CL ↓ → f_p1 ↑ → GBW ↑ → 接近 f_p2 → PM ↓（不稳）。

**5T-OTA 设计 CL 范围**：
- CL = 0.5 pF 起：GBW 接近 f_p2，PM 紧（< 50°）
- CL = 1-10 pF：sweet spot，PM 60-80°
- CL > 10 pF：BW 太低，5T 失去 high-speed 优势

## 失稳模式（PM < 50°）

### 模式 1: GBW 太接近 f_p2

**症状**：tran 仿真有 ringing，AC PM < 45°。

**根因路径**：
```
GBW = gm_M1 / (2π · CL) 
f_p2 = gm_M3 / (2π · C_mirror_node)

GBW / f_p2 = (gm_M1 / gm_M3) · (C_mirror_node / CL)
```

通常 gm_M1 / gm_M3 ≈ 3（噪声铁律），所以要 GBW / f_p2 < 1/3 → C_mirror_node / CL < 1/9。

**修复路径**：
1. **CL ↑**（最直接）—— 把 GBW 推低 → PM 改善
2. **W_LOAD ↓**（增 Vdsat 但减 mirror cap）—— f_p2 ↑ → PM 改善
3. **L_LOAD ↑** —— 不太直接影响 f_p2（gm_M3 微变），但 ro_M4 ↑ → gain ↑，可让 W_LOAD 缩得更激进

### 模式 2: tail 节点 zero / pole

5T-OTA tail 节点（M1, M2 source）也会引入 pole-zero pair（差分到共模信号转换路径）。**通常远高于 GBW**，差分应用下不影响 PM。但 single-ended-input 应用要注意。

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
- **不同 OTA 拓扑的极点对比** → `blocks/folded-cascode-ota/ac-stability` / `two-stage-ota/ac-stability`（多极点 + Miller）
- **Vds-Vdsat 触发的 PM 假象** → `bias-headroom.md`（device 不 sat 时 PM 数值无意义）

## Related

- `skill: ac-feedback-loop-method` 通用断环 + Method C 推导
- `blocks/two-stage-ota/ac-stability` Miller 补偿 / RHP zero（对照学习）
- `simulators/ngspice/measurements` .meas 语法
