#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "mac-alert requires macOS." >&2
  exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Install Xcode Command Line Tools first: xcode-select --install" >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"
temp_binary="$(mktemp "$BUILD_DIR/mac-alert.XXXXXX")"
trap 'rm -f "$temp_binary"' EXIT
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}" \
  xcrun swiftc -O "$ROOT_DIR/MacAlert.swift" -o "$temp_binary"
chmod 755 "$temp_binary"
mv -f "$temp_binary" "$BUILD_DIR/mac-alert"
echo "Built: $BUILD_DIR/mac-alert"
