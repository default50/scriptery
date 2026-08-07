#!/bin/bash

# Recreate the "FF" GUI launcher app so the ff script can be started from
# Spotlight / Finder (not just a terminal). The original was an Automator
# "Run Shell Script" applet; this rebuilds an equivalent launcher from scratch
# with osacompile, so it's reproducible on a new machine.
#
# The generated app is a tiny AppleScript applet whose only action is to run the
# ff script sitting next to this installer. All the real work — moving managed
# prefs aside, cfprefsd flushing, Touch ID auth — lives in ff itself.
#
# Usage:
#   ./install-ff-app.sh                 # installs /Applications/FF.app
#   ./install-ff-app.sh ~/Applications/FF.app   # custom location
#
# sudo is used automatically only if the destination directory isn't writable.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FF_SCRIPT="${SCRIPT_DIR}/ff"
FF_ICON="${SCRIPT_DIR}/ff-app.icns"
APP_PATH="${1:-/Applications/FF.app}"

if [[ ! -x "${FF_SCRIPT}" ]]; then
    echo "ERROR: ff script not found or not executable at ${FF_SCRIPT}" >&2
    exit 1
fi

# Escape for embedding the path inside the AppleScript string literal.
esc_path=${FF_SCRIPT//\\/\\\\}
esc_path=${esc_path//\"/\\\"}

echo "Building launcher that runs: ${FF_SCRIPT}"
BUILD_DIR="$(mktemp -d)"
BUILD_APP="${BUILD_DIR}/FF.app"
osacompile -o "${BUILD_APP}" -e "do shell script \"${esc_path}\""

# Run headless (no Dock icon / menu bar), matching the original applet.
if ! /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" \
        "${BUILD_APP}/Contents/Info.plist" 2>/dev/null; then
    /usr/libexec/PlistBuddy -c "Set :LSUIElement true" \
        "${BUILD_APP}/Contents/Info.plist"
fi

# Apply the preserved app icon, if present.
#
# osacompile ships TWO icon mechanisms: the loose applet.icns (referenced by
# CFBundleIconFile) and an asset catalog (Assets.car + CFBundleIconName). On
# modern macOS the asset-catalog icon WINS, so just replacing applet.icns leaves
# the stock applet icon showing. We therefore overwrite applet.icns with our
# icon AND strip the asset-catalog icon so CFBundleIconFile is authoritative.
if [[ -f "${FF_ICON}" ]]; then
    echo "Applying icon: ${FF_ICON}"
    cp "${FF_ICON}" "${BUILD_APP}/Contents/Resources/applet.icns"
    # Make CFBundleIconFile the sole icon source.
    /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" \
        "${BUILD_APP}/Contents/Info.plist" 2>/dev/null || true
    rm -f "${BUILD_APP}/Contents/Resources/Assets.car"
    if ! /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile applet" \
            "${BUILD_APP}/Contents/Info.plist" 2>/dev/null; then
        /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string applet" \
            "${BUILD_APP}/Contents/Info.plist"
    fi
    # Re-seal the bundle: editing Info.plist / Resources invalidates the ad-hoc
    # signature osacompile applied.
    codesign --force --sign - "${BUILD_APP}" 2>/dev/null || true
else
    echo "WARNING: ${FF_ICON} not found; app will use the default applet icon." >&2
fi

# Install, elevating only if the destination isn't writable.
DEST_DIR="$(dirname "${APP_PATH}")"
SUDO=""
[[ -w "${DEST_DIR}" ]] || SUDO="sudo"

echo "Installing to ${APP_PATH}${SUDO:+ (needs sudo)}..."
${SUDO} rm -rf "${APP_PATH}"
${SUDO} ditto "${BUILD_APP}" "${APP_PATH}"
${SUDO} touch "${APP_PATH}"
rm -rf "${BUILD_DIR}"

# Force LaunchServices to re-read the bundle and refresh the icon, then bounce
# Dock/Finder so the new icon shows immediately.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[[ -x "${LSREGISTER}" ]] && "${LSREGISTER}" -f "${APP_PATH}" >/dev/null 2>&1 || true
killall Dock Finder 2>/dev/null || true

echo "Done. Launch 'FF' from Spotlight."
echo "Note: the first run may ask for Full Disk Access and/or Touch ID."
