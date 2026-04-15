@echo off
REM =====================================================
REM  turas.bat — Launch Turas
REM  Double-click this file whenever you want to use Turas
REM
REM  Requires docker-compose.yml and .env in the same folder.
REM  Edit .env to set TURAS_PROJECTS_ROOT to your projects folder.
REM =====================================================

REM Change to the folder where this .bat file lives
cd /d "%~dp0"

echo.
echo ============================================
echo   Starting Turas. Please wait...
echo ============================================
echo.

echo Checking for updates...
docker-compose pull

echo Stopping any previous session...
docker-compose down >nul 2>&1

echo Launching Turas...
docker-compose up -d

echo Waiting for Turas to start...
timeout /t 30 /nobreak >nul

echo Opening Turas in your browser...
start http://localhost:3838

echo.
echo ============================================
echo   Turas is running!
echo   If your browser didn't open automatically,
echo   go to: http://localhost:3838
echo.
echo   Keep this window open while using Turas.
echo   When you are finished, type STOP and
echo   press Enter to shut Turas down.
echo ============================================
echo.

SET /P ACTION=Type STOP and press Enter when you are done:

docker-compose down

echo.
echo Turas has been stopped. You can close this window.
pause
