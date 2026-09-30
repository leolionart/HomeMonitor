#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/Volumes/DATA/Coding Projects/HomeMonitor"
BUILD_DIR="${1:-/tmp/HomeMonitor-build}"
APP_DIR="${BUILD_DIR}/HomeMonitor.app"
APP_CONTENTS="${APP_DIR}/Contents"
APP_MACOS="${APP_CONTENTS}/MacOS"
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX27.0.sdk"
CACHE_PATH="/tmp/clang-cache"

echo "=== 1. Preparing directories ==="
rm -rf "${APP_DIR}"
mkdir -p "${APP_MACOS}" "${APP_CONTENTS}/Resources"
mkdir -p "${CACHE_PATH}"

echo "=== 2. Copying Icon Assets ==="
if [ -f "${PROJECT_DIR}/HomeMonitor/Resources/AppIcon.icns" ]; then
  cp "${PROJECT_DIR}/HomeMonitor/Resources/AppIcon.icns" "${APP_CONTENTS}/Resources/AppIcon.icns"
fi

echo "=== 3. Compiling Pure Native macOS Application ==="
swiftc -module-cache-path "${CACHE_PATH}" \
  -target arm64-apple-macos14.0 \
  -sdk "${SDK_PATH}" \
  "${PROJECT_DIR}/Shared/SharedModels.swift" \
  "${PROJECT_DIR}/HomeMonitor/RTSPStreamPlayer.swift" \
  "${PROJECT_DIR}/HomeMonitor/WindowAccessor.swift" \
  "${PROJECT_DIR}/HomeMonitor/MenuBarManager.swift" \
  "${PROJECT_DIR}/HomeMonitor/Views.swift" \
  "${PROJECT_DIR}/HomeMonitor/HomeMonitorApp.swift" \
  -o "${APP_MACOS}/HomeMonitor"

echo "=== 4. Generating Metadata and Plists ==="
echo "APPL????" > "${APP_CONTENTS}/PkgInfo"
cat << 'EOF' > "${APP_CONTENTS}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>HomeMonitor</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.HomeMonitor</string>
    <key>CFBundleName</key>
    <string>HomeMonitor</string>
    <key>CFBundleDisplayName</key>
    <string>HomeMonitor</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

echo "=== 5. Code signing (Ad-Hoc without sandbox constraints) ==="
codesign -s - --force "${APP_DIR}"

echo "=== Build completed successfully! ==="
echo "Application bundle created at: ${APP_DIR}"
