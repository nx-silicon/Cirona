# &lt;your-pack-name&gt; — PACK README

**作者**：Your Name
**版本**：0.1.0
**Tier**：1（Knowledge-only）

> 把这份模板拷贝到目标位置后，**改本 README** 描述你 PACK 的用途、覆盖范围、使用前提、已知限制。
> 用户在 cirona UI 的 PACK Inspector 里会读这份 README。

---

## 这个 PACK 是什么

一段话解释：
- **领域**：你贡献什么领域 / 电路类型？
- **覆盖范围**：完整电路 / 单方法论 / 一组工具？
- **何时被激活**：用户说什么话或选什么工程会触发 PACK 装载？
- **已验证 PDK**：vpdk180nm？vpdk45nm？sky130？

## 怎么用这个 PACK

### 安装位置

| 你的目标 | 安装到 |
|---|---|
| 团队内部跨项目复用 | `~/.cirona/packages/&lt;pack-name&gt;/` |
| 项目专属 | `&lt;project&gt;/.cirona/packages/&lt;pack-name&gt;/` |
| 任意路径（团队共享盘 / 论文复现）| 任意位置 + 在 `~/.cirona/packs.yaml` 中索引 |

`packs.yaml` 索引示例：
```yaml
packs:
  - name: &lt;pack-name&gt;
    path: D:/team/shared/&lt;pack-name&gt;/
    enabled: true
```

### 加载验证

```bash
# 启动后端后，curl 检查 PACK 是否被识别
curl http://localhost:8001/api/v3/packs | grep &lt;pack-name&gt;
```

或在 cirona 前端 Extensions 面板里查看。

## 包含什么

- `manifest.yaml`        —— PACK 元信息 + contributes 清单
- `knowledge/blocks/example-cell/` —— 示例 Knowledge（事实 + 因果）
  - `index.md` —— Knowledge 索引（frontmatter + chapter 列表）
  - `basic.md` —— 一个示例 chapter
- `skills/`              —— 此模板未启用，去掉前的 `# ` 启用 Tier 2
- `tools/`               —— 此模板未启用，启用即 Tier 3
- `assets/placement_guides/` —— schematic 渲染的 placement JSON（可选）

## 编辑指南

| 你想改 | 改哪个文件 + 看哪份指南 |
|---|---|
| 加新章节（事实 / 因果链） | `knowledge/blocks/example-cell/&lt;chapter&gt;.md` + V4_KNOWLEDGE_FORMAT.md |
| 加新方法论（思维范式） | `skills/circuit-method/&lt;name&gt;.md` + V4_SKILL_FORMAT.md |
| 加新工具（Python）| `tools/&lt;cat&gt;/&lt;name&gt;/` + V4_TOOL_API_SPEC.md |
| 加 schematic placement | `assets/placement_guides/&lt;view&gt;.json` |
| 改 PACK 元信息 / 激活关键词 | `manifest.yaml` + V4_PACK_MANIFEST_SCHEMA.md |

## 已知限制

- &lt;列出 PACK 当前未覆盖的边界场景&gt;
- &lt;列出已知的 spec 不达标拓扑&gt;
- &lt;列出依赖的外部环境（特殊 PDK / 仿真器版本）&gt;

## Changelog

### 0.1.0 — &lt;date&gt;
- 初始版本，Tier 1 Knowledge-only
- 覆盖 X / Y / Z

---

PACK 写作 / 发布 / 分发完整流程见 [docs/v4/PACK_AUTHOR_GUIDE.md](../../../docs/v4/PACK_AUTHOR_GUIDE.md)。
