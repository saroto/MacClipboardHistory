#!/bin/bash
set -euo pipefail
SCHEME=MacOsClipBoard
BUILD=$(mktemp -d)
STAGE=$(mktemp -d)
xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" \
  -configuration Release -derivedDataPath "$BUILD" build
cp -R "$BUILD/Build/Products/Release/$SCHEME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$SCHEME" -srcfolder "$STAGE" -ov -format UDZO "$SCHEME.dmg"
