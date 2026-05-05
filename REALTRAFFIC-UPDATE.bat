@echo off
REM ════════════════════════════════════════════════════════════════════
REM   RealTraffic — Quick Update
REM   ─────────────────────
REM   Pulls latest code from GitHub, rebuilds, restarts. ~3-5 min.
REM   Use this for ongoing feature updates after the first deploy.
REM ════════════════════════════════════════════════════════════════════

setlocal
pushd "%~dp0"

echo.
echo ╔════════════════════════════════════════╗
echo ║   RealTraffic — Quick Update              ║
echo ╚════════════════════════════════════════╝
echo.

REM Verify Docker is up
docker info > nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker Desktop is not running. Start it from the Start menu and retry.
    pause
    exit /b 1
)

echo [1/4] Pulling latest code...
git fetch origin
git pull --ff-only
if errorlevel 1 (
    echo [WARN] git pull failed - you may have local changes. Stash them with:
    echo        git stash push -u -m "manual-stash"
    pause
    exit /b 1
)

echo.
echo [2/4] Stopping old containers...
docker compose -p realtraffic down --remove-orphans

echo.
echo [3/4] Building new images...
docker compose -p realtraffic build

echo.
echo [4/4] Starting services...

REM Detect if TUNNEL_TOKEN is set in .env
findstr /R "^TUNNEL_TOKEN=." .env > nul 2>&1
if errorlevel 1 (
    docker compose -p realtraffic up -d
) else (
    docker compose -p realtraffic --profile tunnel up -d
)

echo.
echo ╔════════════════════════════════════════╗
echo ║   Update complete!                     ║
echo ║                                        ║
echo ║   Status:                              ║
echo ╚════════════════════════════════════════╝
docker compose -p realtraffic ps

popd
endlocal
