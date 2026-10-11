#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE="graphify-action:test"

docker build -t "$IMAGE" "$REPO_ROOT"

pip_show="$(docker run --rm --entrypoint pip "$IMAGE" show graphifyy)"
if ! printf '%s' "$pip_show" | grep -qF "Version: 0.9.84"; then
  echo "FAIL: expected graphifyy Version: 0.9.84, got:"
  printf '%s\n' "$pip_show"
  exit 1
fi

if ! docker run --rm --entrypoint graphify "$IMAGE" --version >/dev/null; then
  echo "FAIL: graphify --version did not exit 0"
  exit 1
fi

source_label="$(docker inspect --format '{{ index .Config.Labels "org.opencontainers.image.source" }}' "$IMAGE")"
if [ "$source_label" != "https://github.com/tdomnitz/graphify-action" ]; then
  echo "FAIL: expected org.opencontainers.image.source label, got: $source_label"
  exit 1
fi

echo "Dockerfile build OK"
