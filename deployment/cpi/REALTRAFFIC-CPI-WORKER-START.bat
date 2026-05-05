@echo off
REM RealTraffic CPI Worker — Start
REM Run this whenever you want to start processing CPI jobs.

setlocal
pushd "%~dp0\..\..\realtraffic-cpi-worker"

if not exist "venv-cpi-worker\Scripts\python.exe" (
    echo [ERROR] venv not found. Run REALTRAFFIC-CPI-SETUP.ps1 first.
    pause
    exit /b 1
)
if not exist "config.yaml" (
    echo [ERROR] config.yaml not found. Copy config.example.yaml to config.yaml and edit it.
    pause
    exit /b 1
)

echo Starting RealTraffic CPI Worker...
echo Press Ctrl+C to stop.
echo.
"venv-cpi-worker\Scripts\python.exe" worker.py --config config.yaml

popd
endlocal
