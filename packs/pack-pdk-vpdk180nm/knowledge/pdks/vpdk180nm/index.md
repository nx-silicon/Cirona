---
type: knowledge
domain: pdk
name: vpdk180nm
version: 1.0
summary: |
  Virtual 180nm CMOS PDK 设计参考：模型名 / .lib section 用法 / Vth & μCox /
  典型 corner / 路径写法。事实+因果格式，加载即看 Quick Facts 避开常踩坑。

chapters: []   # PoC 单文件 knowledge — 全部内容都在 index.md 内

trigger:
  explicit:
    project_pdk: vpdk180nm
  implicit:
    keywords:
      - vpdk180nm
      - 180nm
      - "0.18 um"
      - virtual pdk
    tool_loaded:
      - simulate
      - generate_testbench
      - describe_pdk
    knowledge_loaded:
      - blocks/ldo
      - blocks/ota
      - blocks/bandgap
      - blocks/comparator
      - simulators/ngspice

related:
  knowledge:
    - simulators/ngspice
    - devices/bsim4
  tools:
    - describe_pdk
    - simulate
    - generate_testbench

hierarchy: pdk
applicable_pdks: [vpdk180nm]
applicable_simulators: [ngspice, hspice, spectre]
authors: ["cirona team"]
---

# vpdk180nm 设计参考

## Quick Facts (硬约束 — 一次看清避免反复踩坑)

### 1. 模型名是 `nch` / `pch`（**不是** `nch_18` / `pch_18`）

```spice
* ✅ 正确
M1 vout vin vss vss nch  W=4u  L=0.5u m=1
M2 vdd  vbias vout vdd  pch  W=12u L=0.5u m=1

* ❌ 错误（agent 经常凭直觉写 _18 后缀）
M1 vout vin vss vss nch_18  W=4u  L=0.5u m=1
```

| 设备 | 模型名 | VDD | Vth (typ) | 备注 |
|---|---|---|---|---|
| NMOS core | `nch` | 1.8 V | +0.35 V | 主用，BSIM3v3.3 LEVEL=49 |
| PMOS core | `pch` | 1.8 V | −0.40 V | 主用 |
| NMOS IO | `nch_33` | 3.3 V | +0.55 V | IO / level shifter |
| PMOS IO | `pch_33` | 3.3 V | −0.60 V | IO |

### 2. lib 文件是 **`vpdk180nm_corners.lib`** — 必须用 `.lib '...' <corner>`

PDK 只发一个 lib 文件，所有 corner 作为 named section 在文件内：

```spice
* ✅ 正确（必须给 corner section 名）
.lib '../pdk/vpdk180nm/vpdk180nm_corners.lib' TT

* ❌ 错误（agent 经常用 .include 因为 .lib 路径含空格踩坑）
.include '../pdk/vpdk180nm/vpdk180nm_corners.lib'
*  → 加载所有 corner section 的内容，model 重名冲突 / 仿真异常

* ❌ 错误（不指定 corner section）
.lib '../pdk/vpdk180nm/vpdk180nm_corners.lib'
*  → ngspice 不知道哪个 section，加载 nothing usable
```

**Available corners**：`TT` (typical) / `FF` (fast NMOS+fast PMOS) / `SS` / `FS` (fast-N slow-P) / `SF` (slow-N fast-P)

### 3. 路径含空格的 PDK（如 `C:/Program Files/...`）

ngspice 4.x 在 Windows 路径含空格时**即使加引号也截断**。两条解决路线：

| 方案 | 写法 | 适用 |
|---|---|---|
| **建 junction**（推荐）| 在 repo 根 `mklink /J pdk D:\AnalogCoder\analog-design-system\pdk` 后写 `.lib '../pdk/vpdk180nm/vpdk180nm_corners.lib' TT` | 开发环境 |
| **8.3 短路径** | `cmd /c dir /x "C:\Program Files\"` 找 `PROGRA~1` 然后写 `.lib 'C:/PROGRA~1/Cirona/resources/pdk/vpdk180nm/vpdk180nm_corners.lib' TT` | 安装后用户机 |

**永远不要把 .lib 路径写成绝对 Windows 路径含空格** — 90% 概率被 ngspice 截断。

### 4. 工艺关键数值（gm/ID 起点参考）

| 量 | 典型值 | 用途 |
|---|---|---|
| μ_n · Cox | ~ 270 µA/V² | NMOS sizing |
| μ_p · Cox | ~ 60 µA/V² | PMOS sizing（PMOS 比 NMOS 慢 ~4.5×）|
| Vov 推荐 | 0.1 - 0.3 V | 弱-强反型边界，gm/ID = 5-20 |
| Lmin | 0.18 µm | 工艺最小 |
| L 推荐 | **0.36-0.5 µm**（生产风格 1.5-2× Lmin）| matching / noise / output gds 最优 |
| Cox | ~ 8.5 fF/µm² | 计算 Cgs / Cgd |

### 5. 噪声模型 NOIMOD=2

PDK 默认开 BSIM3 完整噪声模型（thermal + 1/f）。agent 跑 `.noise` 时不需要额外配置。

## When to load this knowledge

- 用户 spec 含 `PDK=vpdk180nm` / `vpdk180nm` / `0.18 µm` / `180 nm`
- 任何 sizing 阶段（Vth / μCox / Vov 起点参考）
- 任何 simulate 阶段（lib 路径 + corner 写法 + 模型名）
- 任何 testbench 阶段

## When NOT to load

- 用户用别的 PDK（gf180mcu / sky130 / vpdk55nm 等 → 加载对应 `pdks/<name>/index`）
- 纯架构阶段（拓扑选择，PDK 数值还不重要）

## Related

- **Knowledge `simulators/ngspice`** — `.lib` / `.include` / `.measure` 完整语法 + PM 公式 + vp() 弧度坑
- **Knowledge `devices/bsim4`** — BSIM3v3.3 / LEVEL=49 device 物理参数
- **Tool `describe_pdk`** — 实时探查 acp.yaml 配置的 PDK 路径
- **Tool `generate_testbench`** — 自动生成正确 lib + corner 的 testbench（**强烈建议用此工具而非手写 testbench**）

## 不在本章范围

- ngspice 通用语法（.measure / .control / vp() / wrdata）→ `simulators/ngspice/analyses` + `common-errors`
- BSIM3 device 参数物理意义 → `devices/bsim4`
- gm/ID 设计方法论 → skill `circuit-method/device-sizing` + `circuit-method/dropout-sizing-method`

## 常见误区（必看）

| 心里想 | 现实 |
|---|---|
| "180nm PDK 模型名是 nch_18 / pch_18" | vpdk180nm 用 `nch` / `pch`（无 `_18` 后缀，那是某些其他 180nm PDK 的命名）|
| "PDK 只有一个 model 文件用 .include" | vpdk180nm 是 named-section corners.lib，**必须 `.lib '...' TT`** |
| "C:/Program Files/ 路径加引号就行" | ngspice 4.x 在 Windows 即使加引号也截断空格路径 — 用 junction 或 8.3 短路径 |
| "Vov 越小越好（gm/ID 高）" | Vov < 0.1V 进入弱反型，gds / gm 模型不准；最低 Vov 0.1-0.15V |
| "L 用 minimum 给最大 gm" | minimum L 给最差 matching / 1/f noise / gds — 生产风格 1.5-2× Lmin |
| "PMOS 跟 NMOS 同 W 给同 gm" | μp ≈ μn / 4.5，相同 gm 需要 W_p ≈ 4.5 × W_n |
