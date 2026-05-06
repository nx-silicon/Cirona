---
chapter: troubleshooting
parent: common-source
summary: 增益不达标 / Miller 主极点漂移 / 大信号失真 三类对照表
tokens: ~400
related_skills:
  - circuit-method/signal-tracing
---

# Common-Source 故障诊断

## 症状 1：增益（Av）远低于 spec

| 原因 | 验证 | 修复 |
|---|---|---|
| L 太短 → ro 偏小 | dc_snapshot 看 ro=VA·L/Id | L ↑ 到 1-2µm |
| Rload 偏低（电阻负载） | Rload 数值 | Rload ↑ 或换 active load |
| active load 自己 ro 偏低 | dc_snapshot 看 load device 的 ro | load L ↑ |
| gm/Id 太低（强反型）| 算 gm/Id = gm/Id | gm/Id ↑（弱反型，但牺牲 BW）|
| 单管极限不够 | 计算理论 Av_max = gm·ro/2 | 升级到 cascoded CS（用 cascode cell） |

## 症状 2：BW 偏低 / 主极点低于预期

| 原因 | 验证 | 修复 |
|---|---|---|
| CL_external 比预期大 | 测试条件检查 | 减 CL（如可改）|
| Miller cap 倍增大（Av 大）| Av·Cgd 数量级 | Miller 补偿（加 Cc）/ cascode（消 Miller）|
| Rout 偏大 | dc_snapshot 看 Rout | 减 Rout（牺牲 Av）|
| Cgd_M 寄生 cap 大 | device M 的 Cgd | layout 优化 / 减 W |

## 症状 3：大信号失真 / clipping

**物理边界**：
- Vout 摆幅范围：[Vov_M, VDD - Vov_load]
- 超出 → device 出 saturation → Av 突变 → 失真

**修复**：
- 减 input swing
- 减 Vov_M（gm/Id ↑）→ Vout_min 降
- 减 Vov_load → Vout_max 升

## 症状 4：右半平面（RHP）零点拖累 PM

CS 含 Miller cap 时：
```
RHP zero ω_z = gm / Cgd（或 gm / Cc 当 Miller 补偿）
```

**修复**：
- nulling resistor 串 Cc 上消零（详见 `blocks/base-cells/miller-compensation/nulling-resistor.md`）
- Ahuja 风格补偿（current buffer adjacent Miller）

## 不在本章范围
- Miller 补偿具体设计 → `blocks/base-cells/miller-compensation`
- 双级 OTA 整体补偿策略 → `blocks/two-stage-ota`
- LDO 中 EA 第二级稳定性 → `blocks/ldo/ac-stability.md`
