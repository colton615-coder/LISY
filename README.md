# LIFE-IN-SYNC

This repository has one real working copy on disk:

- Canonical path: `/Users/colton/Desktop/LIFE-IN-SYNC`

This is the actual repository folder on Desktop, not a symlink.

## Sync Model

Use GitHub as the source of truth between devices.

- Mac: work in `/Users/colton/Desktop/LIFE-IN-SYNC`
- iPhone: use Working Copy or another Git-capable app connected to the GitHub repo
- GitHub: shared remote used to move changes between devices

Do not use iCloud Drive as a second repo copy or as the editing path for this project.

## Daily Workflow

1. Open the repo from `/Users/colton/Desktop/LIFE-IN-SYNC`
2. Run `scripts/repo-health.sh`
3. Pull before starting work
4. Make changes on the branch you intend to use
5. Push before switching devices
6. Merge feature branches before expecting `main` to match everywhere

## Branch Rules

- `main` is the stable shared branch
- Short-lived feature branches are allowed
- If GitHub looks different from local code, check the current branch first

More detail lives in [docs/operations/REPO_SYNC_WORKFLOW.md](docs/operations/REPO_SYNC_WORKFLOW.md).
