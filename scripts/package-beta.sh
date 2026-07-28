#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
DIST_DIR="$PROJECT_DIR/dist"
TAG="${1:-}"
VERSION=$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")
BUILD_NUMBER=$(plutil -extract CFBundleVersion raw "$INFO_PLIST")
EXPECTED_TAG_PREFIX="v${VERSION}-beta."

if [[ -z "$TAG" || "$TAG" != ${EXPECTED_TAG_PREFIX}<-> ]]; then
  echo "Usage: $0 ${EXPECTED_TAG_PREFIX}<number>" >&2
  echo "The tag must match CFBundleShortVersionString ${VERSION}." >&2
  exit 1
fi

OUTPUT_DIR="$DIST_DIR/$TAG"
ARCHIVE_NAME="Claude-Island-${TAG#v}-unsigned.zip"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"
DEPENDENCY_INVENTORY_PATH="$OUTPUT_DIR/Claude-Island-${TAG#v}-swiftpm-dependencies.json"
RELEASE_NOTES_PATH="$OUTPUT_DIR/RELEASE_NOTES.md"

if [[ -e "$OUTPUT_DIR" ]]; then
  echo "Beta output already exists: $OUTPUT_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
PACKAGE_COMPLETE=false
TEMP_DIR=$(mktemp -d)
cleanup() {
  rm -rf "$TEMP_DIR"
  if [[ "$PACKAGE_COMPLETE" != "true" && -d "$OUTPUT_DIR" ]]; then
    rm -rf "$OUTPUT_DIR"
  fi
}
trap cleanup EXIT

APP_PATH=$(CLAUDE_ISLAND_SIGN_IDENTITY=- "$SCRIPT_DIR/build-app.sh")
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

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

APP_VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP_PATH/Contents/Info.plist")
APP_BUILD=$(plutil -extract CFBundleVersion raw "$APP_PATH/Contents/Info.plist")
if [[ "$APP_VERSION" != "$VERSION" || "$APP_BUILD" != "$BUILD_NUMBER" ]]; then
  echo "Packaged app version does not match Resources/Info.plist." >&2
  exit 1
fi

swift package show-dependencies --format json > "$DEPENDENCY_INVENTORY_PATH"
ditto -c -k --norsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"

ditto -x -k "$ARCHIVE_PATH" "$TEMP_DIR"
EXTRACTED_APP="$TEMP_DIR/Claude Island.app"
codesign --verify --deep --strict --verbose=2 "$EXTRACTED_APP"
for executable in \
  "$EXTRACTED_APP/Contents/MacOS/ClaudeIsland" \
  "$EXTRACTED_APP/Contents/Resources/ClaudeIslandHook"; do
  for architecture in arm64 x86_64; do
    lipo -archs "$executable" | tr ' ' '\n' | grep -qx "$architecture"
  done
done
if unzip -Z1 "$ARCHIVE_PATH" | grep -Eq '(^|/)(__MACOSX|\\._)'; then
  echo "Archive contains forbidden Finder metadata." >&2
  exit 1
fi

ARCHIVE_SHA256=$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')
(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$ARCHIVE_NAME" "${DEPENDENCY_INVENTORY_PATH:t}" > SHA256SUMS
)

CHANGELOG_SECTION=$(awk -v version="${TAG#v}" '
  $0 ~ "^## \\[" version "\\]" { printing = 1; next }
  printing && $0 ~ "^## \\[" { exit }
  printing { print }
' "$PROJECT_DIR/CHANGELOG.md")
if [[ -z "${CHANGELOG_SECTION//[[:space:]]/}" ]]; then
  echo "CHANGELOG.md has no release section for ${TAG#v}." >&2
  exit 1
fi

{
  print '## Beta pública / Public beta'
  print
  print 'Compilación universal de Claude Island para Apple Silicon e Intel.'
  print 'Universal Claude Island build for Apple Silicon and Intel.'
  print
  print '### Aviso importante / Important notice'
  print
  print 'Esta beta tiene firma ad hoc, pero **no está firmada con Developer ID ni'
  print 'notarizada por Apple**. macOS puede bloquear el primer arranque.'
  print
  print 'This beta is ad-hoc signed but **not Developer ID signed or Apple-notarized**.'
  print 'macOS may block its first launch.'
  print
  print '### Instalación / Installation'
  print
  print '1. Descarga y descomprime el ZIP / Download and unzip the archive.'
  print '2. Mueve `Claude Island.app` a `Aplicaciones` / Move it to `Applications`.'
  print '3. Intenta abrirla una vez / Try to open it once.'
  print '4. Si macOS la bloquea, usa `Ajustes del Sistema > Privacidad y seguridad > Abrir igualmente`.'
  print '   If blocked, use `System Settings > Privacy & Security > Open Anyway`.'
  print
  print 'No desactives Gatekeeper / Do not disable Gatekeeper:'
  print 'https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac'
  print
  print '### Requisitos / Requirements'
  print
  print -r -- '- macOS 14 Sonoma o posterior / macOS 14 Sonoma or later.'
  print -r -- '- Claude Code instalado y con sesión iniciada / Claude Code installed and signed in.'
  print -r -- '- Apple Silicon o Intel / Apple Silicon or Intel.'
  print
  print '### Verificación / Verification'
  print
  print -r -- "- Version: \`${TAG#v}\`"
  print -r -- "- App build: \`${BUILD_NUMBER}\`"
  print -r -- "- Source commit: \`${GITHUB_SHA:-$(git -C "$PROJECT_DIR" rev-parse HEAD)}\`"
  print -r -- "- SHA-256: \`${ARCHIVE_SHA256}\`"
  print
  print '### Cambios / Changes'
  print
  print -r -- "$CHANGELOG_SECTION"
} > "$RELEASE_NOTES_PATH"

PACKAGE_COMPLETE=true
trap - EXIT
rm -rf "$TEMP_DIR"

echo "$OUTPUT_DIR"
