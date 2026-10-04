#!/bin/bash
# Builds Percolate.app into ./build. Requires Xcode + xcodegen (brew install xcodegen).
set -euo pipefail
cd "$(dirname "$0")"
xcodegen generate --quiet
xcodebuild -project Percolate.xcodeproj -scheme Percolate -configuration "${CONFIG:-Release}" \
  -destination "generic/platform=macOS" -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY=- build -quiet
rm -rf build/Percolate.app
cp -R "build/DerivedData/Build/Products/${CONFIG:-Release}/Percolate.app" build/
echo "Built $(pwd)/build/Percolate.app"
