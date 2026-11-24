#!/bin/bash
set -e

cd "$(dirname "$0")"

CONFIG="${1:-debug}"

echo "Building native Swift ($CONFIG) binary..."
swift build -c "$CONFIG"

APP_NAME="Music"
APP_BUNDLE="build/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

mkdir -p "$MACOS" "$RESOURCES"

cp .build/"$CONFIG"/Music "$MACOS/$APP_NAME"
chmod +x "$MACOS/$APP_NAME"

# Copy AppIcon into bundle resources
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$RESOURCES/AppIcon.icns"
fi

cat << 'EOF' > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Music</string>
    <key>CFBundleIdentifier</key>
    <string>com.music.app</string>
    <key>CFBundleName</key>
    <string>Music</string>
    <key>CFBundleDisplayName</key>
    <string>Music</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
EOF

# Build MusicWidget extension
echo "Building MusicWidget.appex extension..."
PLUGINS="$CONTENTS/PlugIns"
WIDGET_BUNDLE="$PLUGINS/MusicWidget.appex"
WIDGET_CONTENTS="$WIDGET_BUNDLE/Contents"
WIDGET_MACOS="$WIDGET_CONTENTS/MacOS"
WIDGET_RESOURCES="$WIDGET_CONTENTS/Resources"

mkdir -p "$WIDGET_MACOS" "$WIDGET_RESOURCES"

ARCH="$(uname -m)"
SWIFT_FLAGS="-parse-as-library -application-extension -target ${ARCH}-apple-macos14.0"
if [ "$CONFIG" == "release" ]; then
    SWIFT_FLAGS="$SWIFT_FLAGS -O -wmo"
fi

swiftc $SWIFT_FLAGS \
    Sources/Widget/WidgetState.swift \
    WidgetExtension/MusicWidget.swift \
    -o "$WIDGET_MACOS/MusicWidget" \
    -framework WidgetKit -framework SwiftUI -framework AppIntents -framework AppKit \
    -Xlinker -e -Xlinker _NSExtensionMain

chmod +x "$WIDGET_MACOS/MusicWidget"

cat << 'EOF' > "$WIDGET_CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MusicWidget</string>
    <key>CFBundleIdentifier</key>
    <string>com.music.app.widget</string>
    <key>CFBundleName</key>
    <string>MusicWidget</string>
    <key>CFBundleDisplayName</key>
    <string>Music</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>EXAppExtensionAttributes</key>
    <dict>
        <key>EXExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
EOF

WIDGET_ENTITLEMENTS="Resources/MusicWidget.entitlements"

# Detect code signing identity
SIGN_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null | grep -E "Developer ID Application|Apple Development" | head -n 1 | awk -F '"' '{print $2}')
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="-"
fi

xattr -cr "$WIDGET_BUNDLE"
codesign --force --sign "$SIGN_IDENTITY" --entitlements "$WIDGET_ENTITLEMENTS" "$WIDGET_BUNDLE"

# Remove all quarantine flags recursively
xattr -rd com.apple.quarantine "$APP_BUNDLE" 2>/dev/null || true
xattr -cr "$APP_BUNDLE"
codesign --force --sign "$SIGN_IDENTITY" "$APP_BUNDLE"

# Also create zip archive for distribution if release
if [ "$CONFIG" == "release" ]; then
    echo "Creating release zip archive..."
    (cd build && rm -f "$APP_NAME.zip" && zip -qry "$APP_NAME.zip" "$APP_NAME.app")
fi

echo "Application bundle created at: $APP_BUNDLE"

if [ "$2" == "--install" ] || [ "$CONFIG" == "release" ]; then
    echo "Terminating any running instance of Music..."
    pkill -f /Applications/Music.app/Contents/MacOS/Music 2>/dev/null || true
    sleep 1

    echo "Installing to /Applications/Music.app..."
    rm -rf /Applications/Music.app
    cp -R "$APP_BUNDLE" /Applications/
    xattr -rd com.apple.quarantine /Applications/Music.app 2>/dev/null || true
    xattr -cr /Applications/Music.app
    codesign --force --sign "$SIGN_IDENTITY" --entitlements "$WIDGET_ENTITLEMENTS" /Applications/Music.app/Contents/PlugIns/MusicWidget.appex
    codesign --force --sign "$SIGN_IDENTITY" /Applications/Music.app
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Music.app 2>/dev/null || true
    launchctl kickstart -kp gui/$(id -u)/com.apple.chronod 2>/dev/null || true
    killall -9 pkd 2>/dev/null || true
    echo "Successfully installed to /Applications/Music.app"
fi
