@echo off
:: ══════════════════════════════════════════════════════════════════════
::  RealTraffic — ONE-CLICK INSTALL (Windows, FULL home-PC deploy)
:: ══════════════════════════════════════════════════════════════════════
::  100% aapke PC pe — frontend + backend + DB + SSL, sab yahan.
::  Sirf DuckDNS (free DNS pointer) bahir se — taki kahin se bhi access ho.
::  Vercel / Cloudflare / koi bhi external service — KUCH NAHI.
::
::  Aapko bas 1 cheez chahiye:
::    • DuckDNS account (FREE — 30 sec, GitHub se signup)
::
::  Yahi file:
::    • Docker stack build + start (mongo + redis + backend + frontend + caddy)
::    • Free SSL cert Let's Encrypt se (yourname.duckdns.org pe)
::    • DuckDNS me public IP auto-update (har 5 min)
::    • Final me admin password + port-forward instructions print
:: ══════════════════════════════════════════════════════════════════════

setlocal ENABLEDELAYEDEXPANSION

cd /d "%~dp0"
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

title RealTraffic — One-Click Install (full home-PC deploy)

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║              RealTraffic — Full Home-PC Install              ║
echo  ║                                                              ║
echo  ║  Frontend + Backend + DB + SSL — sab aapke PC pe             ║
echo  ║  Bahir se sirf DuckDNS (free DNS) — aur kuch nahi            ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

:: ─── [1/7] Docker check ───────────────────────────────────────────────
echo  [1/7] Docker Desktop check...
where docker >nul 2>&1
if errorlevel 1 (
    echo  [X] Docker installed nahi hai.
    echo      Install: https://www.docker.com/products/docker-desktop/
    echo      Phir is file ko dobara chalao.
    pause & exit /b 1
)
docker info >nul 2>&1
if errorlevel 1 (
    echo  [X] Docker Desktop CHAL NAHI RAHA. Start Menu se Docker Desktop kholo,
    echo      green "Running" indicator ka wait karo, phir is file ko chalao.
    pause & exit /b 1
)
for /f "tokens=*" %%v in ('docker --version') do echo      OK — %%v

:: ─── [2/7] Port 80 / 443 conflict check ──────────────────────────────
echo.
echo  [2/7] Port 80 / 443 conflict check...
set "PORT_CONFLICT="
for /f "tokens=*" %%a in ('netstat -ano ^| findstr /C:":80 " /C:":443 " ^| findstr "LISTENING"') do (
    set "PORT_CONFLICT=1"
    echo      [!] Port busy detected: %%a
)
if defined PORT_CONFLICT (
    echo.
    echo  [!!] Port 80 ya 443 pehle se kisi aur process/container me use ho raha hai.
    echo       Agar aap ye install jari rakhenge, Caddy start nahi ho payega.
    echo.
    echo       Fix options:
    echo         A) Us purane project ko stop karo
    echo         B) `docker ps` check karo — agar koi container 80/443 bind
    echo            kiye hai to uske alag port pe shift karo
    echo         C) Cancel karo — apne DevOps se puch lo
    echo.
    set /p CONTINUE="      Continue karna hai anyway? (y/N): "
    if /i not "!CONTINUE!"=="y" (
        echo      Cancelled.
        pause & exit /b 2
    )
) else (
    echo      OK — ports 80 + 443 free.
)

:: ─── [3/7] Configuration prompt (one-time) ────────────────────────────
echo.
echo  [3/7] Configuration check...

if exist "%ROOT%\.env" (
    echo      .env already exists — using saved configuration.
    goto :env_done
)

echo.
echo  ┌──────────────────────────────────────────────────────────────┐
echo  │  Pehli baar setup — bas 3 cheezein chahiye:                   │
echo  │                                                               │
echo  │  Phele DuckDNS account banao ^(free, 30 sec^):                 │
echo  │    1. https://www.duckdns.org open karo                       │
echo  │    2. "Sign in with GitHub" click karo                        │
echo  │    3. Top me "domain" field me apna name daalo                │
echo  │       Example: myrealtraffic                                  │
echo  │       ^(Aapka URL ban jayega: myrealtraffic.duckdns.org^)       │
echo  │    4. "add domain" button press karo                          │
echo  │    5. Top me "token" field ki jo long string dikhayi de,      │
echo  │       use copy karke rakhein                                  │
echo  │                                                               │
echo  │  Ab niche 3 cheez chahiye:                                    │
echo  └──────────────────────────────────────────────────────────────┘
echo.

:ask_subdomain
echo  Q1. DuckDNS subdomain ^(sirf naam, .duckdns.org NA likho^):
echo      Example: myrealtraffic
set "DUCKDNS_NAME="
set /p DUCKDNS_NAME="      Subdomain: "
if "!DUCKDNS_NAME!"=="" (
    echo      [!] Empty nahi rakh sakte. Try again.
    goto :ask_subdomain
)
set "BACKEND_DOMAIN=!DUCKDNS_NAME!.duckdns.org"
echo      OK — final URL: https://!BACKEND_DOMAIN!

echo.
:ask_token
echo  Q2. DuckDNS token ^(duckdns.org page ke top par dikhayi deta hai^)
echo      Example: 1a2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p
set "DUCKDNS_TOKEN="
set /p DUCKDNS_TOKEN="      Token: "
if "!DUCKDNS_TOKEN!"=="" (
    echo      [!] Empty nahi rakh sakte.
    goto :ask_token
)

echo.
:ask_email
echo  Q3. Email ^(Let's Encrypt SSL renewal warnings yahan aayenge^)
set "LE_EMAIL="
set /p LE_EMAIL="      Email: "
if "!LE_EMAIL!"=="" (
    echo      [!] Empty nahi rakh sakte.
    goto :ask_email
)

echo.
echo      Generating strong random secrets...
for /f "usebackq delims=" %%s in (`powershell -NoProfile -Command "[System.Web.Security.Membership]::GeneratePassword(48,6) -replace '[^a-zA-Z0-9]','x'"`) do set "JWT_SECRET=%%s"
for /f "usebackq delims=" %%s in (`powershell -NoProfile -Command "[System.Web.Security.Membership]::GeneratePassword(20,4) -replace '[^a-zA-Z0-9]','x'"`) do set "ADMIN_PASS=%%s"
for /f "usebackq delims=" %%s in (`powershell -NoProfile -Command "[System.Web.Security.Membership]::GeneratePassword(32,4) -replace '[^a-zA-Z0-9]','x'"`) do set "POSTBACK_TOKEN=%%s"

if not defined JWT_SECRET set "JWT_SECRET=rt-%RANDOM%%RANDOM%%RANDOM%-prod"
if not defined ADMIN_PASS set "ADMIN_PASS=rt%RANDOM%admin%RANDOM%"
if not defined POSTBACK_TOKEN set "POSTBACK_TOKEN=rt-pb-%RANDOM%%RANDOM%"

(
    echo # ─── RealTraffic auto-generated .env ─────────────────────────────
    echo # Generated on: %date% %time%
    echo.
    echo DB_NAME=realtraffic
    echo JWT_SECRET_KEY=!JWT_SECRET!
    echo POSTBACK_TOKEN=!POSTBACK_TOKEN!
    echo ADMIN_EMAIL=admin@realtraffic.local
    echo ADMIN_PASSWORD=!ADMIN_PASS!
    echo CORS_ORIGINS=*
    echo.
    echo # Backend public URL ^(via DuckDNS + Caddy auto-SSL^)
    echo BACKEND_DOMAIN=!BACKEND_DOMAIN!
    echo APP_URL=https://!BACKEND_DOMAIN!
    echo PUBLIC_BASE_URL=https://!BACKEND_DOMAIN!
    echo LE_EMAIL=!LE_EMAIL!
    echo.
    echo # DuckDNS auto-update
    echo DUCKDNS_NAME=!DUCKDNS_NAME!
    echo DUCKDNS_TOKEN=!DUCKDNS_TOKEN!
    echo.
    echo # Optional integrations
    echo RESEND_API_KEY=
    echo RESEND_FROM=no-reply@realtraffic.local
    echo GOOGLE_SHEETS_SA_PATH=/app/backend/secrets/gsheets-sa.json
    echo GOOGLE_SHEETS_SA_JSON=
    echo.
    echo # ─── Performance tuning (16 GB host defaults; edit if needed) ───
    echo UVICORN_WORKERS=4
    echo MONGO_MAX_POOL_SIZE=150
    echo MONGO_MIN_POOL_SIZE=20
    echo MONGO_MAX_IDLE_TIME_MS=30000
    echo HEAVY_JOB_CONCURRENCY=8
    echo.
    echo # ─── Sentry monitoring (optional — paste DSN to enable) ──────────
    echo SENTRY_DSN=
    echo SENTRY_ENVIRONMENT=production
    echo SENTRY_RELEASE=realtraffic@latest
    echo SENTRY_TRACES_SAMPLE_RATE=0.05
) > "%ROOT%\.env"

echo      OK — .env saved with strong random JWT + admin password.

:env_done

set "ADMIN_PASS="
set "BACKEND_DOMAIN="
set "DUCKDNS_NAME="
set "DUCKDNS_TOKEN="
for /f "usebackq tokens=1,* delims==" %%a in ("%ROOT%\.env") do (
    if "%%a"=="ADMIN_PASSWORD" set "ADMIN_PASS=%%b"
    if "%%a"=="BACKEND_DOMAIN" set "BACKEND_DOMAIN=%%b"
    if "%%a"=="DUCKDNS_NAME" set "DUCKDNS_NAME=%%b"
    if "%%a"=="DUCKDNS_TOKEN" set "DUCKDNS_TOKEN=%%b"
)

if not exist "%ROOT%\backend\secrets" mkdir "%ROOT%\backend\secrets" >nul 2>&1
if not exist "%ROOT%\ddns-config" mkdir "%ROOT%\ddns-config" >nul 2>&1

:: ─── [4/7] Write DuckDNS updater config ───────────────────────────────
echo.
echo  [4/7] DuckDNS config likh raha hu...

(
    echo {
    echo   "settings": [
    echo     {
    echo       "provider": "duckdns",
    echo       "domain": "!BACKEND_DOMAIN!",
    echo       "token": "!DUCKDNS_TOKEN!",
    echo       "ip_version": "ipv4"
    echo     }
    echo   ]
    echo }
) > "%ROOT%\ddns-config\config.json"
echo      OK — DuckDNS will keep IP synced every 5 min.

:: ─── [5/7] Build Docker images ────────────────────────────────────────
echo.
echo  [5/7] Building Docker images... ^(pehli baar 10-15 min^)
echo       ^(backend + frontend + custom Caddy — Go xcaddy compile kar raha^)
docker compose -p realtraffic -f docker-compose.yml build
if errorlevel 1 (
    echo  [X] Build failed.
    echo      Fix: Docker Desktop ^> Settings ^> Resources ^> Memory 6GB+ ^> Apply
    pause & exit /b 1
)

:: ─── [6/7] Start containers ───────────────────────────────────────────
echo.
echo  [6/7] Starting containers ^(mongo + redis + backend + frontend + caddy + ddns^)...
docker compose -p realtraffic -f docker-compose.yml --profile ddns up -d
if errorlevel 1 (
    echo  [X] docker compose up failed.
    pause & exit /b 1
)
echo      OK — sab 6 containers starting.

:: ─── [7/7] Health checks ──────────────────────────────────────────────
echo.
echo  [7/7] Backend + frontend ready hone ka wait kar raha hu...

set /a TRIES=0
:health_loop
set /a TRIES+=1
docker exec realtraffic-backend curl --silent --max-time 3 http://localhost:8001/health >nul 2>&1
if not errorlevel 1 goto health_backend_ok
if !TRIES! geq 90 goto health_timeout
timeout /t 2 /nobreak >nul
echo | set /p="."
goto health_loop

:health_backend_ok
echo.
echo      OK — Backend healthy.

set /a TRIES=0
:front_loop
set /a TRIES+=1
docker exec realtraffic-frontend wget --spider -q http://localhost:80/ >nul 2>&1
if not errorlevel 1 goto health_ok
if !TRIES! geq 60 goto health_timeout
timeout /t 2 /nobreak >nul
echo | set /p="."
goto front_loop

:health_timeout
echo.
echo  [!] Kuch container ready hone me thoda aur lag raha hai.
echo      Logs check karo:
echo        docker logs -f realtraffic-backend
echo        docker logs -f realtraffic-frontend
echo        docker logs -f realtraffic-caddy
goto detect_ip

:health_ok
echo.
echo      OK — Frontend healthy.

:detect_ip
echo.
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Invoke-RestMethod -Uri 'https://api.ipify.org') 2>$null"`) do set "PUBLIC_IP=%%i"
if not defined PUBLIC_IP set "PUBLIC_IP=^(check whatismyip.com manually^)"

set "LOCAL_IP="
for /f "usebackq tokens=2 delims=:" %%i in (`ipconfig ^| findstr /C:"IPv4 Address"`) do (
    if not defined LOCAL_IP set "LOCAL_IP=%%i"
)
set "LOCAL_IP=!LOCAL_IP: =!"

:: ─── Final summary ────────────────────────────────────────────────────
echo.
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                    ✅ INSTALL COMPLETE                       ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo  📦 Containers running:
docker ps --filter "name=realtraffic-" --format "    {{.Names}}  {{.Status}}"
echo.
echo  🌍 Aapki IPs:
echo       Public IP:  !PUBLIC_IP!
echo       Local IP:   !LOCAL_IP!
echo.
echo  🎯 Aapka App URL ^(frontend + backend, same jagah^):
echo       https://!BACKEND_DOMAIN!
echo.
echo  🔐 Admin Login:
echo       Go to:    https://!BACKEND_DOMAIN!/admin
echo       Email:    admin@realtraffic.local
echo       Password: !ADMIN_PASS!
echo.
echo       *** YE PASSWORD ABHI SAVE KARO ^(password manager ya WhatsApp self^) ***
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║            ⚠️  ABHI SIRF 1 CHEEZ AUR BAAQI HAI                ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo  ┌──────────────────────────────────────────────────────────────┐
echo  │  HUAWEI ROUTER ME PORT FORWARD ^(one-time, 5 min^)             │
echo  └──────────────────────────────────────────────────────────────┘
echo     1. Browser me kholo: http://192.168.100.1
echo     2. Login ^(sticker pe likha hai - usually admin/admin^)
echo     3. Forward Rules ^> Port Mapping ^> Add Rule:
echo          Rule 1:  WAN port 80   → LAN IP !LOCAL_IP! port 80   TCP
echo          Rule 2:  WAN port 443  → LAN IP !LOCAL_IP! port 443  TCP
echo     4. Save aur router restart karo
echo     5. 5-10 min wait karo ^(DuckDNS IP propagate + Caddy SSL cert issue^)
echo     6. Browser me kholo:  https://!BACKEND_DOMAIN!
echo        → RealTraffic login page dikhni chahiye
echo.
echo  ✅ Sab complete. Aap aur aapke users kahin se bhi access kar sakte hain.
echo.
echo  🛠️  Useful commands:
echo       docker logs -f realtraffic-backend    ^<- backend logs
echo       docker logs -f realtraffic-frontend   ^<- nginx logs
echo       docker logs -f realtraffic-caddy      ^<- SSL/proxy logs
echo       docker logs -f realtraffic-ddns       ^<- DuckDNS logs
echo       REALTRAFFIC-STOP.bat                  ^<- sab stop
echo       REALTRAFFIC-UPDATE.bat                ^<- pull GitHub + rebuild
echo       ONE-CLICK-ADMIN-RESET.bat             ^<- admin password reset
echo.
pause
endlocal
