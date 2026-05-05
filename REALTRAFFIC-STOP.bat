@echo off
REM Stop all RealTraffic services (backend, mongo, cloudflared)
setlocal
pushd "%~dp0"
echo Stopping RealTraffic services...
docker compose -p realtraffic --profile tunnel down
echo.
echo All RealTraffic services stopped.
echo (Mongo data is preserved in the named volume.)
popd
endlocal
