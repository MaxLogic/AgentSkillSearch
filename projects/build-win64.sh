#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/projects/AgentSkillSearch.dproj"
OUTPUT_DIR="$ROOT_DIR/bin"
TEST_OUTPUT_DIR="$ROOT_DIR/tests/bin"
RUNTIME_TEMPLATE_DIR="$ROOT_DIR/assets/runtime"
BUILD_CONFIG="${BUILD_CONFIG:-Release}"
DAK_BUILD_SH="${DAK_BUILD_SH:-/mnt/f/projects/MaxLogic/DelphiAiKit/build-delphi.sh}"

install_if_missing() {
  local src="$1"
  local dst="$2"

  if [[ -f "$dst" ]]; then
    return
  fi

  cp "$src" "$dst"
}

"$DAK_BUILD_SH" "$PROJECT_FILE" -ver 23 -config "$BUILD_CONFIG" -platform Win64

install_if_missing "$RUNTIME_TEMPLATE_DIR/settings.ini" "$OUTPUT_DIR/settings.ini"
install_if_missing "$RUNTIME_TEMPLATE_DIR/Sources.lst" "$OUTPUT_DIR/Sources.lst"
install_if_missing "$RUNTIME_TEMPLATE_DIR/excludes.lst" "$OUTPUT_DIR/excludes.lst"
cp "$RUNTIME_TEMPLATE_DIR/search-syntax-help-64.png" "$OUTPUT_DIR/search-syntax-help-64.png"

mkdir -p "$TEST_OUTPUT_DIR"
install_if_missing "$RUNTIME_TEMPLATE_DIR/settings.ini" "$TEST_OUTPUT_DIR/settings.ini"
install_if_missing "$RUNTIME_TEMPLATE_DIR/Sources.lst" "$TEST_OUTPUT_DIR/Sources.lst"
install_if_missing "$RUNTIME_TEMPLATE_DIR/excludes.lst" "$TEST_OUTPUT_DIR/excludes.lst"
cp "$RUNTIME_TEMPLATE_DIR/search-syntax-help-64.png" "$TEST_OUTPUT_DIR/search-syntax-help-64.png"

for dll in sqlite3.dll; do
  if [[ ! -f "$OUTPUT_DIR/$dll" ]]; then
    echo "ERROR: missing runtime dependency $OUTPUT_DIR/$dll" >&2
    exit 1
  fi
  cp "$OUTPUT_DIR/$dll" "$TEST_OUTPUT_DIR/$dll"
done

# Keep app runtime output clean (legacy test/check binaries used to be emitted here).
find "$OUTPUT_DIR" -maxdepth 1 -type f \
  \( -name '*Tests.exe' -o -name '*Tests.cmds' -o -name '*Tests.rsm' -o -name 'DbInitCheck.*' -o -name 'SettingsCheck.*' \) \
  -delete
