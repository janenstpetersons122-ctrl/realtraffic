@echo off
chcp 65001 >nul 2>&1
:: ══════════════════════════════════════════════════════════════════════
::  RealTraffic - START WITH TAILSCALE FUNNEL (auto-locate edition)
:: ══════════════════════════════════════════════════════════════════════

setlocal ENABLEDELAYEDEXPANSION

cd /d "%~dp0"
title RealTraffic - Tailscale Funnel Mode

echo.
echo  ============================================================
echo       RealTraffic - Public Access via Tailscale Funnel
echo       Forever-free, stable URL. No router. No CGNAT issues.
echo  ============================================================
echo.

:: ---- Auto-locate .env (current folder OR parent OR known paths) ----
set "ENV_FILE="
if exist "%~dp0.env"            set "ENV_FILE=%~dp0.env"
if not defined ENV_FILE if exist "%~dp0..\\.env"          set "ENV_FILE=%~dp0..\\.env"
if not defined ENV_FILE if exist "F:\online\RealTraffic\.env" set "ENV_FILE=F:\online\RealTraffic\.env"
if not defined ENV_FILE if exist "C:\RealTraffic\.env"    set "ENV_FILE=C:\RealTraffic\.env"
if not defined ENV_FILE if exist "%USERPROFILE%\RealTraffic\.env" set "ENV_FILE=%USERPROFILE%\RealTraffic\.env"

if not defined ENV_FILE (
    echo  [!] .env file nahi mili — defaults use kar raha hu.
    echo      Agar baad me admin password chahiye to .env me dekho.
    set "TUNNEL_PORT=8080"
    set "ADMIN_PASS=^(check .env file^)"
) else (
    echo  [OK] .env mil gayi: !ENV_FILE!
    set "TUNNEL_PORT=8080"
    set "ADMIN_PASS="
    for /f "usebackq tokens=1,* delims==" %%a in ("!ENV_FILE!") do (
        if "%%a"=="ADMIN_PASSWORD"   set "ADMIN_PASS=%%b"
        if "%%a"=="TUNNEL_HOST_PORT" set "TUNNEL_PORT=%%b"
    )
)

:: ---- Check Tailscale ----
echo.
echo  [1/4] Tailscale check...
where tailscale >nul 2>&1
if errorlevel 1 (
    echo  [X] Tailscale install nahi hai.
    echo      Install: https://tailscale.com/download/windows
    echo      Phir is file ko dobara chalao.
    pause & exit /b 1
)
tailscale status >nul 2>&1
if errorlevel 1 (
    echo  [X] Tailscale logged in nahi hai. System tray icon kholke "Log in".
    pause & exit /b 1
)
echo      OK.

:: ---- Get Tailscale URL ----
echo.
echo  [2/4] Aapki Tailscale URL pata kar raha hu...
set "TS_HOSTNAME="
for /f "usebackq delims=" %%h in (`powershell -NoProfile -Command "(tailscale status --json 2^>$null ^| ConvertFrom-Json).Self.DNSName -replace '\.$',''"`) do set "TS_HOSTNAME=%%h"
if "!TS_HOSTNAME!"=="" (
    echo  [X] Tailscale hostname detect nahi ho saka.
    pause & exit /b 1
)
echo      URL: https://!TS_HOSTNAME!

:: ---- Docker containers ----
echo.
echo  [3/4] Docker containers check...
docker info >nul 2>&1
if errorlevel 1 (
    echo  [X] Docker Desktop CHAL NAHI RAHA. Kholo aur dobara try karo.
    pause & exit /b 1
)

:: Check if frontend is running on TUNNEL_PORT
docker ps --filter "name=realtraffic-frontend" --filter "status=running" --format "{{.Names}}" | findstr realtraffic-frontend >nul 2>&1
if errorlevel 1 (
    echo      Containers chal nahi rahe — start kar raha hu...
    if defined ENV_FILE (
        pushd "!ENV_FILE!\.."
        docker compose -p realtraffic -f docker-compose.yml up -d
        popd
    ) else (
        docker compose -p realtraffic -f docker-compose.yml up -d
    )
    timeout /t 25 /nobreak >nul
) else (
    echo      OK — containers chal rahe hain.
)

:: ---- Configure Tailscale Funnel ----
echo.
echo  [4/4] Tailscale Funnel configure...
tailscale funnel reset >nul 2>&1
tailscale serve reset >nul 2>&1

echo      Forwarding: https://!TS_HOSTNAME!  --^>  http://localhost:!TUNNEL_PORT!
tailscale funnel --bg --https=443 http://localhost:!TUNNEL_PORT!
if errorlevel 1 (
    echo.
    echo  [!] Funnel setup failed. Wajah:
    echo       Funnel feature aapki machine ke liye allow nahi.
    echo       Fix:  https://login.tailscale.com/admin/acls/file
    echo             aur ye paste karo:
    echo.
    echo       {
    echo          "acls": [{"action":"accept","src":["*"],"dst":["*:*"]}],
    echo          "nodeAttrs":[{"target":["*"],"attr":["funnel"]}]
    echo       }
    echo.
    echo       Save karke is BAT ko dobara chalao.
    pause & exit /b 1
)

:: Save URL to file
> "%~dp0tunnel-url.txt" echo App URL:    https://!TS_HOSTNAME!
>>"%~dp0tunnel-url.txt" echo Admin URL:  https://!TS_HOSTNAME!/admin
>>"%~dp0tunnel-url.txt" echo Generated:  %date% %time%

echo.
echo.
echo  ============================================================
echo                ##  TAILSCALE FUNNEL ACTIVE  ##
echo  ============================================================
echo.
echo  Containers:
docker ps --filter "name=realtraffic-" --format "    {{.Names}}  {{.Status}}"
echo.
echo  PUBLIC APP URL (kahin se bhi access):
echo.
echo       https://!TS_HOSTNAME!
echo.
echo  Admin Login:
echo       URL:      https://!TS_HOSTNAME!/admin
echo       Email:    admin@realtraffic.local
echo       Password: !ADMIN_PASS!
echo.
echo  URL `tunnel-url.txt` me bhi save ho gayi hai.
echo.
pause
endlocal
