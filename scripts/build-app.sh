#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_NAME="Cronly"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"

echo "Building Cronly..."
cd "$PROJECT_DIR"
swift build -c release --product CronlyApp
swift build -c release --product cronly

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/CronlyApp" "$APP_BUNDLE/Contents/MacOS/CronlyApp"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>CronlyApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.cronly.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Cronly</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "Installing CLI..."
cp "$BUILD_DIR/cronly" /usr/local/bin/cronly 2>/dev/null || {
    mkdir -p "$HOME/.local/bin"
    cp "$BUILD_DIR/cronly" "$HOME/.local/bin/cronly"
    echo "CLI installed to ~/.local/bin/cronly"
}

echo ""
echo "Done!"
echo "  App:  $APP_BUNDLE"
echo "  CLI:  $(which cronly 2>/dev/null || echo "$HOME/.local/bin/cronly")"
echo ""
echo "To run: open $APP_BUNDLE"
echo "To install to Applications: cp -r $APP_BUNDLE /Applications/"
