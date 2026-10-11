#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

fail=0
for name in path gemini-api-key graphify-version extra-args; do
  if ! grep -qF "\`$name\`" "$REPO_ROOT/README.md"; then
    echo "FAIL: README.md does not document input '$name'"
    fail=1
  fi
done

if ! grep -qF '`changed`' "$REPO_ROOT/README.md"; then
  echo "FAIL: README.md does not document output 'changed'"
  fail=1
fi

if ! grep -qF 'contents: write' "$REPO_ROOT/README.md"; then
  echo "FAIL: README.md usage example does not grant contents: write (git push would 403 on a default GITHUB_TOKEN)"
  fail=1
fi

if ! grep -i 'package' "$REPO_ROOT/README.md" >/dev/null || ! grep -i 'public' "$REPO_ROOT/README.md" >/dev/null; then
  echo "FAIL: README.md does not note that the GHCR package must be made public before consumers can pull it"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "README consistency OK"
fi
exit "$fail"
