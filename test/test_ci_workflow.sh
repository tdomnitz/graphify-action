#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MSYS_NO_PATHCONV=1 docker run --rm -v "$REPO_ROOT":/repo -w /repo python:3.12-slim bash -c '
  pip install --quiet pyyaml
  python3 - <<"PY"
import sys
import yaml

with open(".github/workflows/ci.yml") as f:
    doc = yaml.safe_load(f)

errors = []

def require(cond, msg):
    if not cond:
        errors.append(msg)

on_section = doc.get(True, doc.get("on"))
require(on_section is not None and "pull_request" in on_section, "must trigger on pull_request")

jobs = doc.get("jobs", {})
steps = [s for job in jobs.values() for s in job.get("steps", [])]
run_commands = [s.get("run", "") for s in steps]
require(any("docker build" in r for r in run_commands), "no docker build step found")
require(any("shellcheck" in r and "entrypoint.sh" in r for r in run_commands), "no shellcheck entrypoint.sh step found")

if errors:
    for e in errors:
        print(f"FAIL: {e}")
    sys.exit(1)

print("ci.yml structure OK")
PY
'

# Also actually run the linter the workflow claims to run, so this test
# gives real signal about entrypoint.sh, not just about the YAML text.
MSYS_NO_PATHCONV=1 docker run --rm -v "$REPO_ROOT":/mnt -w /mnt koalaman/shellcheck:stable entrypoint.sh
