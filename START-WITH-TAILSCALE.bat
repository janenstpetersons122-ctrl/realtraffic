@echo off
setlocal EnableDelayedExpansion

cd /d "%~dp0"
title RealTraffic Tailscale Funnel

echo.
echo ============================================================
echo   RealTraffic - Tailscale Funnel Setup
echo ============================================================
echo.

REM ---- Step 1: Tailscale path check ----
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
        pause
        exit /b 1
    )
)
echo [1/5] Tailscale found.

REM ---- Step 2: Check Tailscale connection (NO hanging tailscale up) ----
echo [2/5] Tailscale connection check kar rahe hain...
set /a tries=0
:wait_loop
set /a tries+=1
"%TAILSCALE_EXE%" status >nul 2>nul
if not errorlevel 1 goto connected
if %tries% GEQ 5 goto not_connected
timeout /t 2 /nobreak >nul
goto wait_loop

:not_connected
echo.
echo [X] Tailscale "Starting..." pe stuck hai ya connected nahi.
echo.
echo  FIX (admin CMD me ye 2 commands chalao):
echo     net stop Tailscale
echo     net start Tailscale
echo.
echo  Phir:
echo   1. Start menu se "Tailscale" search karke open karo
echo   2. 30 sec wait karo
echo   3. Tray icon par right-click - "Connect" dikhe to click karo
echo   4. Phir is BAT ko dobara chalao
echo.
pause
exit /b 1

:connected
echo [3/5] Tailscale connected.

REM ---- Step 3: Get Tailscale URL ----
set "TS_URL="
for /f "delims=" %%h in ('powershell -NoProfile -Command "(& '%TAILSCALE_EXE%' status --json ^| ConvertFrom-Json).Self.DNSName -replace '\.$',''"') do set "TS_URL=%%h"

if "%TS_URL%"=="" (
    echo [X] Tailscale URL detect nahi ho saki.
    echo     Manually run: tailscale status
    pause
    exit /b 1
)
echo [4/5] URL: https://%TS_URL%

REM ---- Step 4: Configure Funnel ----
echo [5/5] Funnel configure...

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
