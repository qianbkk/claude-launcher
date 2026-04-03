# Claude Code Multi-Provider Launcher

<!-- Human section -->
## Introduction

A Windows launcher that intercepts the `claude` command and lets you choose from multiple AI model providers via an interactive menu before launching Claude Code.

**Supports:** MiniMax, Kimi (Moonshot), DeepSeek, GLM/Zhipu AI, Aliyun/Qwen, OpenRouter, Anthropic Official, and custom endpoints.

---

<!-- AI section -->
## AI-Readme

**Project type:** CLI launcher / environment router

**Purpose:** Intercepts the `claude` command on Windows, presents a provider/model selection menu, injects API credentials via environment variables (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`, etc.), then delegates to the real Claude Code binary.

**Architecture:**
- `claude.cmd` — batch shim; routes to launcher or passthrough to real Claude based on argument
- `claude_launcher.ps1` — PowerShell launcher; menu UI, provider selection, env injection, session management
- `setup.ps1` — PATH setup/repair; adds launcher dir to user PATH, cleans stale entries
- `claude_config.json` — provider definitions (base URLs, API keys, model lists)
- `last_selection.json` — auto-generated; persists last provider/model for session-resume

**Command routing:**
- `version`, `help`, `mcp`, `agents`, `plugin`, `install`, `setup-token`, `auto-mode` → passthrough to real Claude (no menu)
- `-r`, `-c`, `--resume`, `--continue`, `--from-pr` → auto-inject last selection (session-resume)
- bare `claude` or other args → show provider selection menu

**Provider config schema:** `providers[].api_key` accepts Bearer tokens; `auth_type` can be "Bearer" or "x-api-key"; `openrouter_mode: true` clears `ANTHROPIC_API_KEY`; `anthropic_mode: true` sets it to the raw api_key; `fast_model` sets the default model for the provider.

---

## Setup

### 1. Install Claude Code (if not already)

```powershell
npm install -g @anthropic-ai/claude-code
```

### 2. Run setup to add launcher to PATH

```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

Then **open a new terminal** for PATH changes to take effect.

### 3. Configure your API keys

Edit `claude_config.json` and replace `YOUR_API_KEY_HERE` with your actual API keys for each provider.

### 4. Start using

```powershell
claude
```

## Usage

| Action | Description |
|--------|-------------|
| `claude` | Show provider menu and start session |
| `claude -r` | Resume last session (auto-selects last provider) |
| `claude -c` | Continue last session |
| `claude --version` | Bypass menu, passthrough to real Claude |
| `powershell -ExecutionPolicy Bypass -File setup.ps1` | Repair PATH if launcher not found |

## Features

- **Provider menu** — select from multiple AI providers each time you start
- **Session resume** — `claude -r` remembers your last choice
- **Fast model per provider** — each provider can have its own default model
- **Model list update** — press `U` in the menu to fetch latest models from provider APIs
- **Provider toggle** — enable/disable providers without removing config
- **Session isolation** — each terminal window can use a different provider

## Provider Requirements

| Provider | API Key Location |
|----------|-----------------|
| MiniMax | api.minimaxi.com console |
| Kimi (Moonshot) | platform.moonshot.cn |
| DeepSeek | platform.deepseek.com |
| GLM / Zhipu AI | open.bigmodel.cn |
| Aliyun Bailian | bailian.console.aliyun.com |
| OpenRouter | openrouter.ai/keys |
| Anthropic | console.anthropic.com (VPN required) |

## File Descriptions

| File | Description |
|------|-------------|
| `claude.cmd` | Windows batch wrapper; routes `claude` to launcher or real binary |
| `claude_launcher.ps1` | Core launcher; menu, provider selection, env var injection |
| `setup.ps1` | PATH setup/repair tool for the launcher |
| `claude_config.json` | Provider configuration (fill in API keys here) |
| `last_selection.json` | Auto-saved; stores last provider/model for session resume |
| `CLAUDE.md` | Guidance for Claude Code agents working in this repo |
| `.gitignore` | Ignores `last_selection.json` and `claude_config.json` |

> **Note:** `claude_config.json` is gitignored by default since it contains your API keys. If you want to share your config template, copy it to `claude_config.json.example` and commit that instead.

## License

MIT
