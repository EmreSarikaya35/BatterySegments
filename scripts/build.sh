#!/bin/bash
# Release build -> build/Build/Products/Release/BatterySegments.app
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -scheme BatterySegments -configuration Release -derivedDataPath build build | xcbeautify
