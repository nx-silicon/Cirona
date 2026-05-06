---
chapter: common-errors
parent: ngspice
summary: |
  ngspice 实战 14 条错误 → 症状 / 原因 / 修复对照表。
  按错误**类型**分组（路径 / 命名 / 数值 / setplot / meas / 选项 / 调用），
  不按编号顺序，便于按症状定位。
tokens: ~1100
prerequisite_chapters:
  - analyses
related_skills:
  - meta-cognitive/systematic-debugging
  - circuit-method/causal-chain-debug
  - circuit-method/ac-feedback-loop-method
---

# ngspice 错误对照表

按"症状关键字"快速定位修复方向。每条：**症状** → **物理 / 语义原因** → **修复**。

---

## 路径类

### "Could not find library file"

```
Error: Could not find library file pdk/vpdk180nm_corners.lib
```

**原因**：路径相对 **testbench cwd** 解析（不是 project root）。Testbench 在 `<project>/testbench/`，写 `pdk/...` 解析为 `<project>/testbench/pdk/...`，不存在。

**修复**：写 `../pdk/...` 和 `../design/...`：
```spice
.lib    "../pdk/vpdk180nm_corners.lib" tt
.include "../design/your_ota.cir"
```

### `wrdata` 写到错位置（不报错但找不到文件）

**原因**：同上，`wrdata` 路径也是相对 testbench cwd。

**修复**：
```spice
* library 布局
wrdata ../simulation/tb_ac/bode.csv frequency gain_db phase_deg

* flat 布局
wrdata ../results/tb_ac/bode.csv    frequency gain_db phase_deg
```

ACP 项目有两种目录布局（详见 `chapter=measurements`）；选哪种决定 `wrdata` 路径前缀。

---

## 命名 / 访问类

### "no such parameter @xota.m_dp1[id]"

**原因**：device 参数访问要 **type 前缀**（`m.` MOSFET / `r.` 电阻 / `c.` 电容）。

**修复**：
```spice
* ❌
print @xota.m_dp1[id]

* ✅
print @m.xota.m_dp1[id] @m.xota.m_dp1[vds] @m.xota.m_dp1[vdsat]
```

完整文法：`@<type>.<x_inst_chain>.<device>[param]`。

### "no such vector i(iload)"（在 DC sweep 中）

**原因**：DC sweep 中电流源变量是 `@<source>[i]`（小写 + `[i]` 后缀），不是 `i(<name>)`。`i()` 形式仅适用 transient / op。

**修复**：
```spice
* ❌
wrdata load_reg.csv i(Iload) v(vout)

* ✅
wrdata load_reg.csv @iload[i] v(vout)
```

### `v(ibias)` 显示 ~0.5–0.7 V（**不是错误**，是误读）

**症状**：印 `v(ibias)` 看到 0.57 V，怀疑电流源坏了。

**原因**：`ibias` 是**节点名**，不是电流。Testbench 通常 `Ibias vdd ibias DC 20u`——`ibias` 节点的电压由下游 device 钳位（diode-connected NMOS 钳到 Vth+Vov ≈ 0.5–0.7V，正常）。实际**电流**就是 `Ibias` 卡里写的 20µA。

**修复**：要看电流用 `print @ibias[i]`（DC sweep）或 OP report；要看节点电压用 `print v(ibias)`。两者意思不同。

---

## AC 数值表达类

### "argument out of range for db"（`.control` 中断）

**原因**：`db(x) = 20·log10(x)` 要求 `x > 0`。AC 信号过零或某点为零 → log10(0) = -∞ → 抛错 → 整段 `.control` 中断。

**修复**：
```spice
let gain_db = db(abs(v(vout)) + 1e-20)
```

`abs()` 处理复向量取模 + `1e-20` 防绝对零。

### PM 报 178° 看着对实际错 57×

**原因**：`vp(<node>)` 返回**弧度**不是度。当作度处理 → 误差 180/π ≈ 57.3 倍。

**修复**：
```spice
let phase_deg = 180/PI * vp(vout)
```

`PI` 是 ngspice 内置常数，不需 `.param`。**setplot ac1 后立即转换**，避免后续 `meas` 拿弧度。

---

## setplot 漏切类

### "no such vector frequency"

**原因**：mixed `.op + .ac` 后默认 plot 是 `op1`（第一个分析）。AC 矢量（`frequency` / `vdb(vout)` / `vp(vout)`）只活在 `ac1`。

**修复**：`run` 后立即 `setplot ac1`：
```spice
.control
  run
  setplot ac1                $ <-- 必须
  let gain_db = db(abs(v(vout)) + 1e-20)
  ...
.endc
```

### "no such vector as 'gain_db'"（在 meas 时）

**原因**：要么 (a) `let gain_db = ...` 之前漏 `setplot`，导致 `let` 在错误 plot 上失败；要么 (b) `let` 引用的源向量在当前 plot 不存在。

**修复**：
1. 确认 `setplot ac1` 在所有 AC `let` 之前
2. `print` 一个已知的 AC 矢量（如 `print frequency`）确认 plot 活着
3. 二分法 comment-out 一半 `meas` 块跑，逐步定位失败行

---

## meas 用法类

### "measure limited to tran, dc, sp, or ac"

**原因**：用了 dot-card `.meas`（在 `.control` 块外）。dot-card `.meas` 在 `.control` 执行前就 fire，不能引用 `.control` 内 `let` 定义的向量，也不响应 `setplot`。

**修复**：所有 `meas` 放进 `.control` 块（去掉前导 `.`）：
```spice
* ❌ dot-card 形式
.meas ac gain_dc find db(v(vout)) at=1

* ✅ in-control 形式
.control
  run
  setplot ac1
  let gain_db = db(abs(v(vout)) + 1e-20)
  meas ac gain_dc find gain_db at=1
.endc
```

ACP testbench 一律用 in-`.control` 形式。

### "no such vector as 'gbw'"（在 `at=gbw` 时）

**原因**：`meas ... at=<value>` 只接受**字面数字**，不接受其他 measurement 名。

**修复**：用 `when` 形式直接指定条件：
```spice
* ❌
meas ac gbw           when gain_db=0  cross=1
meas ac phase_at_gbw  find phase_deg  at=gbw

* ✅
meas ac phase_at_gbw  find phase_deg  when gain_db=0 cross=1
```

需要做派生计算（如 PM = 180 + phase_at_gbw，**注意符号**）用 `meas ... param='...'` 形式：
```spice
* phase_at_gbw 是 signed loop-gain phase（在 GBW 处常为负）
* 稳定 OPA：PM = 180 + phase_at_gbw（不是 -）
* 例：phase_at_gbw = -120° → PM = 60°
meas ac pm_deg param='180 + phase_at_gbw'
```
**易错点**：写 `180 - phase_at_gbw` 在 phase 为负时给出 > 180° 的值（错）。
详见 `simulators/ngspice/analyses.md` AC 测量段的 PM 公式说明。

---

## 选项类

### subckt 参数计算静默错误

**症状**：`{param}` 占位符 print 看着对，但 OP 报告的 device 尺寸不对。

**原因**：缺 `.option compat=ps`。ngspice 默认参数代换规则与 SPICE-PS 不同，`{param}` 内的算术有时塌成 0。

**修复**：testbench **第一行**：
```spice
.option compat=ps
```

每个 V4 testbench 模板必须含此行。

---

## 调用类（Windows）

### 调用 ngspice 弹 GUI 窗口

**原因**：Windows 上 `ngspice.exe` 是 GUI 变体——即使 `-b` batch 模式也会弹窗，破坏自动化。

**修复**：用 `ngspice_con.exe`（console 变体）+ `subprocess.CREATE_NO_WINDOW` flag。`simulate` Tool 的 handler 已处理。

---

## 不在本章范围（指向其他章 / skill）

| 现象 | 去哪 |
|---|---|
| DC OP 漂到轨 / 矩阵奇异 / 不收敛 | `chapter=convergence` |
| open-loop OTA AC sweep gain = -148 dB / 相位乱跳 | `chapter=convergence`（"反馈环未闭合"段）+ skill `circuit-method/ac-feedback-loop-method`（断点选择 / Rfb/Cfb 配置）|
| LDO / OTA 不稳定（PM < 30°） | `blocks/ldo/ac-stability.md` / `blocks/ota-*/ac-stability.md` + skill `circuit-method/ac-feedback-loop-method` |
| 比较器 metastability / kickback | `blocks/comparator-latch/troubleshooting.md` |
| 启动失败（bandgap / LDO 上电不振） | `blocks/bandgap/troubleshooting.md` / `blocks/ldo/troubleshooting.md` |
| MC / mismatch 测量 | skill `circuit-method/monte-carlo-mismatch-method` |
| 噪声测量配置 | skill `circuit-method/noise-analysis-method` + `chapter=analyses` § .noise |

ngspice common-errors 章只回答"ngspice 报错 / 不报错但行为错的 14 类"。物理 / 设计 / 拓扑层错误归各电路 knowledge + circuit-method skill。

---

## 自查清单（写完任何 ngspice testbench 必过）

- [ ] 第一行 `.option compat=ps`
- [ ] PDK 路径用 `../pdk/...`（不是 `pdk/...`）
- [ ] 多分析时 `setplot <name>` 显式切换
- [ ] AC `let phase_deg = 180/PI * vp(vout)` 转弧度→度
- [ ] AC `db()` 用 `db(abs(x) + 1e-20)` 防过零
- [ ] device 参数访问带 `m.` / `r.` 类型前缀
- [ ] 频率写 `100Meg` / `1g` 不写 `100M` / `1G`（M 是 milli）
- [ ] `meas` 在 `.control` 内不在外
- [ ] 跨 plot 数据用 `echo "$&var"` 内联展开（多次 `.op` 必备）
- [ ] Windows 调用 `ngspice_con.exe` 不是 `ngspice.exe`
