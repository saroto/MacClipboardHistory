#!/bin/bash
# Builds a Release .app and packages it as a DMG next to this script.
set -euo pipefail

SCHEME=MacOsClipBoard
VOLNAME=Reclip
# Anchor to this script's own directory, never the caller's cwd — the previous
# version wrote the DMG wherever you happened to be standing and said nothing.
PROJECT_DIR=$(cd "$(dirname "$0")" && pwd)
OUT="$PROJECT_DIR/$VOLNAME.dmg"
BUILD="$PROJECT_DIR/build"          # reused, so rebuilds are incremental
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

xcodebuild -project "$PROJECT_DIR/$SCHEME.xcodeproj" -scheme "$SCHEME" \
  -configuration Release -derivedDataPath "$BUILD" build

cp -R "$BUILD/Build/Products/Release/$SCHEME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$OUT"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -ov -format UDZO "$OUT" >/dev/null

echo
echo "DMG written to: $OUT"
ls -lh "$OUT" | awk '{print "Size: " $5}'
