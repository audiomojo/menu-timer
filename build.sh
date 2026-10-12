#!/bin/sh
# Builds AlarmTimer.app in the project root. Usage: ./build.sh [--run]
set -e
cd "$(dirname "$0")"

swift build -c release
APP=AlarmTimer.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/AlarmTimer" "$APP/Contents/MacOS/AlarmTimer"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"

if [ "$1" = "--run" ]; then
    open "$APP"
fi
