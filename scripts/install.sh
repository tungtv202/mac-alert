#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "$#" -gt 1 ]; then
  echo "Usage: $0 [destination-directory]" >&2
  exit 1
fi
DEST_DIR="${1:-$HOME/.codex/bin}"

"$ROOT_DIR/scripts/build.sh"
mkdir -p "$DEST_DIR"
temp_binary="$(mktemp "$DEST_DIR/.mac-alert.XXXXXX")"
trap 'rm -f "$temp_binary"' EXIT
install -m 755 "$ROOT_DIR/.build/mac-alert" "$temp_binary"
mv -f "$temp_binary" "$DEST_DIR/mac-alert"
echo "Installed: $DEST_DIR/mac-alert"
echo "Codex hooks and project settings were not modified."
