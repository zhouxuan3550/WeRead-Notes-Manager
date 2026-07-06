#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
ARCH="${2:-$(uname -m)}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: scripts/package_dmg.sh <version> [arm64|x86_64]" >&2
  exit 1
fi

case "$ARCH" in
  arm64|x86_64) ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    echo "Usage: scripts/package_dmg.sh <version> [arm64|x86_64]" >&2
    exit 1
    ;;
esac

APP_NAME="树懒书摘"
EXECUTABLE_NAME="WeReadNotesManager"
BUNDLE_ID="com.weread.notesmanager"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME-$ARCH.app"
STAGE_DIR="$DIST_DIR/dmg-stage-$ARCH"
ASSET_NAME="$APP_NAME-$VERSION-$ARCH.dmg"
DMG_PATH="$DIST_DIR/$ASSET_NAME"
ICON_PATH="$ROOT_DIR/Sources/WeReadNotesManager/Resources/AppIcon.icns"

cd "$ROOT_DIR"

if [[ ! -f "$ICON_PATH" ]]; then
  echo "Missing app icon: $ICON_PATH" >&2
  exit 1
fi

swift build -c release --arch "$ARCH"

BIN_DIR="$(swift build -c release --arch "$ARCH" --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$EXECUTABLE_NAME"
RESOURCE_BUNDLE="$BIN_DIR/WeReadNotesManager_WeReadNotesManager.bundle"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Missing release executable: $EXECUTABLE_PATH" >&2
  exit 1
fi

if command -v lipo >/dev/null; then
  BUILT_ARCH="$(lipo -archs "$EXECUTABLE_PATH" | tr ' ' '\n' | grep -x "$ARCH" || true)"
  if [[ -z "$BUILT_ARCH" ]]; then
    echo "Release executable does not contain expected architecture: $ARCH" >&2
    lipo -archs "$EXECUTABLE_PATH" >&2 || true
    exit 1
  fi
fi

rm -rf "$APP_DIR" "$STAGE_DIR" "$DMG_PATH"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$STAGE_DIR"

cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
cp "$ICON_PATH" "$APP_DIR/Contents/Resources/AppIcon.icns"
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
  </dict>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"
fi

plutil -lint "$APP_DIR/Contents/Info.plist"

chmod +x "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
codesign --force --deep --sign - "$APP_DIR"

cp -R "$APP_DIR" "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_PATH"
hdiutil verify "$DMG_PATH"

echo "$DMG_PATH"
