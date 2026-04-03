#Requires -Version 5.1
# setup.ps1 - PATH setup/repair tool for Claude Code Launcher
# Run with: powershell -ExecutionPolicy Bypass -File setup.ps1
# v3.4: Added cleanup of stale PATH entries (old paths with spaces)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$ScriptDir = $ScriptDir.TrimEnd("\")

Write-Host ""
Write-Host "  +-----------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   Claude Code Launcher - Setup / Repair       |" -ForegroundColor Cyan
Write-Host "  +-----------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Launcher folder: $ScriptDir" -ForegroundColor Yellow
Write-Host ""

# Check claude.cmd exists
if (-not (Test-Path (Join-Path $ScriptDir "claude.cmd"))) {
    Write-Host "  [X] claude.cmd not found in: $ScriptDir" -ForegroundColor Red
    Write-Host "      Make sure all launcher files are in the same folder." -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

# Read current user PATH
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$paths    = $userPath -split ";" | ForEach-Object { $_.TrimEnd("\") } | Where-Object { $_ -ne "" }

# ----------------------------------------------------------------
# Step 1: Detect stale launcher entries (other Claude_launcher dirs)
# ----------------------------------------------------------------
$stalePaths = $paths | Where-Object {
    $_ -imatch "Claude_launcher" -and ($_ -ine $ScriptDir)
}

if ($stalePaths) {
    Write-Host "  [!] Found stale PATH entries from old launcher location(s):" -ForegroundColor Yellow
    foreach ($s in $stalePaths) {
        Write-Host "      $s" -ForegroundColor DarkGray
    }
    Write-Host ""
    $clean = Read-Host "  Remove stale entries? [Y/N]"
    if ($clean -match "^[Yy]") {
        $paths = $paths | Where-Object { $_ -inotmatch "Claude_launcher" }
        Write-Host "  [OK] Stale entries removed." -ForegroundColor Green
        Write-Host ""
    }
}

# ----------------------------------------------------------------
# Step 2: Ensure current ScriptDir is in PATH at the FRONT
# ----------------------------------------------------------------
$already = $paths | Where-Object { $_ -ieq $ScriptDir }

if ($already) {
    Write-Host "  [OK] Launcher directory already in PATH." -ForegroundColor Green
    # Ensure it is first (in case npm dir appears before it)
    $otherPaths = $paths | Where-Object { $_ -ine $ScriptDir }
    $orderedPaths = @($ScriptDir) + $otherPaths
} else {
    Write-Host "  [+] Adding launcher directory to front of PATH..." -ForegroundColor Cyan
    $otherPaths   = $paths
    $orderedPaths = @($ScriptDir) + $otherPaths
}

# ----------------------------------------------------------------
# Step 3: Write new PATH to registry
# ----------------------------------------------------------------
$newPath = $orderedPaths -join ";"
[Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
Write-Host "  [OK] PATH updated." -ForegroundColor Green
Write-Host ""

# ----------------------------------------------------------------
# Step 4: Verify real claude is findable
# ----------------------------------------------------------------
Write-Host "  Checking for real claude binary..." -ForegroundColor White

$npmCandidates = @(
    "$env:APPDATA\npm\claude.cmd",
    "$env:APPDATA\npm\claude",
    "$env:USERPROFILE\AppData\Roaming\npm\claude.cmd"
)
$realClaudePath = $null
foreach ($c in $npmCandidates) {
    if ($c -and (Test-Path $c)) {
        $realClaudePath = $c
        break
    }
}

if ($realClaudePath) {
    Write-Host "  [OK] Real claude found: $realClaudePath" -ForegroundColor Green
} else {
    Write-Host "  [!] Claude Code not found in npm global bin." -ForegroundColor Yellow
    Write-Host "      Install with: npm install -g @anthropic-ai/claude-code" -ForegroundColor DarkGray
}

# ----------------------------------------------------------------
# Step 5: Verify config file
# ----------------------------------------------------------------
$configPath = Join-Path $ScriptDir "claude_config.json"
if (Test-Path $configPath) {
    Write-Host "  [OK] claude_config.json found." -ForegroundColor Green
} else {
    Write-Host "  [!] claude_config.json not found in: $ScriptDir" -ForegroundColor Yellow
    Write-Host "      Create it before using the launcher." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  Launcher PATH entries:" -ForegroundColor White
[Environment]::GetEnvironmentVariable("PATH","User") -split ";" | Select-String "Claude"
Write-Host ""
Write-Host "  IMPORTANT: Open a NEW terminal window for PATH changes to take effect." -ForegroundColor Yellow
Write-Host "  Then type  claude  to start the launcher." -ForegroundColor Cyan
Write-Host ""
Read-Host "  Press Enter to exit"
