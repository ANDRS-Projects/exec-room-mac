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
# The app is signed ad hoc, which is enough to run it on this Mac. Signing for other Macs and Apple's notarisation
# come with the release build.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=$(sed -n 's/^version: *//p' "$ROOT/exec-room.ref")
REF=$(sed -n 's/^commit: *//p' "$ROOT/exec-room.ref")
NODE_VERSION=$(sed -n 's/^node: *//p' "$ROOT/exec-room.ref")
APP="$ROOT/build/Exec Room.app"

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
(cd "$code" && PATH="$NODE_DIR/bin:/usr/bin:/bin" npm ci --omit=dev --ignore-scripts --no-audit --no-fund --loglevel=error)

echo "build-app: signing (ad hoc, for this Mac)"
codesign --force --sign - "$APP/Contents/Resources/node/bin/node"
codesign --force --sign - "$APP"

echo "build-app: $APP ($(du -sh "$APP" | cut -f1))"
