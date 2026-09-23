@echo off
REM ============================================================================
REM One-Click Firmware Flasher for ESP8266 Neuromorphic Edge Gateway
REM Target: ESP8266 NodeMCU v1.0 (Silicon Labs CP210x on COM4)
REM ============================================================================

set ARDUINO_CLI=C:\Program Files\Arduino IDE\resources\app\lib\backend\resources\arduino-cli.exe
set PORT=COM4
set FQBN=esp8266:esp8266:nodemcuv2
set SKETCH_DIR=%~dp0esp8266_neuromorphic_synch

echo ================================================================
echo  Flashing esp8266_neuromorphic_synch to %PORT% (%FQBN%)...
echo ================================================================

if not exist "%ARDUINO_CLI%" (
    echo [ERROR] arduino-cli.exe not found at %ARDUINO_CLI%
    echo Please open esp8266_neuromorphic_synch.ino in Arduino IDE and upload manually.
    pause
    exit /b 1
)

echo.
echo [1/2] Compiling sketch...
"%ARDUINO_CLI%" compile -b %FQBN% "%SKETCH_DIR%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    pause
    exit /b 1
)

echo.
echo [2/2] Uploading binary to ESP8266 on %PORT%...
"%ARDUINO_CLI%" upload -p %PORT% -b %FQBN% "%SKETCH_DIR%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Upload failed! Make sure Arduino Serial Monitor is closed.
    pause
    exit /b 1
)

echo.
echo ================================================================
echo  SUCCESS: ESP8266 flashed with Neuromorphic Gateway firmware!
echo ================================================================
pause
exit /b 0
