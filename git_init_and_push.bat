@echo off
REM ============================================================================
REM One-Click Git Initializer & GitHub Uploader
REM Project: NeuroBIST-Edge
REM ============================================================================

echo ================================================================
echo  Git Setup & GitHub Repository Uploader for NeuroBIST-Edge
echo ================================================================
echo.

if not exist ".git" (
    echo [INIT] Initializing new Git repository...
    git init -b main
)

echo [GIT] Staging tracked source files...
git add .gitignore
git add README.md
git add index.html
git add twin_bridge.py
git add pretrained_weights.json
git add run_dashboard.bat
git add FRESH_START.bat
git add posix_terminal.py
git add run_posix_terminal.bat
git add synch_dual_monitor.py
git add run_synch_monitor.bat
git add neuro_driver.c
git add Makefile
git add arty_s7_neuromorphic_top.v
git add neuromorphic_bist_core.v
git add ArtyS7_Master.xdc
git add esp8266_neuromorphic_synch.ino
git add esp8266_neuromorphic_synch/esp8266_neuromorphic_synch.ino
git add flash_esp8266.bat
git add TOMORROW_RESUME_GUIDE.md
git add neuromorphic_software_engine.cpp
git add tb_neuromorphic_bist.sv
git add build_and_program.tcl
git add program_fpga.bat
git add run_simulation.bat
git add build_and_run_software.bat

echo.
echo [GIT] Committing production release...
git commit -m "Release: NeuroBIST-Edge Heterogeneous Neuromorphic Hardware Co-Processor with Digital Twin & Supervised AI"

echo.
echo.
echo ================================================================
echo  Repository is committed locally!
echo.
echo  To upload to your GitHub:
echo    1. Create an empty repository on GitHub (e.g. 'NeuroBIST-Edge')
echo    2. Copy your GitHub repository URL (e.g. https://github.com/YourUsername/NeuroBIST-Edge.git)
echo ================================================================
echo.
set /p REPO_URL="Enter your GitHub Repo URL (or press Enter to finish): "
if not "%REPO_URL%"=="" (
    echo [GIT] Pushing to %REPO_URL%...
    git remote remove origin 2>nul
    git remote add origin %REPO_URL%
    git branch -M main
    git push -u origin main
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo [SUCCESS] Code successfully pushed to GitHub!
    ) else (
        echo.
        echo [NOTE] Push completed. Verify credentials if required.
    )
)
echo.
pause
