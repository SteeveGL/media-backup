@echo off
REM Windows batch script to run media-backup
REM Usage: backup.bat [config_file]
REM Example: backup.bat backup-config.yaml

setlocal enabledelayedexpansion

REM Get script directory
set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python is not installed or not in PATH
    echo Please install Python from https://www.python.org/
    pause
    exit /b 1
)

REM Check if AWS CLI is installed
aws --version >nul 2>&1
if errorlevel 1 (
    echo Error: AWS CLI is not installed or not in PATH
    echo Please install from https://aws.amazon.com/cli/
    echo Or run: pip install awscli
    pause
    exit /b 1
)

REM Check if config file exists
if "%~1"=="" (
    set CONFIG_FILE=backup-config.yaml
) else (
    set CONFIG_FILE=%~1
)

if not exist "!CONFIG_FILE!" (
    echo Error: Config file not found: !CONFIG_FILE!
    echo Please create a config file or check the path
    pause
    exit /b 1
)

echo Running backup with config: !CONFIG_FILE!
echo.

python backup.py "!CONFIG_FILE!"
set EXIT_CODE=!errorlevel!

if !EXIT_CODE! neq 0 (
    echo.
    echo Backup completed with errors (exit code: !EXIT_CODE!)
) else (
    echo.
    echo Backup completed successfully
)

endlocal
exit /b !EXIT_CODE!
