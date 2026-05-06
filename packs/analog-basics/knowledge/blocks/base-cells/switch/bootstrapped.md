---
chapter: bootstrapped
parent: switch
summary: |
  Bootstrap 开关 —— gate 跟 source 抬高维持 Vgs ≈ V_clk 恒定 /
  Ron 跨摆幅几乎不变 / 高线性度 / 复杂时序 + 可靠性约束
tokens: ~700
prerequisite_chapters:
  - nmos-only
related_skills:
  - circuit-method/device-sizing
  - circuit-method/signal-tracing
related_knowledge: []
---

# Bootstrap 开关

## 拓扑（gate 跟 source 抬高）

```
                     V_in（信号 source）
                         │
                         ●──────────┬──────────────────┐
                         │          │                  │
                         │     ┌────┴────┐             │
                         │     │  M_sw   │             │
                         │     │ NMOS    │ ← gate 接 V_in + V_boot
                         │     │ (sample)│             │
                         │     └────┬────┘             │
                         │          │                  │
                         │          ●──→ V_out → C_sample
                         │                              │
                         │       ┌──────────────────────┘
                         │       │ V_boot = stored on bootstrap cap C_b
                         │       │
                  ┌──────┴───────┴──────┐
                  │  bootstrap helper   │ ← clk-driven 帮助网络
                  │  (charge C_b in φ1, │   precharge C_b 到 VDD in φ1
                  │   discharge C_b in φ2,│  把 V_in + VDD 加到 M_sw gate in φ2
                  │   gate 跟 V_in)       │
                  └─────────────────────┘
```

**核心机制**：
- **φ1（precharge）**：M_sw 关断；C_b 充电到 VDD（gate-source 间）
- **φ2（sample/track）**：把 C_b 串接在 V_in 与 M_sw gate 之间 → V_gate = V_in + VDD（理想）
- → **Vgs_M_sw ≈ VDD（理想，忽略 C_b droop / 寄生 / 时钟馈通）**
- → Vov_eff = VDD - Vth_eff(VSB)；Ron ≈ 1/(μ·Cox·(W/L)·Vov_eff)
- → 极高线性度 + rail-to-rail 摆幅 + 不需 PMOS

## 关键优势

1. **Ron 跨摆幅近似恒定**（典型变化 < 20%）→ SFDR 显著优于 nmos-only 或 TG
   - 残余变化的来源：① C_b droop（采样期间 Vgs 略降）② 时钟馈通 ③ **body effect**：VSB = V_in - V_bulk 随 V_in 上升 → Vth_eff 上升 → Ron 仍随信号升高（即便 Vgs 已"恒定"）。bulk 接 source（专用工艺）可消除此项；标准 bulk 接地工艺无法消除
2. **rail-to-rail 摆幅** + 不受 NMOS Vth 限
3. **单时钟**（CK + 几个内部辅助 phase，但 V_signal 路径仅一管）
4. **典型 SFDR**：14-16 bit ADC 主采样开关都用 bootstrap

## 实现复杂度

bootstrap 需要：
- bootstrap cap C_b（典型 100 fF - 1 pF MOM/MIM）
- 4-6 个辅助 MOS（precharge / discharge / 时序控制）
- non-overlapping 时钟 phases（CK / CKB / 内部生成）
- **可靠性保护**：主开关 Vgs ≈ VDD，但 **gate 节点**电压可达 Vin + VDD（接近 2×VDD）；逐管检查 Vgs/Vgd/Vgb 应力，常用 cascode + chip-stack 保护栅氧

总面积：相比 nmos-only **5-10×**（C_b + helper devices）。

## sizing trade-off

### bootstrap cap C_b

```
Vgs_actual = VDD × C_b / (C_b + C_parasitic_at_gate)
```

C_parasitic = M_sw.Cgs + helper devices Cgs + metal par。

例 C_b = 500 fF / C_par = 100 fF → Vgs_actual = 0.83 × VDD = 1.5V（vs 理想 1.8V）。

→ C_b 需要 **C_par 的 5-10×**，否则 Vgs droop 显著影响 Ron。

### M_sw 尺寸

```
Ron = 1 / (μn·Cox·(W/L) · VDD)
```
@ VDD = 1.8 V，比 nmos-only 同等 sizing **小 ~2-3×**（因 Vov 大）。

例 W/L = 5/0.18 → Ron ≈ 200-400 Ω across 整个 0-VDD 摆幅。

### 速度与建立

```
τ = Ron × C_sample
```
建立到 0.1%（10-bit）：~7τ；建立到 0.01%（14-bit）：~9τ。

@ Ron=300Ω / C_sample=2pF → τ=600ps → 9τ ≈ 5.4 ns @ 14-bit → fclk_max ≈ 90 MHz（含 hold phase）。

## 可靠性约束（栅氧应力）

**关键风险**：bootstrap 把 V_gate 推到 V_in + VDD，可达 2×VDD（V_in = VDD 时）。
- @ VDD = 1.8 V → V_gate_max = 3.6 V
- 栅氧最大耐压（180nm typical）= 1.98 V（额定）/ 2.5 V（短期 max）
- → **栅氧应力超标** → 长期可靠性问题

**保护方法**：
- **栅 cascode**：用第二个 MOS 串在 gate 路径，分压栅氧应力
- 选用 **2.5V/3.3V I/O FET**（耐压更高，但 sizing 大）
- **clamping diode** 限制 V_gate < V_in + VDD_safe

180nm 通用做法：用 thick-oxide I/O device 做 bootstrap helper，core device 做 sample switch。

## charge injection（与 nmos-only 类似）

bootstrap 不解决 charge inj 问题——开关关断瞬间通道电荷仍存在。
- 但 bootstrap 让 Vov 恒定 → charge inj 也跨摆幅恒定 → **可被校准**（offset that doesn't depend on signal）

→ ADC 设计中：bootstrap + 校准 = 高精度 + 高线性度。

## 应用边界

✅ **适合**：
- 高精度 ADC（≥ 12 bit）主采样开关
- 高速采样（GHz 级）
- 大摆幅模拟接口

❌ **不适合**：
- 低功耗 / 简单设计（开销大）
- 小摆幅 SC（nmos-only 已够）
- 数字开关（无意义）

## sizing 范例（14-bit / 100 MSPS pipeline ADC sample switch）

> 📌 **@ vpdk180nm**（μn·Cox / Vth / Cox 数值参考 `pdks/vpdk180nm/index.md`）。换工艺重算 W_main / C_boot；bootstrapped switch 拓扑（Vgs 跟 Vin 抬升）跨工艺通用。

```
spec: SFDR ≥ 80 dB / fclk = 100 MHz / V_in_pp = 1.8 V / C_sample = 2 pF / VDD = 1.8 V

M_sw (NMOS thick-ox or 2.5V option):
  目标 Ron = 300 Ω
  Vov = VDD = 1.8 V
  μn·Cox·(W/L) = 1/(Ron·VDD) = 1/(300·1.8) = 1.85 mS
  W/L = 1.85m / 200µ = 9.3
  L = 0.18 µm（max speed）→ W = 1.7 µm × m=4 → 6.8 µm

C_b sizing:
  M_sw.Cgs ≈ 8.6f × W·L = 8.6 × 6.8 × 0.18 ≈ 10 fF
  其他 par ≈ 30 fF
  C_b ≥ 5×（10+30）= 200 fF（取 C_b = 500 fF 留余量）

Vgs_droop:
  Vgs_actual = 1.8 × 500/(500+40) = 1.67 V → Vov = 1.67V → Ron 略升 8%

建立时间:
  Ron = 320 Ω × Cs=2pF → τ=640 ps → 14-bit 9τ = 5.8 ns（< T_clk/2 = 5 ns 紧）
  → 可能需要增大 W_M_sw 或减小 C_sample

栅氧保护:
  V_gate_max = 1.8 + 1.67 = 3.47 V（thick-ox 2.5V option 最大耐压 3.6V → 接近极限）
  → 加 cascode 栅保护或用 0.13µm 工艺优于 180nm

charge inj:
  Q_inj = α·W·L·Cox·Vov = 0.5 × 6.8 × 0.18 × 8.6f × 1.8 = 9.5 fC
  ΔV = 9.5f / 2p = 4.7 mV → 14-bit LSB = 1.8/16384 = 0.11 mV → 误差 42 LSB
  → 必须 bottom-plate 优先关断 + dummy switch 抵消，或后端校准
```

## 验证清单

- [ ] tran：跨 V_in 摆幅 Ron 变化 < 20%
- [ ] tran：Vgs(M_sw) actual ≈ VDD ± 10%（bootstrap 高效率）
- [ ] tran：栅 V_gate_max < 栅氧 max rating
- [ ] DC sweep：测 Ron vs V_signal 曲线
- [ ] AC：SFDR / SNDR 在 spec 频段满足
- [ ] tran：bootstrap helper 时序无 race condition

## 常见误区

| 心里想 | 现实 |
|---|---|
| "bootstrap 完美线性" | Ron 还是会有 10-20% 变化（C_b 寄生 + Vgs droop）；不是绝对恒定 |
| "C_b 越大越好" | C_b 大 → 充电时间长 → 顶部时钟 phase 拉长 → fclk 受限；典型 5-10× C_par 平衡 |
| "栅氧 1.8V → V_gate 3.6V 没关系" | 长期可靠性问题（hot carrier / TDDB）；必须 cascode 保护 |
| "bootstrap 解决 charge inj" | 错——charge inj 仍存在，只是变得 V_signal 无关（可校准）|
| "复杂 timing 容易设计" | non-overlap + bootstrap helper 多 phase，时序裕量需 EM 仿真验证 |

## 不在本章范围

- nmos-only 基础 → chapter `nmos-only`
- 传输门 → chapter `transmission-gate`
- 故障 debug → chapter `troubleshooting`
- 完整 ADC 时序 → `systems/sar-adc` / `systems/adc-pipeline`
- 栅氧可靠性 / hot carrier → device reliability knowledge
- bootstrap helper 详细电路（precharge MOS sizing） → 各家 ADC 设计文献
