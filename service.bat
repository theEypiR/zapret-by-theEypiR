@echo off
set "LOCAL_VERSION=1.0.2"

set "GITHUB_USER=theEypiR"
set "GITHUB_REPO=zapret-by-theEypiR"
set "GITHUB_VERSION_URL=https://raw.githubusercontent.com/%GITHUB_USER%/%GITHUB_REPO%/main/.service/version.txt"
set "GITHUB_DOWNLOAD_URL=https://github.com/%GITHUB_USER%/%GITHUB_REPO%/releases/latest"

set "LATEST_VERSION="
set "UPDATE_AVAILABLE=0"
set "AUTO_UPDATE_CHECKED=0"

if "%~1"=="check_updates" exit /b

:: External commands
if "%~1"=="status_zapret" (
    call :test_service zapret soft
    call :tcp_enable
    exit /b
)

if "%~1"=="load_game_filter" (
    call :game_switch_status
    exit /b
)

if "%1"=="admin" (
    call :check_command chcp
    call :check_command find
    call :check_command findstr
    call :check_command netsh
    echo Started with admin rights
) else (
    call :check_extracted
    call :check_command powershell
    echo Requesting admin rights...
    powershell -NoProfile -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
    exit
)

:: ПОЛУЧЕНИЕ ПОСЛЕДНЕЙ ВЕРСИИ ==========
:get_latest_version
set "LATEST_VERSION="
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Invoke-WebRequest -Uri \"%GITHUB_VERSION_URL%\" -UseBasicParsing -TimeoutSec 3).Content.Trim()" 2^>nul') do set "LATEST_VERSION=%%A"
exit /b

:: MENU ================================
:menu
cls

:: Проверяем обновления, если ещё не проверяли
if "%AUTO_UPDATE_CHECKED%"=="0" (
    set "AUTO_UPDATE_CHECKED=1"
    call :get_latest_version
    if not "%LATEST_VERSION%"=="" (
        if not "%LOCAL_VERSION%"=="%LATEST_VERSION%" (
            set "UPDATE_AVAILABLE=1"
            :: Автооткрытие браузера, если включено
            if "%CheckUpdatesStatus%"=="enabled" (
                start "" "%GITHUB_DOWNLOAD_URL%"
            )
        )
    )
)

call :load_settings
call :ipset_switch_status
call :game_switch_status
call :check_updates_switch_status

set "menu_choice=null"

echo.
echo   ZAPRET SERVICE MANAGER v%LOCAL_VERSION% by theEypiR
if not "%LATEST_VERSION%"=="" (
    if "%UPDATE_AVAILABLE%"=="1" (
        echo   [!!!] New version %LATEST_VERSION% available!
    ) else (
        echo   Latest version: %LATEST_VERSION% (up to date)
    )
) else if "%CheckUpdatesStatus%"=="enabled" (
    echo   [?] Version check failed (no internet?)
)
echo   ----------------------------------------
echo.
echo   :: SERVICE
echo      1. Install Service
echo      2. Remove Services
echo      3. Check Status
echo.
echo   :: SETTINGS
echo      4. Game Filter         [!GameFilterStatus!]
echo      5. IPSet Filter        [!IPsetStatus!]
echo      6. Auto-Update Check   [!CheckUpdatesStatus!]
echo.
echo   :: UPDATES
echo      7. Update IPSet List
echo      8. Update Hosts File
echo      9. Check for Updates
echo.
echo   :: TOOLS
echo      10. Run Diagnostics
echo      11. Run Tests
echo.
echo   ----------------------------------------
echo      0. Exit
echo.

set /p menu_choice=   Select option (0-11): 

if "%menu_choice%"=="1" goto service_install
if "%menu_choice%"=="2" goto service_remove
if "%menu_choice%"=="3" goto service_status
if "%menu_choice%"=="4" goto game_switch
if "%menu_choice%"=="5" goto ipset_switch
if "%menu_choice%"=="6" goto check_updates_switch
if "%menu_choice%"=="7" goto ipset_update
if "%menu_choice%"=="8" goto hosts_update
if "%menu_choice%"=="9" goto service_check_updates
if "%menu_choice%"=="10" goto service_diagnostics
if "%menu_choice%"=="11" goto run_tests
if "%menu_choice%"=="0" exit /b
goto menu

:: ЗАГРУЗКА НАСТРОЕК ИЗ РЕЕСТРА ========
:load_settings
set "REG_KEY=HKLM\Software\ZapretConfig"

:: Значения по умолчанию
set "GameFilterStatus=enabled"
set "GameFilter=1024-65535"
set "IPsetStatus=any"
set "CheckUpdatesStatus=disabled"

:: Читаем Game Filter из реестра
for /f "tokens=3" %%A in ('reg query "%REG_KEY%" /v GameFilter 2^>nul') do (
    if "%%A"=="0" (
        set "GameFilterStatus=disabled"
        set "GameFilter=12"
    ) else (
        set "GameFilterStatus=enabled"
        set "GameFilter=1024-65535"
    )
)

:: Читаем IPSet из реестра
for /f "tokens=3" %%A in ('reg query "%REG_KEY%" /v IPSet 2^>nul') do (
    if "%%A"=="0" set "IPsetStatus=none"
    if "%%A"=="1" set "IPsetStatus=loaded"
    if "%%A"=="2" set "IPsetStatus=any"
)

:: Читаем Auto-Update из реестра
for /f "tokens=3" %%A in ('reg query "%REG_KEY%" /v AutoUpdate 2^>nul') do (
    if "%%A"=="1" ( set "CheckUpdatesStatus=enabled" ) else ( set "CheckUpdatesStatus=disabled" )
)
exit /b

:: TCP ENABLE ==========================
:tcp_enable
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul || netsh interface tcp set global timestamps=enabled > nul 2>&1
exit /b

:: STATUS ==============================
:service_status
cls
chcp 437 > nul

sc query "zapret" >nul 2>&1
if !errorlevel!==0 (
    for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube 2^>nul') do echo Service strategy installed from "%%B"
)

call :test_service zapret
call :test_service WinDivert

set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" (
    call :PrintRed "WinDivert64.sys file NOT found."
)
echo:

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    call :PrintGreen "Bypass (winws.exe) is RUNNING."
) else (
    call :PrintRed "Bypass (winws.exe) is NOT running."
)

pause
goto menu

:test_service
set "ServiceName=%~1"
set "ServiceStatus="

for /f "tokens=3 delims=: " %%A in ('sc query "%ServiceName%" ^| findstr /i "STATE"') do set "ServiceStatus=%%A"
set "ServiceStatus=%ServiceStatus: =%"

if "%ServiceStatus%"=="RUNNING" (
    if "%~2"=="soft" (
        echo "%ServiceName%" is ALREADY RUNNING as service, use "service.bat" and choose "Remove Services" first if you want to run standalone bat.
        pause
        exit /b
    ) else (
        echo "%ServiceName%" service is RUNNING.
    )
) else if "%ServiceStatus%"=="STOP_PENDING" (
    call :PrintYellow "!ServiceName! is STOP_PENDING, that may be caused by a conflict with another bypass. Run Diagnostics to try to fix conflicts"
) else if not "%~2"=="soft" (
    echo "%ServiceName%" service is NOT running.
)

exit /b


:: REMOVE ==============================
:service_remove
cls
chcp 65001 > nul

set SRVCNAME=zapret
sc query "!SRVCNAME!" >nul 2>&1
if !errorlevel!==0 (
    net stop %SRVCNAME%
    sc delete %SRVCNAME%
) else (
    echo Service "%SRVCNAME%" is not installed.
)

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    taskkill /IM winws.exe /F > nul
)

sc query "WinDivert" >nul 2>&1
if !errorlevel!==0 (
    net stop "WinDivert"
    sc delete "WinDivert"
)
net stop "WinDivert14" >nul 2>&1
sc delete "WinDivert14" >nul 2>&1

pause
goto menu


:: INSTALL =============================
:service_install
cls
chcp 437 > nul

cd /d "%~dp0"
set "BIN_PATH=%~dp0bin\"
set "LISTS_PATH=%~dp0lists\"

echo Pick one of the options:
set "count=0"
for /f "delims=" %%F in ('powershell -NoProfile -Command "Get-ChildItem -LiteralPath '.' -Filter '*.bat' | Where-Object { $_.Name -notlike 'service*' } | Sort-Object { [Regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(8, '0') }) } | ForEach-Object { $_.Name }"') do (
    set /a count+=1
    echo !count!. %%F
    set "file!count!=%%F"
)

set "choice="
set /p "choice=Input file index (number): "
if "!choice!"=="" (
    echo The choice is empty, exiting...
    pause
    goto menu
)

set "selectedFile=!file%choice%!"
if not defined selectedFile (
    echo Invalid choice, exiting...
    pause
    goto menu
)

set "args_with_value=sni host altorder"
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="

for /f "tokens=*" %%a in ('type "!selectedFile!"') do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"

    echo !line! | findstr /i "%BIN%winws.exe" >nul
    if not errorlevel 1 (
        set "capture=1"
    )

    if !capture!==1 (
        if not defined args (
            set "line=!line:*%BIN%winws.exe"=!"
        )

        set "temp_args="
        for %%i in (!line!) do (
            set "arg=%%i"

            if not "!arg!"=="^" (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 (
                    set "mergeargs=0"
                )

                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"

                    echo !arg! | findstr ":" >nul
                    if !errorlevel!==0 (
                        set "arg=\!QUOTE!!arg!\!QUOTE!"
                    ) else if "!arg:~0,1!"=="@" (
                        set "arg=\!QUOTE!@%~dp0!arg:~1!\!QUOTE!"
                    ) else if "!arg:~0,5!"=="%%BIN%%" (
                        set "arg=\!QUOTE!!BIN_PATH!!arg:~5!\!QUOTE!"
                    ) else if "!arg:~0,7!"=="%%LISTS%%" (
                        set "arg=\!QUOTE!!LISTS_PATH!!arg:~7!\!QUOTE!"
                    ) else (
                        set "arg=\!QUOTE!%~dp0!arg!\!QUOTE!"
                    )
                ) else if "!arg:~0,12!" EQU "%%GameFilter%%" (
                    set "arg=%GameFilter%"
                )

                if !mergeargs!==1 (
                    set "temp_args=!temp_args!,!arg!"
                ) else if !mergeargs!==3 (
                    set "temp_args=!temp_args!=!arg!"
                    set "mergeargs=1"
                ) else (
                    set "temp_args=!temp_args! !arg!"
                )

                if "!arg:~0,2!" EQU "--" (
                    set "mergeargs=2"
                ) else if !mergeargs! GEQ 1 (
                    if !mergeargs!==2 set "mergeargs=1"
                    for %%x in (!args_with_value!) do (
                        if /i "%%x"=="!arg!" set "mergeargs=3"
                    )
                )
            )
        )

        if not "!temp_args!"=="" (
            set "args=!args! !temp_args!"
        )
    )
)

call :tcp_enable

set ARGS=%args%
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
echo Final args: !ARGS!
set SRVCNAME=zapret

net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
sc create %SRVCNAME% binPath= "\"%BIN_PATH%winws.exe\" !ARGS!" DisplayName= "zapret" start= auto
sc description %SRVCNAME% "Zapret DPI bypass software"
sc start %SRVCNAME%
for %%F in ("!file%choice%!") do set "filename=%%~nF"
reg add "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube /t REG_SZ /d "!filename!" /f

pause
goto menu

:: GAME SWITCH ========================
:game_switch_status
if "%GameFilterStatus%"=="enabled" (
    set "GameFilterStatus=enabled"
    set "GameFilter=1024-65535"
) else (
    set "GameFilterStatus=disabled"
    set "GameFilter=12"
)
exit /b

:game_switch
cls
if "%GameFilterStatus%"=="enabled" (
    set "GameFilterStatus=disabled"
    set "GameFilter=12"
    echo Game Filter DISABLED
    reg add "HKLM\Software\ZapretConfig" /v GameFilter /t REG_DWORD /d 0 /f >nul
) else (
    set "GameFilterStatus=enabled"
    set "GameFilter=1024-65535"
    echo Game Filter ENABLED
    reg add "HKLM\Software\ZapretConfig" /v GameFilter /t REG_DWORD /d 1 /f >nul
)
echo Restart zapret to apply changes
pause
goto menu

:: CHECK UPDATES SWITCH =================
:check_updates_switch_status
if "%CheckUpdatesStatus%"=="enabled" (
    set "CheckUpdatesStatus=enabled"
) else (
    set "CheckUpdatesStatus=disabled"
)
exit /b

:check_updates_switch
cls
if "%CheckUpdatesStatus%"=="enabled" (
    set "CheckUpdatesStatus=disabled"
    echo Auto-update check DISABLED
    reg add "HKLM\Software\ZapretConfig" /v AutoUpdate /t REG_DWORD /d 0 /f >nul
) else (
    set "CheckUpdatesStatus=enabled"
    echo Auto-update check ENABLED
    reg add "HKLM\Software\ZapretConfig" /v AutoUpdate /t REG_DWORD /d 1 /f >nul
)
pause
goto menu

:: IPSET SWITCH =======================
:ipset_switch_status
if "%IPsetStatus%"=="none" set "IPsetStatus=none"
if "%IPsetStatus%"=="loaded" set "IPsetStatus=loaded"
if "%IPsetStatus%"=="any" set "IPsetStatus=any"
exit /b

:ipset_switch
cls
if "%IPsetStatus%"=="loaded" (
    set "IPsetStatus=none"
    reg add "HKLM\Software\ZapretConfig" /v IPSet /t REG_DWORD /d 0 /f >nul
) else if "%IPsetStatus%"=="none" (
    set "IPsetStatus=any"
    reg add "HKLM\Software\ZapretConfig" /v IPSet /t REG_DWORD /d 2 /f >nul
) else if "%IPsetStatus%"=="any" (
    set "IPsetStatus=loaded"
    reg add "HKLM\Software\ZapretConfig" /v IPSet /t REG_DWORD /d 1 /f >nul
)
echo IPSet Filter set to: %IPsetStatus%
echo Restart zapret to apply changes
pause
goto menu

:: IPSET UPDATE =======================
:ipset_update
cls
set "listFile=%~dp0lists\ipset-all.txt"
set "url=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/ipset-service.txt"
echo Updating ipset list...
if exist "%SystemRoot%\System32\curl.exe" ( curl -L -o "%listFile%" "%url%" ) else ( powershell -NoProfile -Command "Invoke-WebRequest -Uri '%url%' -OutFile '%listFile%' -TimeoutSec 10" )
echo Done
pause
goto menu

:: HOSTS UPDATE =======================
:hosts_update
cls
set "hostsFile=%SystemRoot%\System32\drivers\etc\hosts"
set "hostsUrl=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/hosts"
set "tempFile=%TEMP%\zapret_hosts.txt"
echo Checking hosts file...
if exist "%SystemRoot%\System32\curl.exe" ( curl -L -s -o "%tempFile%" "%hostsUrl%" ) else ( powershell -NoProfile -Command "Invoke-WebRequest -Uri '%hostsUrl%' -OutFile '%tempFile%' -TimeoutSec 10" )
if not exist "%tempFile%" ( echo Failed to download hosts file & pause & goto menu )
set "firstLine="
for /f "usebackq delims=" %%a in ("%tempFile%") do if not defined firstLine set "firstLine=%%a"
findstr /C:"!firstLine!" "%hostsFile%" >nul 2>&1
if !errorlevel! neq 0 (
    echo Hosts file needs to be updated
    start notepad "%tempFile%"
    explorer /select,"%hostsFile%"
) else (
    echo Hosts file is up to date
    del /f /q "%tempFile%"
)
pause
goto menu

:: CHECK UPDATES =======================
:service_check_updates
cls
echo Checking for updates...
timeout /t 2 > nul

call :get_latest_version

if "%LATEST_VERSION%"=="" (
    echo Failed to check for updates (no internet?)
    pause
    goto menu
)

if "%LOCAL_VERSION%"=="%LATEST_VERSION%" (
    echo Latest version installed: %LOCAL_VERSION%
    pause
    goto menu
)

echo New version available: %LATEST_VERSION%
echo Current version: %LOCAL_VERSION%
echo.
echo Opening download page...
start "" "%GITHUB_DOWNLOAD_URL%"
pause
goto menu

:: DIAGNOSTICS =========================
:service_diagnostics
chcp 437 > nul
cls

sc query BFE | findstr /I "RUNNING" > nul
if !errorlevel!==0 ( call :PrintGreen "Base Filtering Engine check passed" ) else ( call :PrintRed "[X] Base Filtering Engine is not running" )
echo:

set "proxyEnabled=0"
for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable 2^>nul ^| findstr /i "ProxyEnable"') do if "%%B"=="0x1" set "proxyEnabled=1"
if !proxyEnabled!==1 ( call :PrintYellow "[?] System proxy is enabled" ) else ( call :PrintGreen "Proxy check passed" )
echo:

netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul
if !errorlevel!==0 ( call :PrintGreen "TCP timestamps check passed" ) else ( netsh interface tcp set global timestamps=enabled > nul 2>&1 && call :PrintGreen "TCP timestamps enabled" || call :PrintRed "[X] Failed to enable TCP timestamps" )
echo:

tasklist /FI "IMAGENAME eq AdguardSvc.exe" | find /I "AdguardSvc.exe" > nul && call :PrintRed "[X] Adguard process found" || call :PrintGreen "Adguard check passed"
echo:

sc query | findstr /I "Killer" > nul && call :PrintRed "[X] Killer services found" || call :PrintGreen "Killer check passed"
echo:

sc query | findstr /I "Intel" | findstr /I "Connectivity" | findstr /I "Network" > nul && call :PrintRed "[X] Intel Connectivity Network Service found" || call :PrintGreen "Intel Connectivity check passed"
echo:

set "checkpointFound=0"
sc query | findstr /I "TracSrvWrapper" > nul && set "checkpointFound=1"
sc query | findstr /I "EPWD" > nul && set "checkpointFound=1"
if !checkpointFound!==1 ( call :PrintRed "[X] Check Point services found" ) else ( call :PrintGreen "Check Point check passed" )
echo:

sc query | findstr /I "SmartByte" > nul && call :PrintRed "[X] SmartByte services found" || call :PrintGreen "SmartByte check passed"
echo:

set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" call :PrintRed "WinDivert64.sys file NOT found."

set "VPN_SERVICES="
for /f "tokens=2 delims=:" %%A in ('sc query ^| findstr /I "VPN"') do (
    if not defined VPN_SERVICES ( set "VPN_SERVICES=%%A" ) else ( set "VPN_SERVICES=!VPN_SERVICES!,%%A" )
)
if defined VPN_SERVICES ( call :PrintYellow "[?] VPN services found:!VPN_SERVICES!" ) else ( call :PrintGreen "VPN check passed" )
echo:

set "dohfound=0"
for /f "delims=" %%a in ('powershell -NoProfile -Command "Get-ChildItem -Recurse -Path 'HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\' | Get-ItemProperty | Where-Object { $_.DohFlags -gt 0 } | Measure-Object | Select-Object -ExpandProperty Count"') do if %%a gtr 0 set "dohfound=1"
if !dohfound!==0 ( call :PrintYellow "[?] Configure secure DNS in browser or Windows settings" ) else ( call :PrintGreen "Secure DNS check passed" )
echo:

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
set "winws_running=!errorlevel!"
sc query "WinDivert" | findstr /I "RUNNING STOP_PENDING" > nul
set "windivert_running=!errorlevel!"

if !winws_running! neq 0 if !windivert_running!==0 (
    call :PrintYellow "[?] winws.exe not running but WinDivert is active. Attempting to delete..."
    net stop "WinDivert" >nul 2>&1
    sc delete "WinDivert" >nul 2>&1
)

set "conflicting_services=GoodbyeDPI discordfix_zapret winws1 winws2"
set "found_conflicts="
for %%s in (!conflicting_services!) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel!==0 (
        if "!found_conflicts!"=="" ( set "found_conflicts=%%s" ) else ( set "found_conflicts=!found_conflicts! %%s" )
    )
)
if defined found_conflicts (
    call :PrintRed "[X] Conflicting services found: !found_conflicts!"
    set "CHOICE="
    set /p "CHOICE=Remove them? (Y/N) (default: N) "
    if /i "!CHOICE!"=="Y" (
        for %%s in (!found_conflicts!) do (
            net stop "%%s" >nul 2>&1
            sc delete "%%s" >nul 2>&1
        )
        net stop "WinDivert" >nul 2>&1
        sc delete "WinDivert" >nul 2>&1
        net stop "WinDivert14" >nul 2>&1
        sc delete "WinDivert14" >nul 2>&1
    )
    echo:
)

set "CHOICE="
set /p "CHOICE=Clear Discord cache? (Y/N) (default: Y) "
if /i "!CHOICE!"=="Y" (
    tasklist /FI "IMAGENAME eq Discord.exe" | findstr /I "Discord.exe" > nul && taskkill /IM Discord.exe /F > nul
    set "discordCacheDir=%appdata%\discord"
    for %%d in ("Cache" "Code Cache" "GPUCache") do (
        if exist "!discordCacheDir!\%%~d" rd /s /q "!discordCacheDir!\%%~d"
    )
)
echo:

pause
goto menu

:: RUN TESTS ==========================
:run_tests
cls
powershell -NoProfile -Command "if ($PSVersionTable.PSVersion.Major -ge 3) { exit 0 } else { exit 1 }" >nul 2>&1
if %errorLevel% neq 0 (
    echo PowerShell 3.0+ required
    pause
    goto menu
)
start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0utils\test zapret.ps1"
pause
goto menu

:: UTILITY FUNCTIONS ==================
:PrintGreen
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Green"
exit /b

:PrintRed
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Red"
exit /b

:PrintYellow
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Yellow"
exit /b

:check_command
where %1 >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] %1 not found in PATH
    pause
    exit /b 1
)
exit /b 0

:check_extracted
if not exist "%~dp0bin\" (
    echo Zapret must be extracted from archive first
    pause
    exit
)
exit /b 0