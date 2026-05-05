@echo off
REM ════════════════════════════════════════════════════════════════════
REM   RealTraffic — Force Sync from GitHub + Clean Rebuild
REM   ────────────────────────────────────────────────
REM   Use this when a regular `docker compose up -d --build` doesn't
REM   pick up the latest code (typically because the folder was
REM   originally extracted from a ZIP, not `git clone`d — so `git pull`
REM   was a no-op, AND Docker's COPY layer cache stayed stale).
REM
REM   What this script does:
REM     1. Ensures the current folder is a git repo pointing at the
REM        canonical remote `https://github.com/lenovogen03/lenovo-realtraffic.git`
REM     2. Fetches + HARD RESETS to origin/main (overwrites any local edits)
REM     3. Rebuilds the backend image with --no-cache (bypasses the stale
REM        COPY layer) and forces container recreation.
REM
REM   After this, future updates can use plain `REALTRAFFIC-UPDATE.bat`.
REM ════════════════════════════════════════════════════════════════════

setlocal ENABLEDELAYEDEXPANSION
pushd "%~dp0"

echo.
echo ============================================================
echo   RealTraffic — Force Sync from GitHub + Clean Rebuild
echo ============================================================
echo.

REM -- Verify Docker is running -----------------------------------------
docker info > nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker Desktop is not running. Start it and retry.
    pause
    exit /b 1
)

REM -- Verify git is installed ------------------------------------------
git --version > nul 2>&1
if errorlevel 1 (
    echo [ERROR] git is not installed or not on PATH.
    echo         Install from https://git-scm.com/download/win then retry.
    pause
    exit /b 1
)

set "REPO_URL=https://github.com/lenovogen03/lenovo-realtraffic.git"

REM -- Step 1: Ensure folder is a git repo with correct remote ----------
echo [1/5] Checking git repository state...

if not exist ".git" (
    echo        .git folder missing — initializing new repo...
    git init
    git remote add origin %REPO_URL%
) else (
    for /f "tokens=* usebackq" %%u in (`git remote get-url origin 2^>nul`) do set "CURRENT_REMOTE=%%u"
    if "!CURRENT_REMOTE!"=="" (
        echo        origin remote missing — adding...
        git remote add origin %REPO_URL%
    ) else if /I not "!CURRENT_REMOTE!"=="%REPO_URL%" (
        echo        origin points to !CURRENT_REMOTE! — fixing to %REPO_URL%
        git remote set-url origin %REPO_URL%
    ) else (
        echo        origin already set correctly.
    )
)

REM -- Step 2: Fetch + hard reset to origin/main ------------------------
echo.
echo [2/5] Fetching latest code from origin/main...
git fetch origin main
if errorlevel 1 (
    echo [ERROR] git fetch failed — check your internet connection.
    pause
    exit /b 1
)

echo.
echo [3/5] HARD RESET to origin/main (local edits will be discarded)...
git reset --hard origin/main
if errorlevel 1 (
    echo [ERROR] git reset failed.
    pause
    exit /b 1
)

REM Print current commit so user can confirm it matches GitHub
for /f "tokens=* usebackq" %%h in (`git log -1 --pretty^=format^:"%%h %%s"`) do echo        On commit: %%h

REM -- Step 4: Rebuild backend image WITHOUT CACHE ----------------------
echo.
echo [4/5] Rebuilding backend image with --no-cache (bypasses stale COPY layer)...
docker compose build --no-cache backend
if errorlevel 1 (
    echo [ERROR] Docker build failed — check the output above.
    pause
    exit /b 1
)

REM -- Step 5: Restart backend (and cloudflared if tunnel is used) ------
echo.
echo [5/5] Restarting backend container...
findstr /R "^TUNNEL_TOKEN=." .env > nul 2>&1
if errorlevel 1 (
    docker compose up -d --force-recreate --no-deps backend
) else (
    docker compose --profile tunnel up -d --force-recreate --no-deps backend cloudflared
)

echo.
echo ============================================================
echo   Force sync complete!
echo ============================================================
echo.
echo Verify the new target-screenshot endpoint is live by running:
echo    curl -X POST https://api.realtraffic.online/api/uploads/target-screenshot
echo Expected: HTTP 401 "Not authenticated"   (NOT 405 "Method Not Allowed")
echo.
docker compose ps

popd
endlocal
