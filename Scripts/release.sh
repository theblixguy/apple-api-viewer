#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: release.sh <version>}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# The count must come from this repository, not the caller's working
# directory. Sparkle orders releases by this number.
BUILD_NUMBER="$(git rev-list --count HEAD)"

RELEASE_DIR="$REPO_ROOT/.release"
ARCHIVE_PATH="$RELEASE_DIR/AppleAPIViewer.xcarchive"
EXPORT_DIR="$RELEASE_DIR/export"
DMG_STAGE_DIR="$RELEASE_DIR/dmg-stage"
SPARKLE_DIR="$RELEASE_DIR/sparkle"
APPCAST_DIR="$RELEASE_DIR/appcast"

APP_NAME="apple_api_viewer.app"
STAGED_APP_NAME="Apple API Viewer.app"
DMG_NAME="AppleAPIViewer-$VERSION.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"

DOWNLOAD_URL_PREFIX="https://github.com/theblixguy/apple-api-viewer/releases/download/v$VERSION/"
SPARKLE_TARBALL_URL="https://github.com/sparkle-project/Sparkle/releases/download/2.9.4/Sparkle-2.9.4.tar.xz"

mkdir -p "$RELEASE_DIR"

NOTES_MD="$RELEASE_DIR/release-notes.md"

# A missing changelog section means the release would have no notes,
# so the build stops before the long archive step.
awk -v version="$VERSION" '
  $0 == "## " version { found = 1; next }
  /^## / && found { exit }
  found { print }
' "$REPO_ROOT/CHANGELOG.md" > "$NOTES_MD"
if ! grep -q '[^[:space:]]' "$NOTES_MD"; then
  echo "CHANGELOG.md has no section for $VERSION" >&2
  exit 1
fi

echo "Building version $VERSION build $BUILD_NUMBER"

tuist install || {
  rm -rf Tuist/.build/workspace-state.json Tuist/.build/artifacts
  tuist install
}
tuist generate --no-open

# The generated project pins automatic signing with an Apple Development
# identity. A CI runner has neither that identity nor an Apple ID session,
# so the archive overrides to the Developer ID identity.
rm -rf "$ARCHIVE_PATH"
xcodebuild archive \
  -workspace AppleAPIViewer.xcworkspace \
  -scheme apple-api-viewer \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM=97346KBR2S

rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$REPO_ROOT/Scripts/ExportOptions.plist"

rm -rf "$DMG_STAGE_DIR"
mkdir -p "$DMG_STAGE_DIR"
ditto "$EXPORT_DIR/$APP_NAME" "$DMG_STAGE_DIR/$STAGED_APP_NAME"

rm -f "$DMG_PATH"
create-dmg \
  --volname "Apple API Viewer" \
  --app-drop-link 600 185 \
  "$DMG_PATH" \
  "$DMG_STAGE_DIR" || true

# create-dmg sometimes exits nonzero because of a Finder scripting failure
# even when the DMG was written, so the retry runs only when the output is
# missing
if [[ ! -f "$DMG_PATH" ]]; then
  create-dmg \
    --volname "Apple API Viewer" \
    --app-drop-link 600 185 \
    "$DMG_PATH" \
    "$DMG_STAGE_DIR"
fi

if [[ ! -f "$DMG_PATH" ]]; then
  echo "create-dmg did not produce $DMG_PATH" >&2
  exit 1
fi

SIGN_IDENTITY="$(security find-identity -v -p codesigning | awk -F '"' '/Developer ID Application/ { print $2; exit }')"
if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "No Developer ID Application identity found in the keychain" >&2
  exit 1
fi

codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"

: "${ASC_KEY_PATH:?ASC_KEY_PATH must point at the App Store Connect API key}"
: "${ASC_KEY_ID:?ASC_KEY_ID is required for notarization}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID is required for notarization}"

xcrun notarytool submit "$DMG_PATH" \
  --key "$ASC_KEY_PATH" \
  --key-id "$ASC_KEY_ID" \
  --issuer "$ASC_ISSUER_ID" \
  --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

mkdir -p "$SPARKLE_DIR"
if [[ ! -x "$SPARKLE_DIR/bin/generate_appcast" ]]; then
  curl -sL -o "$RELEASE_DIR/Sparkle-2.9.4.tar.xz" "$SPARKLE_TARBALL_URL"
  tar -xf "$RELEASE_DIR/Sparkle-2.9.4.tar.xz" -C "$SPARKLE_DIR"
fi

rm -rf "$APPCAST_DIR"
mkdir -p "$APPCAST_DIR"
cp "$DMG_PATH" "$APPCAST_DIR/"

# generate_appcast attaches notes from a file that shares the DMG's base
# name. GitHub renders the markdown, so the update dialog and the release
# page show the same notes.
gh api markdown --field mode=gfm --field text="$(cat "$NOTES_MD")" \
  > "$APPCAST_DIR/AppleAPIViewer-$VERSION.html"

GENERATE_APPCAST_ARGS=(--download-url-prefix "$DOWNLOAD_URL_PREFIX")
if [[ -n "${SPARKLE_PRIVATE_KEY_PATH:-}" ]]; then
  GENERATE_APPCAST_ARGS+=(--ed-key-file "$SPARKLE_PRIVATE_KEY_PATH")
fi

"$SPARKLE_DIR/bin/generate_appcast" "${GENERATE_APPCAST_ARGS[@]}" "$APPCAST_DIR"
mv -f "$APPCAST_DIR/appcast.xml" "$REPO_ROOT/appcast.xml"

echo "Release summary"
echo "Version $VERSION"
echo "Build number $BUILD_NUMBER"
echo "DMG at $DMG_PATH"
