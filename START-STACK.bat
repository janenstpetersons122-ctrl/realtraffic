@echo off
:: ══════════════════════════════════════════════════════════════════════
::  RealTraffic — START STACK (no rebuild, super fast)
:: ══════════════════════════════════════════════════════════════════════
::  Use cases:
::    • Build pehle se ho chuka hai, sirf containers (re)start karne hain
::    • docker-compose.yml me chhota change hua (jaise healthcheck fix)
::    • PC reboot ke baad jaldi se stack chalu karni hai
::
::  Ye REBUILD nahi karta — bas existing images se containers up karta hai.
::  ~30 sec me poora stack ready ho jata hai (vs 15 min full rebuild).
:: ══════════════════════════════════════════════════════════════════════

setlocal ENABLEDELAYEDEXPANSION

cd /d "%~dp0"
title RealTraffic — Start Stack

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║              RealTraffic — Start Stack                       ║
echo  ║       (no rebuild, just bring containers up)                 ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

if not exist "%~dp0.env" (
    echo  [X] .env file nahi mili. Pehle INSTALL.bat chalao.
    pause & exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
    echo  [X] Docker Desktop CHAL NAHI RAHA. Start Menu se Docker Desktop kholo.
    pause & exit /b 1
)

echo  [1/2] Old containers down kar raha hu (volumes safe rahenge)...
docker compose -p realtraffic -f docker-compose.yml down >nul 2>&1
echo      OK.

echo.
echo  [2/2] Containers up kar raha hu...
docker compose -p realtraffic -f docker-compose.yml --profile ddns up -d
if errorlevel 1 (
    echo  [X] docker compose up failed.
    echo      Logs check karo:  docker logs realtraffic-frontend
    pause & exit /b 1
)

echo.
echo  Wait kar raha hu (~30 sec) sab containers ready hone ke liye...
timeout /t 30 /nobreak >nul

echo.
echo  📦 Status:
docker ps --filter "name=realtraffic-" --format "    {{.Names}}  {{.Status}}"
echo.

echo  📋 Aapki config:
findstr /B /C:"BACKEND_DOMAIN=" /C:"ADMIN_EMAIL=" /C:"ADMIN_PASSWORD=" /C:"HTTP_PORT=" /C:"HTTPS_PORT=" "%~dp0.env"
echo.
echo  🛠️  Logs check karne ke liye:
echo       docker logs -f realtraffic-frontend    ^<- agar issue ho
echo       docker logs -f realtraffic-caddy       ^<- SSL / proxy
echo       docker logs -f realtraffic-backend     ^<- API errors
echo.
pause
endlocal
