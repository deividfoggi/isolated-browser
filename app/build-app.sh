#!/usr/bin/env bash
# Gera dist/IsolatedBrowser.app a partir do fonte Swift (ADR-0003).
# Compila o app nativo, gera o ícone, monta o bundle e assina ad-hoc.
set -euo pipefail

cd "$(dirname "$0")/.."
APP_DIR="dist/IsolatedBrowser.app"
CONTENTS="${APP_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
RES="${CONTENTS}/Resources"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS}" "${RES}"

echo "[build-app] compilando IsolatedBrowser.swift"
swiftc app/IsolatedBrowser.swift -O -o "${MACOS}/IsolatedBrowser" \
    -framework Cocoa -framework WebKit

echo "[build-app] copiando Info.plist"
cp app/Info.plist "${CONTENTS}/Info.plist"

echo "[build-app] gerando ícone"
tmpicon="$(mktemp -d)"
swiftc app/make-icon.swift -o "${tmpicon}/mkicon" -framework Cocoa
"${tmpicon}/mkicon" "${tmpicon}/icon_1024.png"
iconset="${tmpicon}/icon.iconset"
mkdir -p "${iconset}"
for s in 16 32 64 128 256 512; do
    sips -z "$s" "$s"       "${tmpicon}/icon_1024.png" --out "${iconset}/icon_${s}x${s}.png"     >/dev/null
    d=$((s * 2))
    sips -z "$d" "$d"       "${tmpicon}/icon_1024.png" --out "${iconset}/icon_${s}x${s}@2x.png"  >/dev/null
done
cp "${tmpicon}/icon_1024.png" "${iconset}/icon_512x512@2x.png"
iconutil -c icns "${iconset}" -o "${RES}/icon.icns"
rm -rf "${tmpicon}"

echo "[build-app] assinatura ad-hoc"
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

echo "[build-app] pronto: ${APP_DIR}"
echo "Instale com: cp -R ${APP_DIR} /Applications/"
