#!/bin/bash
# Build script for Goose Desktop Companion - macOS/Linux

cd "$(dirname "$0")/.."

echo ""
echo "========================================"
echo "Goose Desktop Companion - Build Script"
echo "========================================"
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed"
    exit 1
fi

echo "[1/3] Installing dependencies..."
python3 -m pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install dependencies"
    exit 1
fi

echo ""
echo "[2/3] Installing PyInstaller..."
python3 -m pip install pyinstaller
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install PyInstaller"
    exit 1
fi

echo ""
echo "[3/3] Building executable..."
python3 -m PyInstaller build/build.spec
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build executable"
    exit 1
fi

echo ""
echo "========================================"
echo "Build complete!"
echo "Executable: dist/GooseDesktop/GooseDesktop"
echo "========================================"
echo ""
