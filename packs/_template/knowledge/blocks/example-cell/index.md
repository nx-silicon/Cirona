---
type: knowledge
domain: circuit
name: example-cell
version: 0.1.0
summary: |
  示例 base-cell / 子电路。**Iron Law: 写新电路前先 load reference 章节，
  不要从零造拓扑**。本 PACK 用作 V4 PACK 模板，把 example-cell 替换成你
  的真实电路名称。
chapters:
  - name: basic
    summary: 拓扑骨架 + 起点 sizing + 关键 spec 参数（cheatsheet）
    tokens: ~600
trigger:
  explicit:
    user_selected_pack: my-pack-name
  implicit:
    keywords:
      - example-cell
      - 示例电路
related:
  knowledge:
    - blocks/base-cells/current-mirror
    - simulators/ngspice
    - pdks/vpdk180nm
  skills:
    - device_sizing
hierarchy: block
applicable_pdks: [vpdk180nm]
applicable_simulators: [ngspice]
authors: ["Your Name"]
---

# Example-Cell Knowledge Index

> 这是 V4 PACK 模板中的 Knowledge 示例。改写本文件时：
> - 把 `example-cell` 替换为你的真实电路名（kebab-case）
> - 在 frontmatter 中声明所有可用 chapters
> - 在 Quick Facts / Cheatsheet 表格里给出 5-10 条事实速读
> - 详细写作规范见 V4_KNOWLEDGE_FORMAT.md

## Quick Facts

- example-cell 是 NMOS / PMOS / mixed 拓扑（具体写明）
- 典型 gain：xx-yy dB / 典型 BW：xx-yy MHz
- 必备 bias：tail / cascode bias / mirror reference
- 典型 sizing 起点（@vpdk180nm）：W=10µm L=0.5µm m=1

## Cheatsheet (vpdk180nm, VDD=1.8V)

| Spec | 典型值 | 影响因素 |
|---|---|---|
| DC gain | xx-yy dB | gm × ro 链路（哪几个 device）|
| Bandwidth | xx-yy MHz | 主极点位置 |
| Power | xx-yy µW | tail current × VDD |

## When to load this knowledge

- 用户 spec 含 "example-cell" / "示例电路"
- 设计某 system block 评估是否复用 example-cell

## When NOT to load

- 用户在做完全不相关的电路（如 PLL / RF mixer）
- 单纯方法论问题（应改 load 对应 skill）

## Related

- `blocks/base-cells/current-mirror` — example-cell 内部 mirror sizing 复用
- `simulators/ngspice` — testbench 模板
- `pdks/vpdk180nm` — 工艺常数
