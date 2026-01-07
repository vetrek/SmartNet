---
description: Commit all changes and push to remote (supports git and jj)
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(jj status:*), Bash(jj diff:*), Bash(jj log:*), Bash(jj describe:*), Bash(jj git push:*), Bash(jj new:*), Bash(ls:*), Bash(test:*)
---

Check if `.jj` directory exists to determine if jj is in use.

## If jj is in use (`.jj` exists):

1. Run `jj status` to see current changes
2. Run `jj diff` to see what will be committed
3. Run `jj log -r ::@ -n 5` to see recent commit style
4. Run `jj describe -m "commit message"` to set the commit message
5. Run `jj new` to create a new empty working copy
6. Run `jj git push` to push to remote

## If only git (no `.jj` directory):

1. Run `git status` to see all changes
2. Run `git diff @{upstream}...HEAD` to see all changes from the branch it detached from (if no upstream, use `git diff` for unstaged changes)
3. Run `git log -3 --oneline` to see recent commit style
4. Stage all relevant changes with `git add`
5. Create a commit with a concise message based on the changes
6. Run `git push` to push to the current branch

Do NOT include Claude Code attribution or Co-Authored-By lines in the commit message.
