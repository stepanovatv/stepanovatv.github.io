#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
BUILD_ROOT="${SCHEDULE_BUILD_ROOT:-$PWD/.build}"
SCHEDULE_SDK_PATH="${SCHEDULE_MACOS_SDK:-$(xcrun --show-sdk-path)}"
export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/module-cache"
swift build --sdk "$SCHEDULE_SDK_PATH" --build-system native -c release --disable-sandbox --scratch-path "$BUILD_ROOT" --cache-path "$BUILD_ROOT/cache" -Xswiftc -no-toolchain-stdlib-rpath
BIN_DIR="$(swift build --sdk "$SCHEDULE_SDK_PATH" --build-system native -c release --disable-sandbox --scratch-path "$BUILD_ROOT" --cache-path "$BUILD_ROOT/cache" --show-bin-path)"
APP_DIR="${SCHEDULE_APP_OUTPUT:-$PWD/build/Расписание занятий.app}"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/AvailabilitySchedule" "$APP_DIR/Contents/MacOS/AvailabilitySchedule"
# SwiftPM can explicitly add the local toolchain to LC_RPATH even with the
# compiler flag above. A distributed application must not depend on that path.
while IFS= read -r RUNTIME_PATH; do
  case "$RUNTIME_PATH" in
    /Library/Developer/*|/Applications/Xcode*.app/*|/Users/*)
      install_name_tool -delete_rpath "$RUNTIME_PATH" "$APP_DIR/Contents/MacOS/AvailabilitySchedule"
      ;;
  esac
done < <(otool -l "$APP_DIR/Contents/MacOS/AvailabilitySchedule" | awk '
  $1 == "cmd" { command = $2 }
  command == "LC_RPATH" && $1 == "path" { sub(/^[[:space:]]*path /, ""); sub(/ \(offset.*$/, ""); print }
')
cp -R "$BIN_DIR/PublicAvailabilitySchedule_ScheduleApp.bundle" "$APP_DIR/Contents/Resources/"
swift -module-cache-path "$BUILD_ROOT/module-cache" BuildTools/GenerateIcon.swift "$BUILD_ROOT/AppIcon.iconset"
cp "$BUILD_ROOT/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
chmod 755 "$APP_DIR" "$APP_DIR/Contents" "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/MacOS/AvailabilitySchedule"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>AvailabilitySchedule</string>
<key>CFBundleIdentifier</key><string>app.publicavailability.schedule</string>
<key>CFBundleName</key><string>Расписание занятий</string>
<key>CFBundleDisplayName</key><string>Расписание занятий</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleIconFile</key><string>AppIcon.icns</string>
<key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
<key>CFBundleShortVersionString</key><string>1.3.0</string>
<key>CFBundleVersion</key><string>7</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDevelopmentRegion</key><string>ru</string>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><false/></dict>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
"$APP_DIR/Contents/MacOS/AvailabilitySchedule" --verify-package
echo "Готово: $APP_DIR"
