#!/bin/bash
# Builds Reword in Release and packages it into a DMG under the repo root.
#
# Usage: scripts/build-dmg.sh
#
# Signing identity, in order of preference:
#   1. $CODE_SIGN_IDENTITY, if set in the environment.
#   2. The local "Reword Local Dev" self-signed certificate, if present in the keychain
#      (see scripts/create-local-signing-identity.sh) — keeps the app's identity stable across
#      rebuilds, so macOS permissions (Accessibility, etc.) granted once don't get silently
#      revoked on the next build, which happens with true ad-hoc signing.
#   3. Ad-hoc ("-"), if neither of the above apply — first launch then requires right-click →
#      Open to bypass Gatekeeper, and OS permissions may need re-granting after each rebuild.

set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="build"
APP_PATH="$BUILD_DIR/Build/Products/Release/Reword.app"

if [ -n "${CODE_SIGN_IDENTITY:-}" ]; then
  SIGN_IDENTITY="$CODE_SIGN_IDENTITY"
elif security find-identity -v -p codesigning 2>/dev/null | grep -q "Reword Local Dev"; then
  SIGN_IDENTITY="Reword Local Dev"
else
  SIGN_IDENTITY="-"
fi

echo "==> Regenerating Xcode project (xcodegen)"
xcodegen generate

echo "==> Building Release configuration (signing identity: $SIGN_IDENTITY)"
rm -rf "$BUILD_DIR"

if [ "$SIGN_IDENTITY" = "-" ]; then
  xcodebuild \
    -project Reword.xcodeproj \
    -scheme Reword \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build
else
  xcodebuild \
    -project Reword.xcodeproj \
    -scheme Reword \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    DEVELOPMENT_TEAM="" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    build
fi

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
