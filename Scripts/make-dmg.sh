#!/bin/bash
# Packages Tickline.app into a distributable .dmg with a drag-to-Applications
# affordance, for attaching to a GitHub release.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Tickline"
VERSION="${1:-$(defaults read "$ROOT_DIR/Resources/Info.plist" CFBundleShortVersionString)}"
DMG_PATH="$ROOT_DIR/build/$APP_NAME-$VERSION.dmg"
STAGING_DIR="$ROOT_DIR/build/dmg-staging"

"$ROOT_DIR/Scripts/build-app.sh"

echo "==> Staging DMG contents..."
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$ROOT_DIR/build/$APP_NAME.app" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Building $DMG_PATH..."
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"
echo "Built: $DMG_PATH"
