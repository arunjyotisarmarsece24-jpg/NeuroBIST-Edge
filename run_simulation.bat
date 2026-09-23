@echo off
REM ============================================================================
REM One-Click Vivado Simulation Batch Script for Neuromorphic BIST Core
REM ============================================================================

set VIVADO_BIN=C:\AMDDesignTools\2025.2\Vivado\bin

echo ================================================================
echo  Compiling neuromorphic_bist_core and testbench with xvlog...
echo ================================================================
call "%VIVADO_BIN%\xvlog.bat" -sv neuromorphic_bist_core.v tb_neuromorphic_bist.sv
if %ERRORLEVEL% NEQ 0 goto error

echo.
echo ================================================================
echo  Elaborating simulation snapshot with xelab...
echo ================================================================
call "%VIVADO_BIN%\xelab.bat" -top tb_neuromorphic_bist -snapshot sim_neuro_snap -debug typical
if %ERRORLEVEL% NEQ 0 goto error

echo.
echo ================================================================
echo  Running simulation with xsim...
echo ================================================================
call "%VIVADO_BIN%\xsim.bat" sim_neuro_snap -runall
if %ERRORLEVEL% NEQ 0 goto error

echo.
echo [SUCCESS] Neuromorphic BIST Simulation completed successfully!
pause
exit /b 0

:error
echo.
echo [ERROR] Simulation failed! Check above log.
pause
exit /b 1
