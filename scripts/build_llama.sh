#!/bin/bash
# build_llama.sh — Build llama.cpp static library for macOS arm64
# Produces: LlamaCpp/lib/libllama.a, LlamaCpp/include/llama.h
# Also produces shared ggml libs used by both llama and whisper

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/_build_llama"
LLAMA_TAG="b8200"    # Pinned llama.cpp release

LLAMA_LIB_DIR="$PROJECT_DIR/LlamaCpp/lib"
LLAMA_INCLUDE_DIR="$PROJECT_DIR/LlamaCpp/include"
GGML_LIB_DIR="$PROJECT_DIR/Whisper/lib"

echo "=== Building llama.cpp ($LLAMA_TAG) for macOS arm64 ==="

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clone llama.cpp at pinned tag
echo "--- Cloning llama.cpp at $LLAMA_TAG ---"
git clone --depth 1 --branch "$LLAMA_TAG" https://github.com/ggerganov/llama.cpp.git llama.cpp
cd llama.cpp

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
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_SERVER=OFF \
    -DLLAMA_CURL=OFF

cmake --build . --config Release -j$(sysctl -n hw.ncpu)

echo "--- Collecting artifacts ---"

# Create output directories
mkdir -p "$LLAMA_LIB_DIR" "$LLAMA_INCLUDE_DIR"

# Copy libllama.a
find . -name "libllama.a" -exec cp {} "$LLAMA_LIB_DIR/libllama.a" \;
echo "Copied libllama.a"

# Copy llama.h
cp ../include/llama.h "$LLAMA_INCLUDE_DIR/llama.h"
echo "Copied llama.h"

# Copy shared ggml libs to Whisper/lib/ (replacing old ones)
for lib in libggml.a libggml-base.a libggml-cpu.a libggml-metal.a libggml-blas.a; do
    found=$(find . -name "$lib" -print -quit)
    if [ -n "$found" ]; then
        cp "$found" "$GGML_LIB_DIR/$lib"
        echo "Copied $lib → Whisper/lib/"
    else
        echo "WARNING: $lib not found"
    fi
done

# Check for any additional ggml libs we might need
echo "--- All ggml libs found in build ---"
find . -name "libggml*.a" -exec basename {} \;

# Copy ggml headers to Whisper/include/ (update existing)
GGML_INCLUDE_DIR="$PROJECT_DIR/Whisper/include"
for header in ggml.h ggml-alloc.h ggml-backend.h ggml-cpp.h ggml-cpu.h ggml-metal.h ggml-opt.h gguf.h; do
    found=$(find ../ggml -name "$header" -print -quit)
    if [ -n "$found" ]; then
        cp "$found" "$GGML_INCLUDE_DIR/$header"
        echo "Updated header: $header"
    fi
done

# Also copy llama-specific ggml headers if any
find ../include -name "*.h" ! -name "llama.h" -exec cp {} "$LLAMA_INCLUDE_DIR/" \;

echo ""
echo "=== llama.cpp build complete ==="
echo "  libllama.a → $LLAMA_LIB_DIR/"
echo "  llama.h    → $LLAMA_INCLUDE_DIR/"
echo "  ggml libs  → $GGML_LIB_DIR/"
echo ""
echo "ggml source commit for whisper rebuild:"
cd "$BUILD_DIR/llama.cpp"
GGML_DIR=$(find . -path "*/ggml/CMakeLists.txt" -exec dirname {} \; | head -1)
echo "  ggml dir: $GGML_DIR"
echo ""
echo "Next: run build_whisper.sh to rebuild whisper.cpp against the same ggml"

# Save ggml source path for whisper build script
echo "$BUILD_DIR/llama.cpp" > "$BUILD_DIR/llama_source_path.txt"
