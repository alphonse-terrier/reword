#!/bin/bash
# Builds Reword in Release and packages it into a DMG under the repo root.
#
# Usage: scripts/build-dmg.sh
#
# The app is built ad-hoc signed (no Developer ID) unless CODE_SIGN_IDENTITY is overridden in
# the environment, so first launch requires right-click → Open to bypass Gatekeeper. To sign
# with a real identity: CODE_SIGN_IDENTITY="Developer ID Application: ..." scripts/build-dmg.sh

set -euo pipefail

cd "$(dirname "$0")/.."

CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/Build/Products/Release/Reword.app"

echo "==> Regenerating Xcode project (xcodegen)"
xcodegen generate

echo "==> Building Release configuration"
rm -rf "$BUILD_DIR"
xcodebuild \
  -project Reword.xcodeproj \
  -scheme Reword \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

if [ ! -d "$APP_PATH" ]; then
  echo "error: build succeeded but $APP_PATH is missing" >&2
  exit 1
fi

VERSION=$(defaults read "$(pwd)/$APP_PATH/Contents/Info.plist" CFBundleShortVersionString)
DMG_NAME="Reword-${VERSION}.dmg"

echo "==> Packaging $DMG_NAME"
DMG_STAGING=$(mktemp -d)
trap 'rm -rf "$DMG_STAGING"' EXIT

cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
rm -f "$DMG_NAME"
hdiutil create -volname "Reword" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_NAME"

echo "==> Done: $DMG_NAME"
