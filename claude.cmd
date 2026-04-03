@echo off
setlocal EnableDelayedExpansion

set "LAUNCHER_DIR=%~dp0"
set "LAUNCHER_DIR=%LAUNCHER_DIR:~0,-1%"

:: Check first argument
set "FIRST=%~1"

:: If no arguments, run launcher
if "%FIRST%"=="" goto run_launcher

:: Strip leading dash(s)
set "ARG=%FIRST%"
if "%ARG:~0,2%"=="--" set "ARG=%ARG:~2%"
if "%ARG:~0,1%"=="-" set "ARG=%ARG:~1%"

:: Pure local commands that bypass launcher - call real claude directly
:: These are used by VSCode extension for auth/status checks
set "IS_LOCAL=0"
if /i "%ARG%"=="version" set IS_LOCAL=1
if /i "%ARG%"=="v"       set IS_LOCAL=1
if /i "%ARG%"=="help"    set IS_LOCAL=1
if /i "%ARG%"=="h"       set IS_LOCAL=1

if "%IS_LOCAL%"=="1" goto call_real_claude

:run_launcher
endlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude_launcher.ps1" %*
exit /b %ERRORLEVEL%

:call_real_claude
:: Find real claude - skip our launcher directory
:: FIX: use "claude" (finds claude.cmd) not "claude.exe" (never found on Windows npm)
for /f "delims=" %%P in ('where claude 2^>nul') do (
    set "C=%%P"
    echo !C! | findstr /i /c:"Claude_launcher" >nul
    if errorlevel 1 (
        endlocal
        "%%P" %*
        exit /b %ERRORLEVEL%
    )
)
:: Fallback: check standard Windows npm global location directly
if exist "%APPDATA%\npm\claude.cmd" (
    endlocal
    "%APPDATA%\npm\claude.cmd" %*
    exit /b %ERRORLEVEL%
)
if exist "%USERPROFILE%\AppData\Roaming\npm\claude.cmd" (
    endlocal
    "%USERPROFILE%\AppData\Roaming\npm\claude.cmd" %*
    exit /b %ERRORLEVEL%
)
echo [Launcher] claude not found. Run: npm install -g @anthropic-ai/claude-code
exit /b 1
endlocal
