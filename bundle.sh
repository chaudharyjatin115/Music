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
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.music.app</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>music-widget</string>
            </array>
        </dict>
    </array>
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

# Generate AppIntents Metadata so interactive WidgetKit Button(intent:) works without Xcode
APPINTENTS_DIR="$WIDGET_RESOURCES/Metadata.appintents"
mkdir -p "$APPINTENTS_DIR"

cat << 'EOF' > "$APPINTENTS_DIR/version.json"
{
  "toolsVersion" : "16E6052g",
  "version" : "3.0"
}
EOF

cat << 'EOF' > "$APPINTENTS_DIR/extract.actionsdata"
{
  "actions": {
    "WidgetTogglePlayPauseIntent": {
      "assistantDefinedSchemaTraits": [],
      "assistantDefinedSchemas": [],
      "authenticationPolicy": 0,
      "availabilityAnnotations": {
        "LNPlatformNameWildcard": {
          "introducedVersion": "*"
        }
      },
      "descriptionMetadata": {
        "descriptionText": {
          "alternatives": [],
          "key": "Toggles music playback"
        },
        "searchKeywords": []
      },
      "effectiveBundleIdentifiers": [],
      "fullyQualifiedTypeName": "MusicWidget.WidgetTogglePlayPauseIntent",
      "identifier": "WidgetTogglePlayPauseIntent",
      "isAuthPolExplicit": false,
      "isDiscoverable": false,
      "mangledTypeName": "11MusicWidget0B21TogglePlayPauseIntentV",
      "mangledTypeNameByBundleIdentifier": {},
      "mangledTypeNameByBundleIdentifierV2": {},
      "mangledTypeNameV2": "11MusicWidget0B21TogglePlayPauseIntentV",
      "openAppWhenRun": false,
      "outputFlags": 0,
      "parameters": [],
      "presentationStyle": 0,
      "requiredCapabilities": [],
      "supportedModes": 1,
      "systemProtocolMetadata": [],
      "systemProtocolMetadataV2": [],
      "systemProtocols": [],
      "title": {
        "alternatives": [],
        "key": "Play/Pause"
      },
      "typeSpecificMetadata": [],
      "visibilityMetadata": {
        "assistantOnly": false,
        "isDiscoverable": false
      }
    },
    "WidgetNextTrackIntent": {
      "assistantDefinedSchemaTraits": [],
      "assistantDefinedSchemas": [],
      "authenticationPolicy": 0,
      "availabilityAnnotations": {
        "LNPlatformNameWildcard": {
          "introducedVersion": "*"
        }
      },
      "descriptionMetadata": {
        "descriptionText": {
          "alternatives": [],
          "key": "Skips to the next track"
        },
        "searchKeywords": []
      },
      "effectiveBundleIdentifiers": [],
      "fullyQualifiedTypeName": "MusicWidget.WidgetNextTrackIntent",
      "identifier": "WidgetNextTrackIntent",
      "isAuthPolExplicit": false,
      "isDiscoverable": false,
      "mangledTypeName": "11MusicWidget0B15NextTrackIntentV",
      "mangledTypeNameByBundleIdentifier": {},
      "mangledTypeNameByBundleIdentifierV2": {},
      "mangledTypeNameV2": "11MusicWidget0B15NextTrackIntentV",
      "openAppWhenRun": false,
      "outputFlags": 0,
      "parameters": [],
      "presentationStyle": 0,
      "requiredCapabilities": [],
      "supportedModes": 1,
      "systemProtocolMetadata": [],
      "systemProtocolMetadataV2": [],
      "systemProtocols": [],
      "title": {
        "alternatives": [],
        "key": "Next Track"
      },
      "typeSpecificMetadata": [],
      "visibilityMetadata": {
        "assistantOnly": false,
        "isDiscoverable": false
      }
    },
    "WidgetPreviousTrackIntent": {
      "assistantDefinedSchemaTraits": [],
      "assistantDefinedSchemas": [],
      "authenticationPolicy": 0,
      "availabilityAnnotations": {
        "LNPlatformNameWildcard": {
          "introducedVersion": "*"
        }
      },
      "descriptionMetadata": {
        "descriptionText": {
          "alternatives": [],
          "key": "Plays previous track or seeks to start"
        },
        "searchKeywords": []
      },
      "effectiveBundleIdentifiers": [],
      "fullyQualifiedTypeName": "MusicWidget.WidgetPreviousTrackIntent",
      "identifier": "WidgetPreviousTrackIntent",
      "isAuthPolExplicit": false,
      "isDiscoverable": false,
      "mangledTypeName": "11MusicWidget0B19PreviousTrackIntentV",
      "mangledTypeNameByBundleIdentifier": {},
      "mangledTypeNameByBundleIdentifierV2": {},
      "mangledTypeNameV2": "11MusicWidget0B19PreviousTrackIntentV",
      "openAppWhenRun": false,
      "outputFlags": 0,
      "parameters": [],
      "presentationStyle": 0,
      "requiredCapabilities": [],
      "supportedModes": 1,
      "systemProtocolMetadata": [],
      "systemProtocolMetadataV2": [],
      "systemProtocols": [],
      "title": {
        "alternatives": [],
        "key": "Previous Track"
      },
      "typeSpecificMetadata": [],
      "visibilityMetadata": {
        "assistantOnly": false,
        "isDiscoverable": false
      }
    }
  },
  "assistantEntities": [],
  "assistantIntentNegativePhrases": [],
  "assistantIntents": [],
  "autoShortcuts": [],
  "entities": {},
  "enums": [],
  "generator": {
    "name": "xcode-tools",
    "version": "16E6052g"
  },
  "negativePhrases": [],
  "queries": {},
  "shortcutTileColor": 14,
  "version": 1
}
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
    killall NotificationCenter 2>/dev/null || true
    echo "Successfully installed to /Applications/Music.app"
fi
