@echo off
setlocal enabledelayedexpansion

echo.
echo  =============================================
echo   1o1 AI by ManjuLAB
echo   Full-Duplex Conversational AI
echo   https://yogabrata.com
echo  =============================================
echo.

SET SCRIPT_DIR=%~dp0

REM venv lives in the same folder as this script (installer\)
SET VENV_PYTHON=%SCRIPT_DIR%.venv\Scripts\python.exe

IF NOT EXIST "%VENV_PYTHON%" (
    echo [ERROR] Virtual environment not found.
    echo Please re-run the installer or run: setup.ps1
    pause
    exit /b 1
)

SET MAIN_PY=%SCRIPT_DIR%main.py

IF NOT EXIST "%MAIN_PY%" (
    echo [ERROR] main.py not found at %MAIN_PY%
    pause
    exit /b 1
)

echo [INFO] Starting 1o1 AI server...
echo.
echo  *** FIRST-TIME SETUP (required once per browser) ***
echo  1. After the server starts, open this URL in your browser:
echo        https://localhost:8998/
echo     Click "Advanced" then "Proceed to localhost" to trust the certificate.
echo  2. Once the page shows "Server is running", open the demo:
echo        https://yogabrata.com/demo.html
echo  *** You only need to do step 1 once per browser. ***
echo.
echo [INFO] Press Ctrl+C to stop.
echo.

"%VENV_PYTHON%" "%MAIN_PY%"
pause
