#!/bin/bash
# Build Voice2Text.dmg for distribution
# Usage: bash scripts/build_dmg.sh
#
# Prerequisites:
#   - Xcode 15+ with command line tools
#   - XcodeGen (brew install xcodegen)
#
# Output: build/Voice2Text-<version>.dmg

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/Voice2Text.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_STAGING="$BUILD_DIR/dmg_staging"
APP_NAME="Voice2Text"

# Read version from project.yml
VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_DIR/project.yml" | head -1 | sed 's/.*"\(.*\)".*/\1/')
DMG_PATH="$BUILD_DIR/${APP_NAME}-${VERSION}.dmg"

cd "$PROJECT_DIR"

echo "==> Regenerating Xcode project..."
xcodegen generate

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building archive..."
xcodebuild archive \
    -project Voice2Text.xcodeproj \
    -scheme Voice2Text \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "platform=macOS" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=YES \
    ARCHS=arm64 \
    | tail -20

echo "==> Exporting app..."
# Extract .app directly from the archive (no signing needed for ad-hoc)
mkdir -p "$EXPORT_DIR"
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$EXPORT_DIR/"

# Ad-hoc sign so macOS doesn't immediately quarantine-block it
codesign --force --deep --sign - "$EXPORT_DIR/$APP_NAME.app" 2>/dev/null || true

echo "==> Creating DMG..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$EXPORT_DIR/$APP_NAME.app" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

# Include Getting Started guide if docs exist
DOCS_DIR="$PROJECT_DIR/docs"
if [ -d "$DOCS_DIR" ] && [ -f "$DOCS_DIR/Getting Started.html" ]; then
    echo "==> Including Getting Started guide..."
    cp "$DOCS_DIR/Getting Started.html" "$DMG_STAGING/"
    if [ -d "$DOCS_DIR/images" ] && [ "$(ls -A "$DOCS_DIR/images" 2>/dev/null)" ]; then
        mkdir -p "$DMG_STAGING/images"
        cp -R "$DOCS_DIR/images/"* "$DMG_STAGING/images/"
    fi
fi

# Remove old DMG if exists
rm -f "$DMG_PATH"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Clean up staging
rm -rf "$DMG_STAGING"

echo ""
echo "==> Done! DMG created at:"
echo "    $DMG_PATH"
echo ""
echo "    Size: $(du -h "$DMG_PATH" | cut -f1)"
