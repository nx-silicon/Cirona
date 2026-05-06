<div align="center">

# Cirona

**AI-Powered Analog IC Design Platform** · **AI 驱动的模拟集成电路设计平台**

*From spec to silicon — analog design assisted end-to-end*
*从规格书到仿真验证，全流程 AI 辅助*

[![Release](https://img.shields.io/badge/release-v1.0.0--rc9.20-blue?style=flat-square)](https://github.com/nx-silicon/Cirona/releases)
[![Platform](https://img.shields.io/badge/platform-Windows-lightgrey?style=flat-square&logo=windows)](https://github.com/nx-silicon/Cirona/releases)
[![Python](https://img.shields.io/badge/python-3.12%2B-yellow?style=flat-square&logo=python)](https://www.python.org/downloads/)
[![GitHub](https://img.shields.io/badge/github-nx--silicon%2FCirona-181717?style=flat-square&logo=github)](https://github.com/nx-silicon/Cirona)

📥 **[Download Installer / 下载安装包](https://github.com/nx-silicon/Cirona/releases)**  ·  💬 **[Report an Issue / 提交反馈](https://github.com/nx-silicon/Cirona/issues)**

[**English**](#english)  |  [**中文**](#中文)

</div>

---

> **Where do I get the Windows installer?**
> Grab it from the **[Releases page](https://github.com/nx-silicon/Cirona/releases)**
> of this repo. This repository also hosts the open **Pack library** (knowledge
> bundles you can install at runtime).
>
> **Windows 安装包在哪下载？**
> 到本仓库的 **[Releases 页面](https://github.com/nx-silicon/Cirona/releases)** 下载。
> 本仓库同时提供开放的 **Pack 知识库**（可在运行时安装）。

---

<a name="english"></a>

# English

## What is Cirona

Cirona is a Windows desktop tool that lets analog IC engineers go from a
circuit specification to a verified SPICE simulation through natural-language
conversation. No scripting, no complex EDA suite — tell the AI your design
targets and it picks the topology, runs gm/ID sizing, generates the netlist,
drives ngspice (DC / AC / transient / noise), and self-corrects on the results.

## Key features

- **End-to-end AI design loop** — chat-driven flow from spec to verified
  simulation; the AI picks the topology, sizes devices, writes the netlist,
  runs simulation and self-corrects.
- **Built-in knowledge base** — circuit-family Packs (OTA, Bandgap, LDO,
  Comparator, …), base-cell design rules, automatic process binding
  (180 nm / 55 nm).
- **Bundled simulator** — ngspice ships with the installer. DC / AC /
  transient / noise out of the box, plus PVT sweeps and a built-in
  waveform viewer (Bode + time-domain).
- **Automatic optimisation** — single- and multi-objective optimisers for
  gain × power × bandwidth Pareto sweeps.
- **Cross-session memory** — Cirona remembers your preferences and the
  insights it has discovered; reopen a project and the context restores.
- **Multi-provider LLM support** — Anthropic, OpenAI, DeepSeek, Gemini,
  Kimi, MiniMax, GLM (configurable in Settings).

## System requirements

| Item | Requirement |
|------|-------------|
| OS | Windows 10 / 11 (x64) |
| Python | **3.12 or newer** (mandatory) |
| Disk | Installer ~100 MB; runtime data ~500 MB |
| ngspice | **Bundled** — no separate install needed |

## Install

**1. Install Python 3.12+** from <https://www.python.org/downloads/>. Tick
**"Add Python to PATH"** during setup. Verify with `python --version`.

**2. Install Cirona** — download `exe` from the
**[Releases page](https://github.com/nx-silicon/Cirona/releases)** and run it.
Windows Defender SmartScreen may warn because the binary is unsigned — click
**More info → Run anyway**.

**3. First-run wizard** (3 steps, ~3–8 min):
- **Pick a data directory** — e.g. `D:\Cirona`. Don't put it under
  `Program Files`.
- **Auto-install dependencies** — Cirona creates a Python venv, installs
  backend packages, and copies demo projects + PDKs to your data directory.
- **Enter API keys** — at least one LLM provider key. Editable later in
  **Settings**.

The wizard runs only once; later launches go straight to the main UI.

## Quick start

After install you'll find 4 demo projects in your library:

| Cell | Process / VDD | Headline measured KPIs (TT 27 °C) | Status |
|------|---------------|-----------------------------------|--------|
| **fc_ota** | vpdk180nm / 1.8 V | Gain = 72.2 dB · GBW = 10.16 MHz · PM = 67.8° · P = 0.18 mW | ✅ 4/4 PASS |
| **two_stage** | vpdk55nm core / 1.2 V | Gain = 77.0 dB · GBW = 10.7 MHz · PM = 75° · P = 165 µW | ⚠️ 4/5 + 1 marginal |
| **bandgap** | vpdk180nm / 1.8 V | Vref = 1.185 V · TC = 44.7 ppm/°C · Iq ~ 24 µA · startup = 562 ns | ✅ 5/5 PASS |
| **ldo** | vpdk55nm IO / 1.8 V→1.2 V | Vout error < ±1 mV · Iq ~ 60 µA · PSRR = 70.8 dB @ 1 kHz · PM = 62°–76° (Iload 0–10 mA) · undershoot 0.45 mV / overshoot 0.36 mV @ 100 ns load step | ✅ 13/13 PASS |

Open one and chat:

```
Continue this design. Show me the latest simulation result.
```

Or start fresh:

```
Design an OTA: gain > 60 dB, PM > 60°, power < 1 mW, 180 nm process.
```

## FAQ

**Do I need Cadence Virtuoso / HSPICE?**
No. Cirona uses bundled ngspice with virtual 180 nm / 55 nm PDKs. No
commercial EDA license needed.

**Can I bring my own PDK?**
Not in v1.0. External PDK import is on the roadmap.

**Are my API keys safe?**
Stored locally at `<data-dir>\.cirona\settings\.env`. Cirona itself doesn't
phone home — LLM calls go directly from your machine to the chosen provider.

**Will I lose data when I upgrade?**
No. User data lives in your data directory, fully separated from the
install. In-place upgrades don't touch it.

## Known limitations (v1.0-rc)

- Windows only (Mac / Linux planned)
- Installer is unsigned (SmartScreen warning is expected)
- Some complex topologies (e.g. fully-differential opamps) still being tuned

## Feedback

Bugs and feature requests at <https://github.com/nx-silicon/Cirona/issues>,
please include a description, screenshots, and the contents of
`<data-dir>\.cirona\logs\frontend.log`.

## Roadmap

- [ ] Mac / Linux support
- [ ] Embedded Python runtime (no manual install)
- [ ] More circuit families (Switched-Capacitor / Class-D / PLL)
- [ ] Custom PDK import
- [ ] Multi-corner waveform overlay

## What's in this repository

| Path | Purpose |
|------|---------|
| `README.md` | This file (English + 中文) |
| `packs/` | Open-source knowledge **Packs** — circuit families, design flows, reference netlists. Install at runtime via the Pack manager, or `git clone` into your data directory. |
| `LICENSE` | License terms for the Packs and documentation in this repo |

The Windows installer is published on the **[Releases page](https://github.com/nx-silicon/Cirona/releases)** of this repo.

---

<a name="中文"></a>

# 中文

## 这是什么

Cirona 是一个 Windows 桌面工具，让模拟 IC 工程师通过自然语言对话完成从电路规格到 SPICE 仿真验证的完整设计流程。不需要写脚本，不需要熟悉复杂的 EDA 软件——告诉 AI 你的设计指标，它会自动完成拓扑选择、gm/ID sizing、SPICE 网表生成、ngspice 仿真（DC / AC / 瞬态 / 噪声），并根据结果自我修正。

## 主要功能

- **AI 全流程设计**——对话驱动，从指标到仿真验证一站式打通；AI 自动完成拓扑选择、器件 sizing、网表生成、仿真并根据结果自我修正
- **内置知识库**——电路族 Pack（OTA / Bandgap / LDO / Comparator 等）、base-cell 设计规则、自动匹配工艺（180nm / 55nm）
- **仿真器内置**——ngspice 随安装包发布，开箱即用；支持 DC / AC / 瞬态 / 噪声仿真、PVT 扫描、波形可视化（Bode 图 + 时域）
- **自动优化**——单目标和多目标优化算法，支持增益 × 功耗 × 带宽 Pareto 寻优
- **跨会话记忆**——AI 记住你的设计偏好和已发现的电路规律，重新打开同一项目时自动恢复上下文
- **多 LLM Provider 支持**——Anthropic、OpenAI、DeepSeek、Gemini、Kimi、MiniMax、GLM（在 Settings 里配置）

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10 / 11（x64） |
| Python | **3.12 或更高版本**（必须） |
| 磁盘空间 | 安装包 ~100MB，运行时数据 ~500MB |
| ngspice | **已内置**，无需另行安装 |

## 安装步骤

**1. 安装 Python 3.12+**——前往 <https://www.python.org/downloads/> 下载，安装时勾选 **"Add Python to PATH"**。验证：命令提示符输入 `python --version`，应显示 `Python 3.12.x`。

**2. 安装 Cirona**——从 **[Releases 页面](https://github.com/nx-silicon/Cirona/releases)** 下载 exe安装包，双击运行。Windows Defender 可能弹出 SmartScreen 警告（因没有代码签名证书），点击「更多信息」→「仍要运行」即可。

**3. 首次启动初始化**（三步向导，约 3–8 分钟）：
- **选择数据目录**——建议 `D:\Cirona`，不要放在 `Program Files` 里
- **自动安装依赖**——创建 Python 虚拟环境、安装后端包、复制示例项目和 PDK
- **填写 API Key**——至少填一个 LLM provider，之后在 Settings 里随时可改

向导只运行一次，之后直接进入主界面。

## 快速开始

安装完成后，左侧文件树已包含 4 个示例项目：

| Cell | 工艺 / VDD | 主要实测 KPI (TT 27 °C) | 状态 |
|------|-----------|------------------------|------|
| **fc_ota** | vpdk180nm / 1.8 V | Gain = 72.2 dB · GBW = 10.16 MHz · PM = 67.8° · P = 0.18 mW | ✅ 4/4 PASS |
| **two_stage** | vpdk55nm core / 1.2 V | Gain = 77.0 dB · GBW = 10.7 MHz · PM = 75° · P = 165 µW | ⚠️ 4/5 + 1 marginal |
| **bandgap** | vpdk180nm / 1.8 V | Vref = 1.185 V · TC = 44.7 ppm/°C · Iq ~ 24 µA · startup = 562 ns | ✅ 5/5 PASS |
| **ldo** | vpdk55nm IO / 1.8 V→1.2 V | Vout 误差 < ±1 mV · Iq ~ 60 µA · PSRR = 70.8 dB @ 1 kHz · PM = 62°–76°（Iload 0–10 mA）· undershoot 0.45 mV / overshoot 0.36 mV @ 100 ns load step | ✅ 13/13 PASS |

点击任一项目，在右侧聊天框输入：

```
继续这个设计，查看当前的仿真结果
```

或者新建项目从零开始：

```
我需要设计一个 OTA：增益 > 60dB，相位裕量 > 60°，功耗 < 1mW，工艺 180nm
```

## 常见问题

**需要 Cadence Virtuoso / HSPICE 吗？**
不需要。Cirona 内置 ngspice + 虚拟 180nm / 55nm PDK，不需要商业 EDA 授权。

**支持自己的工艺库吗？**
v1.0 暂不支持，未来版本会开放接口。

**API Key 安全吗？**
Key 只保存在本机 `<数据目录>\.cirona\settings\.env`，不上传任何服务器。Cirona 本身不联网，AI 调用直接从你的电脑发到对应 provider。

**升级版本时数据会丢失吗？**
不会。用户数据保存在你选的数据目录里，与安装包完全分离，覆盖安装不影响数据。

## 已知限制（v1.0-rc）

- 仅支持 Windows（Mac / Linux 计划中）
- 安装包无代码签名，Windows Defender 会弹警告
- 部分复杂拓扑（如全差分运放）的自动设计准确率仍在优化中

## 反馈与问题

到 <https://github.com/nx-silicon/Cirona/issues> 提交，附上：问题描述、截图、`<数据目录>\.cirona\logs\frontend.log` 内容。

## 开发路线

- [ ] Mac / Linux 支持
- [ ] Python 运行时内嵌（无需用户手动安装）
- [ ] 更多电路族（Switched-Capacitor / Class-D / PLL）
- [ ] 自定义 PDK 导入
- [ ] 多 corner 波形对比

## 仓库内容说明

| 路径 | 作用 |
|------|------|
| `README.md` | 当前文件（中英双语） |
| `packs/` | 开源 **Pack 知识库**——电路族、设计流程、参考网表。可通过 Pack 管理器在运行时安装，或 `git clone` 到数据目录直接使用 |
| `LICENSE` | 本仓库 Pack 和文档的许可条款 |

Windows 安装包发布在本仓库的 **[Releases 页面](https://github.com/nx-silicon/Cirona/releases)**。

---

<div align="center">

Made for analog IC engineers, by analog IC engineers.

[**🌐 Website**](https://www.nx-si.ai/)  ·  [**📥 Download**](https://github.com/nx-silicon/Cirona/releases)  ·  [**💬 GitHub Issues**](https://github.com/nx-silicon/Cirona/issues)

</div>
