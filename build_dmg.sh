#!/bin/zsh
# Build Orpheus and package as a DMG for GitHub distribution.
# Usage: ./build_dmg.sh [version]
# Example: ./build_dmg.sh 1.1

set -e

VERSION="${1:-1.0}"
ARCHIVE=/tmp/Orpheus.xcarchive
STAGE=/tmp/dmg_stage
RELEASE_DIR="$(dirname "$0")/release"

echo "==> Building Orpheus $VERSION..."
rm -rf "$ARCHIVE" "$STAGE"

xcodebuild -project MusicOverlay.xcodeproj \
  -scheme MusicOverlay \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  archive \
  CODE_SIGN_STYLE=Automatic \
  2>&1 | grep -E "error:|warning:|ARCHIVE"

echo "==> Staging..."
mkdir -p "$STAGE"
cp -R "$ARCHIVE/Products/Applications/Orpheus.app" "$STAGE/"
ln -sf /Applications "$STAGE/Applications"

echo "==> Creating DMG..."
mkdir -p "$RELEASE_DIR"
hdiutil create \
  -volname "Orpheus" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$RELEASE_DIR/Orpheus-$VERSION.dmg"

echo "==> Done: $RELEASE_DIR/Orpheus-$VERSION.dmg"
open "$RELEASE_DIR"
