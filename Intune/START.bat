@echo off
REM ================================================================================
REM AUTOPILOT HASH COLLECTOR - LAUNCHER
REM ================================================================================
REM
REM This batch file launches the AutopilotHashCollector.ps1 script with the
REM proper PowerShell execution policy to allow script execution during OOBE.
REM
REM USAGE:
REM   1. At the OOBE screen, press Shift + F10 to open Command Prompt
REM   2. Navigate to your USB drive (e.g., type "E:" and press Enter)
REM   3. Type "START.bat" and press Enter
REM
REM ================================================================================

echo.
echo ================================================================================
echo                    AUTOPILOT HASH COLLECTOR - MOTHER PROTOCOL
echo                              Starting System...
echo ================================================================================
echo.

REM Change to the directory where this batch file is located
REM This ensures we can find the .ps1 script regardless of current directory
cd /d "%~dp0"

REM Launch PowerShell with execution policy bypass and run the script
REM -ExecutionPolicy Bypass: Allows the script to run without changing system policy
REM -NoProfile: Speeds up launch by skipping profile loading
REM -File: Specifies the script to execute
powershell.exe -ExecutionPolicy Bypass -NoProfile -File ".\AutopilotHashCollector.ps1"

REM If the script exits with an error, pause so the user can see the error message
if errorlevel 1 (
    echo.
    echo [ERROR] Script encountered an error. Press any key to exit...
    pause >nul
)
