#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/Walter Water.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
CACHE_ROOT="${TMPDIR:-/private/tmp}/walterwater-swift-cache"
mkdir -p "$CACHE_ROOT/clang" "$CACHE_ROOT/swift"
CLANG_MODULE_CACHE_PATH="$CACHE_ROOT/clang" SWIFT_MODULECACHE_PATH="$CACHE_ROOT/swift" \
    swiftc -parse-as-library -O -framework AppKit -framework SwiftUI "$ROOT/Sources/main.swift" -o "$APP/Contents/MacOS/WalterWater"
cp "$ROOT/Resources/water.gif" "$APP/Contents/Resources/water.gif"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Walter Water</string>
    <key>CFBundleDisplayName</key><string>Walter Water</string>
    <key>CFBundleIdentifier</key><string>com.walterwater.reminder</string>
    <key>CFBundleExecutable</key><string>WalterWater</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
/usr/libexec/PlistBuddy -c 'Print' "$APP/Contents/Info.plist" >/dev/null
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built %s\n' "$APP"
