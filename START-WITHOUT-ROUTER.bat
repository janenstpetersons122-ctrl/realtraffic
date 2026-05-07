@echo off
:: ══════════════════════════════════════════════════════════════════════
::  RealTraffic — START WITHOUT ROUTER (Cloudflare Tunnel mode)
:: ══════════════════════════════════════════════════════════════════════
::  Router admin panel access nahi hai? Port forward nahi kar sakte?
::  Koi baat nahi — Cloudflare Tunnel se direct deploy ho jayega.
::
::  Kaise kaam karta hai:
::    PC se Cloudflare ko OUTBOUND connection (regular browsing jaisa).
::    Public URL milegi: https://random-name.trycloudflare.com
::    Bilkul stable rahegi jab tak container chal raha hai.
::
::  Pre-requisites:
::    • Build pehle se ho chuka hai (INSTALL.bat run kiya tha)
::    • OR pehli baar chala rahe ho — sab images build karega
:: ══════════════════════════════════════════════════════════════════════

setlocal ENABLEDELAYEDEXPANSION

cd /d "%~dp0"
title RealTraffic — Cloudflare Tunnel Mode

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║       RealTraffic — Public Access via Cloudflare Tunnel      ║
echo  ║                                                              ║
echo  ║   No router port-forward needed. No DNS setup. No account.   ║
echo  ║   Bas outbound connection PC se Cloudflare ko jaati hai.     ║
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

echo  [1/3] Old containers down kar raha hu...
docker compose -p realtraffic -f docker-compose.yml down >nul 2>&1
echo      OK.

echo.
echo  [2/3] Containers + Cloudflare Tunnel start kar raha hu...
echo       (mongo + redis + backend + frontend + caddy + ddns + cloudflared)
docker compose -p realtraffic -f docker-compose.yml --profile ddns --profile tunnel up -d
if errorlevel 1 (
    echo  [X] docker compose up failed.
    pause & exit /b 1
)

echo.
echo  [3/3] Cloudflare Tunnel URL detect kar raha hu (~30 sec)...
timeout /t 25 /nobreak >nul

set "TUNNEL_URL="
:: Try up to 30 attempts to find the URL in cloudflared logs
set /a TRIES=0
:url_loop
set /a TRIES+=1
for /f "usebackq tokens=*" %%u in (`docker logs realtraffic-cloudflared 2^>^&1 ^| findstr /R /C:"https://[a-z0-9-]*\.trycloudflare\.com"`) do (
    for /f "tokens=2 delims= " %%a in ("%%u") do (
        echo %%a | findstr "trycloudflare.com" >nul && set "TUNNEL_URL=%%a"
    )
)
if defined TUNNEL_URL goto url_found
if !TRIES! geq 12 goto url_not_found
timeout /t 5 /nobreak >nul
echo | set /p="."
goto url_loop

:url_found
echo.
echo      OK — Tunnel URL: !TUNNEL_URL!

:: Save URL to file for future reference
> "%~dp0tunnel-url.txt" echo !TUNNEL_URL!
> "%~dp0tunnel-url.txt" echo Generated: %date% %time%
>>"%~dp0tunnel-url.txt" echo.
>>"%~dp0tunnel-url.txt" echo App URL:    !TUNNEL_URL!
>>"%~dp0tunnel-url.txt" echo Admin URL:  !TUNNEL_URL!/admin
goto print_summary

:url_not_found
echo.
echo  [!] Tunnel URL nahi mil saka. Manually check karo:
echo        docker logs realtraffic-cloudflared
echo      "https://...trycloudflare.com" wali line dhundo.
set "TUNNEL_URL=^(check `docker logs realtraffic-cloudflared` for URL^)"

:print_summary
echo.
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                  ✅ TUNNEL ACTIVE!                           ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

set "ADMIN_PASS="
for /f "usebackq tokens=1,* delims==" %%a in ("%~dp0.env") do (
    if "%%a"=="ADMIN_PASSWORD" set "ADMIN_PASS=%%b"
)

echo  📦 Containers:
docker ps --filter "name=realtraffic-" --format "    {{.Names}}  {{.Status}}"
echo.
echo  🌍 PUBLIC APP URL ^(use this to access from anywhere^):
echo.
echo       !TUNNEL_URL!
echo.
echo       (URL `tunnel-url.txt` me bhi save kar di hai aapke folder me)
echo.
echo  🔐 Admin Login:
echo       Go to:    !TUNNEL_URL!/admin
echo       Email:    admin@realtraffic.local
echo       Password: !ADMIN_PASS!
echo.
echo  ⚠️  Important Notes:
echo       1. URL random hai but stable — jab tak container chal raha hai
echo          ye URL kaam karega ^(weeks/months^).
echo       2. Agar `realtraffic-cloudflared` container restart ho jaye
echo          to URL CHANGE ho jayega. Naya URL `tunnel-url.txt` me save
echo          ho jayega.
echo       3. Jab tak Docker Desktop chal raha hai aur container UP hai,
echo          URL kaam karega.
echo.
echo  🛠️  Useful commands:
echo       docker logs realtraffic-cloudflared    ^<- tunnel logs / URL
echo       docker logs -f realtraffic-backend     ^<- backend logs
echo       type tunnel-url.txt                    ^<- saved URL
echo.
pause
endlocal
