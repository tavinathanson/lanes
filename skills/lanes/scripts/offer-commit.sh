#!/usr/bin/env bash
# offer-commit.sh <worktree>: run by 'lanes start' after Claude exits. When the
# lane has uncommitted work, offer to commit it right there, with a message
# Claude writes from the diff (like /yolo) or one you type.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

WT="$1"
LANE="$(basename "$WT")"
[ -d "$WT" ] || exit 0
summary="$(dirty_summary "$WT")"
[ -n "$summary" ] || exit 0

echo
echo "Lane $LANE has uncommitted work ($summary)."
if [ ! -t 0 ]; then
  echo "  Resume with 'lanes start $LANE' and run /wrap, or 'lanes dirty' for all lanes."
  exit 0
fi
read -r -p "Commit it? [Y] auto message, [m] type one, [n] leave it: " answer

cd "$WT"
export GIT_PAGER=cat   # we are at a terminal now; keep git from opening a pager
case "$answer" in
  ""|[yY]*)
    echo "Writing a message from the diff..."
    git add -A -N 2>/dev/null || true   # so untracked files show up in the diff
    out="$( { git status --short; echo; git diff HEAD; } | head -c 200000 | claude -p \
      'Write a git commit message for this diff. Line 1: the message, one plain sentence (two only if needed), imperative mood, about the user-visible effect, no prefix, no em-dashes. Line 2: a 2 to 4 word lowercase hyphenated slug naming the work. Output only those two lines.')"
    msg="$(printf '%s\n' "$out" | sed -n 1p)"
    slug="$(printf '%s\n' "$out" | sed -n 2p)"
    [ -n "$msg" ] || { echo "Couldn't write a message. Nothing committed."; exit 1; }
    echo "Message: $msg"
    ;;
  [mM]*)
    read -r -p "Message: " msg
    slug=""
    [ -n "$msg" ] || { echo "Empty message. Nothing committed."; exit 0; }
    ;;
  *)
    echo "Left uncommitted. 'lanes dirty' lists lanes like this one."
    exit 0
    ;;
esac
"$(dirname "$0")/checkpoint.sh" ${slug:+--name "$slug"} "$msg"
