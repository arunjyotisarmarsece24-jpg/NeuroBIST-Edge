@echo off
REM ============================================================================
REM One-Click Launcher: Synchronized Hardware Monitor (ESP8266 + Arty S7 FPGA)
REM ============================================================================

title Synchronized Hardware Monitor: ESP8266 (COM4) + Arty S7 FPGA (COM5)
color 0B
cd /d "%~dp0"
python synch_dual_monitor.py
pause
