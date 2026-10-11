#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MSYS_NO_PATHCONV=1 docker run --rm -v "$REPO_ROOT":/repo -w /repo python:3.12-slim bash -c '
  pip install --quiet pyyaml
  python3 - <<"PY"
import sys
import yaml

with open(".github/workflows/publish.yml") as f:
    doc = yaml.safe_load(f)

errors = []

def require(cond, msg):
    if not cond:
        errors.append(msg)

# PyYAML resolves a bare "on" key as the boolean True under YAML 1.1 rules.
on_section = doc.get(True, doc.get("on"))
require(on_section is not None, "missing on: trigger section")
tags = (on_section or {}).get("push", {}).get("tags", [])
require("v*.*.*" in tags, f"on.push.tags must include v*.*.*, got {tags!r}")

require(doc.get("permissions", {}).get("packages") == "write", "permissions.packages must be write")

jobs = doc.get("jobs", {})
steps = [s for job in jobs.values() for s in job.get("steps", [])]
uses_list = [s.get("uses", "") for s in steps]
require(any("docker/build-push-action" in u for u in uses_list), "no docker/build-push-action step found")

build_step = next((s for s in steps if "docker/build-push-action" in s.get("uses", "")), {})
tags_value = build_step.get("with", {}).get("tags", "")
require("graphify-action" in tags_value and "ghcr.io/tdomnitz" in tags_value, "build-push tags must target ghcr.io/tdomnitz/graphify-action")

if errors:
    for e in errors:
        print(f"FAIL: {e}")
    sys.exit(1)

print("publish.yml structure OK")
PY
'
