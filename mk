#!/bin/sh
set -e -x

MODE=${1:-release}

cat > "Sources/Cpcre/module.modulemap" <<EOF
module Cpcre [system] {
	header "$(pkg-config --variable=includedir libpcre)/pcre.h"
	link "pcre"
	export *
}
EOF
WEBP_DIR=$(pkg-config --variable=includedir libwebp)
cat > "Sources/Cwebp/module.modulemap" <<EOF
module Cwebp [system] {
	module Decode {
		header "$WEBP_DIR/webp/decode.h"
		export *
	}
	module Encode {
		header "$WEBP_DIR/webp/encode.h"
		export *
	}
	module Types {
		header "$WEBP_DIR/webp/types.h"
		export *
	}
	link "pcre"
}
EOF
swift build -c $MODE

APP=".build/sciv.app"

rm -rf "$APP"
mkdir -p "$APP"/Contents/MacOS
cp ".build/$MODE/sciv" "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents"
