#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/projects/AgentSkillSearch.dproj"
OUTPUT_DIR="$ROOT_DIR/bin"
TEST_OUTPUT_DIR="$ROOT_DIR/tests/bin"
RUNTIME_TEMPLATE_DIR="$ROOT_DIR/assets/runtime"

bash /home/pawel/.codex/skills/build-delphi/scripts/build-delphi.sh "$PROJECT_FILE" -ver 23 -config Debug -platform Win64

cp "$RUNTIME_TEMPLATE_DIR/settings.ini" "$OUTPUT_DIR/settings.ini"
cp "$RUNTIME_TEMPLATE_DIR/Sources.lst" "$OUTPUT_DIR/Sources.lst"
cp "$RUNTIME_TEMPLATE_DIR/excludes.lst" "$OUTPUT_DIR/excludes.lst"
cp "$RUNTIME_TEMPLATE_DIR/search-syntax-help-64.png" "$OUTPUT_DIR/search-syntax-help-64.png"

mkdir -p "$TEST_OUTPUT_DIR"
cp "$RUNTIME_TEMPLATE_DIR/settings.ini" "$TEST_OUTPUT_DIR/settings.ini"
cp "$RUNTIME_TEMPLATE_DIR/Sources.lst" "$TEST_OUTPUT_DIR/Sources.lst"
cp "$RUNTIME_TEMPLATE_DIR/excludes.lst" "$TEST_OUTPUT_DIR/excludes.lst"
cp "$RUNTIME_TEMPLATE_DIR/search-syntax-help-64.png" "$TEST_OUTPUT_DIR/search-syntax-help-64.png"

for dll in sqlite3.dll vec0.dll; do
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
