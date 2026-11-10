#!/bin/bash
# Ad-hoc signed app -> BatterySegments.dmg (no Apple Developer account, not notarized)
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh

APP=build/Build/Products/Release/BatterySegments.app
codesign --force --deep --sign - "$APP"

rm -rf build/dmg BatterySegments.dmg
mkdir -p build/dmg
cp -R "$APP" build/dmg/
cp Okuyun.txt build/dmg/

create-dmg --volname BatterySegments --window-size 600 400 --icon-size 96 \
  --icon BatterySegments.app 150 170 --app-drop-link 450 170 --icon Okuyun.txt 300 310 \
  BatterySegments.dmg build/dmg
