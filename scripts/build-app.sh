#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Claude Island.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
LEGAL_DIR="$RESOURCES_DIR/Legal"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
SIGN_IDENTITY="${CLAUDE_ISLAND_SIGN_IDENTITY:--}"

cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64 --product ClaudeIsland >&2
swift build -c release --arch arm64 --arch x86_64 --product ClaudeIslandHook >&2

UNIVERSAL_PRODUCTS_DIR="$PROJECT_DIR/.build/apple/Products/Release"
APP_EXECUTABLE="$UNIVERSAL_PRODUCTS_DIR/ClaudeIsland"
HOOK_EXECUTABLE="$UNIVERSAL_PRODUCTS_DIR/ClaudeIslandHook"
for executable in "$APP_EXECUTABLE" "$HOOK_EXECUTABLE"; do
  for architecture in arm64 x86_64; do
    if ! lipo -archs "$executable" | tr ' ' '\n' | grep -qx "$architecture"; then
      echo "$executable is missing required architecture $architecture" >&2
      exit 1
    fi
  done
done

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$LEGAL_DIR" "$FRAMEWORKS_DIR" "$ICONSET_DIR"

cp "$APP_EXECUTABLE" "$MACOS_DIR/ClaudeIsland"
cp "$HOOK_EXECUTABLE" "$RESOURCES_DIR/ClaudeIslandHook"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "Resources/PrivacyInfo.xcprivacy" "$RESOURCES_DIR/PrivacyInfo.xcprivacy"
cp Resources/Clawd-*.svg "$RESOURCES_DIR/"
cp Resources/Clawdia-*.svg "$RESOURCES_DIR/"
cp "Resources/ClawdPet-LICENSE" "$RESOURCES_DIR/ClawdPet-LICENSE"
for legal_document in \
  DISCLAIMER.md \
  LICENSE \
  LICENSING.md \
  PRIVACY.md \
  SAFETY.md \
  SECURITY.md \
  SUPPORT.md \
  THIRD_PARTY_NOTICES.md \
  TRADEMARKS.md; do
  cp "$legal_document" "$LEGAL_DIR/$legal_document"
done

SPARKLE_FRAMEWORK_SOURCE=$(find "$PROJECT_DIR/.build/artifacts" -path '*/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework' -print -quit)
if [[ -z "$SPARKLE_FRAMEWORK_SOURCE" ]]; then
  echo "Sparkle.framework was not found in SwiftPM artifacts" >&2
  exit 1
fi
ditto "$SPARKLE_FRAMEWORK_SOURCE" "$FRAMEWORKS_DIR/Sparkle.framework"

SOURCE_ICON_SVG="$PROJECT_DIR/Resources/AppIcon.svg"
SOURCE_ICON="$BUILD_DIR/AppIcon-source.png"
sips -s format png "$SOURCE_ICON_SVG" --out "$SOURCE_ICON" >/dev/null
for spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"; do
  size="${spec%% *}"
  name="${spec#* }"
  sips -z "$size" "$size" "$SOURCE_ICON" --out "$ICONSET_DIR/$name" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
rm -rf "$ICONSET_DIR"
rm -f "$SOURCE_ICON"

chmod 755 "$MACOS_DIR/ClaudeIsland" "$RESOURCES_DIR/ClaudeIslandHook"

sign_item() {
  local item="$1"
  local preserve_entitlements="${2:-false}"
  local args=(--force --sign "$SIGN_IDENTITY")
  if [[ "$SIGN_IDENTITY" != "-" ]]; then
    args+=(--options runtime --timestamp)
  fi
  if [[ "$preserve_entitlements" == "true" ]]; then
    args+=(--preserve-metadata=entitlements)
  fi
  codesign "${args[@]}" "$item" >/dev/null
}

SPARKLE_VERSION_DIR="$FRAMEWORKS_DIR/Sparkle.framework/Versions/Current"
# Sparkle's documented manual signing order. Applying --deep here can copy
# incompatible entitlements across the framework's helper processes.
sign_item "$SPARKLE_VERSION_DIR/XPCServices/Installer.xpc"
sign_item "$SPARKLE_VERSION_DIR/XPCServices/Downloader.xpc" true
sign_item "$SPARKLE_VERSION_DIR/Autoupdate"
sign_item "$SPARKLE_VERSION_DIR/Updater.app"
sign_item "$FRAMEWORKS_DIR/Sparkle.framework"
sign_item "$RESOURCES_DIR/ClaudeIslandHook"
sign_item "$APP_DIR"

for signed_item in \
  "$SPARKLE_VERSION_DIR/XPCServices/Installer.xpc" \
  "$SPARKLE_VERSION_DIR/XPCServices/Downloader.xpc" \
  "$SPARKLE_VERSION_DIR/Autoupdate" \
  "$SPARKLE_VERSION_DIR/Updater.app" \
  "$FRAMEWORKS_DIR/Sparkle.framework" \
  "$RESOURCES_DIR/ClaudeIslandHook"; do
  codesign --verify --strict --verbose=2 "$signed_item"
done
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "$APP_DIR"
