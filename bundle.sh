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

SWIFT_FLAGS="-parse-as-library -target x86_64-apple-macos14.0"
if [ "$CONFIG" == "release" ]; then
    SWIFT_FLAGS="$SWIFT_FLAGS -O"
fi

swiftc $SWIFT_FLAGS \
    Sources/Widget/WidgetState.swift \
    WidgetExtension/MusicWidget.swift \
    -o "$WIDGET_MACOS/MusicWidget" \
    -framework WidgetKit -framework SwiftUI -framework AppIntents -framework AppKit

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
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
EOF

xattr -cr "$WIDGET_BUNDLE"
codesign --force --deep --sign - "$WIDGET_BUNDLE"

# Remove all quarantine flags recursively
xattr -rd com.apple.quarantine "$APP_BUNDLE" 2>/dev/null || true
xattr -cr "$APP_BUNDLE"
codesign --force --deep --sign - "$APP_BUNDLE"

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
    codesign --force --deep --sign - /Applications/Music.app
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Music.app 2>/dev/null || true
    echo "Successfully installed to /Applications/Music.app"
fi
