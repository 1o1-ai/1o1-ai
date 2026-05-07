@echo off
REM 1o1 AI Server Launcher - ManjuLAB
REM Starts the 1o1-ai backend at wss://localhost:8998
REM Frontend: https://yogabrata.com/demo.html
REM Author: whizyoga-ai

title 1o1 AI Server - ManjuLAB

SETLOCAL ENABLEDELAYEDEXPANSION

SET SCRIPT_DIR=%~dp0
SET PARENT_DIR=%SCRIPT_DIR%..
SET VENV_PYTHON=%PARENT_DIR%\.venv\Scripts\python.exe
SET CONFIG=%PARENT_DIR%\config.json
SET LOG=%PARENT_DIR%\server.log

echo.
echo  =============================================
echo   1o1 AI by ManjuLAB
echo   Full-Duplex Conversational AI
echo   https://yogabrata.com
echo  =============================================
echo.

REM Check if venv exists
IF NOT EXIST "%VENV_PYTHON%" (
    echo [ERROR] Virtual environment not found.
    echo Please re-run the installer or run: installer\setup.ps1
    echo.
    pause
    exit /b 1
)

REM Check if config.json exists
IF NOT EXIST "%CONFIG%" (
    echo [WARN] config.json not found, using defaults.
)

echo [1o1-ai] Starting server...
echo [1o1-ai] WebSocket endpoint: wss://localhost:8998
echo [1o1-ai] Connect via: https://yogabrata.com/demo.html
echo [1o1-ai] Logs: %LOG%
echo.
echo Press Ctrl+C to stop the server.
echo.

REM Change to the install root directory
cd /d "%PARENT_DIR%"

REM Activate venv and launch server
"%VENV_PYTHON%" -m uvicorn moshi.server:app ^  
    --host 0.0.0.0 ^  
    --port 8998 ^  
    --ssl-certfile certs\localhost.crt ^  
    --ssl-keyfile certs\localhost.key ^  
    --log-level info ^  
    >> "%LOG%" 2>&1

IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Server exited with code %ERRORLEVEL%
    echo Check logs at: %LOG%
    echo.
    pause
)

ENDLOCAL
