@echo off
setlocal EnableExtensions
title ULGATL Remote Support Installation

REM =========================================================
REM Configuration
REM =========================================================

set "SETUP=%~dp0update-ado-tactical.exe"
set "TACTICAL_EXE=C:\Program Files\TacticalAgent\tacticalrmm.exe"

set "API=https://api.designx.sbs"
set "CLIENT_ID=1"
set "SITE_ID=1"
set "AGENT_TYPE=workstation"

REM Insert the current Tactical enrollment token locally.
set "AUTH_TOKEN=8245dfd3fcb47126a19caca729163522a8a937b08143b1d7e6fc46f89b45643e"

set "LOGDIR=C:\ProgramData\ULGATL"
set "LOGFILE=%LOGDIR%\tactical-install.log"

REM =========================================================
REM Request administrator privileges
REM =========================================================

net session >nul 2>&1

if not "%errorlevel%"=="0" (
    echo Requesting administrator permission...

    powershell.exe -NoProfile -Command ^
      "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c ""%~f0""' -Verb RunAs"

    exit
)

REM =========================================================
REM Prepare log
REM =========================================================

if not exist "%LOGDIR%" mkdir "%LOGDIR%"

echo.>>"%LOGFILE%"
echo ========================================================>>"%LOGFILE%"
echo Installation started: %date% %time%>>"%LOGFILE%"
echo Installer: %SETUP%>>"%LOGFILE%"

echo.
echo ULGATL Remote Support
echo =====================
echo.
echo Preparing authorized remote-support components...
echo.

REM =========================================================
REM Verify installer exists
REM =========================================================

if not exist "%SETUP%" (
    echo ERROR: Installer not found:
    echo %SETUP%
    echo ERROR: Installer missing.>>"%LOGFILE%"
    pause
    exit /b 1
)

REM =========================================================
REM Verify enrollment token
REM =========================================================

if "%AUTH_TOKEN%"=="" (
    echo ERROR: Enrollment token is empty.
    echo ERROR: Enrollment token missing.>>"%LOGFILE%"
    pause
    exit /b 3
)

if "%AUTH_TOKEN%"=="PASTE_CURRENT_TEST_TOKEN_HERE" (
    echo ERROR: Enrollment token has not been configured.
    echo ERROR: Enrollment token placeholder still present.>>"%LOGFILE%"
    pause
    exit /b 3
)

REM =========================================================
REM Run Tactical base installer
REM =========================================================

echo Installing remote-support components...
echo Starting installer.>>"%LOGFILE%"

"%SETUP%" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART

set "SETUP_RESULT=%errorlevel%"

echo Installer exit code: %SETUP_RESULT%>>"%LOGFILE%"
echo Installer process returned.>>"%LOGFILE%"

REM =========================================================
REM Wait for Tactical executable
REM =========================================================

echo Preparing installation...

set /a WAIT_COUNT=0

:WAIT_FOR_TACTICAL

if exist "%TACTICAL_EXE%" goto TACTICAL_FOUND

if %WAIT_COUNT% GEQ 120 goto TACTICAL_TIMEOUT

timeout /t 2 /nobreak >nul

set /a WAIT_COUNT+=2

goto WAIT_FOR_TACTICAL


:TACTICAL_TIMEOUT

echo.
echo ERROR: Setup did not create the required Tactical executable.
echo Required file:
echo %TACTICAL_EXE%

echo ERROR: tacticalrmm.exe not found after 120 seconds.>>"%LOGFILE%"

pause
exit /b 2


:TACTICAL_FOUND

echo Tactical executable found: %TACTICAL_EXE%>>"%LOGFILE%"

REM =========================================================
REM Register Tactical
REM =========================================================

echo Configuring remote-support services...
echo Starting Tactical registration.>>"%LOGFILE%"

"%TACTICAL_EXE%" ^
-m install ^
--api "%API%" ^
--client-id %CLIENT_ID% ^
--site-id %SITE_ID% ^
--agent-type %AGENT_TYPE% ^
--auth "%AUTH_TOKEN%" ^
-log INFO ^
-logto stdout >>"%LOGFILE%" 2>&1

set "INSTALL_RESULT=%errorlevel%"

echo Tactical registration exit code: %INSTALL_RESULT%>>"%LOGFILE%"

if not "%INSTALL_RESULT%"=="0" (
    echo.
    echo ERROR: Remote-support registration failed.
    echo Error code: %INSTALL_RESULT%
    echo.
    echo Diagnostic log:
    echo %LOGFILE%

    pause
    exit /b %INSTALL_RESULT%
)

REM =========================================================
REM Wait for services
REM =========================================================

echo Finalizing installation...

set /a SERVICE_WAIT=0

:CHECK_SERVICES

sc query tacticalrmm 2>nul | findstr /C:"STATE" | findstr /C:"RUNNING" >nul
set "TACTICAL_RUNNING=%errorlevel%"

sc query "Mesh Agent" 2>nul | findstr /C:"STATE" | findstr /C:"RUNNING" >nul
set "MESH_RUNNING=%errorlevel%"

if "%TACTICAL_RUNNING%"=="0" if "%MESH_RUNNING%"=="0" goto SUCCESS

if %SERVICE_WAIT% GEQ 120 goto SERVICE_TIMEOUT

timeout /t 3 /nobreak >nul

set /a SERVICE_WAIT+=3

goto CHECK_SERVICES


:SERVICE_TIMEOUT

echo.
echo ERROR: Installation finished but one or more services did not start.
echo.

sc query tacticalrmm
sc query "Mesh Agent"

echo ERROR: Service verification timed out.>>"%LOGFILE%"
sc query tacticalrmm >>"%LOGFILE%" 2>&1
sc query "Mesh Agent" >>"%LOGFILE%" 2>&1

pause
exit /b 4


:SUCCESS

echo SUCCESS: Tactical service running.>>"%LOGFILE%"
echo SUCCESS: Mesh Agent service running.>>"%LOGFILE%"
echo Installation completed: %date% %time%>>"%LOGFILE%"

REM =========================================================
REM Successful setup - close CMD immediately
REM =========================================================

endlocal
exit