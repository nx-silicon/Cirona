---
chapter: basic
parent: source-follower
summary: SF 物理 + Av 表达 + body effect + Rout=1/gm + sizing 范例
tokens: ~600
related_skills:
  - circuit-method/device-sizing
related_knowledge:
  - blocks/base-cells/current-mirror
---

# 基础 Source-Follower

## 拓扑结构

```
        vdd（NMOS SF）
          │
        ┌─┴─┐
   vin──│M  │
        └─┬─┘
          │ vout
          │
        ┌─┴─┐
        │I_tail│  (可以是电流源 / 镜像 / 电阻)
        └─┬─┘
          │
        vss
```

**核心机制**：M 的 source 接 vout，drain 接 vdd（NMOS）/ vss（PMOS），gate 接输入。

## Av 因果

```
Av = gm / (gm + gmb + gds + 1/Rload)
```

理想 Av = 1，实际有三项让它 < 1：
1. **body effect (gmb)**：约 gm/5 在 NMOS in p-substrate 时，因 body 不接 source → vsb > 0 → Vth 漂移 → 等效 transconductance gmb
2. **gds 项**（≈ 1/ro，通常小但需算上）
3. **Rload 不无穷大**：1/Rload 加到分母

**典型实测 Av ≈ 0.7–0.95**。

**消除 body effect 的方法**：
- NMOS in **deep n-well + p-well**（source 接 p-well），source 与 body 同电位 → gmb=0 → Av 接近 1（但工艺贵）
- PMOS in n-well（source 与 n-well 同电位）→ gmb=0 → 这是 PMOS SF 的天然优势

## Rout（小）

```
Rout = 1 / (gm + gmb) ≈ 1/gm
```

典型 gm = 100µS → Rout = 10kΩ（vs CS 的 ro=1MΩ，**100× 小**）。

→ 这是 SF 作 output buffer 的物理基础。

## Vth 偏移（dropout）

NMOS SF（含 body effect）：
```
vout = vin - Vgs = vin - (Vth_eff(VSB) + Vov)
       Vth_eff = Vth0 + γ(√(2ΦF + VSB) - √(2ΦF))   # body 不接 source 时
```

→ 这是隐式方程（VSB ≈ vout - V_bulk 也含 vout），需要迭代或扫 vin/vout 求解。
→ vout **永远低于 vin** 一个 Vth_eff + Vov ≈ 0.6–0.9 V（VSB 大时 Vth_eff 抬升 50-200 mV @ 180nm γ ≈ 0.4 V^0.5）。

这是 SF 作"level shifter"的物理基础——把高电平 vin 平移下来一个 Vth。

但也是限制：vin 必须 > Vth + Vov + Vds_sat_tail，否则 SF 撞地。

## Sizing Guideline

按 spec 反推（典型 LDO output buffer）：

```
Spec: 驱动 Cload=10pF, Iload_max=50mA, Vin=1.5V, Vout target=1.0V
        f_unity > 10 MHz, dropout < 100mV
```

- Iload = 50 mA → device 必须能流通
- ⚠️ **二选一约束**（Vov 与 gm/Id 不能同时取小，因 Vov ≈ 2/(gm/Id) 强反型近似）：
  - **路径 A（dropout 优先 → 小 Vov）**：Vov_target = 100 mV → gm/Id ≈ 2/0.1 = 20 V⁻¹（弱反型/中等反型方向）→ gm = 50m × 20 = 1 S（**1 西门子，极大**）
  - **路径 B（速度优先 → 强反型）**：gm/Id = 5 → Vov ≈ 2/5 = 400 mV → gm = 50m × 5 = 250 mS / dropout = Vth + 0.4 ≈ 850 mV（dropout 大）
- LDO output buffer 通常选 **路径 A**：W 极大但 dropout 小
- Rout = 1/gm（路径 A 算 1 Ω；路径 B 算 4 Ω）—— 都极小，good buffer
- 路径 A sizing：W/L = 2·Iload/(μn·Cox·Vov²) = 2·50m/(270u·0.01) ≈ 37000 → L=0.5 µm → W = 18500 µm，m = 100 × W=185 µm 单 finger
- f_unity = gm / (2π·CL)（A 路径 ≈ 16 GHz / B 路径 ≈ 4 GHz）—— 都远超 spec
- dropout = Vth_eff + Vov（A 路径 ≈ 0.45 + 0.1 = 550 mV，**仍不达标 100 mV spec**，body effect 让它更大）
- **结论**：standard NMOS SF dropout 物理下限是 Vth+Vov，要 < 100mV 必须 PMOS pass FET（不是 SF），见 `blocks/ldo/architecture.md`

→ **SF 不适合 LDO 主 pass 设备**（dropout 太大），适合**输出 buffer 在 OTA 输出端驱动 Cload**。

## 验证清单

- [ ] dc_snapshot 显示 M 在 saturation
- [ ] Av(DC) 测量值与公式一致（含 body effect）
- [ ] Rout 测量与 1/gm 一致
- [ ] vin 工作范围（不能让 tail current source 撞地）
- [ ] 驱动负载 Iload 满足 spec

## 常见误区

| 心里想 | 现实 |
|---|---|
| "SF 用作 LDO pass 设备" | dropout = Vth+Vov ≈ 0.6V，太大；LDO 用 PMOS 接 vdd 配置（不是 SF） |
| "SF 增益是 1" | body effect 让 Av < 1，典型 0.85；spec 严苛时要算精确 |
| "SF 不能高频" | Rout=1/gm 小，f_unity 高；BW 通常不是瓶颈 |
| "SF 输入直接接 OTA 输出端没事" | OTA 输出端有 Cload，Cgs of SF 加进去会拖慢 OTA → 仍要算 |
