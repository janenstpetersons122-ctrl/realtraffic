@echo off
:: ══════════════════════════════════════════════════════════════════════
::  RealTraffic — ONE-CLICK INSTALL (Windows)
:: ══════════════════════════════════════════════════════════════════════
::  Aapko sirf 2 cheezein chahiye:
::    1. DuckDNS account (FREE — 30 sec, GitHub se signup)
::    2. Vercel account (FREE — 30 sec, GitHub se signup)
::
::  Yahi file:
::    • Docker stack build + start karega
::    • Free SSL cert lega Let's Encrypt se (yourname.duckdns.org pe)
::    • DuckDNS me public IP auto-update karega
::    • Final me admin password + Vercel me jo URL daalna print karega
:: ══════════════════════════════════════════════════════════════════════

setlocal ENABLEDELAYEDEXPANSION

cd /d "%~dp0"
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

title RealTraffic — One-Click Install

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                  RealTraffic — Easy Install                  ║
echo  ║                                                              ║
echo  ║  Frontend → Vercel ^(free .vercel.app domain^)                 ║
echo  ║  Backend  → Aapka home PC ^(yahi script setup karega^)         ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

:: ─── [1/6] Docker check ───────────────────────────────────────────────
echo  [1/6] Docker Desktop check...
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

:: ─── [2/6] Configuration prompt (one-time) ────────────────────────────
echo.
echo  [2/6] Configuration check...

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
echo  │    5. Top me "token" field me JO long string dikhayi de,      │
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

:: ─── [3/6] Write DuckDNS updater config ───────────────────────────────
echo.
echo  [3/6] DuckDNS config likh raha hu...

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

:: ─── [4/6] Build Docker images ────────────────────────────────────────
echo.
echo  [4/6] Building Docker images... ^(pehli baar 5-10 min^)
docker compose -p realtraffic -f docker-compose.yml build
if errorlevel 1 (
    echo  [X] Build failed.
    echo      Fix: Docker Desktop ^> Settings ^> Resources ^> Memory 4GB+
    pause & exit /b 1
)

:: ─── [5/6] Start containers ───────────────────────────────────────────
echo.
echo  [5/6] Starting containers ^(mongo + backend + caddy + ddns^)...
docker compose -p realtraffic -f docker-compose.yml --profile ddns up -d
if errorlevel 1 (
    echo  [X] docker compose up failed.
    pause & exit /b 1
)
echo      OK — sab containers starting.

:: ─── [6/6] Health checks ──────────────────────────────────────────────
echo.
echo  [6/6] Backend ready hone ka wait kar raha hu ^(Playwright install + first SSL cert^)...

set /a TRIES=0
:health_loop
set /a TRIES+=1
docker exec realtraffic-backend curl --silent --max-time 3 http://localhost:8001/health >nul 2>&1
if not errorlevel 1 goto health_ok
if !TRIES! geq 90 goto health_timeout
timeout /t 2 /nobreak >nul
echo | set /p="."
goto health_loop

:health_timeout
echo.
echo  [!] Backend ready hone me thoda aur lag raha hai.
echo      Logs check karo: docker logs -f realtraffic-backend
goto detect_ip

:health_ok
echo.
echo      OK — Backend internal health green.

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
echo  🎯 Backend public URL:
echo       https://!BACKEND_DOMAIN!
echo.
echo  🔐 Admin Login:
echo       Email:    admin@realtraffic.local
echo       Password: !ADMIN_PASS!
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║              ⚠️  ABHI 2 CHEEZEIN BAAQI HAIN                  ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo  ┌──────────────────────────────────────────────────────────────┐
echo  │  STEP A — HUAWEI ROUTER ME PORT FORWARD                       │
echo  └──────────────────────────────────────────────────────────────┘
echo     1. Browser me kholo: http://192.168.100.1
echo     2. Login ^(sticker pe likha hai - usually admin/admin^)
echo     3. Forward Rules ^> Port Mapping ^> Add Rule:
echo          Rule 1:  WAN port 80   → LAN IP !LOCAL_IP! port 80   TCP
echo          Rule 2:  WAN port 443  → LAN IP !LOCAL_IP! port 443  TCP
echo     4. Save aur router restart karo.
echo.
echo     5-10 min wait karo ^(DuckDNS IP propagate karega + Caddy SSL cert ^)
echo     6. Test: browser me kholo https://!BACKEND_DOMAIN!/health
echo        Aana chahiye: {"status":"ok"^}
echo.
echo  ┌──────────────────────────────────────────────────────────────┐
echo  │  STEP B — VERCEL PE FRONTEND DEPLOY                          │
echo  └──────────────────────────────────────────────────────────────┘
echo     1. https://vercel.com/signup → "Continue with GitHub"
echo     2. "Add New" ^> "Project" → import lenovo-realflow repo
echo     3. Project settings:
echo           Framework Preset:  Create React App
echo           Root Directory:    frontend                 ^(IMPORTANT^)
echo           Build Command:     yarn build
echo           Output Directory:  build
echo     4. "Environment Variables" expand karo aur ye 3 add karo:
echo           REACT_APP_BACKEND_URL = https://!BACKEND_DOMAIN!
echo           WDS_SOCKET_PORT       = 443
echo           CI                    = false
echo     5. "Deploy" press karo
echo     6. 3-5 min me URL milega: https://lenovo-realflow.vercel.app
echo        Wahi aapka public app hai — aap aur aapke users kahin se login!
echo.
echo  ✅ Sab teen steps complete hone ke baad:
echo       Vercel URL kahin se bhi access karo. Backend yahan ghar pe chalega.
echo.
echo  🛠️  Useful commands:
echo       docker logs -f realtraffic-backend   ^<- backend logs
echo       docker logs -f realtraffic-caddy     ^<- SSL/proxy logs
echo       docker logs -f realtraffic-ddns      ^<- DuckDNS logs
echo       REALTRAFFIC-STOP.bat                 ^<- sab stop
echo       REALTRAFFIC-UPDATE.bat               ^<- pull GitHub + rebuild
echo.
pause
endlocal
