---
description: Run /yolo-push, then close this tmux pane (and the window, if it was the last pane). Manual use only.
allowed-tools: Bash, Read, Grep, Glob
disable-model-invocation: true
---

Use the lanes skill.

Goal: do exactly what `/yolo-push` does (commit with an auto-written message, then push), and if the push succeeds, close the tmux pane this session is running in. Killing the pane terminates this Claude session; that is intentional. tmux automatically closes the window when its last pane dies, so no window handling is needed.

This command is MANUAL-ONLY. It runs only when the user themselves typed `/yolo-push-close`. Never invoke it on your own initiative and never suggest it as a way to push.

Steps:

1. Follow the `/yolo-push` command file (`~/.claude/commands/yolo-push.md`) in full: yolo-style commit via `~/.claude/skills/lanes/scripts/checkpoint.sh`, then push, following all of its steps and rules (no force push, current branch only, stop if checkpoint.sh refuses).
2. Briefly report the commit message(s) and push result BEFORE closing, in case the user is watching.
3. Only if the push succeeded (or there was nothing to commit AND nothing to push): close the pane with

   `tmux kill-pane -t "$TMUX_PANE"`

   Run this as its own final Bash call with nothing after it; the session ends when it runs. If `$TMUX_PANE` is empty (not inside tmux), say so and skip the close.
4. If the commit or push failed, do NOT close the pane. Report the failure and stop, so the user can inspect the session.
