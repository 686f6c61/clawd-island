#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
DIST_DIR="$PROJECT_DIR/dist"
VERSION=$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")
BUILD_NUMBER=$(plutil -extract CFBundleVersion raw "$INFO_PLIST")
TAG="v${VERSION}"
OUTPUT_DIR="$DIST_DIR/$TAG"
ARCHIVE_NAME="Claude-Island-${TAG}.zip"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"
DEPENDENCY_INVENTORY_PATH="$OUTPUT_DIR/Claude-Island-${TAG}-swiftpm-dependencies.json"
RELEASE_NOTES_PATH="$OUTPUT_DIR/Claude-Island-${TAG}.md"
EVIDENCE_DIR="$PROJECT_DIR/.build/release-evidence/$TAG"
NOTARY_RESULT_PATH="$EVIDENCE_DIR/notarization.json"
DOWNLOAD_PREFIX="https://github.com/686f6c61/clawd-island/releases/download/${TAG}/"
REPOSITORY_URL="https://github.com/686f6c61/clawd-island"
SIGN_IDENTITY="${CLAUDE_ISLAND_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${CLAUDE_ISLAND_NOTARY_PROFILE:-}"

if [[ -z "$SIGN_IDENTITY" || "$SIGN_IDENTITY" == "-" || "$SIGN_IDENTITY" != Developer\ ID\ Application:* ]]; then
  echo "A Developer ID Application identity is required for a public release." >&2
  exit 1
fi
if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "CLAUDE_ISLAND_NOTARY_PROFILE is required for a public release." >&2
  exit 1
fi
if [[ -e "$OUTPUT_DIR" ]]; then
  echo "Release output already exists: $OUTPUT_DIR" >&2
  echo "Archive it or remove that exact version directory before rebuilding." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR" "$EVIDENCE_DIR"
RELEASE_COMPLETE=false
cleanup_incomplete_release() {
  if [[ "$RELEASE_COMPLETE" != "true" && -d "$OUTPUT_DIR" ]]; then
    rm -rf "$OUTPUT_DIR"
  fi
}
trap cleanup_incomplete_release EXIT

APP_PATH=$("$SCRIPT_DIR/build-app.sh")
GENERATE_APPCAST=$(find "$PROJECT_DIR/.build/artifacts" -path '*/Sparkle/bin/generate_appcast' -print -quit)
SIGN_UPDATE=$(find "$PROJECT_DIR/.build/artifacts" -path '*/Sparkle/bin/sign_update' -print -quit)
if [[ -z "$GENERATE_APPCAST" || -z "$SIGN_UPDATE" ]]; then
  echo "Sparkle release tools were not found in SwiftPM artifacts." >&2
  exit 1
fi

for executable in \
  "$APP_PATH/Contents/MacOS/ClaudeIsland" \
  "$APP_PATH/Contents/Resources/ClaudeIslandHook"; do
  for architecture in arm64 x86_64; do
    if ! lipo -archs "$executable" | tr ' ' '\n' | grep -qx "$architecture"; then
      echo "$executable is missing required architecture $architecture" >&2
      exit 1
    fi
  done
done

CODESIGN_DETAILS=$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)
if [[ "$CODESIGN_DETAILS" != *"runtime"* ]]; then
  echo "The release app is missing Hardened Runtime." >&2
  exit 1
fi
ENTITLEMENTS=$(codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || true)
if [[ "$ENTITLEMENTS" == *"com.apple.security.get-task-allow"* ]]; then
  echo "The release app contains the forbidden get-task-allow entitlement." >&2
  exit 1
fi

swift package show-dependencies --format json > "$DEPENDENCY_INVENTORY_PATH"

awk -v version="$VERSION" '
  $0 ~ "^## \\[" version "\\]" { printing = 1; next }
  printing && $0 ~ "^## \\[" { exit }
  printing { print }
' "$PROJECT_DIR/CHANGELOG.md" > "$RELEASE_NOTES_PATH"
if [[ ! -s "$RELEASE_NOTES_PATH" ]]; then
  echo "CHANGELOG.md has no release section for $VERSION." >&2
  exit 1
fi

ditto -c -k --keepParent "$APP_PATH" "$ARCHIVE_PATH"

echo "Submitting ${ARCHIVE_NAME} to Apple's notary service…"
xcrun notarytool submit "$ARCHIVE_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait \
  --output-format json > "$NOTARY_RESULT_PATH"
NOTARY_STATUS=$(plutil -extract status raw "$NOTARY_RESULT_PATH")
if [[ "$NOTARY_STATUS" != "Accepted" ]]; then
  echo "Apple notarization did not accept the release. See $NOTARY_RESULT_PATH" >&2
  exit 1
fi
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"
rm -f "$ARCHIVE_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ARCHIVE_PATH"

APPCAST_ARGS=(
  --download-url-prefix "$DOWNLOAD_PREFIX"
  --link "$REPOSITORY_URL"
  --versions "$BUILD_NUMBER"
  --maximum-deltas 0
  --embed-release-notes
  "$OUTPUT_DIR"
)

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  print -rn -- "$SPARKLE_PRIVATE_KEY" | "$GENERATE_APPCAST" --ed-key-file - "${APPCAST_ARGS[@]}"
  print -rn -- "$SPARKLE_PRIVATE_KEY" | "$SIGN_UPDATE" --verify --ed-key-file - "$OUTPUT_DIR/appcast.xml"
else
  "$GENERATE_APPCAST" "${APPCAST_ARGS[@]}"
  "$SIGN_UPDATE" --verify "$OUTPUT_DIR/appcast.xml"
fi

(
  cd "$OUTPUT_DIR"
  shasum -a 256 \
    "$ARCHIVE_NAME" \
    "appcast.xml" \
    "${DEPENDENCY_INVENTORY_PATH:t}" > "SHA256SUMS"
)

RELEASE_COMPLETE=true
trap - EXIT

echo "Release ${TAG} prepared in a clean staging directory:"
echo "  $ARCHIVE_PATH"
echo "  $OUTPUT_DIR/appcast.xml"
echo "  $OUTPUT_DIR/SHA256SUMS"
echo "  $DEPENDENCY_INVENTORY_PATH"
echo "Private notarization evidence retained at: $NOTARY_RESULT_PATH"
