#!/usr/bin/env bash
set -euo pipefail

path="$1"
graphify_version="${2:-}"
extra_args="${3:-}"

git config --global --add safe.directory '*'

if [ -z "${GEMINI_API_KEY:-}" ]; then
  unset GEMINI_API_KEY
fi

if [ -n "$graphify_version" ]; then
  pip install --quiet "graphifyy[gemini]==${graphify_version}"
fi

# shellcheck disable=SC2086 # extra_args is a user-supplied flag string meant to word-split
graphify update "$path" $extra_args

status="$(git status --porcelain -- "$path/graphify-out")"
if [ -n "$status" ]; then
  echo "changed=true" >> "$GITHUB_OUTPUT"
else
  echo "changed=false" >> "$GITHUB_OUTPUT"
fi
