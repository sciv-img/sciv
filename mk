#!/bin/sh

swift build -c release

APP=".build/sciv.app"

rm -rf "$APP"
mkdir -p "$APP"/Contents/MacOS
cp ".build/release/sciv" "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents"
