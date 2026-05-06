# backend/packs/ — V4 内置 PACK manifest 仓

**这个目录看起来"空"是有意为之**：bundled PACK 的 `manifest.yaml` 放在这里，资产本体留在共享层
`backend/{knowledge,skills,tools}/`。本文解释这个分层与 V4 的 PACK 模型。

详见 [V4_DIRECTION.md §1.5 / §5](../../docs/v4/V4_DIRECTION.md) +
[V4_PACK_MANIFEST_SCHEMA.md](../../docs/v4/V4_PACK_MANIFEST_SCHEMA.md) +
[PACK_AUTHOR_GUIDE.md](../../docs/v4/PACK_AUTHOR_GUIDE.md)。

---

## 一句话

PACK 是**复合发行单元**（manifest + 它声明 contributes 的资产），不是物理目录。
一个 PACK 可以同时贡献 Knowledge / Skill / Tool / Asset，运行时由
`pack_loader_v4.py` 按 manifest 中的 `contributes:` 路径解析装载。

## 四种 source kind

V4 的 `manifest_schema_version: v4-1.x` 通过 **source_kind** 区分 PACK 来源，
路径解析规则各异（`pack_loader_v4.py` L11-L17）：

| source_kind | 物理位置 | contributes 路径解析为 | 资产形态 |
|---|---|---|---|
| **bundled** | `backend/packs/<pack>/manifest.yaml` | `<repo>/backend/<rel_path>` | **共享层**（与第三方扩展共用 backend/{knowledge,skills,tools}/）|
| **installed** | `<user-home>/.cirona/packages/<pack>/manifest.yaml` | `<pack-root>/<rel_path>` | **自包含** |
| **user** | 任意路径（`<user-home>/.cirona/packs.yaml` 索引）| `<pack-root>/<rel_path>` | **自包含** |
| **project** | `<project>/.cirona/packages/<pack>/manifest.yaml` | `<pack-root>/<rel_path>` | **自包含** |

冲突时优先级：project > user > installed > bundled。

## 为什么 bundled 用共享层

把 bundled 资产留在 `backend/knowledge/` 等共享目录，让**第三方扩展**和**内置默认**
能在同一物理路径协作：用户想给 LDO 补一章 advanced.md，直接放
`backend/knowledge/blocks/ldo/advanced.md` 即可，不需要 fork 整个 PACK。
如果 bundled 改成自包含，扩展就要硬性"内置只读、改要 fork"——门槛立刻上去。

## 当前内容

```
backend/packs/
├── README.md              ← 本文
├── _template/             ← Tier 1/2/3 PACK 起手骨架（cp -r 即可改）
└── default-foundation/    ← V4 默认装载 PACK（覆盖 4 系统级 + 6 OTA + base-cells + 5 skill + 5 tool）
    └── manifest.yaml      ← contributes 全部指向 backend/{knowledge,skills,tools}/
```

## 自己写一个 PACK？

不要以这个目录为起点——**bundled 是给 cirona 自身维护者用的**。

第三方/团队/项目级 PACK 按 source_kind 落到对应位置：

| 你的目标 | 起手命令 |
|---|---|
| 个人收藏（跨项目复用）| `cp -r backend/packs/_template ~/.cirona/packages/my-pack` |
| 项目专属（仅本项目复用）| `cp -r backend/packs/_template <project>/.cirona/packages/my-pack` |
| 团队 / 论文复现（任意路径）| 任意位置 + 在 `~/.cirona/packs.yaml` 中注册 |
| 设计完成后导出（最快路径）| 在 cirona 聊天框输入 `/export-pack [name]`，AI 自动从对话+工作区生成草稿 |

详细写作步骤、frontmatter 字段、Tier 选择见 [PACK_AUTHOR_GUIDE.md](../../docs/v4/PACK_AUTHOR_GUIDE.md)。

## 本目录不该出现的内容

- ❌ 单一 markdown chapter（应在 `backend/knowledge/blocks/<块>/<chapter>.md`）
- ❌ 单一 Skill 文件（应在 `backend/skills/<category>/<name>.md`）
- ❌ 单一 Python 工具（应在 `backend/tools/<category>/<tool>/`）
- ❌ `.cir / .sp / placement_guide.json` 等资产（应在 `backend/knowledge/blocks/<块>/assets/`）

只有需要"一组装一起加载"语义的复合发行单元才用 PACK 包装。
