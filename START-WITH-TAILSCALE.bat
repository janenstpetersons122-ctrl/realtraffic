@echo off
:: ══════════════════════════════════════════════════════════════════════
::  RealTraffic — START WITH TAILSCALE FUNNEL (no router needed)
:: ══════════════════════════════════════════════════════════════════════
::  Stable public URL via Tailscale Funnel.  Forever free.
::
::  Pre-requisites (one-time, ~5 min):
::    1. Tailscale install: https://tailscale.com/download/windows
::    2. Login (Google / Microsoft / GitHub) — free account
::    3. Funnel feature enable: https://login.tailscale.com/admin/dns
::       (Tailnet name → Edit → choose simple name like "realtraffic")
::    4. Funnel ACL: admin → DNS → "Funnel" tab → enable for your machine
::
::  Phir is file ko double-click karo.
:: ══════════════════════════════════════════════════════════════════════

setlocal ENABLEDELAYEDEXPANSION

cd /d "%~dp0"
title RealTraffic — Tailscale Funnel Mode

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║      RealTraffic — Public Access via Tailscale Funnel        ║
echo  ║                                                              ║
echo  ║   Forever-free, stable URL. No router. No CGNAT issues.      ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

:: ─── [1/5] Pre-flight checks ──────────────────────────────────────────
echo  [1/5] Pre-flight checks...

if not exist "%~dp0.env" (
    echo  [X] .env file nahi mili. Pehle INSTALL.bat chalao.
    pause & exit /b 1
)

where tailscale >nul 2>&1
if errorlevel 1 (
    echo.
    echo  [X] Tailscale install nahi hai PC pe.
    echo.
    echo      ─── Install kaise karein ─────────────────────────────────
    echo      1. Open: https://tailscale.com/download/windows
    echo      2. "Download" button click karo, .exe download hoga
    echo      3. Installer chalao, "Next" -^> "Install"
    echo      4. Install ke baad system tray ^(niche right corner^) me
    echo         Tailscale icon dikhega
    echo      5. Right-click icon -^> "Log in" -^> Google se sign in karo
    echo      6. Phir is BAT file ko dobara chalao
    echo      ─────────────────────────────────────────────────────────
    echo.
    pause & exit /b 1
)

echo      OK — Tailscale CLI mil gayi.

tailscale status >nul 2>&1
if errorlevel 1 (
    echo.
    echo  [X] Tailscale logged in nahi hai.
    echo      System tray me Tailscale icon -^> Right-click -^> "Log in"
    echo      Google se login karo, phir is file ko dobara chalao.
    pause & exit /b 1
)

echo      OK — Tailscale logged in.

docker info >nul 2>&1
if errorlevel 1 (
    echo  [X] Docker Desktop CHAL NAHI RAHA. Start Menu se Docker Desktop kholo.
    pause & exit /b 1
)
echo      OK — Docker running.

:: ─── [2/5] Get Tailscale machine info ─────────────────────────────────
echo.
echo  [2/5] Tailscale machine info pata kar raha hu...

set "TS_HOSTNAME="
for /f "usebackq delims=" %%h in (`powershell -NoProfile -Command "(tailscale status --json 2>$null | ConvertFrom-Json).Self.DNSName -replace '\.$',''"`) do set "TS_HOSTNAME=%%h"

if "!TS_HOSTNAME!"=="" (
    echo  [X] Tailscale hostname detect nahi ho saka.
    echo      Run manually: tailscale status
    pause & exit /b 1
)

echo      OK — Tailscale URL: https://!TS_HOSTNAME!

:: ─── [3/5] Make sure Funnel is allowed for this machine ───────────────
echo.
echo  [3/5] Funnel feature check ^(machine must be funnel-enabled^)...
echo      Agar "permission denied" aaye:
echo        1. https://login.tailscale.com/admin/dns kholo
echo        2. "Funnel" tab par jao
echo        3. Apni machine select karke enable karo
echo.

:: ─── [4/5] Start Docker stack ─────────────────────────────────────────
echo  [4/5] Docker containers start kar raha hu...
docker compose -p realtraffic -f docker-compose.yml down >nul 2>&1
docker compose -p realtraffic -f docker-compose.yml up -d
if errorlevel 1 (
    echo  [X] docker compose up failed.
    pause & exit /b 1
)

echo      Wait ~30 sec for containers to be ready...
timeout /t 30 /nobreak >nul

:: ─── [5/5] Configure Tailscale Funnel ─────────────────────────────────
echo.
echo  [5/5] Tailscale Funnel configure kar raha hu...

:: Read host port for frontend
set "TUNNEL_PORT=8080"
for /f "usebackq tokens=1,* delims==" %%a in ("%~dp0.env") do (
    if "%%a"=="TUNNEL_HOST_PORT" set "TUNNEL_PORT=%%b"
)

:: Reset previous funnel config
tailscale funnel reset >nul 2>&1
tailscale serve reset >nul 2>&1

:: Set up funnel: HTTPS:443 → http://localhost:TUNNEL_PORT
echo      Forwarding: https://!TS_HOSTNAME! → http://localhost:!TUNNEL_PORT!
tailscale funnel --bg --https=443 http://localhost:!TUNNEL_PORT! 2>&1
if errorlevel 1 (
    echo.
    echo  [!] Funnel setup failed.  Aam reasons:
    echo       a^) Funnel feature is machine ke liye allowed nahi hai
    echo          → https://login.tailscale.com/admin/dns
    echo            → "Funnel" tab → machine enable karo
    echo       b^) Free plan ka quota khatam ^(rare^)
    echo.
    pause & exit /b 1
)

:: Save URL to file
> "%~dp0tunnel-url.txt" echo App URL:    https://!TS_HOSTNAME!
>>"%~dp0tunnel-url.txt" echo Admin URL:  https://!TS_HOSTNAME!/admin
>>"%~dp0tunnel-url.txt" echo Generated:  %date% %time%

set "ADMIN_PASS="
for /f "usebackq tokens=1,* delims==" %%a in ("%~dp0.env") do (
    if "%%a"=="ADMIN_PASSWORD" set "ADMIN_PASS=%%b"
)

echo.
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║              ✅ TAILSCALE FUNNEL ACTIVE!                     ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo  📦 Containers:
docker ps --filter "name=realtraffic-" --format "    {{.Names}}  {{.Status}}"
echo.
echo  🌍 PUBLIC APP URL ^(forever stable, kahin se bhi access^):
echo.
echo       https://!TS_HOSTNAME!
echo.
echo       ^(Saved in `tunnel-url.txt`^)
echo.
echo  🔐 Admin Login:
echo       Go to:    https://!TS_HOSTNAME!/admin
echo       Email:    admin@realtraffic.local
echo       Password: !ADMIN_PASS!
echo.
echo  💡 Tailnet name customize karna hai? ^(jaise "realtraffic"^):
echo       https://login.tailscale.com/admin/settings/general
echo       "Rename tailnet" se URL ban jayegi:
echo       https://your-pc.realtraffic.ts.net
echo.
echo  💡 Hostname customize:
echo       tailscale set --hostname=app
echo       Phir URL: https://app.your-tailnet.ts.net
echo.
echo  🛠️  Useful commands:
echo       tailscale status                       ^<- machine status
echo       tailscale funnel status                ^<- active funnels
echo       tailscale funnel reset                 ^<- stop funnel
echo       docker logs -f realtraffic-backend     ^<- backend logs
echo       type tunnel-url.txt                    ^<- saved URL
echo.
pause
endlocal
