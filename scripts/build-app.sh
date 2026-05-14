#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SpacePeek"
BUNDLE_ID="com.zeyadamer.spacepeek"
VERSION="0.1.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/dist"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
DMG_STAGE="${BUILD_DIR}/dmg-stage"

echo "==> Cleaning ${BUILD_DIR}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

ICON_PATH="${ROOT_DIR}/Resources/AppIcon.icns"
if [[ ! -f "${ICON_PATH}" ]]; then
    echo "==> Generating AppIcon.icns"
    swift "${ROOT_DIR}/scripts/make-icon.swift" "${ROOT_DIR}/Resources"
fi

echo "==> Release build"
cd "${ROOT_DIR}"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"
if [[ ! -x "${BIN_PATH}" ]]; then
    echo "Cannot locate release binary at ${BIN_PATH}" >&2
    exit 1
fi

echo "==> Assembling ${APP_NAME}.app"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${ROOT_DIR}/Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

if [[ -f "${ICON_PATH}" ]]; then
    cp "${ICON_PATH}" "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

echo "==> Ad-hoc codesign"
codesign --force --deep --options runtime --sign - "${APP_DIR}"
codesign --verify --verbose=2 "${APP_DIR}"

echo "==> Stripping quarantine attribute"
xattr -dr com.apple.quarantine "${APP_DIR}" || true

echo "==> Creating DMG"
mkdir -p "${DMG_STAGE}"
cp -R "${APP_DIR}" "${DMG_STAGE}/"
ln -s /Applications "${DMG_STAGE}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGE}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

rm -rf "${DMG_STAGE}"

echo ""
echo "Done."
echo "  App: ${APP_DIR}"
echo "  DMG: ${DMG_PATH}"
echo ""
echo "Recipients open DMG, drag SpacePeek to Applications, right-click SpacePeek > Open (first launch)."
