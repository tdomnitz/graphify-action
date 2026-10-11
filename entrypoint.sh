#!/usr/bin/env bash
set -euo pipefail

path="$1"
gemini_api_key="${2:-}"
graphify_version="${3:-}"
extra_args="${4:-}"

git config --global --add safe.directory '*'

if [ -n "$graphify_version" ]; then
  pip install --quiet "graphifyy[gemini]==${graphify_version}"
fi

if [ -n "$gemini_api_key" ]; then
  export GEMINI_API_KEY="$gemini_api_key"
fi

# shellcheck disable=SC2086 # extra_args is a user-supplied flag string meant to word-split
graphify update "$path" $extra_args

status="$(git status --porcelain)"
if [ -n "$status" ]; then
  echo "changed=true" >> "$GITHUB_OUTPUT"
else
  echo "changed=false" >> "$GITHUB_OUTPUT"
fi
