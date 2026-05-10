---
chapter: analyses
parent: ngspice
summary: |
  .op .dc .ac .tran .noise 五种分析卡 + 混合分析时 setplot 切换 +
  关键陷阱（vp 弧度 / db 过零 / Mega 单位 / op vs ac 标量vs向量）
tokens: ~900
prerequisite_chapters: []
related_skills:
  - circuit-method/ac-feedback-loop-method
  - circuit-method/noise-analysis-method
---

# ngspice 分析类型

## 五种分析卡（速查）

| 分析 | 卡 | 求解什么 | 结果 plot | 典型用途 |
|---|---|---|---|---|
| DC OP | `.op` | 时间无关稳态偏置 | `op1` | 检查 device region / 初始 bias |
| DC sweep | `.dc V1 0 5 0.1` | 一组 DC 解 vs 扫描变量 | `dc1` | 输入特性 / I-V 曲线 / dropout 测试 |
| AC | `.ac dec 50 1 1G` | 围绕 .op 的小信号线性化解 | `ac1` | gain / GBW / PM / PSRR / impedance |
| Tran | `.tran 1n 1u 0 1n` | 时域非线性解 | `tran1` | 启动 / 大信号 / 振荡器 / 开关 |
| Noise | `.noise v(out) Vin dec 10 1 1G` | 输出噪声 PSD 谱 | `noise1` | 输入参考噪声 / SNR |

每种分析的结果矢量活在自己的 plot 里——多分析混合时**必须 `setplot <name>` 显式切换**（默认停在第一个分析的 plot，后续 `meas` / `print` 取不到）。

## .op（DC 工作点）

```spice
.op
.control
  run
  print v(vout) v(vinn)              $ 节点电压（标量）
  print @m.xota.mn1[vds] @m.xota.mn1[vdsat] @m.xota.mn1[id]    $ device 参数
.endc
```

**关键事实**：
- `.op` 总是隐含运行（每个分析都会先解一个 OP）；显式声明 `.op` 让数据进 `op1` 可被查询
- 在 `op1` 中 `v(<node>)` 是**标量**（不是向量）—— 不能 `meas op ... find v(vout) at=0`，应直接 `print` 或 `let var = v(vout)` 后再用
- hierarchical device 名要 `@<type>.<x_chain>.<dev>[param]` 格式（`m.` / `r.` / `c.` 类型前缀必须）
- DC OP 不收敛 / 漂移 → 见 `chapter=convergence`

**device 参数访问表**：

| 参数 | 含义 | 用途 |
|---|---|---|
| `[id]` | 漏极电流 | bias chain 验证 |
| `[vds]` | 漏-源电压 | region 判断 |
| `[vdsat]` | 饱和电压 (Vov) | region 判断（`vds > vdsat` ⇒ saturation） |
| `[vgs]` | 栅-源电压 | bias 推算 |
| `[gm]` | 跨导 | sizing 验证 |
| `[gds]` | 输出电导 | gain 验证（gm/gds = intrinsic gain） |
| `[cgs]` / `[cgd]` / `[cdb]` | 寄生电容 | BW / Miller 分析 |
| `[vth]` | 阈值电压（含 body effect） | overdrive 验证 |

## .dc（DC 扫描）

```spice
.dc Vin 0 5 0.01                     $ 单变量
.dc Vin 0 5 0.01 Vbias 0.5 1.0 0.1   $ 嵌套（外层 Vbias，内层 Vin）
.dc Iload 0 100m 1m                  $ 电流源扫描
```

**关键事实**：
- 嵌套扫描：第二个变量是**外层** loop（每个 Vbias 值跑一次完整 Vin 扫描）
- 结果在 `dc1`，扫描轴是 `<source_name>` 或 `v-sweep`（视版本）
- 电流源扫描用 `wrdata` 时变量名是 `@<source>[i]`（小写 + `[i]` 后缀），不是 `i(<source>)`
- DC sweep + 反馈回路：与 .op 同—— Rfb=1G 这种 DC 闭环招在 sweep 中会拖动 vout，需要专门 testbench

## .ac（小信号 AC）

```spice
.ac dec 50 1 1G                      $ 50 pts/decade，1 Hz – 1 GHz
.ac dec 100 1k 100Meg                $ 加密扫，注意写 Meg 不是 M
.ac lin 1001 0 10Meg                 $ 线性，1001 点
```

| `<variation>` | 含义 |
|---|---|
| `dec` | 每十倍频程 N 点（Bode 图首选）|
| `oct` | 每倍频程 N 点 |
| `lin` | 总点数（窄带 / 谐振响应用）|

**Bode 图默认**：`dec 50` 足够 `meas when cross=1` 准确定位 GBW，仿真时间也短。

**关键陷阱**：

| 陷阱 | 症状 | 原因 | 修复 |
|---|---|---|---|
| 不切 plot | "no such vector frequency" | 默认 plot 是 `op1`，AC 矢量在 `ac1` | `setplot ac1` 在 `run` 后立即 |
| `vp()` 当成度 | PM 报 178° 看似正常实际错 57× | `vp` 返回**弧度** | `let phase_deg = 180/PI * vp(vout)` |
| `db()` 过零 | `argument out of range for db` | log10(0) / log10(<0) 抛错，整段 `.control` 中断 | `let gain_db = db(abs(v(vout)) + 1e-20)` |
| 写 `1M` 当 Mega | sizing 看着对仿真错 | SPICE 历史：M = milli，Mega 写 `meg` | 频率写 `100Meg` / 电阻写 `1meg` / 1G 用 `1g` |
| DC 没收敛就 AC | gain_dc = -148 dB / 相位乱 | DC OP 漂到轨，线性化在错误 bias 上 | 先解 DC（chapter=convergence + ac-feedback-loop-method skill）|

**AC 在做什么**（理解后避免误用）：
1. 解 .op 得到 bias
2. 围绕 bias 把每个非线性器件做雅可比线性化
3. 在每个频率点解线性方程 → 复数响应

→ **DC 收敛是 AC 前置条件**。DC 不对 AC 必错。

## .tran（瞬态）

```spice
.tran 1n 1u 0 1n                     $ tstep=1n / tstop=1u / tstart=0 / tmax=1n
.tran 1n 1u uic                      $ uic = use initial conditions（跳过 .op）
```

| 参数 | 含义 | 默认 |
|---|---|---|
| `tstep` | print step（输出粒度） | 必填 |
| `tstop` | 仿真结束时间 | 必填 |
| `tstart` | 数据保存起始 | 0 |
| `tmax` | ngspice 最大允许内部步长 | tstop/50 |
| `uic` | 跳过 .op，用 .ic 初值 | 关 |

**关键事实**：
- `tstep` 是 print step 不是积分 step（积分 step 由 ngspice 自调）—— 想 print 密一点不会让仿真变慢
- `tmax` 强制内部步长上限——**振荡 / 高速开关电路必设**（默认可能跳过振荡周期）
- `uic` 仅在已经知道初始状态时用（如 startup transient 从复位拉起）；多数情况留默认让 .op 解 t=0
- `.ic v(node)=value` 在 `uic` 模式下持续到 t=0+；不带 `uic` 时仅作 .op 初值

## .noise（噪声分析）

```spice
.noise v(vout) Vin dec 10 1 1G
.control
  run
  setplot noise1
  meas noise vn_in_total integ inoise_spectrum from=1 to=1e9    $ Vrms
.endc
```

**参数**：
- `v(<output>)` —— 输出节点（差分用 `v(out_p, out_n)`）
- `<source>` —— 输入参考的 AC 信号源
- `dec/oct/lin <pts> <fstart> <fstop>` —— 同 .ac

**输出矢量**：
- `inoise_spectrum`（V/√Hz）—— 输入参考电压噪声 PSD
- `onoise_spectrum`（V/√Hz）—— 输出电压噪声 PSD
- 每个 device 的贡献（`inoise_<device>_<type>`）—— 用于排序噪声源

**通用方法学见 skill `circuit-method/noise-analysis-method`**（噪声目标识别 / 测量配置 / corner 验证 / 比较器 / VCO 等非线性场景）。本章只给 ngspice 卡的接口契约。

## 多分析混合

最常见模式：`.op + .ac` 同 testbench——一次仿真同时拿 DC 状态 + AC 响应。

```spice
.option compat=ps
.lib    "../pdk/vpdk180nm_corners.lib" tt
.include "../design/your_ota.cir"

* ... sources, DUT, loop break ...

.op
.ac dec 50 1 1G

.control
  run

  * ── 1) DC OP（curplot=op1，标量）──
  setplot op1
  print v(vout) v(vinn) v(vinp)
  print @m.xota.mn1[vds] @m.xota.mn1[vdsat] @m.xota.mn1[id]

  * ── 2) AC（curplot=ac1，向量）──
  setplot ac1
  let gain_db   = db(abs(v(vout)) + 1e-20)
  let phase_deg = 180/PI * vp(vout)
  meas ac gain_dc      find gain_db    at=1
  meas ac gbw_hz       when gain_db=0  cross=1
  meas ac phase_dc     find phase_deg  at=1
  meas ac phase_at_ugf find phase_deg  when gain_db=0 cross=1
  * PM 公式（按主极点位置选）:
  *   方法 B (anchor-difference, OTA 默认 — 主极点 >> 1Hz):
  *     PM = 180° - (phase_dc - phase_at_ugf)
  *     物理：phase 走过的距离与 -180° 的余量；universal 对 vinp/vinn 注入 + 内部反相数都对
  *     例: phase_dc=0°, phase_at_ugf=-120°  → PM = 180 - (0 - (-120)) = 60° ✓
  *     例: phase_dc=180°, phase_at_ugf=60°  → PM = 180 - (180 - 60)   = 60° ✓
  *   方法 C (起点观察法, LDO 必用 — 主极点 < 1Hz, anchor-diff 会算偏):
  *     forward gain DC 起点 0°  → pm = 180 + phase_at_ugf
  *     forward gain DC 起点 180° → pm = phase_at_ugf
  *     不需 phase_dc 锚点，对低主极点稳健；要先确认拓扑 DC 极性
  meas ac pm_deg       param='180 - (phase_dc - phase_at_ugf)'

  echo "gain_dc=$&gain_dc  gbw=$&gbw_hz  pm=$&pm_deg"
  wrdata ../simulation/tb_ac/bode.csv frequency gain_db phase_deg
.endc
```

**关键**：两次 `setplot` 是必须的——同一个表达式 `v(vout)` 在 `op1` 是标量、在 `ac1` 是复数向量，意义完全不同。

## 跨 plot 数据访问的陷阱

ngspice 把每个 `.op` 的结果存在独立 plot（`op1` / `op2` / ...）。**bare `print` / `wrdata` 跨 plot 拿不到**——因为 `print` 操作的是 curplot 的 namespace。

修复：用 `echo "$&var"` **内联展开** scalar 后写 log，再在外层 plot 拿：

```spice
* 错：跨 plot 拿不到
.control
  run
  setplot op1
  let v_init = v(vout)              $ v_init 活在 op1
  setplot op2
  print v_init                      $ ❌ "no such vector v_init"
.endc

* 对：先 echo 落 log，外层 parser 拿
.control
  run
  setplot op1
  let v_init = v(vout)
  echo "v_init = $&v_init"          $ ✅ 落 log，跨 plot 都看得到
.endc
```

这是 V3 实测踩坑——多次 `.op` 让 let 变量活在不同 plot，bare print/wrdata 跨 plot 不可见。

## 不在本章范围

- **DC OP 漂移 / 不收敛**——见 `chapter=convergence`
- **怎么写 .control / let / meas**——见 `chapter=measurements`
- **AC 断点位置 / Rfb / Cfb 选择**——见 skill `circuit-method/ac-feedback-loop-method` + 各电路 `blocks/<circuit>/ac-stability.md`
- **Noise 测量方法学**——见 skill `circuit-method/noise-analysis-method`
- **error 信息对照**——见 `chapter=common-errors`
