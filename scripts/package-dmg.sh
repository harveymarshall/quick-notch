#!/usr/bin/env bash
# Build QuickNotch.app and package dist/QuickNotch-<version>.dmg
# Works with full Xcode (preferred) or Command Line Tools + macOS SDK (fallback).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="QuickNotch"
CONFIGURATION="${CONFIGURATION:-Release}"
# Prefer explicit VERSION (CI release workflow), then fall back to Xcode marketing version.
if [[ -z "${VERSION:-}" ]]; then
  VERSION="$(grep -E 'MARKETING_VERSION' QuickNotch.xcodeproj/project.pbxproj | head -1 | sed -E 's/.*=[[:space:]]*([0-9.]+);/\1/' || true)"
fi
VERSION="${VERSION:-1.0.0}"
VERSION="${VERSION#v}"

BUILD_ROOT="${ROOT}/build"
STAGE="${BUILD_ROOT}/dmg-stage"
DMG_DIR="${ROOT}/dist"
DMG_PATH="${DMG_DIR}/${APP_NAME}-${VERSION}.dmg"
APP_BUNDLE="${BUILD_ROOT}/${APP_NAME}.app"

mkdir -p "${DMG_DIR}" "${BUILD_ROOT}"
rm -rf "${STAGE}" "${APP_BUNDLE}"
mkdir -p "${STAGE}"

have_full_xcode() {
  if xcodebuild -version >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

build_with_xcode() {
  local derived="${BUILD_ROOT}/DerivedData"
  rm -rf "${derived}"
  echo "==> Building with xcodebuild (${CONFIGURATION})"
  xcodebuild \
    -project QuickNotch.xcodeproj \
    -scheme "${APP_NAME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${derived}" \
    -destination "platform=macOS" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=YES \
    build

  local built
  built="$(find "${derived}/Build/Products/${CONFIGURATION}" -name "${APP_NAME}.app" -maxdepth 1 | head -1)"
  if [[ -z "${built}" ]]; then
    echo "error: ${APP_NAME}.app not found after xcodebuild" >&2
    exit 1
  fi
  cp -R "${built}" "${APP_BUNDLE}"
}

build_with_swiftc() {
  echo "==> Building with swiftc (Command Line Tools fallback)"
  local sdk
  sdk="$(xcrun --sdk macosx --show-sdk-path)"
  local bin_dir="${BUILD_ROOT}/bin"
  mkdir -p "${bin_dir}"

  local sources=(
    QuickNotch/QuickNotchApp.swift
    QuickNotch/AppDelegate.swift
    QuickNotch/AppState.swift
    QuickNotch/Notch/NotchGeometry.swift
    QuickNotch/Notch/NotchExpansionShape.swift
    QuickNotch/Notch/NotchPanelController.swift
    QuickNotch/Notch/NotchViews.swift
    QuickNotch/Settings/SettingsView.swift
    QuickNotch/Settings/SettingsWindowController.swift
    QuickNotch/Services/SettingsStore.swift
    QuickNotch/Services/NoteWriter.swift
    QuickNotch/Services/GlobalHotKey.swift
  )

  compile_slice() {
    local arch="$1"
    local out="$2"
    xcrun --sdk macosx swiftc \
      -sdk "${sdk}" \
      -target "${arch}-apple-macos14.0" \
      -O \
      -parse-as-library \
      -framework SwiftUI \
      -framework AppKit \
      -framework Carbon \
      -framework QuartzCore \
      "${sources[@]}" \
      -o "${out}"
  }

  local host_arch
  host_arch="$(uname -m)"
  if [[ "${UNIVERSAL:-1}" == "1" ]]; then
    echo "==> Compiling arm64 + x86_64 slices"
    compile_slice arm64 "${bin_dir}/${APP_NAME}-arm64"
    compile_slice x86_64 "${bin_dir}/${APP_NAME}-x86_64"
    lipo -create \
      "${bin_dir}/${APP_NAME}-arm64" \
      "${bin_dir}/${APP_NAME}-x86_64" \
      -output "${bin_dir}/${APP_NAME}"
  else
    echo "==> Compiling ${host_arch} only"
    compile_slice "${host_arch}" "${bin_dir}/${APP_NAME}"
  fi

  echo "==> Assembling ${APP_BUNDLE}"
  mkdir -p "${APP_BUNDLE}/Contents/MacOS"
  mkdir -p "${APP_BUNDLE}/Contents/Resources"
  cp "${bin_dir}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

  # Resolve Info.plist placeholders for a standalone bundle.
  /usr/bin/sed \
    -e "s/\$(EXECUTABLE_NAME)/${APP_NAME}/g" \
    -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.harvey.QuickNotch/g" \
    -e "s/\$(PRODUCT_NAME)/${APP_NAME}/g" \
    -e "s/\$(MARKETING_VERSION)/${VERSION}/g" \
    -e "s/\$(CURRENT_PROJECT_VERSION)/1/g" \
    -e "s/\$(MACOSX_DEPLOYMENT_TARGET)/14.0/g" \
    QuickNotch/Info.plist > "${APP_BUNDLE}/Contents/Info.plist"

  printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"
}

if have_full_xcode; then
  build_with_xcode
else
  build_with_swiftc
fi

echo "==> Ad-hoc signing ${APP_BUNDLE}"
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Staging DMG contents"
cp -R "${APP_BUNDLE}" "${STAGE}/"
ln -sf /Applications "${STAGE}/Applications"

echo "==> Creating ${DMG_PATH}"
rm -f "${DMG_PATH}"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGE}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" >/dev/null

echo "==> Done"
ls -lh "${DMG_PATH}"
echo "${DMG_PATH}"
