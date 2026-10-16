#!/usr/bin/env bash
# dirty-reminder.sh: Claude Code Stop hook. When a session in a lane worktree
# ends a turn with uncommitted work, show a one-line reminder to commit it.
# Reminds at most once every 30 minutes per session so it doesn't nag.
set -euo pipefail

input="$(cat)"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
session="$(jq -r '.session_id // "none"' <<<"$input")"
[[ "$cwd" == */.claude/worktrees/* ]] || exit 0

. "$HOME/.claude/skills/lanes/scripts/lib.sh"
summary="$(dirty_summary "$cwd")"
[ -n "$summary" ] || exit 0

stamp="${TMPDIR:-/tmp}/lanes-dirty-reminder-$session"
if [ -e "$stamp" ] && [ $(( $(date +%s) - $(cat "$stamp") )) -lt 1800 ]; then
  exit 0
fi
date +%s > "$stamp"

jq -n --arg m "Uncommitted in this lane: $summary. Run /wrap to keep it." '{systemMessage: $m}'
