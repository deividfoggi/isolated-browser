#!/usr/bin/env bash
# Empacota dist/IsolatedBrowser.app em dist/IsolatedBrowser.dmg (com atalho para /Applications).
set -euo pipefail

cd "$(dirname "$0")/.."
APP="dist/IsolatedBrowser.app"
DMG="dist/IsolatedBrowser.dmg"
VOL="Isolated Browser"

[ -d "${APP}" ] || ./app/build-app.sh

rm -f "${DMG}"
staging="$(mktemp -d)"
cp -R "${APP}" "${staging}/"
ln -s /Applications "${staging}/Applications"

hdiutil create \
    -volname "${VOL}" \
    -srcfolder "${staging}" \
    -ov -format UDZO \
    "${DMG}"

rm -rf "${staging}"
echo "[build-dmg] pronto: ${DMG}"
