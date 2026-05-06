---
chapter: measurements
parent: ngspice
summary: |
  ngspice 测量与输出 —— .control 块结构 / let 计算 / meas ac dc tran 用法 /
  wrdata CSV 输出 / vp() radians vs deg 单位陷阱 / 跨 plot echo $&var 内联展开
tokens: ~900
prerequisite_chapters:
  - analyses
related_skills:
  - circuit-method/ac-feedback-loop-method
  - meta-cognitive/systematic-debugging
related_knowledge:
  - simulators/ngspice/common-errors
---

# ngspice 测量与输出（.control / let / meas / wrdata）

## .control 块基础

```spice
.control
  * 1) 跑分析（按需多个）
  op
  ac dec 50 1 1G
  
  * 2) 切换 plot（推荐显式写；当前 plot 是最后一次分析生成的 plot）
  setplot ac1
  
  * 3) 派生计算变量（let）
  let gain_db   = db(abs(v(vout)) + 1e-20)
  let phase_deg = 180/PI * vp(vout)
  
  * 4) 命名测量（meas）
  meas ac gain_dc      find gain_db    at=1
  meas ac gbw_hz       when gain_db=0  cross=1
  meas ac phase_at_gbw find phase_deg  when gain_db=0 cross=1
  meas ac pm_deg       param='180 + phase_at_gbw'   $ phase_at_gbw signed → PM = 180+phase
  
  * 5) 屏幕回显（关键 KPI 给 agent 抓）
  echo "gain_dc=$&gain_dc dB  gbw=$&gbw_hz Hz  pm=$&pm_deg deg"
  
  * 6) 写 CSV 给后续可视化
  wrdata ../simulation/tb_ac/bode.csv frequency gain_db phase_deg
.endc
```

⚠️ `.meas` dot-card 是 ngspice 支持的测量语句；agent testbench 统一**优先用 `.control` 内 `meas`**——结果会变成可继续引用的 vector，且更适合脚本化。

## let：内存变量计算

| 用途 | 语法 |
|---|---|
| 基础算术 | `let phase_deg = 180/PI * vp(vout)` |
| dB 变换 | `let gain_db = db(abs(v(vout)) + 1e-20)` （**+1e-20 防过零**）|
| 复数模 | `let mag = abs(v(vout))` |
| 复数相位（rad）| `vp(vout)` —— ngspice 自带函数 |
| 比例 / 折算 | `let loop_gain = abs(v(vout) / v(vinn))` |

⚠️ **vp() / phase 默认单位是 radians 不是 degrees**（除非显式 `set units=degrees`）—— ngspice 最常踩的坑。需要 deg 时乘 `180/PI` 或统一设置单位。
⚠️ **db(x) = 20·log10(mag(x))**；对可能为 0 的幅度统一加 `+ 1e-20`，避免 `-Inf` / 测量失败污染 KPI。

## meas：命名测量

三种典型用法：

### 1. `find ... at=` —— 取某点的值

```spice
meas ac gain_dc find gain_db at=1     $ DC 增益（@ f=1Hz 近似）
meas dc id_op  find @m.x_ldo.mn1[id] at=<source_value>  $ DC sweep 中某个 source 值下的器件电流
```

### 2. `when ... cross=` —— 找穿越点

```spice
meas ac gbw_hz       when gain_db=0  cross=1   $ gain 第 1 次穿 0 dB
meas ac phase_at_gbw find phase_deg when gain_db=0 cross=1   $ phase 在 GBW 处的值（必须 find phase_deg；裸 when 返回横轴值不是 phase）
meas tran tdelay     when v(vout)=0.5 cross=1  $ 边沿穿越 0.5V 的时间
```

### 3. `param=` —— 派生计算（用前面 meas 结果）

```spice
meas ac pm_deg param='180 + phase_at_gbw'    $ PM = 180 + signed phase
meas dc rout_kohm param='(v_out_h - v_out_l) / (i_h - i_l) / 1e3'
```

⚠️ `param='...'` 用于**标量派生计算**（必须单引号）；可引用前面 `meas` 结果或已定义的标量参数 / 标量 vector。**不要把完整波形 `v(...)` / `@m.X[Y]` 直接塞进 `param`**——这是 vector 不是 scalar；在 `.control` 内先 `let` 成 vector，再用 `find/when` 取标量。

## echo + $&var：跨 plot 内联展开（重要）

ngspice 的 `let` 变量、`meas` 结果都活在**当前 plot**。多次 `op` / 切换 plot 后，**bare print/wrdata 拿不到**：

```spice
.control
  op                              $ plot=op1
  let id_op = @m.x.mn1[id]
  
  ac dec 50 1 1G                  $ plot=ac1（自动切换）
  setplot ac1
  
  meas ac gbw_hz when ... cross=1 $ gbw_hz 在 ac1 plot
  
  setplot op1                     $ 切回 op1 想看 id_op
  print id_op                     $ ❌ 可能拿到旧值或失败
.endc
```

**解决方案**：用 `echo "$&var"` **内联展开**（`$&` 把当前 scalar / vector 值展开成字符串写进日志，写进去后不再依赖当前 plot；跨 plot 也可用 `plotname.vector` 显式引用）：

```spice
.control
  op
  let id_op = @m.x.mn1[id]         $ 先 let 成别名（@m.X[Y] 复杂设备名直接 $& 不稳）
  echo "id_op=$&id_op"             $ ✅ 立即展开值

  ac dec 50 1 1G
  setplot ac1
  meas ac gbw_hz when ... cross=1
  echo "gbw=$&gbw_hz"              $ ✅ 立即展开
.endc
```

agent 抓 KPI 时**统一用 echo "$&var"**，不要依赖 print / wrdata 跨 plot 取值。

## wrdata：写 CSV

```spice
wrdata ../simulation/tb_ac/bode.csv frequency gain_db phase_deg
```

**重要约定**：
- 路径**相对 testbench 工作目录**（不是绝对路径）
- 默认输出是**空白分隔 simple table**（不是严格 CSV）。real vec 默认每个 vec 占 **2 列**（scale + value）；**complex vec 占 3 列**（scale + real + imag）。`wr_singlescale` / `wr_vecnames` 选项会改变列布局——读 CSV 时按当前 set 状态解析。
- 文件不存在自动创建；存在则覆盖。
- 没有显式 header；读取方需自己知道列顺序。

## print：屏幕直接输出

```spice
print v(vout) v(vinn)              $ 多个节点
print @m.x_ldo.mn1[vds]            $ hierarchical 器件参数（注意 @m. 前缀）
print id_op gbw_hz                 $ 已 measured 命名变量
```

hierarchical 器件参数命名：
- 顶层 instance：`@m.<instance>[<param>]`，如 `@m.mn1[vds]`
- subckt 内 device：`@m.<x_chain>.<dev>[<param>]`，如 `@m.x_ldo.x_ea.mn1[vds]`
- 常用 param：`vds` / `vgs` / `vth` / `vdsat` / `gm` / `id` / `ids` / `region`（BSIM3 常见：0=cutoff / 1=triode-linear / 2=sat / 3=subth；以模型实现为准）

## 常用 measurement 模板

### AC：DC 增益 + GBW + PM（OPA / LDO loop）

```spice
.control
  op
  ac dec 50 1 1G
  setplot ac1
  
  let gain_db   = db(abs(v(vout)/v(vinn)) + 1e-20)    $ loop gain
  let phase_deg = 180/PI * (vp(vout) - vp(vinn))      $ loop phase
  
  meas ac gain_dc      find gain_db    at=1
  meas ac gbw_hz       when gain_db=0  cross=1
  meas ac phase_at_gbw find phase_deg  when gain_db=0 cross=1
  meas ac pm_deg       param='180 + phase_at_gbw'    $ signed phase(deg) 约为负值时：PM = 180+phase
  
  echo "gain_dc=$&gain_dc gbw=$&gbw_hz pm=$&pm_deg"
  wrdata ../simulation/tb_ac/loop.csv frequency gain_db phase_deg
.endc
```

### Tran：Slew Rate / settling

```spice
.control
  tran 1n 5u
  
  meas tran sr_pos    deriv v(vout) when v(vout)=0.9   $ V/s, rising slope
  meas tran vfinal    find v(vout) at=5u                $ 先取 final 值（标量）
  let vset_1pct = 0.99 * vfinal                         $ 派生标量 target
  meas tran tset_1pct trig v(vin) val=0.5 td=0 cross=1 targ v(vout) val=$&vset_1pct cross=1   $ trig+targ 必须在同一行，$&vset_1pct 内联展开
  echo "sr=$&sr_pos tset=$&tset_1pct"
.endc
```

### DC：Rout / Iload curve

```spice
.control
  dc Vout 0 1.8 0.01
  
  let rout_vec_kohm = deriv(i(vvout))^-1 / 1e3          $ 先 let 成 vector
  meas dc rout_kohm find rout_vec_kohm at=1.2           $ find <vector> at=（不是 find param='deriv(...)' at=）
  echo "rout_at_op=$&rout_kohm kΩ"
  wrdata ../simulation/tb_dc/iload.csv v-sweep i(vvout)
.endc
```

## 验证清单（agent 写 testbench 时 self-check）

- [ ] 多分析时 **`setplot <plot>` 显式切换**（不要假设当前 plot）
- [ ] 所有 `db(x)` 都加了 `+ 1e-20`
- [ ] 所有 `vp(x)` 都乘了 `180/PI`（或全局 `set units=degrees`）
- [ ] `meas ac pm_deg` 先确认 phase 约定；signed negative phase 用 `'180 + phase_at_gbw'`
- [ ] `meas ac phase_at_gbw` 用 `find phase_deg when ...`（不是 bare `when`，bare when 返回横轴值不是 phase）
- [ ] `.control` 内 `meas tran trig...targ` **写在同一行**（不要换行，换行后 targ 会变独立命令）
- [ ] `.control` 内 `find rout_vec at=...`（不是 `find param='deriv(...)' at=...`；先 `let` 成 vector）
- [ ] 关键 KPI 用 `echo "$&var"` 输出（不依赖 print / wrdata 跨 plot）
- [ ] `meas` 在 `.control` 内（不是 dot-card）
- [ ] `wrdata` 路径相对 testbench cwd

## 常见误区（self-check）

| 心里想 | 现实 |
|---|---|
| "vp() 返回度" | 默认 radians（除非 `set units=degrees`），必须 ×180/PI 或全局设单位 |
| "PM 永远 = 180 ± phase_at_gbw" | 先确认 phase signed/unsigned 与单位；signed negative phase 常用 `'180 + phase'` |
| "db(0) 没事，0 → -∞" | 产生 -Inf 污染 KPI；统一 `+ 1e-20` 数值防御 |
| ".meas dot-card 不可靠" | 不准——dot-card 与 control 内 meas 是 ngspice 支持的等价语句；agent **优先**用 .control 内 meas（结果可继续引用）|
| "多次 op 后变量都活" | 跨 plot 失活；用 `echo "$&var"` 立即展开（或 `plotname.vector` 显式引用）|
| "wrdata 输出有 header" | 没有；real vec 默认 2 列（scale+value）/ complex vec 3 列（scale+real+imag）/ `wr_singlescale` 等 set 改布局 |
| "`meas ac phase_at_gbw when gain_db=0`" | 错——`when` 返回横轴值（频率）不是 phase；必须 `find phase_deg when ...` |
| "`.control` 内 trig + targ 可换行" | 错——换行后 targ 变独立命令；必须同一行 |
| "`find param='deriv(...)' at=...`" | 错——param 只能引用 scalar；vector 必须先 `let`，再 `find <vector> at=` |

## 不在本章范围

- 分析卡（.op / .ac / .tran 语法）→ chapter `analyses`
- 不收敛 / 矩阵奇异调 .options → chapter `convergence`
- 14 条实战错误对照 → chapter `common-errors`
- AC 断环测稳定性具体 Rfb / Cfb 配置 → skill `circuit-method/ac-feedback-loop-method`
- LDO loop AC 测量完整模板 → `blocks/ldo/ac-stability.md`
