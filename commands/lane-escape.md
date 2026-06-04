---
description: Move uncommitted work from the main checkout into a new lane (worktree), leaving main clean, then print a command to continue this conversation in the lane.
allowed-tools: Bash
---

Use the lanes skill.

The user started working in the main checkout without a lane and wants to move into one.

Lane name: $ARGUMENTS

If no lane name was given, ask for a short kebab-case name before running anything.

Run:
~/.claude/skills/lanes/scripts/escape-to-lane.sh "$ARGUMENTS"

Rules:
- Only meaningful from the main checkout. If the script reports you're already in a worktree, stop and relay that.
- Do not push, merge, commit, or amend. The script only stashes, creates the worktree, and pops the stash.
- After it runs, show the printed "continue this conversation" command verbatim and tell the user they must exit this session and run it themselves: you cannot launch the new session for them.
- If the script reports it rolled back, reassure the user their work is intact in main and nothing moved.
