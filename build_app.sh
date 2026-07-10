#!/bin/bash

# Exit on error
set -e

APP_NAME="Sonix"
EXECUTABLE_NAME="SonixMac"
BUNDLE_DIR="$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🧹 Cleaning previous build..."
swift package clean

echo "🔨 Building release binary using Swift Package Manager..."
swift build -c release --arch arm64 --arch x86_64

echo "📦 Creating macOS App Bundle structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "🚚 Moving binary into App Bundle..."
cp .build/apple/Products/Release/$EXECUTABLE_NAME "$MACOS_DIR/$APP_NAME" 2>/dev/null || cp .build/release/$EXECUTABLE_NAME "$MACOS_DIR/$APP_NAME"

echo "🎨 Copying AppIcon..."
cp Resources/AppIcon.icns "$RESOURCES_DIR/" 2>/dev/null || true

echo "📝 Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.sonix.mac</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

# Touch the app bundle to force Finder to refresh the icon cache
touch "$BUNDLE_DIR"

echo "💿 Creating macOS DMG file..."
DMG_NAME="${APP_NAME}.dmg"
DMG_TMP_DIR="dmg_tmp"

# Clean up previous dmg if exists
rm -f "$DMG_NAME"
rm -rf "$DMG_TMP_DIR"

# Create a temporary directory for the DMG contents
mkdir -p "$DMG_TMP_DIR"
cp -R "$BUNDLE_DIR" "$DMG_TMP_DIR/"

# Create a symlink to Applications folder
ln -s /Applications "$DMG_TMP_DIR/Applications"

# Generate the DMG
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_TMP_DIR" -ov -format UDZO "$DMG_NAME"

# Clean up temporary directory
rm -rf "$DMG_TMP_DIR"

echo "✅ Done! You can now find '$DMG_NAME' in the SonixMac folder."
echo "You can double-click it to install."
