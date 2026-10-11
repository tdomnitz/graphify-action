#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MSYS_NO_PATHCONV=1 docker run --rm -v "$REPO_ROOT":/repo -w /repo python:3.12-slim bash -c '
  pip install --quiet pyyaml
  python3 - <<"PY"
import sys
import yaml

with open("action.yml") as f:
    doc = yaml.safe_load(f)

errors = []

def require(cond, msg):
    if not cond:
        errors.append(msg)

require("runs" in doc, "missing top-level runs key")
require(doc.get("runs", {}).get("using") == "docker", "runs.using must be \"docker\"")
require(
    doc.get("runs", {}).get("image", "").startswith("docker://ghcr.io/tdomnitz/graphify-action:"),
    "runs.image must point at ghcr.io/tdomnitz/graphify-action",
)

expected_inputs = ["path", "gemini-api-key", "graphify-version", "extra-args"]
inputs = doc.get("inputs", {})
for name in expected_inputs:
    require(name in inputs, f"missing input: {name}")

require("changed" in doc.get("outputs", {}), "missing output: changed")

args = doc.get("runs", {}).get("args", [])
expected_args = [
    "${{ inputs.path }}",
    "${{ inputs.gemini-api-key }}",
    "${{ inputs.graphify-version }}",
    "${{ inputs.extra-args }}",
]
require(args == expected_args, f"runs.args must be {expected_args!r}, got {args!r}")

if errors:
    for e in errors:
        print(f"FAIL: {e}")
    sys.exit(1)

print("action.yml structure OK")
PY
'
