@echo off
setlocal

cd /d "%~dp0"
title RealTraffic Tailscale Funnel

echo.
echo ============================================================
echo   RealTraffic - Tailscale Funnel Setup
echo ============================================================
echo.

REM ---- Step 1: Tailscale path check (handle PATH not refreshed after install) ----
set "TAILSCALE_EXE=tailscale"
where tailscale >nul 2>nul
if errorlevel 1 (
    if exist "C:\Program Files\Tailscale\tailscale.exe" (
        set "TAILSCALE_EXE=C:\Program Files\Tailscale\tailscale.exe"
    ) else if exist "C:\Program Files (x86)\Tailscale\tailscale.exe" (
        set "TAILSCALE_EXE=C:\Program Files (x86)\Tailscale\tailscale.exe"
    ) else (
        echo [X] Tailscale install nahi mila.
        echo     Install: https://tailscale.com/download/windows
        echo     Install ke baad CMD band karke nayi CMD kholo, phir ye file chalao.
        pause
        exit /b 1
    )
)

echo [1/4] Tailscale found.

REM ---- Step 2: Tailscale login check ----
"%TAILSCALE_EXE%" status >nul 2>nul
if errorlevel 1 (
    echo [X] Tailscale logged in nahi.
    echo     System tray me icon par right-click - Log in - Google se sign in.
    pause
    exit /b 1
)
echo [2/4] Tailscale logged in.

REM ---- Step 3: Get Tailscale URL ----
set "TS_URL="
for /f "tokens=2 delims= " %%a in ('"%TAILSCALE_EXE%" status ^| findstr /C:"Self"') do set "TS_HOST=%%a"
for /f "delims=" %%h in ('powershell -NoProfile -Command "(& '%TAILSCALE_EXE%' status --json ^| ConvertFrom-Json).Self.DNSName -replace '\.$',''"') do set "TS_URL=%%h"

if "%TS_URL%"=="" (
    echo [X] Tailscale URL detect nahi ho saki.
    echo     Manually run: tailscale status
    pause
    exit /b 1
)
echo [3/4] URL: https://%TS_URL%

REM ---- Step 4: Configure Funnel ----
echo [4/4] Funnel configure...

"%TAILSCALE_EXE%" funnel reset >nul 2>nul
"%TAILSCALE_EXE%" serve reset >nul 2>nul

"%TAILSCALE_EXE%" funnel --bg --https=443 http://localhost:8080
if errorlevel 1 (
    echo.
    echo [!] Funnel setup failed. Solution:
    echo     1. https://login.tailscale.com/admin/acls/file open karo
    echo     2. Saara content delete karke ye paste karo:
    echo.
    echo     {
    echo       "acls": [{"action":"accept","src":["*"],"dst":["*:*"]}],
    echo       "nodeAttrs": [{"target":["*"],"attr":["funnel"]}]
    echo     }
    echo.
    echo     3. Save karke is BAT ko phir chalao.
    pause
    exit /b 1
)

REM ---- Save URL to file ----
echo App URL:    https://%TS_URL%       > "%~dp0tunnel-url.txt"
echo Admin URL:  https://%TS_URL%/admin >> "%~dp0tunnel-url.txt"

REM ---- Get admin password from .env ----
set "ADMIN_PASS=(check .env file)"
if exist "%~dp0.env" (
    for /f "tokens=1,* delims==" %%a in ('findstr /B "ADMIN_PASSWORD=" "%~dp0.env"') do set "ADMIN_PASS=%%b"
)

echo.
echo.
echo ============================================================
echo                 ## TAILSCALE FUNNEL ACTIVE ##
echo ============================================================
echo.
echo   PUBLIC URL ( kahin se bhi access ):
echo.
echo        https://%TS_URL%
echo.
echo   Admin Login:
echo        URL:      https://%TS_URL%/admin
echo        Email:    admin@realtraffic.local
echo        Password: %ADMIN_PASS%
echo.
echo   URL bhi tunnel-url.txt me save ho gayi.
echo.
pause
endlocal
