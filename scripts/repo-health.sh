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
for path in \
  "/Users/colton/Desktop/LIFE-IN-SYNC" \
  "/Users/colton/Library/Mobile Documents/com~apple~CloudDocs/LIFE-IN-SYNC"
do
  if [[ -L "$path" ]]; then
    echo "$path -> $(/usr/bin/stat -f '%Y' "$path")"
  elif [[ -e "$path" ]]; then
    echo "$path"
  else
    echo "$path (missing)"
  fi
done
