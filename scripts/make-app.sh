#!/bin/bash
# Release binary'sini /Applications/Droper.app paketine sarar.
# Kullanım: ./scripts/make-app.sh  (önce: swift build -c release)
set -euo pipefail

cd "$(dirname "$0")/.."

BINARY=".build/release/Droper"
APP="/Applications/Droper.app"

if [ ! -f "$BINARY" ]; then
    echo "Önce derleyin: swift build -c release" >&2
    exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp "$BINARY" "$APP/Contents/MacOS/Droper"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Droper</string>
    <key>CFBundleIdentifier</key>
    <string>com.uveyscolak.droper</string>
    <key>CFBundleName</key>
    <string>Droper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"

echo "Hazır: $APP"
echo "Başlatmak için: open $APP"
echo "İlk açılışta Erişilebilirlik izni verin: Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik → Droper"
