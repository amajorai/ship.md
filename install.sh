#!/usr/bin/env bash
# install.sh — install ship.md skills
# Usage: ./install.sh [--codex] [--dir <path>]
set -euo pipefail

PLATFORM="claude"
CUSTOM_DIR=""

for arg in "$@"; do
  case $arg in
    --codex) PLATFORM="codex" ;;
    --dir) shift; CUSTOM_DIR="$1" ;;
  esac
done

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"

if [[ "$PLATFORM" == "codex" ]]; then
  DEST="${CUSTOM_DIR:-$HOME/.codex/skills}"
  echo "Installing Codex skills to $DEST..."
  mkdir -p "$DEST"
  for skill_dir in "$SKILLS_SRC"/*/; do
    skill_name="$(basename "$skill_dir")"
    mkdir -p "$DEST/$skill_name"
    cp "$skill_dir/SKILL.md" "$DEST/$skill_name/SKILL.md"
    echo "  installed: $skill_name  (invoke with \$$skill_name)"
  done
else
  DEST="${CUSTOM_DIR:-$HOME/.claude/skills}"
  echo "Installing Claude Code skills to $DEST..."
  mkdir -p "$DEST"
  for skill_dir in "$SKILLS_SRC"/*/; do
    skill_name="$(basename "$skill_dir")"
    cp "$skill_dir/SKILL.md" "$DEST/$skill_name.md"
    echo "  installed: $skill_name  (invoke with /$skill_name)"
  done
fi

echo ""
echo "Done. Restart Claude Code / Codex to pick up new skills."
