#!/bin/zsh
# Lapso をビルドして build/Lapso.app と dist/Lapso-v<版>.zip を作る
#   SDK=<path> ./build.sh   … SDK を指定（コンパイラと SDK の版が合わないとき）
#   INSTALL=1 ./build.sh    … ~/Applications にも配置する
set -euo pipefail
cd "$(dirname "$0")"

SDK="${SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
APP=build/Lapso.app

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist
swiftc -sdk "$SDK" -target arm64-apple-macos13.0 -O -swift-version 5 main.swift -o "$APP/Contents/MacOS/Lapso"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
codesign --verify --verbose "$APP"

ZIP="dist/Lapso-v$VERSION.zip"
rm -f "$ZIP"
# 拡張属性・リソースフォークは含めない（._ ファイルを作らない）
ditto -c -k --norsrc --noextattr --noqtn --keepParent "$APP" "$ZIP"
echo "OK: $APP / $ZIP"

if [[ "${INSTALL:-}" == "1" ]]; then
    mkdir -p ~/Applications
    ditto "$APP" ~/Applications/Lapso.app
    # アイコン差し替えを Finder に反映させる（同じパスだと古いアイコンがキャッシュされたままになる）
    touch ~/Applications/Lapso.app
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f ~/Applications/Lapso.app
    echo "Installed: ~/Applications/Lapso.app"
fi
