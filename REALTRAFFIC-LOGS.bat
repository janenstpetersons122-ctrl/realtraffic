@echo off
REM Live logs from RealTraffic backend
setlocal
pushd "%~dp0"
echo Following backend logs (Ctrl+C to exit)...
docker compose -p realtraffic logs -f --tail 100 backend
popd
endlocal
