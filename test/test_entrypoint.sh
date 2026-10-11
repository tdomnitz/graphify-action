#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENTRYPOINT="$REPO_ROOT/entrypoint.sh"
STUBS="$SCRIPT_DIR/stubs"

pass=0
fail=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $desc"
    echo "  expected: $expected"
    echo "  actual:   $actual"
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $desc"
    echo "  expected to contain: $needle"
    echo "  actual: $haystack"
  fi
}

# Isolated sandbox: its own HOME (so `git config --global` never touches the
# real developer's ~/.gitconfig), its own git repo, nothing shared across tests.
new_sandbox() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/home"
  (
    export HOME="$dir/home"
    cd "$dir"
    git init -q repo
    cd repo
    git config user.email test@example.com
    git config user.name test
    echo "hello" > file.txt
    git add file.txt
    git commit -q -m init
  )
  printf '%s' "$dir"
}

run_entrypoint() {
  local sandbox="$1" gemini="$2" version="$3" extra="$4" out_file="$5"
  (
    unset GEMINI_API_KEY
    export HOME="$sandbox/home"
    cd "$sandbox/repo"
    PATH="$STUBS:$PATH" \
    GITHUB_OUTPUT="$out_file" \
    "$ENTRYPOINT" "." "$gemini" "$version" "$extra"
  )
}

# --- Test 1: no version override => pip stub never runs ---
sandbox="$(new_sandbox)"
pip_log="$(mktemp)"; graphify_log="$(mktemp)"; out="$(mktemp)"
GRAPHIFY_STUB_LOG="$graphify_log" PIP_STUB_LOG="$pip_log" \
  run_entrypoint "$sandbox" "" "" "" "$out"
assert_eq "no pip install when graphify-version is empty" "" "$(cat "$pip_log")"

# --- Test 2: version override => pip stub runs with pinned version ---
sandbox="$(new_sandbox)"
pip_log="$(mktemp)"; graphify_log="$(mktemp)"; out="$(mktemp)"
GRAPHIFY_STUB_LOG="$graphify_log" PIP_STUB_LOG="$pip_log" \
  run_entrypoint "$sandbox" "" "9.9.9" "" "$out"
assert_contains "pip install pins requested version with gemini extra" "$(cat "$pip_log")" "graphifyy[gemini]==9.9.9"

# --- Test 3: gemini key set => exported to graphify ---
sandbox="$(new_sandbox)"
pip_log="$(mktemp)"; graphify_log="$(mktemp)"; out="$(mktemp)"
GRAPHIFY_STUB_LOG="$graphify_log" PIP_STUB_LOG="$pip_log" \
  run_entrypoint "$sandbox" "secret-key" "" "" "$out"
assert_contains "GEMINI_API_KEY exported when provided" "$(cat "$graphify_log")" "GEMINI_API_KEY=<set:secret-key>"

# --- Test 4: gemini key empty => never exported, not even as empty string ---
sandbox="$(new_sandbox)"
pip_log="$(mktemp)"; graphify_log="$(mktemp)"; out="$(mktemp)"
GRAPHIFY_STUB_LOG="$graphify_log" PIP_STUB_LOG="$pip_log" \
  run_entrypoint "$sandbox" "" "" "" "$out"
assert_contains "GEMINI_API_KEY left unset when omitted" "$(cat "$graphify_log")" "GEMINI_API_KEY=<unset>"

# --- Test 5: extra-args word-split into separate argv entries ---
sandbox="$(new_sandbox)"
pip_log="$(mktemp)"; graphify_log="$(mktemp)"; out="$(mktemp)"
GRAPHIFY_STUB_LOG="$graphify_log" PIP_STUB_LOG="$pip_log" \
  run_entrypoint "$sandbox" "" "" "--mode deep" "$out"
assert_contains "extra-args word-split" "$(cat "$graphify_log")" "args: [update] [.] [--mode] [deep]"

# --- Test 6: changed=true when the graphify run leaves the workspace dirty ---
sandbox="$(new_sandbox)"
pip_log="$(mktemp)"; graphify_log="$(mktemp)"; out="$(mktemp)"
GRAPHIFY_STUB_TOUCH="$sandbox/repo/new-file.txt" GRAPHIFY_STUB_LOG="$graphify_log" PIP_STUB_LOG="$pip_log" \
  run_entrypoint "$sandbox" "" "" "" "$out"
assert_eq "changed=true when files were modified" "changed=true" "$(cat "$out")"

# --- Test 7: changed=false when nothing changed ---
sandbox="$(new_sandbox)"
pip_log="$(mktemp)"; graphify_log="$(mktemp)"; out="$(mktemp)"
GRAPHIFY_STUB_LOG="$graphify_log" PIP_STUB_LOG="$pip_log" \
  run_entrypoint "$sandbox" "" "" "" "$out"
assert_eq "changed=false when nothing was modified" "changed=false" "$(cat "$out")"

# --- Test 8: graphify failure propagates its exit code and skips changed output ---
sandbox="$(new_sandbox)"
pip_log="$(mktemp)"; graphify_log="$(mktemp)"; out="$(mktemp)"
set +e
GRAPHIFY_STUB_LOG="$graphify_log" PIP_STUB_LOG="$pip_log" GRAPHIFY_STUB_EXIT="7" \
  run_entrypoint "$sandbox" "" "" "" "$out"
code=$?
set -e
assert_eq "graphify failure exit code propagates" "7" "$code"
assert_eq "no changed output written on failure" "" "$(cat "$out")"

# --- Test 9: git status failure propagates instead of reporting a false changed=false ---
sandbox="$(new_sandbox)"
pip_log="$(mktemp)"; graphify_log="$(mktemp)"; out="$(mktemp)"
rm -rf "$sandbox/repo/.git"
set +e
GRAPHIFY_STUB_LOG="$graphify_log" PIP_STUB_LOG="$pip_log" \
  run_entrypoint "$sandbox" "" "" "" "$out"
code=$?
set -e
assert_eq "git status failure is not silently exit 0" "1" "$([ "$code" -ne 0 ] && echo 1 || echo 0)"
assert_eq "no changed output written when git status fails" "" "$(cat "$out")"

echo "---"
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
