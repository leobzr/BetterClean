#!/bin/zsh
# Builds BetterClean and wraps it in an app bundle at build/BetterClean.app.
#
#   scripts/build-app.sh            # debug build (20 s auto-unlock)
#   scripts/build-app.sh release    # release build (180 s auto-unlock)
#
# Signing: set SIGN_IDENTITY to a certificate name (see `security find-identity -p codesigning`)
# to keep the Accessibility permission across rebuilds. Without one the app is
# ad-hoc signed, and macOS treats every rebuild as a new app: remove and re-add
# it in System Settings › Privacy & Security › Accessibility after each build.
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="${0:A:h:h}"
APP="$ROOT/build/BetterClean.app"
BUNDLE_ID="local.betterclean.prototype"

cd "$ROOT"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/BetterClean"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/BetterClean"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>BetterClean</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>BetterClean</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign "${SIGN_IDENTITY:--}" --identifier "$BUNDLE_ID" "$APP"
echo "Built $APP ($CONFIG, signed with ${SIGN_IDENTITY:-ad-hoc})"
