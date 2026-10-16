#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${1:-${PROJECT_DIR}/build/HomeMonitor.app}"
OUTPUT_DIR="${2:-$(dirname "${APP_DIR}")}"
APP_VERSION="${APP_VERSION:-${VERSION:-2.1.0}}"

if [ ! -d "${APP_DIR}" ]; then
  echo "Error: App bundle not found at ${APP_DIR}"
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
DMG_NAME="HomeMonitor-${APP_VERSION}.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
ZIP_NAME="HomeMonitor-${APP_VERSION}.zip"
ZIP_PATH="${OUTPUT_DIR}/${ZIP_NAME}"

echo "=== Packaging HomeMonitor v${APP_VERSION} ==="
echo "App Bundle: ${APP_DIR}"
echo "Output Dir: ${OUTPUT_DIR}"

# 1. Create ZIP Archive
echo "--- 1. Creating ZIP Archive ---"
rm -f "${ZIP_PATH}"
(cd "$(dirname "${APP_DIR}")" && zip -r -y "${ZIP_PATH}" "$(basename "${APP_DIR}")")
cp -f "${ZIP_PATH}" "${OUTPUT_DIR}/HomeMonitor.zip"
echo "Created: ${ZIP_PATH}"

# 2. Create DMG Disk Image
echo "--- 2. Creating DMG Disk Image ---"
rm -f "${DMG_PATH}" "${OUTPUT_DIR}/HomeMonitor.dmg"

STAGING_DIR=$(mktemp -d /tmp/hm-dmg-staging-XXXXXX)
trap 'rm -rf "${STAGING_DIR}"' EXIT

cp -R "${APP_DIR}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

if command -v create-dmg >/dev/null 2>&1; then
  echo "Using create-dmg tool..."
  create-dmg \
    --volname "HomeMonitor" \
    --volicon "${PROJECT_DIR}/HomeMonitor/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "HomeMonitor.app" 175 190 \
    --hide-extension "HomeMonitor.app" \
    --app-drop-link 425 190 \
    "${DMG_PATH}" \
    "${STAGING_DIR}" || \
  hdiutil create -volname "HomeMonitor" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_PATH}"
else
  echo "Using native hdiutil..."
  hdiutil create -volname "HomeMonitor" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_PATH}"
fi

cp -f "${DMG_PATH}" "${OUTPUT_DIR}/HomeMonitor.dmg"
echo "Created: ${DMG_PATH}"

# 3. Calculate SHA256 Checksums
echo "--- 3. Checksums (SHA256) ---"
(
  cd "${OUTPUT_DIR}"
  shasum -a 256 "${DMG_NAME}" "${ZIP_NAME}" | tee "checksums.txt"
)

echo "=== Packaging Completed Successfully ==="
