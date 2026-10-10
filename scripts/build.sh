#!/usr/bin/env bash
# Builds HideNotch.app and HideNotch.dmg into ./build.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
APP="build/HideNotch.app"
DMG="build/HideNotch-${VERSION}.dmg"

swift build -c release --arch arm64 --arch x86_64

rm -rf "$APP" "$DMG" build/dmg
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/HideNotch" "$APP/Contents/MacOS/HideNotch"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>HideNotch</string>
    <key>CFBundleDisplayName</key><string>HideNotch</string>
    <key>CFBundleIdentifier</key><string>com.agpriyanshu.HideNotch</string>
    <key>CFBundleExecutable</key><string>HideNotch</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.graphics-design</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>Wallpaper</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSHandlerRank</key><string>None</string>
            <key>LSItemContentTypes</key>
            <array><string>public.image</string><string>public.folder</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough to run locally, not a Developer ID signature.
codesign --force --deep --sign - "$APP"

mkdir -p build/dmg
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -volname "HideNotch" -srcfolder build/dmg -ov -format UDZO "$DMG" >/dev/null
rm -rf build/dmg

echo "$APP"
echo "$DMG"
