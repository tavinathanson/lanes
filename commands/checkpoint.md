---
description: Create a lane-local checkpoint commit for the current Claude Code worktree.
allowed-tools: Bash, Read, Grep, Glob
---

Use the lanes skill.

Create a checkpoint commit in the current lane.

Message: $ARGUMENTS

Pick a lane slug from the message: 2 to 4 lowercase words joined by hyphens (e.g. `start-autoname`). The script only uses it to rename a lane that still has its timestamp name from a bare `lanes start`.

Run:
~/.claude/skills/lanes/scripts/checkpoint.sh --name <slug> "$ARGUMENTS"

If it prints "Lane renamed", tell the user the new name.

Rules:
- Commit only in the current worktree.
- Do not push to GitHub.
- Do not merge.
- Do not amend previous commits.
- Do not squash.
- If there are no changes, say so.
- If the working tree has conflicts, stop and report them.
- After committing, show the latest 5 commits for this lane.
