#!/bin/zsh
# Build, sign, notarize and staple a release DMG on this Mac.
#
#   usage: App/scripts/release-local.sh 1.0.0-rc1
#
# One-time setup (stores an App Store Connect key or app-specific password in the
# login keychain — nothing is written to this repo):
#
#   xcrun notarytool store-credentials AC_PASSWORD \
#     --apple-id "you@example.com" --team-id R35977T6M6 --password "abcd-efgh-ijkl-mnop"
#
# The app-specific password comes from appleid.apple.com ▸ Sign-In and Security ▸
# App-Specific Passwords. Alternatively use --key/--key-id/--issuer with an API key.
set -euo pipefail

VERSION="${1:?usage: release-local.sh <version>   e.g. 1.0.0-rc1}"
HERE="${0:A:h}"; APP_DIR="${HERE:h}"; REPO="${APP_DIR:h}"
IDENTITY="Developer ID Application"
PROFILE="${NOTARY_PROFILE:-AC_PASSWORD}"
NAME="DiveSaveEd-macOS-v$VERSION"
OUT="$REPO/dist"; STAGE="$(mktemp -d)"

command -v xcodegen >/dev/null || { echo "brew install xcodegen" >&2; exit 1; }
security find-identity -v -p codesigning | grep -q "$IDENTITY" \
  || { echo "No '$IDENTITY' certificate in the keychain." >&2; exit 1; }
xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 \
  || { echo "No notary profile '$PROFILE'. See the header of this script." >&2; exit 1; }

mkdir -p "$OUT"; cd "$APP_DIR"; xcodegen generate >/dev/null

echo "▸ Building Release…"
xcodebuild -project DaveTheDiverSaveEditor.xcodeproj \
  -scheme DaveTheDiverSaveEditor -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build \
  MARKETING_VERSION="$VERSION" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" \
  ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build >/dev/null

APP="$APP_DIR/build/Build/Products/Release/DaveTheDiverSaveEditor.app"
echo "▸ Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "▸ Packaging DMG…"
cp -R "$APP" "$STAGE/DiveSaveEd.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname DiveSaveEd -srcfolder "$STAGE" -ov -format UDZO "$OUT/$NAME.dmg" >/dev/null

echo "▸ Notarizing (this waits on Apple, usually a few minutes)…"
xcrun notarytool submit "$OUT/$NAME.dmg" --keychain-profile "$PROFILE" --wait

echo "▸ Stapling…"
xcrun stapler staple "$OUT/$NAME.dmg"

echo "▸ Gatekeeper verdict:"
spctl -a -vvv -t install "$OUT/$NAME.dmg" 2>&1 | sed 's/^/    /'

echo "▸ SHA-256:"
shasum -a 256 "$OUT/$NAME.dmg" | sed 's/^/    /'
echo "✓ $OUT/$NAME.dmg"
