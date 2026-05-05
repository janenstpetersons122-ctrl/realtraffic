@echo off
:: ═══════════════════════════════════════════════════════════════
::  RealTraffic — UNINSTALL / Clean Shutdown
:: ═══════════════════════════════════════════════════════════════
::  Ye file sirf realtraffic project ke containers + volumes hataegi.
::  Aapke baaki Docker projects safe rahenge.

setlocal
title RealTraffic — Uninstall

echo.
echo  ⚠️  RealTraffic Uninstall
echo.
echo  Ye kya karega:
echo    • realtraffic-backend container stop + remove
echo    • realtraffic-mongo container stop + remove
echo    • realtraffic-cloudflared container stop + remove ^(if running^)
echo    • Saari user data ^(DB, uploads, screenshots, UA batches^) DELETE
echo.
echo  Aapka doosra Docker project bilkul SAFE rahega.
echo.
set /p confirm="Aap sure ho? [yes/no]: "
if /i not "%confirm%"=="yes" (
    echo Cancelled.
    pause
    exit /b 0
)

cd /d "%~dp0"

echo.
echo  Stopping + removing containers...
docker compose -p realtraffic -f docker-compose.yml down -v --remove-orphans

echo.
echo  ✅ Done. Saara RealTraffic data hata diya gaya.
echo.
echo  Dobara install karne ke liye: INSTALL.bat chalao.
echo.
pause
endlocal
