#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${1:-${PROJECT_DIR}/build}"
APP_DIR="${BUILD_DIR}/HomeMonitor.app"
APP_CONTENTS="${APP_DIR}/Contents"
APP_MACOS="${APP_CONTENTS}/MacOS"
APP_RESOURCES="${APP_CONTENTS}/Resources"
SDK_PATH="${SDK_PATH:-$(xcrun --show-sdk-path)}"
CACHE_PATH="${CACHE_PATH:-/tmp/clang-cache}"
APP_VERSION="${APP_VERSION:-${VERSION:-2.1.0}}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

echo "=== 1. Preparing directories ==="
echo "Project Directory: ${PROJECT_DIR}"
echo "Build Directory:   ${BUILD_DIR}"
echo "SDK Path:          ${SDK_PATH}"
echo "Version:           ${APP_VERSION} (Build ${BUILD_NUMBER})"

rm -rf "${APP_DIR}"
mkdir -p "${APP_MACOS}" "${APP_RESOURCES}"
mkdir -p "${CACHE_PATH}"

echo "=== 2. Copying Icon Assets ==="
if [ -f "${PROJECT_DIR}/HomeMonitor/Resources/AppIcon.icns" ]; then
  cp "${PROJECT_DIR}/HomeMonitor/Resources/AppIcon.icns" "${APP_RESOURCES}/AppIcon.icns"
fi

SWIFT_SOURCES=(
  "${PROJECT_DIR}/Shared/SharedModels.swift"
  "${PROJECT_DIR}/HomeMonitor/StreamHub.swift"
  "${PROJECT_DIR}/HomeMonitor/RTSPStreamPlayer.swift"
  "${PROJECT_DIR}/HomeMonitor/WindowAccessor.swift"
  "${PROJECT_DIR}/HomeMonitor/DockPanel.swift"
  "${PROJECT_DIR}/HomeMonitor/MenuBarManager.swift"
  "${PROJECT_DIR}/HomeMonitor/Views.swift"
  "${PROJECT_DIR}/HomeMonitor/HomeMonitorApp.swift"
)

echo "=== 3. Compiling Universal (arm64 + x86_64) Native macOS Binary ==="
TEMP_BIN_DIR=$(mktemp -d /tmp/hm-bin-XXXXXX)
trap 'rm -rf "${TEMP_BIN_DIR}"' EXIT

echo "  -> Compiling arm64..."
swiftc -module-cache-path "${CACHE_PATH}" \
  -target arm64-apple-macos14.0 \
  -sdk "${SDK_PATH}" \
  -O \
  "${SWIFT_SOURCES[@]}" \
  -o "${TEMP_BIN_DIR}/HomeMonitor-arm64"

echo "  -> Compiling x86_64..."
swiftc -module-cache-path "${CACHE_PATH}" \
  -target x86_64-apple-macos14.0 \
  -sdk "${SDK_PATH}" \
  -O \
  "${SWIFT_SOURCES[@]}" \
  -o "${TEMP_BIN_DIR}/HomeMonitor-x86_64"

echo "  -> Creating Universal Fat Binary with lipo..."
lipo -create -output "${APP_MACOS}/HomeMonitor" \
  "${TEMP_BIN_DIR}/HomeMonitor-arm64" \
  "${TEMP_BIN_DIR}/HomeMonitor-x86_64"

chmod +x "${APP_MACOS}/HomeMonitor"

echo "=== 4. Generating Metadata and Plists ==="
echo "APPL????" > "${APP_CONTENTS}/PkgInfo"
cat << EOF > "${APP_CONTENTS}/Info.plist"
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
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHomeKitUsageDescription</key>
    <string>HomeMonitor needs HomeKit access to discover and display your camera feeds.</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.example.HomeMonitor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>homemonitor</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "=== 5. Code signing (Ad-Hoc without sandbox constraints) ==="
codesign -s - --force "${APP_DIR}"

echo "=== Build completed successfully! ==="
echo "Application bundle created at: ${APP_DIR}"
lipo -info "${APP_MACOS}/HomeMonitor"
