#!/bin/sh

mkdir -p ".build/release"
xcrun -sdk macosx swiftc -O -o ".build/release/sciv" Sources/*.swift -F Carthage/Build/Mac

APP=".build/sciv.app"

rm -rf "$APP"
mkdir -p "$APP"/Contents/{MacOS,Frameworks}
cp ".build/release/sciv" "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents"
cp -R "Carthage/Build/Mac/PathKit.framework" "$APP/Contents/Frameworks/"
cp -R "Carthage/Build/Mac/Regex.framework" "$APP/Contents/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/sciv"
