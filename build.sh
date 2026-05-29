#!/bin/bash
set -e

# Reset build folder directory
rm -rf build
mkdir -p build/DeskGPT.app/Contents/MacOS
mkdir -p build/DeskGPT.app/Contents/Resources

# 1. Automate macOS ICNS App Icon bundle generation from flat high-res PNG
echo "🎨 플랫 앱 아이콘 생성 중..."
ICON_SRC="/Users/hunchulchoi/.gemini/antigravity/brain/46601610-fd48-492e-bdeb-86cf24510bea/deskgpt_flat_icon_1780031119679.png"
ICONSET_DIR="build/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

sips -s format png -z 16 16     "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16.png"
sips -s format png -z 32 32     "$ICON_SRC" --out "$ICONSET_DIR/icon_16x16@2x.png"
sips -s format png -z 32 32     "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32.png"
sips -s format png -z 64 64     "$ICON_SRC" --out "$ICONSET_DIR/icon_32x32@2x.png"
sips -s format png -z 128 128   "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128.png"
sips -s format png -z 256 256   "$ICON_SRC" --out "$ICONSET_DIR/icon_128x128@2x.png"
sips -s format png -z 256 256   "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256.png"
sips -s format png -z 512 512   "$ICON_SRC" --out "$ICONSET_DIR/icon_256x256@2x.png"
sips -s format png -z 512 512   "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512.png"
sips -s format png -z 1024 1024 "$ICON_SRC" --out "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o build/DeskGPT.app/Contents/Resources/AppIcon.icns
rm -rf "$ICONSET_DIR"

# 2. Copy metadata settings plist file
cp src/Info.plist build/DeskGPT.app/Contents/Info.plist

# 3. Swift high-performance compile & pack
echo "🚀 Swift 파일 고속 컴파일 및 패키징..."
swiftc src/DeskGPTViewController.swift \
       src/DeskGPTPDFViewController.swift \
       src/AppDelegate.swift \
       src/main.swift \
       -o build/DeskGPT.app/Contents/MacOS/DeskGPT \
       -framework Cocoa -framework WebKit -framework PDFKit

echo "🎉 DeskGPT.app 빌드 성공! 경로: build/DeskGPT.app"
