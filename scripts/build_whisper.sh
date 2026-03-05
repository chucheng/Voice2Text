#!/bin/bash
# build_whisper.sh — Rebuild whisper.cpp against the same ggml used by llama.cpp
# Must run after build_llama.sh
# Produces: Whisper/lib/libwhisper.a (compatible with shared ggml libs)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/_build_llama"
WHISPER_BUILD_DIR="$SCRIPT_DIR/_build_whisper"
WHISPER_TAG="v1.8.3"    # Pinned whisper.cpp release

WHISPER_LIB_DIR="$PROJECT_DIR/Whisper/lib"
WHISPER_INCLUDE_DIR="$PROJECT_DIR/Whisper/include"

# Check that llama.cpp was built first
if [ ! -f "$BUILD_DIR/llama_source_path.txt" ]; then
    echo "ERROR: Run build_llama.sh first to build ggml libs"
    exit 1
fi
LLAMA_SOURCE=$(cat "$BUILD_DIR/llama_source_path.txt")

echo "=== Rebuilding whisper.cpp ($WHISPER_TAG) against llama.cpp ggml ==="
echo "  llama.cpp source: $LLAMA_SOURCE"

# Clean previous whisper build
rm -rf "$WHISPER_BUILD_DIR"
mkdir -p "$WHISPER_BUILD_DIR"
cd "$WHISPER_BUILD_DIR"

# Clone whisper.cpp at pinned tag
echo "--- Cloning whisper.cpp at $WHISPER_TAG ---"
git clone --depth 1 --branch "$WHISPER_TAG" https://github.com/ggerganov/whisper.cpp.git whisper.cpp
cd whisper.cpp

# Replace whisper's ggml with llama's ggml for ABI compatibility
echo "--- Replacing ggml source with llama.cpp's version ---"
if [ -d "ggml" ]; then
    rm -rf ggml
    cp -R "$LLAMA_SOURCE/ggml" ggml
    echo "Replaced ggml/ directory"
else
    echo "WARNING: No ggml/ directory found in whisper.cpp — structure may have changed"
fi

# Build with CMake
echo "--- Building with CMake ---"
mkdir build && cd build
cmake .. \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="14.0" \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_METAL=ON \
    -DGGML_BLAS=ON \
    -DGGML_BLAS_USE_ACCELERATE=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=OFF

cmake --build . --config Release -j$(sysctl -n hw.ncpu)

echo "--- Collecting artifacts ---"

# Copy libwhisper.a (only the whisper lib, ggml libs come from llama build)
found=$(find . -name "libwhisper.a" -print -quit)
if [ -n "$found" ]; then
    cp "$found" "$WHISPER_LIB_DIR/libwhisper.a"
    echo "Copied libwhisper.a → Whisper/lib/"
else
    echo "ERROR: libwhisper.a not found!"
    exit 1
fi

# Update whisper.h if needed
cp ../include/whisper.h "$WHISPER_INCLUDE_DIR/whisper.h"
echo "Updated whisper.h"

echo ""
echo "=== whisper.cpp rebuild complete ==="
echo "  libwhisper.a → $WHISPER_LIB_DIR/"
echo ""
echo "Library summary in Whisper/lib/:"
ls -la "$WHISPER_LIB_DIR/"
echo ""
echo "Both whisper and llama now share the same ggml ABI."
echo "Run 'xcodegen generate' to regenerate the Xcode project."
