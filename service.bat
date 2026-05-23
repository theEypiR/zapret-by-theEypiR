@echo off
cd /d "%~dp0"
setlocal enabledelayedexpansion
title Zapret Service Manager
set "LOCAL_VERSION=1.0.3b"

:: Проверка папки стратегий
set "STRATEGY_DIR=strategies"
if not exist "%STRATEGY_DIR%" (
    echo ERROR: '%STRATEGY_DIR%' folder not found.
    echo Please create it and add your strategy .bat files.
    pause
    exit /b
)

:: Автозапрос прав администратора
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Загрузка настроек из реестра
set "REG_KEY=HKLM\Software\ZapretConfig"
set "GameFilterStatus=enabled"
set "GameFilter=1024-65535"
set "IPsetStatus=any"
set "CheckUpdatesStatus=disabled"

for /f "tokens=3" %%A in ('reg query "%REG_KEY%" /v GameFilter 2^>nul') do (
    if "%%A"=="0" (
        set "GameFilterStatus=disabled"
        set "GameFilter=12"
    ) else (
        set "GameFilterStatus=enabled"
        set "GameFilter=1024-65535"
    )
)

for /f "tokens=3" %%A in ('reg query "%REG_KEY%" /v IPSet 2^>nul') do (
    if "%%A"=="0" set "IPsetStatus=none"
    if "%%A"=="1" set "IPsetStatus=loaded"
    if "%%A"=="2" set "IPsetStatus=any"
)

for /f "tokens=3" %%A in ('reg query "%REG_KEY%" /v AutoUpdate 2^>nul') do (
    if "%%A"=="1" ( set "CheckUpdatesStatus=enabled" ) else ( set "CheckUpdatesStatus=disabled" )
)

:menu
cls
:: Автоматическая проверка обновлений
for /f "delims=" %%A in ('curl -s --connect-timeout 2 "https://raw.githubusercontent.com/theEypiR/zapret-by-theEypiR/main/.service/version.txt" 2^>nul') do set "LATEST=%%A"
if not "%LATEST%"=="" if not "%LOCAL_VERSION%"=="%LATEST%" (
    echo.
    echo   [!] New version %LATEST% available!
    echo   Press 7 to open download page.
    echo.
)
echo ===============================================
echo   Zapret Service Manager v%LOCAL_VERSION% by theEypiR
echo ===============================================
echo.
echo   1. Install Service
echo   2. Remove Service
echo   3. Check Status
echo.
echo   4. Game Filter      [%GameFilterStatus%]
echo   5. IPSet Filter     [%IPsetStatus%]
echo   6. Auto-Update      [%CheckUpdatesStatus%]
echo.
echo   7. Check for Updates (GitHub)
echo   8. Switch Strategy
echo   0. Exit
echo.
set /p choice=Choose:

if "%choice%"=="1" goto install
if "%choice%"=="2" goto remove
if "%choice%"=="3" goto status
if "%choice%"=="4" goto game_switch
if "%choice%"=="5" goto ipset_switch
if "%choice%"=="6" goto autoupdate_switch
if "%choice%"=="7" goto check_updates
if "%choice%"=="8" goto switch_strategy
if "%choice%"=="0" exit
goto menu

:install
cls
set "BIN_PATH=%~dp0bin\"

set "count=0"
for %%F in ("%STRATEGY_DIR%\*.bat") do (
    set /a count+=1
    set "strategy!count!=%%~nxF"
)

if %count%==0 (
    echo No strategy files found in %STRATEGY_DIR%
    pause
    goto menu
)

echo Available strategies:
for /l %%i in (1,1,%count%) do (
    echo   %%i. !strategy%%i!
)

set /p "choice=Select strategy (1-%count%): "
if "%choice%"=="" goto menu

echo %choice%|findstr /r "^[0-9]*$" >nul
if errorlevel 1 (
    echo Invalid input.
    pause
    goto menu
)

set "selected=!strategy%choice%!"
if not defined selected (
    echo Invalid choice.
    pause
    goto menu
)

set "ARGS="
for /f "usebackq tokens=*" %%a in ("%STRATEGY_DIR%\%selected%") do (
    set "line=%%a"
    echo !line! | findstr /i "winws.exe" >nul
    if not errorlevel 1 (
        set "line=!line:*winws.exe=!"
        set "ARGS=!line!"
    )
)

if "%ARGS%"=="" (
    echo Could not extract winws parameters.
    pause
    goto menu
)

set "ARGS=%ARGS:start =%"
set "ARGS=%ARGS:/min =%"
set "ARGS=%ARGS:& =%"
set "ARGS=%ARGS:^=%"

echo Installing service with: winws.exe %ARGS%

sc stop zapret >nul 2>&1
sc delete zapret >nul 2>&1
sc create zapret binPath= "\"%BIN_PATH%winws.exe\" %ARGS%" start= auto
sc start zapret >nul 2>&1

if %errorlevel% equ 0 (
    echo Service installed and started successfully.
) else (
    echo Failed to start service.
)
pause
goto menu

:switch_strategy
cls
echo === SWITCH STRATEGY ===
set "STRATEGY_DIR=strategies"
set "BIN_PATH=%~dp0bin\"

if not exist "%STRATEGY_DIR%" (
    echo ERROR: '%STRATEGY_DIR%' folder not found.
    pause
    goto menu
)

set "count=0"
for %%F in ("%STRATEGY_DIR%\*.bat") do (
    set /a count+=1
    set "strategy!count!=%%~nxF"
)

if %count%==0 (
    echo No strategy files found.
    pause
    goto menu
)

echo Available strategies:
for /l %%i in (1,1,%count%) do (
    echo   %%i. !strategy%%i!
)

set /p "choice=Select strategy (1-%count%): "
if "%choice%"=="" goto menu

set "selected=!strategy%choice%!"
if not defined selected (
    echo Invalid choice.
    pause
    goto menu
)

set "ARGS="
for /f "usebackq tokens=*" %%a in ("%STRATEGY_DIR%\%selected%") do (
    set "line=%%a"
    echo !line! | findstr /i "winws.exe" >nul
    if not errorlevel 1 (
        set "line=!line:*winws.exe=!"
        set "ARGS=!line!"
    )
)

if "%ARGS%"=="" (
    echo Could not extract winws parameters.
    pause
    goto menu
)

set "ARGS=%ARGS:start =%"
set "ARGS=%ARGS:/min =%"
set "ARGS=%ARGS:& =%"
set "ARGS=%ARGS:^=%"

echo Switching to: %selected%
echo Params: %ARGS%

sc stop zapret >nul 2>&1
sc delete zapret >nul 2>&1
timeout /t 1 >nul
sc create zapret binPath= "\"%BIN_PATH%winws.exe\" %ARGS%" start= auto
sc start zapret >nul 2>&1

if %errorlevel% equ 0 (
    echo Strategy switched successfully.
) else (
    echo Failed to switch strategy.
    echo Check parameters in registry manually.
)
pause
goto menu

:remove
cls
echo Removing service...
sc query zapret >nul 2>&1
if %errorlevel% equ 1060 (
    echo Service is not installed.
    pause
    goto menu
)
sc stop zapret >nul 2>&1
sc delete zapret >nul 2>&1
taskkill /f /im winws.exe >nul 2>&1
echo Service removed.
pause
goto menu

:status
cls
echo ========================================
echo   Service Status
echo ========================================
echo.
sc query zapret
echo.
tasklist /FI "IMAGENAME eq winws.exe"
echo.
pause
goto menu

:game_switch
if "%GameFilterStatus%"=="enabled" (
    set "GameFilterStatus=disabled"
    set "GameFilter=12"
    reg add "%REG_KEY%" /v GameFilter /t REG_DWORD /d 0 /f >nul
    echo Game Filter DISABLED
) else (
    set "GameFilterStatus=enabled"
    set "GameFilter=1024-65535"
    reg add "%REG_KEY%" /v GameFilter /t REG_DWORD /d 1 /f >nul
    echo Game Filter ENABLED
)
echo Restart zapret to apply changes.
pause
goto menu

:ipset_switch
if "%IPsetStatus%"=="loaded" (
    set "IPsetStatus=none"
    reg add "%REG_KEY%" /v IPSet /t REG_DWORD /d 0 /f >nul
) else if "%IPsetStatus%"=="none" (
    set "IPsetStatus=any"
    reg add "%REG_KEY%" /v IPSet /t REG_DWORD /d 2 /f >nul
) else (
    set "IPsetStatus=loaded"
    reg add "%REG_KEY%" /v IPSet /t REG_DWORD /d 1 /f >nul
)
echo IPSet set to: %IPsetStatus%
echo Restart zapret to apply changes.
pause
goto menu

:autoupdate_switch
if "%CheckUpdatesStatus%"=="enabled" (
    set "CheckUpdatesStatus=disabled"
    reg add "%REG_KEY%" /v AutoUpdate /t REG_DWORD /d 0 /f >nul
    echo Auto-Update DISABLED
) else (
    set "CheckUpdatesStatus=enabled"
    reg add "%REG_KEY%" /v AutoUpdate /t REG_DWORD /d 1 /f >nul
    echo Auto-Update ENABLED
)
pause
goto menu

:check_updates
cls
for /f "delims=" %%A in ('curl -s --connect-timeout 3 "https://raw.githubusercontent.com/theEypiR/zapret-by-theEypiR/main/.service/version.txt" 2^>nul') do set "LATEST=%%A"
if "%LATEST%"=="" (
    echo Failed to check for updates
    pause
    goto menu
)
if "%LOCAL_VERSION%"=="%LATEST%" (
    echo You have the latest version: %LOCAL_VERSION%
) else (
    echo New version available: %LATEST%
    start "" "https://github.com/theEypiR/zapret-by-theEypiR/releases/latest"
)
pause
goto menu