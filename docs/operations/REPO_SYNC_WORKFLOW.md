# Repo Sync Workflow

## Status: operational workflow note.


## Canonical topology

There is exactly one real repository checkout for this project:

- `/Users/colton/Desktop/LIFE-IN-SYNC`

## Source of truth

GitHub is the cross-device sync engine.

- Mac changes sync by `git push`
- iPhone changes sync by pulling and pushing through a Git-capable app
- Local folders do not auto-merge branch state for you

## iPhone workflow

Use Working Copy on iPhone with the GitHub repository.

Recommended loop:

1. Pull in Working Copy before editing
2. Make the change on iPhone
3. Commit in Working Copy
4. Push to GitHub
5. Pull on Mac before continuing

Do not depend on iCloud Drive Files as a live repo editor for this project.

## Mac workflow

Always work from:

- `/Users/colton/Desktop/LIFE-IN-SYNC`

Before starting:

1. Confirm the branch with `git branch --show-current`
2. Confirm status with `git status --short --branch`
3. Pull the branch you plan to use

Before switching devices:

1. Commit intentional changes
2. Push the branch
3. If the work should appear on GitHub `main`, merge the feature branch first

## Branch expectations

If local code and GitHub look different, check these in order:

1. Are you on `main` locally?
2. Is GitHub showing `main` while local is on a feature branch?
3. Has the feature branch been pushed?
4. Has it been merged back into `main`?

Most "not in sync" cases for this repo are branch mismatches, not duplicate code copies.
