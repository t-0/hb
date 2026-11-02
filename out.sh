#!/usr/bin/env bash
# out.sh - run on the INTERNET-CONNECTED machine.
#
# Copies the Claude entries from the Homebrew cache into this repo, split into
# 16 MiB parts so they fit GitHub's file size limit, and commits the result.
#
#   Cask/<name>      symlink -> stored as <name>.link (contains the link target)
#   downloads/<name> file    -> stored as <name>.part.aa, .ab, ... + <name>.sha256
#
# Usage:  ./out.sh [--push]
set -euo pipefail

cd "$(dirname "$0")"

CACHE="$HOME/Library/Caches/Homebrew"
DIRS=(Cask downloads)
PATTERN='*claude*'
PART_SIZE=16777216
PUSH=0

for arg in "$@"; do
  case "$arg" in
    --push) PUSH=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

version=""

for dir in "${DIRS[@]}"; do
  src_dir="$CACHE/$dir"
  [[ -d "$src_dir" ]] || { echo "missing $src_dir" >&2; exit 1; }

  # Drop the previous version from the index and working tree.
  git rm -rq --ignore-unmatch -- "$dir"
  rm -rf -- "$dir"
  mkdir -p -- "$dir"

  shopt -s nullglob
  entries=("$src_dir"/$PATTERN)
  shopt -u nullglob
  [[ ${#entries[@]} -gt 0 ]] || { echo "no $PATTERN entries in $src_dir" >&2; exit 1; }

  for src in ${entries[@]+"${entries[@]}"}; do
    name="$(basename "$src")"
    if [[ -L "$src" ]]; then
      target="$(readlink "$src")"
      printf '%s\n' "$target" > "$dir/$name.link"
      echo "$dir/$name -> $target (link)"
    elif [[ -f "$src" ]]; then
      split -b "$PART_SIZE" -- "$src" "$dir/$name.part."
      (cd "$src_dir" && shasum -a 256 -- "$name") > "$dir/$name.sha256"
      echo "$dir/$name split into $(ls "$dir/$name.part."* | wc -l | tr -d ' ') parts"
    else
      echo "skipping $src (not a file or symlink)" >&2
    fi
    # Cask entries look like claude-code--2.1.309; use that for the commit message.
    if [[ "$dir" == "Cask" && "$name" =~ --([0-9][^/]*)$ ]]; then
      version="${BASH_REMATCH[1]}"
    fi
  done
done

git add -A -- "${DIRS[@]}"

if git diff --cached --quiet; then
  echo "nothing changed; no commit made"
  exit 0
fi

git commit -qm "${version:-update claude}"
echo "committed: $(git log -1 --oneline)"

if [[ $PUSH -eq 1 ]]; then
  git push
else
  echo "now sync the repo (git push) and run ./in.sh on the other side"
fi
