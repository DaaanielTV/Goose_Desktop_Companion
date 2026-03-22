@echo off
REM Build script for Goose Desktop Companion - Windows

cd /d "%~dp0.."

echo.
echo ========================================
echo Goose Desktop Companion - Build Script
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.9+ and add it to your system PATH
    exit /b 1
)

echo [1/3] Installing dependencies...
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    exit /b 1
)

echo.
echo [2/3] Installing PyInstaller...
pip install pyinstaller
if errorlevel 1 (
    echo ERROR: Failed to install PyInstaller
    exit /b 1
)

echo.
echo [3/3] Building executable...
pyinstaller build\build.spec
if errorlevel 1 (
    echo ERROR: Failed to build executable
    exit /b 1
)

echo.
echo ========================================
echo Build complete!
echo Executable: dist\GooseDesktop\GooseDesktop.exe
echo ========================================
echo.

pause
