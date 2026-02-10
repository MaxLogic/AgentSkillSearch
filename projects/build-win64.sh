#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/projects/AgentSkillSearch.dproj"

bash /home/pawel/.codex/skills/build-delphi/scripts/build-delphi.sh "$PROJECT_FILE" -ver 23 -config Debug -platform Win64
