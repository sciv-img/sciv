#!/bin/sh
set -x

MODE=${1:-release}

swift build -c $MODE -Xlinker -L/usr/local/lib

APP=".build/sciv.app"

rm -rf "$APP"
mkdir -p "$APP"/Contents/MacOS
cp ".build/$MODE/sciv" "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents"
