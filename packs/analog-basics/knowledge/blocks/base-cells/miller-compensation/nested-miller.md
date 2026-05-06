---
chapter: nested-miller
parent: miller-compensation
summary: |
  嵌套 Miller 补偿 —— 三级 opamp 多 Cc / 极点距离设计 / Cc1 + Cc2 双层 /
  LDO 与音频 / 大 Cload 应用
tokens: ~700
prerequisite_chapters:
  - plain-miller
  - nulling-resistor
related_skills:
  - circuit-method/ac-feedback-loop-method
  - circuit-method/device-sizing
related_knowledge: []
---

# 嵌套 Miller 补偿（Nested Miller）

## 何时需要三级 opamp

两级 opamp 限制：
- 增益限制 ~ 70-80 dB（gm·ro 两次相乘的上限）
- 大 Cload 时 fp2 = gm_2/(2π·CL) 被 CL 压低 → PM 难保

三级解决：增益 ~ 100-120 dB / 大 Cload 仍稳定。

## 拓扑（典型三级，命名约定：**Cc1 = 外层 / Cc2 = 内层**）

```
                   VDD
                    │
        ┌───────────┴────────────┐
        │                        │
   ┌────┴────┐  Cc1  ┌────┴────┐ │
   │ Stage 1 ├───────┤ Stage 3 │ │  Cc1（外层 Miller）：跨 Stage1 输出 ↔ Stage3 输出
   │ (diff   │       │ (CS or  │ │  Cc2（内层 Miller）：跨 Stage2 输出 ↔ Stage3 输出
   │  pair)  │       │  output)│ │  （注意：图与正文统一用 Cc1=外/Cc2=内）
   └────┬────┘       └────┬────┘
        │                 │
   ┌────┴────┐  Cc2  ┌────┴────┐
   │ Stage 2 ├───────┤         │
   │ (CS)    │       │         │
   └────┬────┘       │         │
                     └─── Vout
                          ↓
                          CL
```

**核心机制**：
- Cc1（外层 Miller，跨 stage 1 ↔ stage 3）→ 主导极点（最低 fp1）+ 极点分裂
- Cc2（内层 Miller，跨 stage 2 ↔ stage 3）→ 推高 stage 2-3 间次极点 fp2

## 极点结构（三极点 + 多零点）

```
fp1 ≈ 1/(2π × Rout_1 × Cc1·|Av_2·Av_3|)    # 主导极点（最低，由外层 Cc1 主导）
fp2 ≈ gm_2 / (2π × Cc2·|Av_3|)              # 次极点（由内层 Cc2 推高）
fp3 ≈ gm_3 / (2π × CL)                       # 第三极点（最高）

设计目标：fp3 / fp2 ≥ 3，fp2 / GBW ≥ 3
```

**关键约束**：3 个极点必须满足"最大平坦度"或类似分布，否则 PM 不达标。

## sizing 关系（双 Cc 选择）

| 量 | 推荐 | 因果 |
|---|---|---|
| Cc1 | gm_1 / (2π × GBW) | 同 plain Miller |
| Cc2 | Cc1 / 5-10 | 内层 Cc 小一些；占内部节点 Cgs 比例 |
| 各级 nulling Rz | 1/gm_对应级 | 必须每级都加（典型 stage 2 + stage 3 都有 Rz）|

## 与 LDO 的应用

LDO pass FET + EA 反馈环 → 三级（EA 第一级 + EA 第二级 + pass FET）→ nested Miller 是经典选择。

特别是大 Cload (µF 级旁路电容)，nested Miller 能保持稳定：
- Cc1 大（pF 级）→ 主导极点拖到 kHz
- pass FET fp 即使在 µF Cload 下也能保 PM

## 与 audio amplifier 的应用

音频功放（输出驱动 µF 级喇叭电容）必须 nested Miller：
- 三级或四级（前级 preamp + driver + output buffer）
- 嵌套 Cc 让大 Cload 不破坏 PM
- 需配合 Bode 设计取最大平坦度

## 验证清单

- [ ] AC：3 极点位置（log scale 上等距分布或 fp3/fp2 ≥ 3）
- [ ] AC：PM ≥ 60° @ GBW
- [ ] AC：所有 RHP zero 都被消（每级 nulling Rz）
- [ ] tran：LDO 负载阶跃 → 不振铃
- [ ] PVT corner：3 极点都在合理位置

## 常见误区

| 心里想 | 现实 |
|---|---|
| "nested Miller 只是大号 Miller" | 极点结构完全不同；3 个极点要分层管理，单 Cc 不够 |
| "Cc2 越大越稳" | Cc2 大 → fp2 降太快 → 与 fp1 重叠 → PM 反差 |
| "三级 opamp 总是用 nested" | 可以用其他补偿（feedforward / pole-zero pair）；nested 是经典但非唯一 |
| "音频功放只需大 Cc1" | 大 CL 时 fp3 也得管（stage 3 输出节点）→ 必须 Cc2 + Cc1 双管 |

## 不在本章范围

- plain / nulling Rz / Ahuja → 对应 chapter
- 寄生 Miller → chapter `parasitic-miller`
- 故障 debug → chapter `troubleshooting`
- LDO 整体反馈环 → `blocks/ldo/ac-stability.md`
- 音频功放完整设计 → 未来 `blocks/audio-amp`
- 三级 opamp pole-zero 设计 → 未来 `blocks/three-stage-ota`
