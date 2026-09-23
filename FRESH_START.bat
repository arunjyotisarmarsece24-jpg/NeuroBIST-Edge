@echo off
REM ============================================================================
REM One-Click Fresh Start Launcher for NeuroBIST-Edge
REM Re-initializes FPGA, ESP8266 Bridge, and Launches Synchronized Dashboard
REM ============================================================================

title NeuroBIST-Edge: Fresh Start & Hardware Resync
color 0A

echo ================================================================
echo  NeuroBIST-Edge: 1-Click Fresh Start & System Resync
echo ================================================================
echo.

echo [0/4] Freeing COM ports and cleaning stale background bridge processes...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8765') do taskkill /f /pid %%a 2>nul
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8000') do taskkill /f /pid %%a 2>nul
timeout /t 1 /nobreak >nul

echo [1/4] Checking Vivado hardware and programming Spartan-7 FPGA...
call "C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat" -mode batch -source program_only.tcl -nolog -nojournal
if %ERRORLEVEL% NEQ 0 (
    echo [WARN] FPGA programming step completed with warnings, continuing...
) else (
    echo [OK] Spartan-7 FPGA programmed successfully with neurobist_edge.bit!
)

echo.
echo [2/4] Verifying Python dependencies (websockets, pyserial)...
python -c "import websockets, serial; print('  [OK] Dependencies verified.')"

echo.
echo [3/4] Opening Digital Twin Dashboard in default browser...
start "" "http://localhost:8000"

echo.
echo [4/4] Starting Bidirectional Hardware Bridge Server on COM4 / COM5...
echo ================================================================
echo  ESP8266 Serial Monitor and Hardware Synchronizer Active!
echo  Press Ctrl+C to stop the bridge.
echo ================================================================
python -u twin_bridge.py

pause
