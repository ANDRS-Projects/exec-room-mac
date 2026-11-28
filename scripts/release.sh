#!/bin/sh
# Builds the download: "Exec Room.app" signed with a Developer ID and notarised by Apple, in a signed and notarised
# disk image, dist/Exec-Room-<version>.dmg, with its SHA-256 next to it.
#
#   SIGN_ID="Developer ID Application: <name> (<team id>)" NODE_DIR=… EXEC_ROOM_DIR=… scripts/release.sh
#
# NOTARY_PROFILE  the notarisation sign-in saved in the Keychain with `xcrun notarytool store-credentials`
#                 (default "exec-room"). This script never sees the password or key behind it.
# NODE_DIR, EXEC_ROOM_DIR  as for scripts/build-app.sh.
#
# Apple checks every program inside and can take a few minutes per submission; a refusal prints Apple's reasons.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=$(sed -n 's/^version: *//p' "$ROOT/exec-room.ref")
APP="$ROOT/build/Exec Room.app"
DMG="$ROOT/dist/Exec-Room-$VERSION.dmg"
NOTARY_PROFILE=${NOTARY_PROFILE:-exec-room}

fail() { echo "release: $*" >&2; exit 1; }

case "${SIGN_ID:-}" in
    "Developer ID Application: "*) ;;
    *) fail 'set SIGN_ID to your "Developer ID Application: <name> (<team id>)" certificate (see `security find-identity -v -p codesigning`)' ;;
esac
security find-identity -v -p codesigning | grep -qF "\"$SIGN_ID\"" || fail "the certificate \"$SIGN_ID\" isn't in your Keychain"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || fail "no notarisation sign-in saved as \"$NOTARY_PROFILE\": run \`xcrun notarytool store-credentials $NOTARY_PROFILE\` first"

# Sends a file to Apple and waits. On a refusal, prints Apple's log, which names each problem and the file it is in.
notarise() {
    echo "release: sending $(basename "$1") to Apple for notarisation (this can take a few minutes)"
    result=$(xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)
    status=$(printf '%s' "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status", ""))')
    id=$(printf '%s' "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id", ""))')
    if [ "$status" != "Accepted" ]; then
        echo "release: Apple answered \"$status\" for submission $id. Apple's log:" >&2
        [ -n "$id" ] && xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2
        exit 1
    fi
    echo "release: notarised ($id)"
}

SIGN_ID="$SIGN_ID" "$ROOT/scripts/build-app.sh"

# 1. The app: notarised and its ticket stapled on, so it opens even on a Mac that is offline at first start.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
ditto -c -k --keepParent "$APP" "$work/Exec Room.zip"
notarise "$work/Exec Room.zip"
xcrun stapler staple "$APP"

# 2. The disk image: the app and a link to Applications to drag it onto; signed, notarised and stapled itself.
mkdir -p "$ROOT/dist" "$work/dmg"
ditto "$APP" "$work/dmg/Exec Room.app"
ln -s /Applications "$work/dmg/Applications"
rm -f "$DMG"
hdiutil create -volname "Exec Room" -srcfolder "$work/dmg" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
codesign --force --sign "$SIGN_ID" --timestamp "$DMG"
notarise "$DMG"
xcrun stapler staple "$DMG"

# 3. What a downloading Mac will check.
spctl --assess --type execute -vv "$APP" 2>&1 | sed 's/^/release: /'
spctl --assess --type open --context context:primary-signature -vv "$DMG" 2>&1 | sed 's/^/release: /'
(cd "$ROOT/dist" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "release: $DMG ($(du -h "$DMG" | cut -f1)), SHA-256 in $(basename "$DMG").sha256"
