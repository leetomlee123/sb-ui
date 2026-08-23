@echo off
set "APP_DIR=C:\Apps\sb ui"
set "SRC_DIR=C:\Temp\stage one"
set "EXE_NAME=sb_ui.exe"

:wait_exit
tasklist /FI "IMAGENAME eq %EXE_NAME%" 2>nul | find /I "%EXE_NAME%" >nul 2>&1
if not errorlevel 1 (
  ping -n 2 127.0.0.1 >nul
  goto wait_exit
)

if exist "%APP_DIR%\%EXE_NAME%" move /y "%APP_DIR%\%EXE_NAME%" "%APP_DIR%\%EXE_NAME%.old" >nul 2>&1

xcopy /e /y /i "%SRC_DIR%\*" "%APP_DIR%\" >nul 2>&1

rem The staging copy includes this script itself; drop the duplicated one.
del /f /q "%APP_DIR%\sb_ui_self_update.bat" >nul 2>&1

if exist "%APP_DIR%\%EXE_NAME%" (
  if exist "%APP_DIR%\%EXE_NAME%.old" del /f /q "%APP_DIR%\%EXE_NAME%.old" >nul 2>&1
)

cd /d "%APP_DIR%"
start "" "%EXE_NAME%"
rd /s /q "%SRC_DIR%" >nul 2>&1
del /f /q "%~f0" >nul 2>&1
