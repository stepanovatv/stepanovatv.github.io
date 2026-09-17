#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
BUILD_ROOT="${SCHEDULE_BUILD_ROOT:-$PWD/.build}"
export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/module-cache"
swift build -c release --disable-sandbox --scratch-path "$BUILD_ROOT" --cache-path "$BUILD_ROOT/cache"
BIN_DIR="$(swift build -c release --disable-sandbox --scratch-path "$BUILD_ROOT" --cache-path "$BUILD_ROOT/cache" --show-bin-path)"
APP_DIR="$PWD/build/Расписание занятий.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/AvailabilitySchedule" "$APP_DIR/Contents/MacOS/AvailabilitySchedule"
cp -R "$BIN_DIR/PublicAvailabilitySchedule_ScheduleApp.bundle" "$APP_DIR/Contents/Resources/"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>AvailabilitySchedule</string>
<key>CFBundleIdentifier</key><string>app.publicavailability.schedule</string>
<key>CFBundleName</key><string>Расписание занятий</string>
<key>CFBundleDisplayName</key><string>Расписание занятий</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDevelopmentRegion</key><string>ru</string>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><false/></dict>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP_DIR"
echo "Готово: $APP_DIR"
