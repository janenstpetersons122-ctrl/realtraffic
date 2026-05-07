@echo off
:: ══════════════════════════════════════════════════════════════════════
::  RealTraffic — RETRY BUILD (network-friendly)
:: ══════════════════════════════════════════════════════════════════════
::  Agar `INSTALL.bat` chalate waqt build fail ho gaya tha
::  (network timeout / pip download fail / yarn timeout) — to ye file
::  chalao. Ye:
::    • Existing .env aur configuration preserve karega (kuch nahi mitayega)
::    • Saare incomplete docker images saaf karega
::    • Build dobara start karega — pehle se faster (cached layers reuse)
::    • Containers up karega
:: ══════════════════════════════════════════════════════════════════════

setlocal ENABLEDELAYEDEXPANSION

cd /d "%~dp0"
title RealTraffic — Retry Build

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║              RealTraffic — Retry Build                       ║
echo  ║                                                              ║
echo  ║  Network timeout / partial build se recovery — apna kaam     ║
echo  ║  jahan se ruka tha wahan se aage badhega                     ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

if not exist "%~dp0.env" (
    echo  [X] .env file nahi mili. Pehle INSTALL.bat chalao.
    pause & exit /b 1
)

echo  [1/3] Adhoore docker builds saaf kar raha hu ^(images intact rahenge^)...
docker compose -p realtraffic -f docker-compose.yml down >nul 2>&1
docker builder prune -f >nul 2>&1
echo      OK.

echo.
echo  [2/3] Build dobara start kar raha hu...
echo       ^(slow internet pe pip + yarn ko 10 min tak retry milenge^)
docker compose -p realtraffic -f docker-compose.yml build
if errorlevel 1 (
    echo.
    echo  [X] Build phir fail hua. Common causes:
    echo       1. Internet bahut slow / unstable hai. Wifi / 4G / Ethernet
    echo          switch karke try karo.
    echo       2. Docker Desktop me memory kam hai — Settings ^> Resources
    echo          ^> Memory 6 GB+ ^> Apply.
    echo       3. PyPI / Docker Hub temporarily down. https://status.python.org
    echo          aur https://www.dockerstatus.com check karo.
    echo.
    echo       5-10 min wait karo, phir is RETRY-BUILD.bat ko phir chalao.
    pause & exit /b 1
)

echo.
echo  [3/3] Containers start kar raha hu...
docker compose -p realtraffic -f docker-compose.yml --profile ddns up -d
if errorlevel 1 (
    echo  [X] docker compose up failed.
    pause & exit /b 1
)

echo.
echo  ✅ Sab containers start ho gaye.
echo.
echo  Live status:
docker ps --filter "name=realtraffic-" --format "    {{.Names}}  {{.Status}}"
echo.
echo  Logs check karne ke liye:
echo    docker logs -f realtraffic-backend
echo    docker logs -f realtraffic-caddy
echo.
echo  App URL aur admin password .env file me hai:
findstr /B /C:"BACKEND_DOMAIN=" /C:"ADMIN_PASSWORD=" "%~dp0.env"
echo.
pause
endlocal
