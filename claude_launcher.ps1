#Requires -Version 5.1
# claude_launcher.ps1 - Claude Code Multi-Provider Launcher v3.3
# Pure ASCII source. Reads UTF-8 config JSON. Intercepts the claude command.
# v3.3: Selective interception - session resume (-r/-c/--from-pr) auto-use last selection,
#        other API calls show menu, local-only commands passthrough
$PassthroughArgs = $args

Set-StrictMode -Off
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$Script:Dir           = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Script:ConfigPath    = Join-Path $Script:Dir "claude_config.json"
$Script:LastSelectPath = Join-Path $Script:Dir "last_selection.json"
$Script:Version       = "3.3"

# ================================================================
# FIND THE REAL CLAUDE BINARY
# ================================================================
function Find-RealClaude {
    param([switch]$Silent)

    # Method 1: native installer location (highest priority - always newest version)
    $nativeCandidates = @(
        "$env:USERPROFILE\.local\bin\claude.exe",
        "$env:LOCALAPPDATA\Programs\claude\claude.exe",
        "$env:USERPROFILE\.claude\bin\claude.exe",
        "$env:LOCALAPPDATA\AnthropicClaude\claude.exe"
    )
    foreach ($c in $nativeCandidates) {
        if ($c -and (Test-Path $c)) {
            if (-not $Silent) { Write-Info "Real claude (native): $c" }
            return $c
        }
    }

    # Method 2: Get-Command -All, skip our shim directory
    $all = Get-Command claude -All -ErrorAction SilentlyContinue
    foreach ($cmd in $all) {
        $src = $cmd.Source
        if ([string]::IsNullOrWhiteSpace($src)) { continue }
        $dir = Split-Path -Parent $src
        if ($dir -ieq $Script:Dir) { continue }
        if ($src -ieq (Join-Path $Script:Dir "claude.cmd")) { continue }
        if (-not $Silent) { Write-Info "Real claude (PATH): $src" }
        return $src
    }

    # Method 3: npm global bin (legacy npm install)
    $npmCandidates = @(
        "$env:APPDATA\npm\claude.cmd",
        "$env:APPDATA\npm\claude",
        "$env:USERPROFILE\AppData\Roaming\npm\claude.cmd",
        "$env:USERPROFILE\AppData\Roaming\npm\claude"
    )
    foreach ($c in $npmCandidates) {
        if ($c -and (Test-Path $c)) {
            if (-not $Silent) { Write-Info "Real claude (npm): $c" }
            return $c
        }
    }

    return $null
}

# ================================================================
# LAST SELECTION PERSISTENCE (for session-resume auto-inject)
# ================================================================
function Save-LastSelection {
    param($Provider, [string]$ModelId)
    try {
        $fastMod = if ($Provider.PSObject.Properties["fast_model"] -and $Provider.fast_model) {
                        $Provider.fast_model
                    } else { $ModelId }
        $data = @{
            provider_id   = $Provider.id
            provider_name = $Provider.name
            base_url      = $Provider.base_url.TrimEnd("/")
            api_key       = $Provider.api_key
            model         = $ModelId
            fast_model    = $fastMod
            auth_type     = if ($Provider.PSObject.Properties["auth_type"]) { $Provider.auth_type } else { "Bearer" }
            openrouter_mode = if ($Provider.PSObject.Properties["openrouter_mode"]) { $Provider.openrouter_mode } else { $false }
            anthropic_mode  = if ($Provider.PSObject.Properties["anthropic_mode"]) { $Provider.anthropic_mode } else { $false }
            timestamp     = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        }
        $json = $data | ConvertTo-Json -Depth 5
        Set-Content -Path $Script:LastSelectPath -Value $json -Encoding UTF8
    } catch {
        # Silent fail - non-critical feature
    }
}

function Load-LastSelection {
    if (-not (Test-Path $Script:LastSelectPath)) { return $null }
    try {
        $raw = Get-Content -Path $Script:LastSelectPath -Raw -Encoding UTF8
        return $raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

# ================================================================
# COMMAND CLASSIFICATION
# ================================================================
# LOCAL-ONLY commands: pure passthrough (no API call)
$LocalOnlyCommands = @(
    "^-?--version$",
    "^-?--help$",
    "^-?--print-set-options$",
    "^mcp$",
    "^mcp\s",
    "^agents$",
    "^agents\s",
    "^plugin$",
    "^plugin\s",
    "^plugins$",
    "^plugins\s",
    "^install$",
    "^install\s",
    "^setup-token$",
    "^setup-token\s",
    "^auto-mode$",
    "^auto-mode\s"
)

# SESSION-RESUME commands: auto-inject last selection (no menu)
$SessionResumeFlags = @(
    "^-r$",
    "^--resume$",
    "^-c$",
    "^--continue$",
    "^--from-pr$"
)

function Test-IsLocalOnly {
    param([string[]]$Args)
    if (-not $Args -or $Args.Count -eq 0) { return $false }
    foreach ($arg in $Args) {
        foreach ($pattern in $LocalOnlyCommands) {
            if ($arg -match $pattern) { return $true }
        }
    }
    return $false
}

function Test-HasSessionResume {
    param([string[]]$Args)
    if (-not $Args -or $Args.Count -eq 0) { return $false }
    foreach ($arg in $Args) {
        $lower = $arg.ToLower()
        foreach ($pattern in $SessionResumeFlags) {
            if ($lower -match $pattern) { return $true }
        }
    }
    return $false
}

# ================================================================
# PASSTHROUGH GUARD
# If CLAUDE_LAUNCHER_ACTIVE is already set, this is an internal
# call from within Claude Code. Skip the menu entirely.
# ================================================================
if ($env:CLAUDE_LAUNCHER_ACTIVE -eq "1") {
    $real = Find-RealClaude -Silent
    if ($real) {
        & $real @PassthroughArgs
        exit $LASTEXITCODE
    }
    Write-Host "[Launcher] Cannot find real claude binary." -ForegroundColor Red
    exit 1
}

# ================================================================
# COMMAND ROUTING (v3.3)
# - Local-only commands: direct passthrough
# - Session-resume (-r/-c/--from-pr): auto-inject last selection, then passthrough
# - All other cases (bare claude, -p, --model, etc.): show menu
# ================================================================
if ($PassthroughArgs -and $PassthroughArgs.Count -gt 0) {
    $argList = @($PassthroughArgs)

    # Local-only commands: passthrough directly
    if (Test-IsLocalOnly $argList) {
        $real = Find-RealClaude -Silent
        if ($real) {
            & $real @PassthroughArgs
            exit $LASTEXITCODE
        }
        Write-Host "[Launcher] Real claude not found." -ForegroundColor Red
        exit 1
    }

    # Session-resume commands: auto-inject last selection, then passthrough
    if (Test-HasSessionResume $argList) {
        $last = Load-LastSelection
        if ($last) {
            Clear-AnthropicEnv
            $env:ANTHROPIC_BASE_URL             = $last.base_url
            $env:ANTHROPIC_AUTH_TOKEN           = $last.api_key
            $env:ANTHROPIC_MODEL                = $last.model
            $env:ANTHROPIC_SMALL_FAST_MODEL     = $last.fast_model
            $env:ANTHROPIC_DEFAULT_OPUS_MODEL   = $last.model
            $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $last.model
            $env:ANTHROPIC_DEFAULT_HAIKU_MODEL  = $last.fast_model
            if ($last.openrouter_mode) {
                $env:ANTHROPIC_API_KEY = ""
            } elseif ($last.anthropic_mode) {
                $env:ANTHROPIC_API_KEY = $last.api_key
            } else {
                $env:ANTHROPIC_API_KEY = ""
            }
            $env:CLAUDE_LAUNCHER_ACTIVE = "1"
            Write-Host ""
            Write-Host "  [i] Session-resume: auto-using last selection ($($last.provider_name) / $($last.model))" -ForegroundColor Cyan
            $real = Find-RealClaude -Silent
            if ($real) {
                & $real @PassthroughArgs
                exit $LASTEXITCODE
            }
            Write-Host "[Launcher] Real claude not found." -ForegroundColor Red
            exit 1
        } else {
            # No last selection saved - fall through to menu
            Write-Host ""
            Write-Host "  [!] No previous selection found. Showing menu..." -ForegroundColor Yellow
        }
    } else {
        # Other commands with args: show menu (user can select provider for new session)
        # But first check if this is a "print-only" mode (-p) where menu might not be desired
        # For -p and --print, we still show menu so user can pick model
        # v3.3 decision: show menu for all unclassified args (let user decide)
    }
}

# ================================================================
# DISPLAY HELPERS
# ================================================================
function Write-OK   { param([string]$m) Write-Host "  [OK] $m" -ForegroundColor Green    }
function Write-Warn { param([string]$m) Write-Host "  [!]  $m" -ForegroundColor Yellow   }
function Write-Err  { param([string]$m) Write-Host "  [X]  $m" -ForegroundColor Red      }
function Write-Info { param([string]$m) Write-Host "  [i]  $m" -ForegroundColor DarkGray }
function Write-Dim  { param([string]$m) Write-Host "  $m"       -ForegroundColor DarkGray }

function Write-Banner {
    Write-Host ""
    Write-Host "  +=========================================================+" -ForegroundColor Cyan
    Write-Host "  |      Claude Code Multi-Provider Launcher v$Script:Version          |" -ForegroundColor Cyan
    Write-Host "  |      Type [0] to exit   [S] Settings   [U] Update       |" -ForegroundColor DarkCyan
    Write-Host "  +=========================================================+" -ForegroundColor Cyan
}

function Write-Rule { Write-Host "  $('-' * 57)" -ForegroundColor DarkGray }

function Pause-Key {
    Write-Host ""
    Write-Host "  Press any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ================================================================
# CONFIG: READ / SAVE
# ================================================================
function Read-Config {
    if (-not (Test-Path $Script:ConfigPath)) {
        Write-Err "Config file not found: $Script:ConfigPath"
        Write-Info "Run setup.ps1 first, then edit claude_config.json with your API keys."
        Pause-Key
        exit 1
    }
    try {
        $raw = Get-Content -Path $Script:ConfigPath -Raw -Encoding UTF8
        return $raw | ConvertFrom-Json
    } catch {
        Write-Err "Failed to parse claude_config.json: $_"
        Write-Info "Fix JSON syntax errors in: $Script:ConfigPath"
        Pause-Key
        exit 1
    }
}

function Save-Config {
    param($Config)

    try {
        $json = $Config | ConvertTo-Json -Depth 10
        Set-Content -Path $Script:ConfigPath -Value $json -Encoding UTF8
        Write-OK "Saved: $Script:ConfigPath"
    } catch {
        Write-Err "Save failed: $_"
    }
}


# ================================================================
# PREREQUISITES CHECK
# ================================================================
function Test-Prerequisites {
    if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
        Write-Err "Node.js not found. Install from https://nodejs.org"
        Pause-Key; exit 1
    }
    $real = Find-RealClaude -Silent
    if (-not $real) {
        Write-Err "Claude Code not found!"
        Write-Info "Install: npm install -g @anthropic-ai/claude-code"
        Pause-Key; exit 1
    }
    $Script:RealClaudePath = $real
    try {
        $ver = & $real --version 2>&1 | Select-Object -First 1
        Write-Info "Claude Code: $ver  |  Launcher: v$Script:Version"
    } catch {
        Write-Info "Claude Code installed  |  Launcher: v$Script:Version"
    }
}

# ================================================================
# BUILD FLAT LIST: provider * model entries (only enabled + keyed)
# ================================================================
function Build-MenuItems {
    param($Config)
    $items = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($p in $Config.providers) {
        if ($p.PSObject.Properties["enabled"] -and $p.enabled -eq $false) { continue }
        $key = if ($p.api_key) { $p.api_key.Trim() } else { "" }
        if ([string]::IsNullOrWhiteSpace($key)) { continue }
        if ($key -match "^YOUR_|^PLACEHOLDER|^<") { continue }
        foreach ($m in $p.models) {
            $mId   = if ($m.PSObject.Properties["id"])   { $m.id   } else { [string]$m }
            $mDesc = if ($m.PSObject.Properties["desc"]) { $m.desc } else { "" }
            if ([string]::IsNullOrWhiteSpace($mId)) { continue }
            $items.Add([PSCustomObject]@{
                Provider  = $p
                ModelId   = $mId
                ModelDesc = $mDesc
            })
        }
    }
    return $items
}

# ================================================================
# MAIN MENU
# ================================================================
function Show-Menu {
    param($Config)
    Clear-Host
    Write-Banner
    Write-Host ""
    Write-Info "Config: $Script:ConfigPath"
    Write-Host ""

    $items = Build-MenuItems $Config

    if ($items.Count -eq 0) {
        Write-Warn "No configured providers found."
        Write-Info "Edit claude_config.json and fill in your API keys."
        Write-Rule
        Write-Host "  [S]  Settings / Edit config"  -ForegroundColor Yellow
        Write-Host "  [0]  Exit"                     -ForegroundColor DarkGray
        Write-Host ""
        return $items
    }

    $lastId  = ""
    $counter = 1
    foreach ($item in $items) {
        if ($item.Provider.id -ne $lastId) {
            Write-Host ""
            Write-Host "  -- $($item.Provider.name)" -ForegroundColor DarkYellow
            $lastId = $item.Provider.id
        }
        $n = $counter.ToString().PadLeft(2)
        Write-Host "  [$n] " -ForegroundColor White -NoNewline
        Write-Host "$($item.ModelId)" -ForegroundColor Cyan -NoNewline
        if (-not [string]::IsNullOrWhiteSpace($item.ModelDesc)) {
            Write-Host "  $($item.ModelDesc)" -ForegroundColor DarkGray
        } else {
            Write-Host ""
        }
        $counter++
    }

    Write-Host ""
    Write-Rule
    Write-Host "  [U]  Update model lists from provider APIs" -ForegroundColor Green
    Write-Host "  [S]  Settings (reorder, toggle, default model)" -ForegroundColor Yellow
    Write-Host "  [0]  Exit" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Tip: If API errors occur after model selection, run:" -ForegroundColor DarkGray
    Write-Host "  powershell -ExecutionPolicy Bypass -File \"D:\AI\Claude code workspace\Claude_launcher\setup.ps1\"" -ForegroundColor DarkGray
    Write-Host ""

    return $items
}

# ================================================================
# CLEAR ANTHROPIC ENV VARS
# ================================================================
function Clear-AnthropicEnv {
    $vars = @(
        "ANTHROPIC_BASE_URL","ANTHROPIC_AUTH_TOKEN","ANTHROPIC_API_KEY",
        "ANTHROPIC_MODEL","ANTHROPIC_SMALL_FAST_MODEL",
        "ANTHROPIC_DEFAULT_OPUS_MODEL","ANTHROPIC_DEFAULT_SONNET_MODEL",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC",
        "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS",
        "API_TIMEOUT_MS","CLAUDE_LAUNCHER_ACTIVE"
    )
    foreach ($v in $vars) {
        if (Test-Path "Env:\$v") { Remove-Item "Env:\$v" -ErrorAction SilentlyContinue }
    }
}

# ================================================================
# START CLAUDE SESSION
# ================================================================
function Start-ClaudeSession {
    param($Provider, [string]$ModelId)

    $cfg     = Read-Config
    $s       = $cfg.settings
    $fastMod = if ($Provider.PSObject.Properties["fast_model"] -and $Provider.fast_model) {
                   $Provider.fast_model
               } else { $ModelId }

    Clear-AnthropicEnv

    $env:ANTHROPIC_BASE_URL             = $Provider.base_url.TrimEnd("/")
    $env:ANTHROPIC_AUTH_TOKEN           = $Provider.api_key
    $env:ANTHROPIC_MODEL                = $ModelId
    $env:ANTHROPIC_SMALL_FAST_MODEL     = $fastMod
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL   = $ModelId
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $ModelId
    $env:ANTHROPIC_DEFAULT_HAIKU_MODEL  = $fastMod

    if ($Provider.PSObject.Properties["openrouter_mode"] -and $Provider.openrouter_mode -eq $true) {
        $env:ANTHROPIC_API_KEY = ""
    } elseif ($Provider.PSObject.Properties["anthropic_mode"] -and $Provider.anthropic_mode -eq $true) {
        $env:ANTHROPIC_API_KEY = $Provider.api_key
    } else {
        $env:ANTHROPIC_API_KEY = ""
    }

    $timeout = if ($s -and $s.PSObject.Properties["timeout_ms"]) { $s.timeout_ms } else { 300000 }
    $env:API_TIMEOUT_MS = "$timeout"

    if ($s -and $s.PSObject.Properties["disable_nonessential_traffic"] -and
        $s.disable_nonessential_traffic -eq $true) {
        $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
    }
    if ($s -and $s.PSObject.Properties["disable_experimental_betas"] -and
        $s.disable_experimental_betas -eq $true) {
        $env:CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS = "1"
    }

    $env:CLAUDE_LAUNCHER_ACTIVE = "1"

    # Save last selection for session-resume auto-inject
    Save-LastSelection -Provider $Provider -ModelId $ModelId

    Write-Host ""
    Write-Host "  +=========================================================+" -ForegroundColor Green
    Write-Host "  |  ACTIVE SESSION                                         |" -ForegroundColor Green
    Write-Host "  +=========================================================+" -ForegroundColor Green
    Write-Host "  Provider : $($Provider.name)" -ForegroundColor Yellow
    Write-Host "  Model    : $ModelId"           -ForegroundColor Cyan
    Write-Host "  Endpoint : $($env:ANTHROPIC_BASE_URL)" -ForegroundColor DarkGray
    Write-Host "  Timeout  : ${timeout}ms"       -ForegroundColor DarkGray
    Write-Rule
    Write-Host "  This window is isolated. Other windows can use different models." -ForegroundColor DarkGray
    Write-Host "  Starting Claude Code..." -ForegroundColor Green
    Write-Host ""

    $real = $Script:RealClaudePath
    if (-not $real -or -not (Test-Path $real)) {
        $real = Find-RealClaude -Silent
    }
    if (-not $real) {
        Write-Err "Real claude binary not found. Cannot start session."
        return
    }

    try {
        if ($PassthroughArgs -and $PassthroughArgs.Count -gt 0) {
            & $real @PassthroughArgs
        } else {
            & $real
        }
    } catch {
        Write-Err "Claude Code error: $_"
    }

    Write-Host ""
    Write-Rule
    Write-Info "Session ended. Cleaning up env vars for this window..."
    Clear-AnthropicEnv
    Write-OK "Done. You can select a new model or type [0] to exit."
}

# ================================================================
# MODEL FILTER FUNCTIONS
# ================================================================
function Get-FilteredModels {
    param(
        [string]$ProviderId,
        [string[]]$FetchedIds
    )

    switch ($ProviderId) {
        "kimi" {
            $FetchedIds = $FetchedIds | Where-Object {
                $_ -match "^kimi-k2\.5$" -or
                $_ -match "^kimi-k2$" -or
                $_ -match "^kimi-k2\.5-pro$" -or
                $_ -match "^kimi-k2-pro$"
            }
        }
        "minimax" {
            $FetchedIds = $FetchedIds | Where-Object {
                $_ -match "^MiniMax-M2\.5" -or
                $_ -match "^MiniMax-M2\.1" -or
                $_ -match "^MiniMax-M2$" -or
                $_ -match "^MiniMax-M1"
            }
        }
        "glm" {
            $FetchedIds = $FetchedIds | Where-Object {
                $_ -match "^glm-4\.\d+$" -or
                $_ -match "^glm-4\.5-air" -or
                $_ -match "^glm-4\.5" -or
                $_ -match "^glm-4-plus"
            }
        }
        "deepseek" {
            $FetchedIds = $FetchedIds | Where-Object {
                $_ -match "^deepseek-chat$" -or
                $_ -match "^deepseek-reasoner$" -or
                $_ -match "^deepseek-coder$" -or
                $_ -match "^deepseek-v3"
            }
        }
        "aliyun" {
            $FetchedIds = $FetchedIds | Where-Object {
                $_ -match "^qwen3" -and $_ -notmatch "^-"
            }
        }
        "anthropic" {
            $FetchedIds = $FetchedIds | Where-Object {
                $_ -match "^claude-opus" -or
                $_ -match "^claude-sonnet" -or
                $_ -match "^claude-haiku"
            }
        }
    }

    return @($FetchedIds | Select-Object -Unique)
}

# ================================================================
# UPDATE MODEL LIST FROM PROVIDER APIS
# ================================================================
function Update-ModelList {
    param($Config, [string]$SingleProviderId = "")

    Write-Host ""
    Write-Host "  Fetching model lists from provider APIs..." -ForegroundColor Cyan
    Write-Rule
    Write-Host ""

    $anyUpdated = $false

    foreach ($p in $Config.providers) {
        if ($SingleProviderId -and $p.id -ne $SingleProviderId) { continue }

        $key = if ($p.api_key) { $p.api_key.Trim() } else { "" }
        if ([string]::IsNullOrWhiteSpace($key)) {
            Write-Info "Skip $($p.name) - no API key"
            continue
        }
        $modelsApi = if ($p.PSObject.Properties["models_api"]) { $p.models_api } else { "" }
        if ([string]::IsNullOrWhiteSpace($modelsApi)) {
            Write-Info "Skip $($p.name) - no models_api endpoint"
            continue
        }

        Write-Host "  Querying $($p.name)... " -ForegroundColor White -NoNewline

        try {
            $hdrs = @{ "Content-Type" = "application/json" }
            $authType = if ($p.PSObject.Properties["auth_type"]) { $p.auth_type } else { "Bearer" }
            if ($authType -eq "x-api-key") {
                $hdrs["x-api-key"]         = $p.api_key
                $hdrs["anthropic-version"] = "2023-06-01"
            } else {
                $hdrs["Authorization"] = "Bearer $($p.api_key)"
            }

            $resp = Invoke-RestMethod -Uri $modelsApi `
                -Method Get -Headers $hdrs -TimeoutSec 20 -ErrorAction Stop

            $rawList = @()
            if     ($resp.PSObject.Properties["data"])   { $rawList = $resp.data   }
            elseif ($resp.PSObject.Properties["models"]) { $rawList = $resp.models }
            elseif ($resp -is [array])                   { $rawList = $resp        }

            $fetchedIds = @(
                $rawList | ForEach-Object {
                    if ($_.PSObject.Properties["id"]) { $_.id }
                    elseif ($_ -is [string]) { $_ }
                } | Where-Object { $_ } | Sort-Object
            )

            if ($fetchedIds.Count -eq 0) {
                Write-Host "no models parsed" -ForegroundColor DarkYellow
                continue
            }

            if ($p.id -eq "openrouter") {
                $existIds = @( $p.models | ForEach-Object {
                    if ($_.PSObject.Properties["id"]) { $_.id } else { [string]$_ }
                })
                $popular = $fetchedIds |
                    Where-Object { $_ -match "claude|gpt|gemini|deepseek|kimi|glm|qwen|mistral|llama" } |
                    Select-Object -First 40
                $fetchedIds = @($existIds + $popular) | Select-Object -Unique | Select-Object -First 50
            } else {
                $fetchedIds = Get-FilteredModels -ProviderId $p.id -FetchedIds $fetchedIds
            }

            $oldModels = $p.models
            $newModels = @(
                $fetchedIds | ForEach-Object {
                    $fid = $_
                    $old = $oldModels | Where-Object {
                        ($_.PSObject.Properties["id"] -and $_.id -eq $fid) -or
                        ($_ -is [string] -and $_ -eq $fid)
                    } | Select-Object -First 1

                    if ($old -and $old.PSObject.Properties["id"]) {
                        $old
                    } else {
                        [PSCustomObject]@{ id = $fid; desc = "" }
                    }
                }
            )

            $p.models   = $newModels
            $anyUpdated = $true
            Write-Host "$($fetchedIds.Count) models" -ForegroundColor Green

        } catch {
            Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host ""
    if ($anyUpdated) {
        Save-Config $Config
    } else {
        Write-Warn "Nothing updated."
    }
    Pause-Key
}

# ================================================================
# SETTINGS MENU
# ================================================================
function Show-SettingsMenu {
    while ($true) {
        $config = Read-Config

        Clear-Host
        Write-Host ""
        Write-Host "  +=========================================================+" -ForegroundColor Yellow
        Write-Host "  |                    SETTINGS                             |" -ForegroundColor Yellow
        Write-Host "  +=========================================================+" -ForegroundColor Yellow
        Write-Host ""
        Write-Info "Config file: $Script:ConfigPath"
        Write-Host ""
        Write-Host "  Current providers (in display order):" -ForegroundColor White
        Write-Host ""

        $idx = 1
        foreach ($p in $config.providers) {
            $enabled = $true
            if ($p.PSObject.Properties["enabled"]) { $enabled = $p.enabled -ne $false }
            $key      = if ($p.api_key) { $p.api_key.Trim() } else { "" }
            $hasKey   = -not [string]::IsNullOrWhiteSpace($key) -and $key -notmatch "^YOUR_|^PLACEHOLDER|^<"
            $modCount = if ($p.models) { $p.models.Count } else { 0 }

            $statusColor = if ($enabled -and $hasKey) { "Green" } elseif (-not $hasKey) { "DarkGray" } else { "Yellow" }
            $statusTxt   = if (-not $hasKey) { "no key" } elseif ($enabled) { "ON " } else { "OFF" }

            $n = $idx.ToString().PadLeft(2)
            Write-Host "  [$n] " -ForegroundColor White -NoNewline
            Write-Host "[$statusTxt] " -ForegroundColor $statusColor -NoNewline
            Write-Host "$($p.name)" -ForegroundColor Cyan -NoNewline
            Write-Host "  ($modCount models)" -ForegroundColor DarkGray
            $idx++
        }

        Write-Host ""
        Write-Rule
        Write-Host "  Enter a provider number to configure it, OR:" -ForegroundColor White
        Write-Host "  [Uxx]  Update models for provider xx  (e.g. U3)" -ForegroundColor Green
        Write-Host "  [U]    Update ALL provider model lists"           -ForegroundColor Green
        Write-Host "  [Mxx+] Move provider xx up   (e.g. M3+)"         -ForegroundColor DarkCyan
        Write-Host "  [Mxx-] Move provider xx down (e.g. M3-)"         -ForegroundColor DarkCyan
        Write-Host "  [E]    Open config in Notepad"                    -ForegroundColor Yellow
        Write-Host "  [B]    Back to main menu"                         -ForegroundColor DarkGray
        Write-Host ""

        Write-Host "  Settings> " -ForegroundColor Yellow -NoNewline
        $raw    = Read-Host
        $choice = $raw.Trim()

        if ($choice -match "^[Bb0]$") { return }

        if ($choice -match "^[Ee]$") {
            Start-Process notepad.exe $Script:ConfigPath
            Write-Info "Opened in Notepad. Save and close, then changes apply next menu refresh."
            Start-Sleep -Seconds 2
            continue
        }

        if ($choice -match "^[Uu]$") {
            $config = Read-Config
            Update-ModelList $config
            continue
        }

        if ($choice -match "^[Uu](\d+)$") {
            $pIdx = [int]$Matches[1] - 1
            if ($pIdx -ge 0 -and $pIdx -lt $config.providers.Count) {
                $config = Read-Config
                Update-ModelList $config -SingleProviderId $config.providers[$pIdx].id
            } else {
                Write-Warn "Invalid provider number."
                Start-Sleep -Seconds 1
            }
            continue
        }

        if ($choice -match "^[Mm](\d+)\+$") {
            $pIdx = [int]$Matches[1] - 1
            if ($pIdx -gt 0 -and $pIdx -lt $config.providers.Count) {
                $list = [System.Collections.ArrayList]$config.providers
                $item = $list[$pIdx]
                $list.RemoveAt($pIdx)
                $list.Insert($pIdx - 1, $item)
                $config.providers = $list.ToArray()
                Save-Config $config
                Write-OK "Moved up."
            } else {
                Write-Warn "Cannot move."
            }
            Start-Sleep -Seconds 1
            continue
        }

        if ($choice -match "^[Mm](\d+)-$") {
            $pIdx = [int]$Matches[1] - 1
            if ($pIdx -ge 0 -and $pIdx -lt ($config.providers.Count - 1)) {
                $list = [System.Collections.ArrayList]$config.providers
                $item = $list[$pIdx]
                $list.RemoveAt($pIdx)
                $list.Insert($pIdx + 1, $item)
                $config.providers = $list.ToArray()
                Save-Config $config
                Write-OK "Moved down."
            } else {
                Write-Warn "Cannot move."
            }
            Start-Sleep -Seconds 1
            continue
        }

        if ($choice -match "^\d+$") {
            $pIdx = [int]$choice - 1
            if ($pIdx -ge 0 -and $pIdx -lt $config.providers.Count) {
                Configure-Provider $config $pIdx
            } else {
                Write-Warn "Invalid number."
                Start-Sleep -Seconds 1
            }
            continue
        }

        Write-Warn "Unknown input: $choice"
        Start-Sleep -Seconds 1
    }
}

# ================================================================
# CONFIGURE SINGLE PROVIDER
# ================================================================
function Configure-Provider {
    param($Config, [int]$PIdx)

    while ($true) {
        $config = Read-Config
        $p      = $config.providers[$PIdx]

        $enabled  = $true
        if ($p.PSObject.Properties["enabled"]) { $enabled = $p.enabled -ne $false }
        $key      = if ($p.api_key) { $p.api_key.Trim() } else { "" }
        $hasKey   = -not [string]::IsNullOrWhiteSpace($key) -and $key -notmatch "^YOUR_|^PLACEHOLDER|^<"
        $fastMod  = if ($p.PSObject.Properties["fast_model"]) { $p.fast_model } else { "(not set)" }

        Clear-Host
        Write-Host ""
        Write-Host "  +=========================================================+" -ForegroundColor Yellow
        Write-Host "  |  Configure: $($p.name)" -ForegroundColor Yellow
        Write-Host "  +=========================================================+" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Enabled    : $(if ($enabled) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($enabled) { "Green" } else { "DarkGray" })
        Write-Host "  API Key    : $(if ($hasKey) { '*** (set)' } else { '(not set)' })" -ForegroundColor $(if ($hasKey) { "Green" } else { "Red" })
        Write-Host "  Base URL   : $($p.base_url)" -ForegroundColor DarkGray
        Write-Host "  Fast model : $fastMod" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Models:" -ForegroundColor White

        $mIdx = 1
        foreach ($m in $p.models) {
            $mId   = if ($m.PSObject.Properties["id"])   { $m.id   } else { [string]$m }
            $mDesc = if ($m.PSObject.Properties["desc"]) { $m.desc } else { "" }
            $isFast = $mId -eq $fastMod
            $tag    = if ($isFast) { " [fast]" } else { "" }
            Write-Host "    [$mIdx] $mId$tag" -ForegroundColor Cyan -NoNewline
            if ($mDesc) { Write-Host "  $mDesc" -ForegroundColor DarkGray } else { Write-Host "" }
            $mIdx++
        }

        Write-Host ""
        Write-Rule
        Write-Host "  [T]    Toggle enabled/disabled"                         -ForegroundColor Yellow
        Write-Host "  [Fxx]  Set model xx as fast/default model  (e.g. F2)"  -ForegroundColor DarkCyan
        Write-Host "  [U]    Update model list from API"                      -ForegroundColor Green
        Write-Host "  [B]    Back"                                            -ForegroundColor DarkGray
        Write-Host ""

        Write-Host "  Provider> " -ForegroundColor Yellow -NoNewline
        $choice = (Read-Host).Trim()

        if ($choice -match "^[Bb0]$") { return }

        if ($choice -match "^[Tt]$") {
            $p.enabled = -not $enabled
            Save-Config $config
            Write-OK "Provider $(if ($p.enabled) { 'enabled' } else { 'disabled' })."
            Start-Sleep -Seconds 1
            continue
        }

        if ($choice -match "^[Uu]$") {
            $config = Read-Config
            Update-ModelList $config -SingleProviderId $p.id
            continue
        }

        if ($choice -match "^[Ff](\d+)$") {
            $mIdxSel = [int]$Matches[1] - 1
            if ($mIdxSel -ge 0 -and $mIdxSel -lt $p.models.Count) {
                $selModel = $p.models[$mIdxSel]
                $selId    = if ($selModel.PSObject.Properties["id"]) { $selModel.id } else { [string]$selModel }
                $p.fast_model = $selId
                Save-Config $config
                Write-OK "Fast/default model set to: $selId"
            } else {
                Write-Warn "Invalid model number."
            }
            Start-Sleep -Seconds 1
            continue
        }

        Write-Warn "Unknown input: $choice"
        Start-Sleep -Seconds 1
    }
}

# ================================================================
# MAIN LOOP
# ================================================================
function Main {
    Test-Prerequisites

    while ($true) {
        $config = Read-Config
        $items  = Show-Menu $config

        Write-Host "  Select: " -ForegroundColor White -NoNewline
        $choice = (Read-Host).Trim()

        switch -Regex ($choice.ToLower()) {

            "^0$" {
                Write-Host ""
                Write-Info "Exiting launcher."
                exit 0
            }

            "^s$" {
                Show-SettingsMenu
            }

            "^u$" {
                $config = Read-Config
                Update-ModelList $config
            }

            "^\d+$" {
                $idx = [int]$choice - 1
                if ($items -and $idx -ge 0 -and $idx -lt $items.Count) {
                    Start-ClaudeSession -Provider $items[$idx].Provider -ModelId $items[$idx].ModelId
                    Pause-Key
                } else {
                    Write-Warn "Invalid choice [$choice]"
                    Start-Sleep -Seconds 1
                }
            }

            default {
                if (-not [string]::IsNullOrWhiteSpace($choice)) {
                    Write-Warn "Unknown input [$choice]"
                    Start-Sleep -Seconds 1
                }
            }
        }
    }
}

Main
