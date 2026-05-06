---
description: Auto-write a 1-2 sentence commit message from the current diff and checkpoint the lane.
allowed-tools: Bash, Read, Grep, Glob
---

Use the lanes skill.

Goal: commit the current lane's changes with a message you generate from the diff. The user does not want to write the message themselves.

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
6. Show the proposed message(s) — and the proposed split, if any — to the user and ask them to confirm or edit.
7. Once confirmed:
   - Single commit: call `~/.claude/skills/lanes/scripts/checkpoint.sh "<final message>"`.
   - Split: for each group, run `git reset` to clear the index, `git add <files...>` to stage just that group, then call `~/.claude/skills/lanes/scripts/checkpoint.sh --only-staged "<message>"`. Repeat per group.
8. Print the resulting `git log --oneline -5`.

Rules:
- Do not push.
- Do not amend.
- Do not merge.
- Do not squash.
- If conflicts or whitespace errors are present, the script will refuse — report what it said.
