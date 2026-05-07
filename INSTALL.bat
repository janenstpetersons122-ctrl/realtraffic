@echo off
:: ══════════════════════════════════════════════════════════════════════
::  RealTraffic — ONE-CLICK INSTALL (Windows, Auto-Port Smart Edition)
:: ══════════════════════════════════════════════════════════════════════
::  100% aapke PC pe — frontend + backend + DB + SSL.
::  Bahir se sirf DuckDNS (free DNS pointer) — kuch nahi.
::
::  Smart auto-handling:
::    • Agar port 80/443 free hain → wo use karega (clean URL)
::    • Agar busy hain (purana Docker project) → AUTO 8080/8443 use karega
::      (Router me port translation — URL phir bhi clean rahega)
::    • SSL DNS-01 challenge se aata hai (DuckDNS API), port 80 ki
::      zaroorat NAHI — purane projects bilkul kharab nahi honge
::
::  Aapko bas 1 cheez chahiye:
::    • DuckDNS account (FREE — 30 sec, GitHub se signup)
:: ══════════════════════════════════════════════════════════════════════

setlocal ENABLEDELAYEDEXPANSION

cd /d "%~dp0"
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

title RealTraffic — One-Click Install (Auto-Port Smart)

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║         RealTraffic — One-Click Install (Smart)              ║
echo  ║                                                              ║
echo  ║  Auto-detects port conflicts, falls back to 8080/8443        ║
echo  ║  Existing Docker projects pe koi farak NAHI parega           ║
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
    echo  [X] Docker Desktop CHAL NAHI RAHA.
    echo      Start Menu se Docker Desktop kholo,
    echo      green "Running" indicator ka wait karo, phir is file ko chalao.
    pause & exit /b 1
)
for /f "tokens=*" %%v in ('docker --version') do echo      OK — %%v

:: ─── [2/7] Port auto-detection ────────────────────────────────────────
echo.
echo  [2/7] Port auto-detection ^(80/443 ya 8080/8443^)...

set "HTTP_PORT=80"
set "HTTPS_PORT=443"

:: Check port 443 (most important — actual user traffic)
netstat -ano | findstr "LISTENING" | findstr /R /C:":443 " >nul 2>&1
if not errorlevel 1 (
    echo      [!] Port 443 busy hai — alternative 8443 use karenge
    set "HTTPS_PORT=8443"
)

:: Check port 80
netstat -ano | findstr "LISTENING" | findstr /R /C:":80 " >nul 2>&1
if not errorlevel 1 (
    echo      [!] Port 80 busy hai — alternative 8080 use karenge
    set "HTTP_PORT=8080"
)

if "!HTTP_PORT!!HTTPS_PORT!"=="80443" (
    echo      OK — ports 80 + 443 free, standard ports use kar rahe hain.
) else (
    echo      OK — alternative ports detect ho gaye:
    echo            HTTP   = !HTTP_PORT!
    echo            HTTPS  = !HTTPS_PORT!
    echo      ^(Router me port translation karke URL phir bhi clean rahega^)
)

:: ─── [3/7] Configuration prompt (one-time) ────────────────────────────
echo.
echo  [3/7] Configuration check...

if exist "%ROOT%\.env" (
    echo      .env already exists — using saved configuration.

    :: Update HTTP_PORT/HTTPS_PORT in existing .env (in case ports changed)
    powershell -NoProfile -Command "(Get-Content '%ROOT%\.env') -replace '^HTTP_PORT=.*','HTTP_PORT=!HTTP_PORT!' -replace '^HTTPS_PORT=.*','HTTPS_PORT=!HTTPS_PORT!' | Set-Content '%ROOT%\.env'"

    :: Add HTTP_PORT/HTTPS_PORT if not present
    findstr /B /C:"HTTP_PORT=" "%ROOT%\.env" >nul 2>&1
    if errorlevel 1 echo HTTP_PORT=!HTTP_PORT!>>"%ROOT%\.env"
    findstr /B /C:"HTTPS_PORT=" "%ROOT%\.env" >nul 2>&1
    if errorlevel 1 echo HTTPS_PORT=!HTTPS_PORT!>>"%ROOT%\.env"

    goto :env_done
)

echo.
echo  ┌──────────────────────────────────────────────────────────────┐
echo  │  Pehli baar setup — bas 3 cheezein chahiye:                   │
echo  │                                                               │
echo  │  Phele DuckDNS account banao ^(free, 30 sec^):                 │
echo  │    1. https://www.duckdns.org open karo                       │
echo  │    2. "Sign in with GitHub" click karo                        │
echo  │    3. Top me "domain" field me apna unique name daalo         │
echo  │       Example: myrealtraffic                                  │
echo  │       ^(URL ban jayega: myrealtraffic.duckdns.org^)             │
echo  │    4. "add domain" button press karo                          │
echo  │    5. Top me "token" wali long string copy karo               │
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
echo      Example: a298314a-983b-4289-a2dc-6986c67bfafd
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
    echo # DuckDNS auto-update ^& DNS-01 ACME challenge
    echo DUCKDNS_NAME=!DUCKDNS_NAME!
    echo DUCKDNS_TOKEN=!DUCKDNS_TOKEN!
    echo.
    echo # Auto-detected ports ^(80/443 if free, else 8080/8443^)
    echo HTTP_PORT=!HTTP_PORT!
    echo HTTPS_PORT=!HTTPS_PORT!
    echo.
    echo # Optional integrations
    echo RESEND_API_KEY=
    echo RESEND_FROM=no-reply@realtraffic.local
    echo GOOGLE_SHEETS_SA_PATH=/app/backend/secrets/gsheets-sa.json
    echo GOOGLE_SHEETS_SA_JSON=
    echo.
    echo # ─── Performance tuning ──────────────────────────────────────────
    echo UVICORN_WORKERS=4
    echo MONGO_MAX_POOL_SIZE=150
    echo MONGO_MIN_POOL_SIZE=20
    echo MONGO_MAX_IDLE_TIME_MS=30000
    echo HEAVY_JOB_CONCURRENCY=8
    echo.
    echo # ─── Sentry monitoring ^(optional^) ────────────────────────────────
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
set "HTTP_PORT_SAVED="
set "HTTPS_PORT_SAVED="
for /f "usebackq tokens=1,* delims==" %%a in ("%ROOT%\.env") do (
    if "%%a"=="ADMIN_PASSWORD"  set "ADMIN_PASS=%%b"
    if "%%a"=="BACKEND_DOMAIN"  set "BACKEND_DOMAIN=%%b"
    if "%%a"=="DUCKDNS_NAME"    set "DUCKDNS_NAME=%%b"
    if "%%a"=="DUCKDNS_TOKEN"   set "DUCKDNS_TOKEN=%%b"
    if "%%a"=="HTTP_PORT"       set "HTTP_PORT_SAVED=%%b"
    if "%%a"=="HTTPS_PORT"      set "HTTPS_PORT_SAVED=%%b"
)

if defined HTTP_PORT_SAVED  set "HTTP_PORT=!HTTP_PORT_SAVED!"
if defined HTTPS_PORT_SAVED set "HTTPS_PORT=!HTTPS_PORT_SAVED!"

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
echo       ^(backend + frontend + custom Caddy with rate-limit + DuckDNS DNS-01^)
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
docker exec realtraffic-frontend wget -qO- http://127.0.0.1/ >nul 2>&1
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
echo  🚪 Caddy ports use ho rahe hain:
echo       HTTP   = !HTTP_PORT!
echo       HTTPS  = !HTTPS_PORT!
echo.
echo  🎯 Aapka App URL:
echo       https://!BACKEND_DOMAIN!
echo.
echo  🔐 Admin Login:
echo       Go to:    https://!BACKEND_DOMAIN!/admin
echo       Email:    admin@realtraffic.local
echo       Password: !ADMIN_PASS!
echo.
echo       *** YE PASSWORD ABHI SAVE KARO ^(WhatsApp self / password manager^) ***
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║          ⚠️  ABHI SIRF 1 CHEEZ AUR BAAQI HAI                 ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo  ┌──────────────────────────────────────────────────────────────┐
echo  │  ROUTER ME PORT FORWARD ^(one-time, 5 min^)                    │
echo  └──────────────────────────────────────────────────────────────┘
echo     1. Browser me kholo: http://192.168.100.1
echo     2. Login ^(router sticker pe likha — usually admin/admin^)
echo     3. Forward Rules ^> Port Mapping ^> Add Rule:
echo.
if "!HTTP_PORT!!HTTPS_PORT!"=="80443" (
    echo          Rule 1:  WAN port 80   → LAN IP !LOCAL_IP! port 80    TCP
    echo          Rule 2:  WAN port 443  → LAN IP !LOCAL_IP! port 443   TCP
) else (
    echo          ⚡ NOTE: Aapke PC pe port 80/443 koi aur project use kar
    echo             raha hai. Hum 8080/8443 pe chal rahe hain. Router me
    echo             port translation karo — URL phir bhi clean rahega:
    echo.
    echo          Rule 1:  WAN port 80   → LAN IP !LOCAL_IP! port !HTTP_PORT!   TCP
    echo          Rule 2:  WAN port 443  → LAN IP !LOCAL_IP! port !HTTPS_PORT!  TCP
)
echo.
echo     4. Save aur router restart karo
echo     5. 5-10 min wait karo ^(DuckDNS IP propagate + Caddy SSL cert via DNS-01^)
echo     6. Browser me kholo:  https://!BACKEND_DOMAIN!
echo        → RealTraffic login page dikhni chahiye
echo.
echo  ✅ Bas. Aap aur aapke users kahin se bhi access kar sakte hain.
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
