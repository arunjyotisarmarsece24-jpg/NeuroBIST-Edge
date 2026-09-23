@echo off
REM ============================================================================
REM One-Click Launcher: NeuroBIST-Edge Digital Twin & Supervised AI Dashboard
REM ============================================================================

echo ================================================================
echo  Launching NeuroBIST-Edge Digital Twin Dashboard...
echo ================================================================
echo.
echo Checking Python environment...
python -c "import websockets, serial; print('[OK] Python dependencies verified.')"
if %ERRORLEVEL% NEQ 0 (
    echo [INFO] Installing required bridge packages: websockets pyserial
    pip install websockets pyserial
)

echo.
echo Starting Bridge Server and Web Dashboard (http://localhost:8000)...
python twin_bridge.py
pause
