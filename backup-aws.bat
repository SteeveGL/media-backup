@echo off
REM Pure AWS CLI backup script - no Python required
REM Only dependency: AWS CLI
REM Usage: backup-aws.bat

setlocal enabledelayedexpansion

REM Configuration
set S3_BUCKET=my-backup-bucket
set SKIP_ERRORS=false

REM Your directories here (adjust paths as needed)
set "DIRS[0]=D:\Pictures|pictures"
set "DIRS[1]=D:\Documents|docs"
set "DIRS[2]=D:\Videos|videos"

REM Check if AWS CLI is installed
aws --version >nul 2>&1
if errorlevel 1 (
    echo Error: AWS CLI not found
    echo Install from: https://aws.amazon.com/cli/
    exit /b 1
)

echo Starting backup to: s3://%S3_BUCKET%
echo.

REM Counter for directories
set COUNT=0
for /f "tokens=1" %%A in ('set DIRS[') do (
    set /a COUNT+=1
)

echo Number of directories: %COUNT%
echo ------------------------------------------------------------
echo.

REM Backup each directory
set SUCCESS=0
set FAILED=0

REM Backup directory 1
echo [%date% %time%] Syncing: D:\Pictures ^-^> s3://%S3_BUCKET%/pictures
aws s3 sync "D:\Pictures" "s3://%S3_BUCKET%/pictures" --delete ^
    --exclude "Thumbs.db" ^
    --exclude "*.tmp"
if errorlevel 1 (
    echo X Backup failed
    set /a FAILED+=1
    if "%SKIP_ERRORS%"=="false" exit /b 1
) else (
    echo ✓ Backup successful
    set /a SUCCESS+=1
)
echo.

REM Backup directory 2
echo [%date% %time%] Syncing: D:\Documents ^-^> s3://%S3_BUCKET%/docs
aws s3 sync "D:\Documents" "s3://%S3_BUCKET%/docs" --delete ^
    --exclude ".git" ^
    --exclude "node_modules"
if errorlevel 1 (
    echo X Backup failed
    set /a FAILED+=1
    if "%SKIP_ERRORS%"=="false" exit /b 1
) else (
    echo ✓ Backup successful
    set /a SUCCESS+=1
)
echo.

REM Backup directory 3
echo [%date% %time%] Syncing: D:\Videos ^-^> s3://%S3_BUCKET%/videos
aws s3 sync "D:\Videos" "s3://%S3_BUCKET%/videos" --delete ^
    --exclude "*.partial"
if errorlevel 1 (
    echo X Backup failed
    set /a FAILED+=1
    if "%SKIP_ERRORS%"=="false" exit /b 1
) else (
    echo ✓ Backup successful
    set /a SUCCESS+=1
)
echo.

echo ------------------------------------------------------------
echo Completed: %SUCCESS% successful, %FAILED% failed
if %FAILED% gtr 0 exit /b 1
