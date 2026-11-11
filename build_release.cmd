@echo off
setlocal
set "SCRIPT=%~dp0tool\build_release.ps1"
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
)
if errorlevel 1 (
  echo.
  echo La compilacion fallo. Revisa el mensaje anterior.
  pause
)
endlocal
