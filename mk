#!/bin/sh

xcrun -sdk macosx swiftc -O -o ".build/release/sciv" Vendor/*.swift Sources/*.swift

APP=".build/sciv.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/sciv" "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents"
