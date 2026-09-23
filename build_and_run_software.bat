@echo off
REM ============================================================================
REM Build and Run Script for Neuromorphic Software Engine
REM Uses MinGW-w64 G++ Toolchain with Static Linking
REM ============================================================================

set GPP_PATH=C:\AMDDesignTools\2025.2\Vivado\tps\mingw\6.2.0\win64.o\nt\bin\g++.exe

echo ================================================================
echo  Compiling neuromorphic_software_engine.cpp with G++ (-O3)...
echo ================================================================
"%GPP_PATH%" -static -O3 -Wall -Wextra neuromorphic_software_engine.cpp -o neuromorphic_software_engine.exe
if %ERRORLEVEL% NEQ 0 goto error

echo.
echo ================================================================
echo  Running neuromorphic_software_engine.exe...
echo ================================================================
neuromorphic_software_engine.exe
if %ERRORLEVEL% NEQ 0 goto error

echo.
echo [SUCCESS] Software pipeline verified 100%%!
pause
exit /b 0

:error
echo.
echo [ERROR] Compilation or execution failed!
pause
exit /b 1
