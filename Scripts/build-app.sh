#!/bin/bash
# Builds Tickline in release mode and assembles it into a real .app bundle
# (no Xcode project needed — just SwiftPM + a hand-written Info.plist).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Tickline"
BUNDLE_DIR="$ROOT_DIR/build/$APP_NAME.app"
BIN_NAME="Tickline"

cd "$ROOT_DIR"

echo "==> Building release binary..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/$BIN_NAME"
if [ ! -f "$BIN_PATH" ]; then
    echo "Build succeeded but binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> Assembling $APP_NAME.app..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp "$BIN_PATH" "$BUNDLE_DIR/Contents/MacOS/$BIN_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"
if [ -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$BUNDLE_DIR/Contents/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$BUNDLE_DIR/Contents/PkgInfo"

echo "==> Ad-hoc code signing..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "Built: $BUNDLE_DIR"
echo "(This build/ copy is not registered with Launch Services — run Scripts/install.sh to install it.)"
