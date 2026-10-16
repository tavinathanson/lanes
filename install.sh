#!/usr/bin/env bash
# Symlink lanes into ~/.local/bin and ~/.claude.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
SKILL_DIR="$HOME/.claude/skills"
CMD_DIR="$HOME/.claude/commands"
HOOK_DIR="$HOME/.claude/hooks"

CMDS=(checkpoint handoff wrap yolo yolo-push yolo-push-close lane-escape push pull sync)

uninstall() {
  rm -f "$BIN/lanes"
  rm -f "$SKILL_DIR/lanes"
  rm -f "$HOOK_DIR/lanes-dirty-reminder.sh"
  for c in "${CMDS[@]}"; do
    target="$CMD_DIR/$c.md"
    [ -L "$target" ] && rm -f "$target"
  done
  echo "uninstalled lanes symlinks"
}

if [ "${1:-}" = "--uninstall" ]; then
  uninstall
  exit 0
fi

mkdir -p "$BIN" "$SKILL_DIR" "$CMD_DIR" "$HOOK_DIR"

ln -sfn "$REPO/bin/lanes" "$BIN/lanes"
ln -sfn "$REPO/skills/lanes" "$SKILL_DIR/lanes"
ln -sfn "$REPO/hooks/dirty-reminder.sh" "$HOOK_DIR/lanes-dirty-reminder.sh"
for c in "${CMDS[@]}"; do
  ln -sfn "$REPO/commands/$c.md" "$CMD_DIR/$c.md"
done

# Clean up stale symlinks from previous installs: any symlink in $CMD_DIR
# that points into this repo's commands dir but whose target no longer exists.
for link in "$CMD_DIR"/*.md; do
  [ -L "$link" ] || continue
  target="$(readlink "$link")"
  case "$target" in
    "$REPO/commands/"*)
      [ -e "$link" ] || rm -f "$link"
      ;;
  esac
done

echo "installed lanes:"
echo "  $BIN/lanes -> $REPO/bin/lanes"
echo "  $SKILL_DIR/lanes -> $REPO/skills/lanes"
echo "  $CMD_DIR/{${CMDS[*]}}.md -> $REPO/commands/"
echo "  $HOOK_DIR/lanes-dirty-reminder.sh -> $REPO/hooks/dirty-reminder.sh"
echo
if ! grep -q lanes-dirty-reminder "$HOME/.claude/settings.json" 2>/dev/null; then
  echo "optional: to get reminded about uncommitted lane work, add this Stop hook"
  echo "to ~/.claude/settings.json under \"hooks\":"
  echo '  "Stop": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/lanes-dirty-reminder.sh" }] }]'
  echo
fi
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "warning: $BIN not on PATH — add it to your shell rc" ;;
esac
