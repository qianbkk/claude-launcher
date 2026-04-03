# Claude Code Multi-Provider Launcher

A Windows launcher that intercepts the `claude` command and lets you choose from multiple AI model providers via an interactive menu before launching Claude Code.

**Supports:** MiniMax, Kimi (Moonshot), DeepSeek, GLM/Zhipu AI, Aliyun/Qwen, OpenRouter, Anthropic Official, and custom endpoints.

## Preview

![Launcher Menu](https://minimax-algeng-chat-tts.oss-cn-wulanchabu.aliyuncs.com/ccv2%2F2026-04-03%2FMiniMax-M2.7%2F2027971906367398583%2F7f27d5cd131814718d05d05014ee4c7d72bfdbede73cde0687809a9c5c16608e..png?Expires=1775284568&OSSAccessKeyId=LTAI5tGLnRTkBjLuYPjNcKQ8&Signature=H48AmKPrDz2AEk%2FNUTzOIP6tR8w%3D)

## Setup

**1.** Install Claude Code:
```powershell
npm install -g @anthropic-ai/claude-code
```

**2.** Run setup to add launcher to PATH:
```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

**3.** Open a **new terminal** and edit `claude_config.json` with your API keys.

**4.** Start:
```powershell
claude
```

## Usage

| Command | Description |
|---|---|
| `claude` | Show provider menu, start session |
| `claude -r` | Resume last session (auto-select last provider) |
| `claude -c` | Continue last session |
| `claude --version` | Passthrough to real Claude (bypass menu) |
| `claude --dangerously-skip-permissions` | Skip permission prompts |
| `claude -p <prompt>` | Print Claude response without starting interactive session |
| `claude --print-set-options` | Print current configuration |
| `claude mcp` | Manage MCP servers |
| `claude agents` | List available agents |
| `claude install` | Install plugin from marketplace |
| `powershell -ExecutionPolicy Bypass -File setup.ps1` | Repair PATH if launcher not found |

## Features

- **Provider menu** — select from multiple AI providers each session
- **Session resume** — `claude -r` remembers your last choice
- **Fast model per provider** — each provider has its own default model
- **Model list update** — press `U` to fetch latest models from provider APIs
- **Provider toggle** — enable/disable providers without removing config
- **Session isolation** — each terminal window can use a different provider

## Architecture

**Project type:** CLI launcher / environment router

**Purpose:** Intercepts `claude` on Windows, shows provider selection menu, injects API credentials via env vars (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`, etc.), delegates to real Claude Code binary.

### File Structure

| File | Description |
|---|---|
| `claude.cmd` | Batch shim; routes to launcher or real Claude based on argument |
| `claude_launcher.ps1` | Core launcher; menu UI, provider selection, env injection, session management |
| `setup.ps1` | PATH setup/repair; adds launcher dir to user PATH, cleans stale entries |
| `claude_config.json` | Provider definitions (base URLs, API keys, model lists) |
| `last_selection.json` | Auto-saved; stores last provider/model for session resume |

### Command Routing

| Pattern | Behavior |
|---|---|
| `version`, `help`, `mcp`, `agents`, `plugin`, `install`, `setup-token`, `auto-mode` | Passthrough directly to real Claude |
| `-r`, `-c`, `--resume`, `--continue`, `--from-pr` | Auto-inject last selection — no menu |
| bare `claude` or other args | Show provider menu |

### Provider Config Schema

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

Key properties:
- `auth_type`: `"Bearer"` (default) or `"x-api-key"` (used by many Chinese providers)
- `openrouter_mode: true` → clears `ANTHROPIC_API_KEY` (OpenRouter uses `Authorization` header only)
- `anthropic_mode: true` → sets `ANTHROPIC_API_KEY` to the raw api_key value
- `fast_model` → default/fast model for this provider

## Provider API Requirements

| Provider | API Key Location |
|---|---|
| MiniMax | api.minimaxi.com console |
| Kimi (Moonshot) | platform.moonshot.cn |
| DeepSeek | platform.deepseek.com |
| GLM / Zhipu AI | open.bigmodel.cn |
| Aliyun Bailian | bailian.console.aliyun.com |
| OpenRouter | openrouter.ai/keys |
| Anthropic | console.anthropic.com |

## File Descriptions

| File | Description |
|---|---|
| `claude.cmd` | Windows batch wrapper; routes `claude` to launcher or real binary |
| `claude_launcher.ps1` | Core launcher; menu, provider selection, env var injection |
| `setup.ps1` | PATH setup/repair tool |
| `claude_config.json` | Provider configuration (fill in API keys here) |
| `last_selection.json` | Auto-saved; stores last provider/model for session resume |
| `CLAUDE.md` | Guidance for Claude Code agents working in this repo |
| `.gitignore` | Ignores `last_selection.json` and `claude_config.json` |

> **Note:** `claude_config.json` is gitignored by default since it contains your API keys. If you want to share your config template, copy it to `claude_config.json.example` and commit that instead.

## License

MIT
