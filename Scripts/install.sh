#!/bin/bash
# Builds Tickline and installs it to /Applications, then sets it as the
# default handler for common Markdown extensions.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Tickline"
DEST="/Applications/$APP_NAME.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

"$ROOT_DIR/Scripts/build-app.sh"

echo "==> Installing to $DEST..."
rm -rf "$DEST"
cp -R "$ROOT_DIR/build/$APP_NAME.app" "$DEST"
codesign --force --deep --sign - "$DEST"

echo "==> Registering with Launch Services..."
"$LSREGISTER" -f "$DEST"

if command -v duti >/dev/null 2>&1; then
    echo "==> Setting Tickline as the default Markdown viewer..."
    duti -s com.luke.tickline net.daringfireball.markdown all || true
    duti -s com.luke.tickline io.typora.markdown all || true
else
    cat <<'EOF'
==> duti not found — set the default manually:
    Right-click a .md file in Finder > Get Info > Open with: > Tickline > Change All...
    (or: brew install duti)
EOF
fi

echo "Installed: $DEST"
