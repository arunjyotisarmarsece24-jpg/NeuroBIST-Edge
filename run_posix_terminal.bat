@echo off
REM ============================================================================
REM One-Click Launcher: term0 POSIX Silicon Terminal for Arty S7 & ESP8266
REM ============================================================================

title term0 - POSIX Silicon Shell (Arty S7-25 Neuromorphic)
color 0A
cd /d "%~dp0"
python posix_terminal.py
pause
