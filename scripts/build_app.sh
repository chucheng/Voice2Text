#!/bin/bash
#
# Build PunctuationServer.app using PyInstaller
# Usage: cd scripts && bash build_app.sh
# Output: dist/PunctuationServer.app
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

VENV_DIR="$SCRIPT_DIR/.build_venv"
DIST_DIR="$SCRIPT_DIR/dist"

echo "=== PunctuationServer.app Builder ==="
echo ""

# Clean previous build artifacts
if [ -d "$SCRIPT_DIR/build" ]; then
    echo "Cleaning previous build directory..."
    rm -rf "$SCRIPT_DIR/build"
fi

# Create temporary venv
if [ -d "$VENV_DIR" ]; then
    echo "Removing existing build venv..."
    rm -rf "$VENV_DIR"
fi

echo "Creating build virtualenv..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

echo "Installing dependencies..."
pip install --upgrade pip -q
pip install torch transformers pyinstaller -q

echo ""
echo "Running PyInstaller..."
pyinstaller PunctuationServer.spec --noconfirm

echo ""
# Clean up venv
echo "Cleaning up build venv..."
rm -rf "$VENV_DIR"
rm -rf "$SCRIPT_DIR/build"

# Verify output
APP_PATH="$DIST_DIR/PunctuationServer.app"
if [ -d "$APP_PATH" ]; then
    APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
    echo "=== Build successful ==="
    echo "  Output: $APP_PATH"
    echo "  Size:   $APP_SIZE"
    echo ""
    echo "To test:"
    echo "  open $APP_PATH"
    echo "  curl http://127.0.0.1:18230/health"
else
    echo "ERROR: Build failed — $APP_PATH not found"
    exit 1
fi
