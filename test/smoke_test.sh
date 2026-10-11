#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE="graphify-action:smoke"

docker build -t "$IMAGE" "$REPO_ROOT"

# A tmpdir from `mktemp -d` can land outside any path the Docker daemon can
# see (e.g. Git Bash's MSYS-only /tmp on Windows, invisible to Docker
# Desktop's VM). A workdir under the repo itself is always on a path Docker
# can bind-mount, on every platform.
tmproot="$REPO_ROOT/.smoke-test-tmp"
mkdir -p "$tmproot"
workdir="$(mktemp -d "$tmproot/XXXXXX")"
outdir="$(mktemp -d "$tmproot/XXXXXX")"
trap 'rm -rf "$workdir" "$outdir"' EXIT

git init -q "$workdir"
(
  cd "$workdir"
  git config user.email smoke@example.com
  git config user.name smoke
  cat > app.py <<'PY'
def add(a, b):
    return a + b
PY
  git add app.py
  git commit -q -m init
)

# GITHUB_OUTPUT must live outside the workspace being status-checked —
# otherwise the output file itself always shows up as an untracked change,
# making changed=true true regardless of what graphify actually did.
output_file="$outdir/output"
touch "$output_file"

MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$workdir":/workspace \
  -v "$outdir":/out \
  -w /workspace \
  -e GITHUB_OUTPUT=/out/output \
  "$IMAGE" "." "" "" ""

if [ ! -f "$workdir/graphify-out/graph.json" ]; then
  echo "FAIL: graphify-out/graph.json was not produced"
  exit 1
fi

if ! grep -q '^changed=true$' "$output_file"; then
  echo "FAIL: expected changed=true on first run, got: $(cat "$output_file")"
  exit 1
fi

echo "smoke test OK: graphify-out/graph.json produced, changed=true reported"
