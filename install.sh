#!/bin/sh
# Builds and tests AlarmTimer.app, puts the latest copy (and a .zip) in install/,
# installs it to /Applications, and restarts it from there. Usage: ./install.sh
set -e
cd "$(dirname "$0")"

./build.sh
AlarmTimer.app/Contents/MacOS/AlarmTimer --self-test

APP=AlarmTimer.app
rm -rf install
mkdir -p install
ditto "$APP" "install/$APP"
ditto -c -k --keepParent "$APP" install/AlarmTimer.zip

pkill -x AlarmTimer 2>/dev/null && sleep 1 || true
rm -rf "/Applications/$APP"
ditto "$APP" "/Applications/$APP"
open "/Applications/$APP"
echo "Installed /Applications/$APP (copy and zip in install/)"
