#!/usr/bin/env bash
# in.sh - run on the OFFLINE machine after syncing this repo.
#
# Reassembles the split files produced by out.sh and puts them back into the
# Homebrew cache, recreating symlinks and verifying checksums.
#
# Usage:  ./in.sh
set -euo pipefail

cd "$(dirname "$0")"

CACHE="$HOME/Library/Caches/Homebrew"
DIRS=(Cask downloads)
status=0

for dir in "${DIRS[@]}"; do
  dest_dir="$CACHE/$dir"
  mkdir -p -- "$dest_dir"

  shopt -s nullglob
  first_parts=("$dir"/*.part.aa)
  links=("$dir"/*.link)
  shopt -u nullglob

  for first in ${first_parts[@]+"${first_parts[@]}"}; do
    base="${first%.part.aa}"
    name="$(basename "$base")"
    dest="$dest_dir/$name"
    echo "assembling $dest"
    # Glob order is alphabetical, which matches split's aa, ab, ac ... suffixes.
    cat -- "$base".part.* > "$dest.tmp"
    if [[ -f "$base.sha256" ]]; then
      expected="$(cut -d' ' -f1 "$base.sha256")"
      actual="$(shasum -a 256 -- "$dest.tmp" | cut -d' ' -f1)"
      if [[ "$expected" != "$actual" ]]; then
        echo "CHECKSUM MISMATCH for $name" >&2
        echo "  expected $expected" >&2
        echo "  actual   $actual" >&2
        rm -f -- "$dest.tmp"
        status=1
        continue
      fi
      echo "  checksum ok"
    fi
    mv -f -- "$dest.tmp" "$dest"
  done

  for link in ${links[@]+"${links[@]}"}; do
    name="$(basename "${link%.link}")"
    target="$(<"$link")"
    echo "linking $dest_dir/$name -> $target"
    ln -sfn -- "$target" "$dest_dir/$name"
  done
done

if [[ $status -ne 0 ]]; then
  echo "done with errors" >&2
  exit $status
fi
echo "done; now e.g.  brew install --cask claude-code   (or brew upgrade --cask claude-code)"
