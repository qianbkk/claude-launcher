# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Claude Code Multi-Provider Launcher** for Windows. It intercepts the `claude` command and presents a menu to select from multiple AI model providers (OpenAI-compatible APIs, Anthropic-compatible endpoints, OpenRouter, etc.) before launching the real Claude Code.

## File Structure

- `claude_launcher.ps1` — Core launcher (PowerShell). Handles provider selection, env var injection, and session management.
- `claude.cmd` — Windows batch wrapper that routes `claude` calls to either the launcher or the real Claude binary.
- `setup.ps1` — PATH setup/repair tool. Ensures the launcher directory is in PATH and cleans stale entries.
- `claude_config.json` — Provider configuration (API keys, base URLs, models).
- `last_selection.json` — Auto-generated. Persists the last selected provider for session-resume auto-inject.

## Architecture

**Command Routing** (claude_launcher.ps1 lines 176-236):
- `version`, `help`, `mcp`, `agents`, `plugin`, `install`, `setup-token`, `auto-mode` → passthrough directly to real Claude
- `-r`, `-c`, `--resume`, `--continue`, `--from-pr` → auto-inject last selection (no menu)
- bare `claude` or all other args → show provider selection menu

**Provider Selection Flow**:
1. `Build-MenuItems` filters enabled providers that have valid API keys
2. User picks a numbered option
3. `Start-ClaudeSession` sets `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`, and model env vars
4. Launches real Claude Code with those env vars

**Model Update**: `Update-ModelList` queries each provider's `models_api` endpoint, then filters models per-provider using `Get-FilteredModels` (kimi keeps k2/k2.5, minimax keeps M1/M2/M2.1/M2.5, etc.).

## Provider Config Schema

```json
{
  "providers": [
    {
      "id": "provider-id",
      "name": "Display Name",
      "base_url": "https://api.example.com/v1",
      "api_key": "YOUR_KEY",
      "auth_type": "Bearer|x-api-key",
      "openrouter_mode": false,
      "anthropic_mode": false,
      "fast_model": "model-id",
      "models_api": "https://api.example.com/v1/models",
      "models": [{ "id": "model-id", "desc": "optional description" }]
    }
  ],
  "settings": {
    "timeout_ms": 300000,
    "disable_nonessential_traffic": false,
    "disable_experimental_betas": false
  }
}
```

Key provider properties:
- `auth_type`: "Bearer" (default) or "x-api-key" (used by many Chinese providers)
- `openrouter_mode`: when true, clears `ANTHROPIC_API_KEY` (OpenRouter uses `Authorization` header only)
- `anthropic_mode`: when true, sets `ANTHROPIC_API_KEY` to the raw `api_key` value
- `fast_model`: the default/fast model for this provider

## Common Commands

- **Run launcher**: `claude` (from any terminal)
- **PATH repair/setup**: `powershell -ExecutionPolicy Bypass -File setup.ps1`
- **Direct real Claude**: `claude.cmd --version` or any local-only command bypasses the launcher
- **Session resume**: `claude -r` auto-uses the last selected provider (no menu)

## Session Resume

When using `-r`, `-c`, or `--from-pr`, the launcher loads `last_selection.json` and auto-injects all env vars, so the same provider/model is used automatically. This avoids the menu on CI/resume flows.
