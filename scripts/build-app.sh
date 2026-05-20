#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SpacePeek"
BUNDLE_ID="com.zeyadamer.spacepeek"
VERSION="1.0.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/dist"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
ZIP_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.zip"
DMG_STAGE="${BUILD_DIR}/dmg-stage"
ENTITLEMENTS="${ROOT_DIR}/Resources/SpacePeek.entitlements"

# Signing config (env-driven so secrets stay out of git).
#   DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE="notary-profile-name"  (created via: xcrun notarytool store-credentials)
# If unset, falls back to ad-hoc signing (same prompt-loop behaviour as before — for local dev only).
SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

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

if [[ -n "${SIGN_IDENTITY}" ]]; then
    echo "==> Codesign with Developer ID: ${SIGN_IDENTITY}"
    codesign --force --deep --options runtime --timestamp \
        --entitlements "${ENTITLEMENTS}" \
        --sign "${SIGN_IDENTITY}" \
        "${APP_DIR}"
else
    echo "==> Ad-hoc codesign (no DEVELOPER_ID_APPLICATION set)"
    codesign --force --deep --options runtime --sign - "${APP_DIR}"
fi
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

echo "==> Creating ZIP"
( cd "${BUILD_DIR}" && /usr/bin/ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "${ZIP_PATH}" )

if [[ -n "${SIGN_IDENTITY}" && -n "${NOTARY_PROFILE}" ]]; then
    echo "==> Submitting ZIP for notarization (profile: ${NOTARY_PROFILE})"
    xcrun notarytool submit "${ZIP_PATH}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait

    echo "==> Stapling notarization ticket to .app"
    xcrun stapler staple "${APP_DIR}"
    xcrun stapler validate "${APP_DIR}"

    echo "==> Re-creating DMG and ZIP with stapled .app"
    rm -f "${DMG_PATH}" "${ZIP_PATH}"
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
    ( cd "${BUILD_DIR}" && /usr/bin/ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "${ZIP_PATH}" )

    echo "==> Notarizing DMG"
    xcrun notarytool submit "${DMG_PATH}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait
    xcrun stapler staple "${DMG_PATH}"
    xcrun stapler validate "${DMG_PATH}"
else
    echo "==> Skipping notarization (set DEVELOPER_ID_APPLICATION and NOTARY_PROFILE to enable)"
fi

echo ""
echo "Done."
echo "  App: ${APP_DIR}"
echo "  DMG: ${DMG_PATH}"
echo "  ZIP: ${ZIP_PATH}"
echo ""
if [[ -z "${SIGN_IDENTITY}" ]]; then
    echo "Recipients open DMG (or unzip), drag SpacePeek to Applications, then bypass Gatekeeper:"
    echo "  xattr -dr com.apple.quarantine /Applications/SpacePeek.app"
fi
