@echo off
REM ============================================================================
REM BOOTSTRAP_WINDOWS.bat — Install make on Windows for argus-infra
REM
REM This script installs Chocolatey (if not present) and then installs make.
REM Run this as Administrator before running any make commands.
REM
REM Usage:
REM   Right-click > "Run as Administrator"
REM   OR from an Administrator Command Prompt:
REM     BOOTSTRAP_WINDOWS.bat
REM
REM After this completes, run:
REM   make install-tools
REM ============================================================================

echo ╔══════════════════════════════════════╗
echo ║   Argus Infra — Windows Bootstrap    ║
echo ╚══════════════════════════════════════╝
echo.

REM Check if running as Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] This script must be run as Administrator.
    echo         Right-click BOOTSTRAP_WINDOWS.bat and select "Run as administrator".
    pause
    exit /b 1
)

echo [INFO] Checking for Chocolatey...
where choco >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Chocolatey not found. Installing Chocolatey...
    echo [INFO] This may take a few minutes...
    @"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
    if %errorLevel% neq 0 (
        echo [ERROR] Failed to install Chocolatey.
        echo         Please install manually: https://chocolatey.org/install
        pause
        exit /b 1
    )
    echo [OK] Chocolatey installed.
) else (
    echo [OK] Chocolatey already installed.
)

echo [INFO] Installing make via Chocolatey...
choco install make -y
if %errorLevel% neq 0 (
    echo [ERROR] Failed to install make via Chocolatey.
    pause
    exit /b 1
)

echo.
echo [OK] make installed successfully!
echo.
echo Next steps:
echo   1. Close and reopen your terminal (or run: refreshenv)
echo   2. Run: make install-tools
echo.
pause
