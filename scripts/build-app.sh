#!/bin/sh
# Builds "Exec Room.app" in build/: the menu-bar program, Node from nodejs.org, and the Exec Room's code at the
# commit pinned in exec-room.ref with its packages. Apple silicon only.
#
#   NODE_DIR=/path/to/node-v22.x-darwin-arm64 EXEC_ROOM_DIR=/path/to/exec-room scripts/build-app.sh
#
# NODE_DIR     an unpacked official Node build for Apple silicon (node-v<version>-darwin-arm64 from nodejs.org).
#              Homebrew's Node can't be used: it needs other Homebrew files that other Macs don't have.
# EXEC_ROOM_DIR a clone of github.com/ANDRS-Projects/exec-room that has the pinned commit (`git fetch` it first).
#
# SIGN_ID       optional: the signing certificate, "Developer ID Application: <name> (<team id>)". Without it the
#               app is signed for this Mac only ("-"). Both use Apple's hardened runtime, so a local build behaves as
#               a release does. scripts/release.sh signs with a Developer ID and has Apple notarise the result.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=$(sed -n 's/^version: *//p' "$ROOT/exec-room.ref")
REF=$(sed -n 's/^commit: *//p' "$ROOT/exec-room.ref")
NODE_VERSION=$(sed -n 's/^node: *//p' "$ROOT/exec-room.ref")
APP="$ROOT/build/Exec Room.app"
SIGN_ID=${SIGN_ID:--}

fail() { echo "build-app: $*" >&2; exit 1; }

[ -n "${NODE_DIR:-}" ] || fail "set NODE_DIR to an unpacked nodejs.org build (node-v$NODE_VERSION-darwin-arm64)"
[ -n "${EXEC_ROOM_DIR:-}" ] || fail "set EXEC_ROOM_DIR to a clone of ANDRS-Projects/exec-room"
[ "$(uname -m)" = arm64 ] || fail "build on an Apple silicon Mac"

# Node: the official build, for Apple silicon, the pinned version.
node_bin="$NODE_DIR/bin/node"
[ -x "$node_bin" ] || fail "$node_bin isn't there"
lipo -archs "$node_bin" | grep -qx arm64 || fail "$node_bin isn't built for Apple silicon only"
[ "$("$node_bin" --version)" = "v$NODE_VERSION" ] || fail "$node_bin is $("$node_bin" --version), exec-room.ref pins v$NODE_VERSION"
codesign -dv "$node_bin" 2>&1 | grep -q "TeamIdentifier=HX7739G8FX" || fail "$node_bin isn't the nodejs.org build (not signed by the Node.js Foundation)"
otool -L "$node_bin" | tail -n +2 | grep -v -e "^\s*/usr/lib/" -e "^\s*/System/" && fail "$node_bin needs libraries outside macOS"

# The Exec Room's code at the pinned commit.
git -C "$EXEC_ROOM_DIR" cat-file -e "$REF^{commit}" 2>/dev/null || fail "$EXEC_ROOM_DIR doesn't have commit $REF: git fetch it"

echo "build-app: the program"
swift build --package-path "$ROOT" -c release --arch arm64 >/dev/null
BIN=$(swift build --package-path "$ROOT" -c release --arch arm64 --show-bin-path)/ExecRoom

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/node/bin" "$APP/Contents/Resources/exec-room"
sed "s/@VERSION@/$VERSION/g" "$ROOT/Resources/Info.plist" > "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/ExecRoom"

echo "build-app: Node $NODE_VERSION"
cp "$node_bin" "$APP/Contents/Resources/node/bin/node"
cp "$NODE_DIR/LICENSE" "$APP/Contents/Resources/node/LICENSE"

echo "build-app: Exec Room at ${REF%"${REF#????????}"}"
code="$APP/Contents/Resources/exec-room"
# Only what the room needs to run, and its licence and notices. Tests, docs, CI and setup.sh stay out.
git -C "$EXEC_ROOM_DIR" archive "$REF" room-server.js mcp-catalog.json package.json package-lock.json public agents \
    LICENSE README.md THIRD-PARTY-NOTICES.md | tar -x -C "$code"
echo "$REF" > "$code/COMMIT"

echo "build-app: the icon, from the room's own mark"
# public/mark.svg at the pinned commit, scaled into Apple's icon grid (824 of 1024 pixels, centred), then every size
# macOS asks for. qlmanage renders SVG with the system's WebKit.
icon_tmp=$(mktemp -d)
python3 - "$code/public/mark.svg" "$icon_tmp/icon.svg" <<'PY'
import re, sys
mark = open(sys.argv[1]).read()
inner = re.sub(r"<title>.*?</title>", "", re.search(r"<svg[^>]*>(.*)</svg>", mark, re.S).group(1), flags=re.S)
k = 824 / 60  # the mark's square runs from 2 to 62 in its 64-unit box
open(sys.argv[2], "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
                             f'<g transform="translate({100 - 2 * k:.3f} {100 - 2 * k:.3f}) scale({k:.5f})">{inner}</g></svg>')
PY
qlmanage -t -s 1024 -o "$icon_tmp" "$icon_tmp/icon.svg" >/dev/null 2>&1
[ -s "$icon_tmp/icon.svg.png" ] || fail "couldn't draw the icon from public/mark.svg"
mkdir "$icon_tmp/AppIcon.iconset"
for size in 16 32 128 256 512; do
    sips -z $size $size "$icon_tmp/icon.svg.png" --out "$icon_tmp/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$icon_tmp/icon.svg.png" --out "$icon_tmp/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$icon_tmp/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$icon_tmp"
(cd "$code" && PATH="$NODE_DIR/bin:/usr/bin:/bin" npm ci --omit=dev --ignore-scripts --no-audit --no-fund --loglevel=error)

# Inside out: Node first (with what V8 needs, see Resources/node.entitlements), then the app around it. A Developer ID
# signature gets Apple's secure timestamp, which notarisation requires.
if [ "$SIGN_ID" = "-" ]; then
    echo "build-app: signing for this Mac only"
    stamp=""
else
    echo "build-app: signing as $SIGN_ID"
    stamp="--timestamp"
fi
codesign --force --sign "$SIGN_ID" --options runtime $stamp --entitlements "$ROOT/Resources/node.entitlements" \
    "$APP/Contents/Resources/node/bin/node"
codesign --force --sign "$SIGN_ID" --options runtime $stamp "$APP"
codesign --verify --strict --deep "$APP" || fail "the signature doesn't check out"

echo "build-app: $APP ($(du -sh "$APP" | cut -f1))"
