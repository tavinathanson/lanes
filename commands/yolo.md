---
description: Like /wrap, but commit the auto-written message immediately without asking for confirmation.
allowed-tools: Bash, Read, Grep, Glob
---

Use the lanes skill.

Goal: commit the current lane's changes with a message you generate from the diff, WITHOUT stopping to confirm. This is the unattended variant of `/wrap`: the user has already opted out of reviewing the message.

Steps:

1. Run `git status --short` and `git diff --stat` to see the scope.
2. If there are no changes, say so and stop.
3. Run `git diff` (and `git diff --cached` if anything is staged) to read the actual changes. For huge diffs, sample the most informative hunks.
4. Decide: one commit or a split?
   - DEFAULT to one commit. Most lane work is a single coherent change.
   - Propose a split ONLY when the diff contains clearly unrelated concerns — e.g. files in disjoint subsystems with no shared rationale, where one short message can't honestly describe both. A "drive-by fix" alongside the main change is a typical split case.
   - When unsure, prefer one commit.
5. Draft a short, plain commit message (one per group, if splitting):
   - Default to ONE sentence. Use two only when one genuinely isn't enough. Reserve three sentences for massive multi-part features.
   - Focus on the problem solved, the feature delivered, or the user-visible effect — not the implementation mechanism, lock primitives, internal file paths, or a file list.
   - Plain, non-technical phrasing where possible. Imperative mood ("add X", "fix Y"). No bullet-list body.
   - Do NOT prefix with `lane(...)`. Do NOT add `Co-Authored-By`.
   - Also pick a lane slug: 2 to 4 lowercase words joined by hyphens naming the lane's overall work (e.g. `start-autoname`). Pass it as `--name <slug>` on every checkpoint call; the script only uses it to rename a lane that still has its timestamp name from a bare `lanes start`, and ignores it otherwise. If it prints "Lane renamed", tell the user the new name.
6. Commit immediately, without asking the user to confirm. Print the message(s) you chose so the result is visible:
   - Single commit: call `~/.claude/skills/lanes/scripts/checkpoint.sh --name <slug> "<final message>"`.
   - Split: for each group, run `git reset` to clear the index, `git add <files...>` to stage just that group, then call `~/.claude/skills/lanes/scripts/checkpoint.sh --only-staged --name <slug> "<message>"`. Repeat per group.
7. Print the resulting `git log --oneline -5`.

Rules:
- Do not push.
- Do not amend.
- Do not merge.
- Do not squash.
- If conflicts or whitespace errors are present, the script will refuse — report what it said.
