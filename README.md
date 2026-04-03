# Claude Code Multi-Provider Launcher

> **跨模型启动器** — 拦截 `claude` 命令，通过交互式菜单选择 AI 模型提供商后启动 Claude Code。

---

## Introduction / 介绍

| | |
|---|---|
| **EN** | A Windows launcher that intercepts the `claude` command and lets you choose from multiple AI model providers via an interactive menu before launching Claude Code. **Supports:** MiniMax, Kimi (Moonshot), DeepSeek, GLM/Zhipu AI, Aliyun/Qwen, OpenRouter, Anthropic Official, and custom endpoints. |
| **中文** | Windows 平台的多提供商启动器。拦截 `claude` 命令，通过交互式菜单选择 AI 模型提供商（MiniMax、Kimi、DeepSeek、智谱 GLM、阿里云百炼、OpenRouter、Anthropic 官方等），然后启动 Claude Code。 |

---

## Preview / 效果预览

![Launcher Menu](https://minimax-algeng-chat-tts.oss-cn-wulanchabu.aliyuncs.com/ccv2%2F2026-04-03%2FMiniMax-M2.7%2F2027971906367398583%2F7f27d5cd131814718d05d05014ee4c7d72bfdbede73cde0687809a9c5c16608e..png?Expires=1775284568&OSSAccessKeyId=LTAI5tGLnRTkBjLuYPjNcKQ8&Signature=H48AmKPrDz2AEk%2FNUTzOIP6tR8w%3D)

---

## Setup / 快速开始

| | |
|---|---|
| **EN** | **1.** Install Claude Code: `npm install -g @anthropic-ai/claude-code`<br>**2.** Run setup to add launcher to PATH:<br>`powershell -ExecutionPolicy Bypass -File setup.ps1`<br>**3.** Open a **new terminal** and edit `claude_config.json` with your API keys.<br>**4.** Start: `claude` |
| **中文** | **1.** 安装 Claude Code：`npm install -g @anthropic-ai/claude-code`<br>**2.** 运行 setup 将启动器加入 PATH：<br>`powershell -ExecutionPolicy Bypass -File setup.ps1`<br>**3.** 打开**新终端窗口**，编辑 `claude_config.json` 填入你的 API keys。<br>**4.** 启动：`claude` |

---

## Usage / 使用方法

| Command 命令 | EN Description | 中文说明 |
|---|---|---|
| `claude` | Show provider menu, start session | 显示提供商菜单，启动会话 |
| `claude -r` | Resume last session (auto-select last provider) | 恢复上次会话（自动使用上次选择的提供商） |
| `claude -c` | Continue last session | 继续上次会话 |
| `claude --version` | Passthrough to real Claude (bypass menu) | 直通真实 Claude（绕过菜单） |
| `powershell -ExecutionPolicy Bypass -File setup.ps1` | Repair PATH if launcher not found | 修复 PATH（启动器找不到时使用） |

---

## Features / 功能特性

| | |
|---|---|
| **EN** | • **Provider menu** — select from multiple AI providers each session<br>• **Session resume** — `claude -r` remembers your last choice<br>• **Fast model per provider** — each provider has its own default model<br>• **Model list update** — press `U` to fetch latest models from provider APIs<br>• **Provider toggle** — enable/disable providers without removing config<br>• **Session isolation** — each terminal window can use a different provider |
| **中文** | • **提供商菜单** — 每次启动可选择不同 AI 提供商<br>• **会话恢复** — `claude -r` 记住上次选择<br>• **每个提供商的快速模型** — 各提供商可设置独立默认模型<br>• **模型列表更新** — 按 `U` 从提供商 API 获取最新模型列表<br>• **提供商开关** — 可启用/禁用提供商而不删除配置<br>• **会话隔离** — 每个终端窗口可使用不同提供商 |

---

## AI-Readme / AI 阅读指南

**Project type / 项目类型:** CLI launcher / environment router

**Purpose / 目的:** Intercepts `claude` on Windows, shows provider selection menu, injects API credentials via env vars (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`, etc.), delegates to real Claude Code binary.

拦截 Windows 上的 `claude` 命令，显示提供商选择菜单，通过环境变量注入 API 凭证，然后调用真实 Claude Code 二进制文件。

**Architecture / 架构:**

| File 文件 | Description 描述 |
|---|---|
| `claude.cmd` | Batch shim; routes to launcher or real Claude based on argument |
| `claude_launcher.ps1` | Core launcher; menu UI, provider selection, env injection, session management |
| `setup.ps1` | PATH setup/repair; adds launcher dir to user PATH, cleans stale entries |
| `claude_config.json` | Provider definitions (base URLs, API keys, model lists) |
| `last_selection.json` | Auto-saved; stores last provider/model for session resume |

**Command routing / 命令路由:**

| Pattern 模式 | Behavior 行为 |
|---|---|
| `version`, `help`, `mcp`, `agents`, `plugin`, `install`, `setup-token`, `auto-mode` | Passthrough directly to real Claude（直接透传给真实 Claude） |
| `-r`, `-c`, `--resume`, `--continue`, `--from-pr` | Auto-inject last selection — no menu（自动注入上次选择，不显示菜单） |
| bare `claude` or other args | Show provider menu（显示提供商菜单） |

**Provider config schema / 提供商配置 schema:**

```json
{
  "id": "provider-id",
  "name": "Display Name",
  "base_url": "https://api.example.com/v1",
  "api_key": "YOUR_API_KEY",
  "auth_type": "Bearer | x-api-key",
  "openrouter_mode": false,
  "anthropic_mode": false,
  "fast_model": "default-model-id",
  "models_api": "https://api.example.com/v1/models",
  "models": [{ "id": "model-id", "desc": "description" }]
}
```

- `auth_type`: `"Bearer"` (default) or `"x-api-key"` (used by many Chinese providers)
- `openrouter_mode: true` → clears `ANTHROPIC_API_KEY` (OpenRouter uses `Authorization` header only)
- `anthropic_mode: true` → sets `ANTHROPIC_API_KEY` to the raw api_key value
- `fast_model` → default/fast model for this provider

---

## Provider API Requirements / 提供商 API 需求

| Provider 提供商 | EN: API Key Location | API Key 获取位置 |
|---|---|---|
| MiniMax | api.minimaxi.com console | api.minimaxi.com 控制台 |
| Kimi (Moonshot) | platform.moonshot.cn | platform.moonshot.cn |
| DeepSeek | platform.deepseek.com | platform.deepseek.com |
| GLM / Zhipu AI | open.bigmodel.cn | open.bigmodel.cn |
| Aliyun Bailian | bailian.console.aliyun.com | bailian.console.aliyun.com |
| OpenRouter | openrouter.ai/keys | openrouter.ai/keys |
| Anthropic | console.anthropic.com (VPN required) | console.anthropic.com（需 VPN） |

---

## File Descriptions / 文件说明

| File 文件 | EN Description | 中文说明 |
|---|---|---|
| `claude.cmd` | Windows batch wrapper; routes `claude` to launcher or real binary | Windows 批处理桥接层；将 `claude` 路由到启动器或真实二进制文件 |
| `claude_launcher.ps1` | Core launcher; menu, provider selection, env var injection | 核心启动器；菜单、提供商选择、环境变量注入 |
| `setup.ps1` | PATH setup/repair tool | PATH 配置/修复工具 |
| `claude_config.json` | Provider configuration (fill in API keys here) | 提供商配置（在此填入 API keys） |
| `last_selection.json` | Auto-saved; stores last provider/model for session resume | 自动保存；存储上次提供商/模型以恢复会话 |
| `CLAUDE.md` | Guidance for Claude Code agents working in this repo | Claude Code 代理在此仓库工作的指南 |
| `.gitignore` | Ignores `last_selection.json` and `claude_config.json` | 忽略 `last_selection.json` 和 `claude_config.json` |

> **Note / 注意:** `claude_config.json` is gitignored by default since it contains your API keys. If you want to share your config template, copy it to `claude_config.json.example` and commit that instead.
>
> `claude_config.json` 默认被 gitignore，因为它包含你的 API keys。如果想分享配置模板，请复制为 `claude_config.json.example` 再提交。

---

## License / 许可证

MIT
