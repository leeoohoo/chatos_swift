#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
APP_DIR="$PROJECT_DIR/.build/ChatOS.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$PROJECT_DIR/.build/arm64-apple-macosx/debug/ChatOSSwift"
SIGNING_IDENTITY=${CHATOS_CODESIGN_IDENTITY:-}

cd "$PROJECT_DIR"
swift build

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE" "$MACOS_DIR/ChatOSSwift"
cp "$PROJECT_DIR/Support/ChatOSSwift-Info.plist" "$CONTENTS_DIR/Info.plist"

if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$APP_DIR"
else
  # Keep a stable designated requirement across local debug rebuilds. A plain
  # ad-hoc signature falls back to its changing cdhash and makes Keychain treat
  # every build as a different application.
  codesign \
    --force \
    --sign - \
    --requirements '=designated => identifier "com.chatos.swift-client"' \
    "$APP_DIR"
fi

echo "$APP_DIR"
