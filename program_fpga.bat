@echo off
REM ============================================================================
REM One-Click Synthesis, Implementation, Bitstream, and Flash Script
REM Project: NeuroBIST-Edge
REM Target: Digilent Arty S7-25 (Spartan-7 XC7S25-CSGA324-1)
REM ============================================================================

set VIVADO_BIN=C:\AMDDesignTools\2025.2\Vivado\bin

echo ================================================================
echo  Synthesizing, Implementing, and Flashing Spartan-7 FPGA...
echo ================================================================
call "%VIVADO_BIN%\vivado.bat" -mode batch -source build_and_program.tcl -nojournal -nolog
if %ERRORLEVEL% NEQ 0 goto error

echo.
echo ================================================================
echo  SUCCESS: NeuroBIST-Edge bitstream programmed to Arty S7-25!
echo ================================================================
pause
exit /b 0

:error
echo.
echo [ERROR] FPGA Build/Program failed! Check log above.
pause
exit /b 1
