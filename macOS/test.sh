#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
BUILD_ROOT="${SCHEDULE_BUILD_ROOT:-$PWD/.build}"
export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/module-cache"
DEVELOPER_DIR_PATH="$(xcode-select -p)"
FRAMEWORKS="$DEVELOPER_DIR_PATH/Library/Developer/Frameworks"
# Command Line Tools 26 includes Swift Testing; supply its framework search path.
if [ -d "$FRAMEWORKS/Testing.framework" ]; then
  swift test --disable-xctest --enable-swift-testing --disable-sandbox --scratch-path "$BUILD_ROOT" --cache-path "$BUILD_ROOT/cache" \
    -Xswiftc -F -Xswiftc "$FRAMEWORKS" -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
    -Xlinker -F -Xlinker "$FRAMEWORKS" -Xlinker -rpath -Xlinker "$FRAMEWORKS"
else
  swift test --disable-xctest --enable-swift-testing --scratch-path "$BUILD_ROOT"
fi
