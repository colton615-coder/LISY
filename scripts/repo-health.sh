#!/bin/zsh

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
current_branch="$(git branch --show-current)"

echo "Repo root: $repo_root"
echo "Branch: $current_branch"
echo
echo "Status:"
git status --short --branch
echo
echo "Remote:"
git remote -v | head -n 2
echo
echo "Access points:"
echo "$repo_root"
