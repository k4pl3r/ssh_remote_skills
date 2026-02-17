#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="${ROOT_DIR}/ops/remote-mcp-runner.sh"

fail() {
  echo "FAIL: $1"
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "${haystack}" != *"${needle}"* ]]; then
    fail "expected output to contain '${needle}', got: ${haystack}"
  fi
}

assert_exit_code() {
  local actual="$1"
  local expected="$2"
  if [[ "${actual}" != "${expected}" ]]; then
    fail "expected exit code ${expected}, got ${actual}"
  fi
}

run_runner() {
  local sandbox="$1"
  shift
  local cmd_output
  set +e
  cmd_output="$(
    MCP_REMOTE_PROJECT_DIR="${sandbox}/project" \
    MCP_REMOTE_LOG_DIR="${sandbox}/logs" \
    MCP_REMOTE_TEST_QUICK_CMD="${MCP_REMOTE_TEST_QUICK_CMD:-echo quick-ok}" \
    MCP_REMOTE_TEST_FULL_CMD="${MCP_REMOTE_TEST_FULL_CMD:-echo full-ok}" \
    MCP_REMOTE_RUN_WHITELIST="${MCP_REMOTE_RUN_WHITELIST:-}" \
    "${RUNNER}" "$@" 2>&1
  )"
  LAST_EXIT_CODE=$?
  set -e
  LAST_OUTPUT="${cmd_output}"
}

LAST_OUTPUT=""
LAST_EXIT_CODE=0

echo "[TEST] runner exists and is executable"
if [[ ! -x "${RUNNER}" ]]; then
  fail "expected executable at ${RUNNER}"
fi

echo "[TEST] quick mode success path"
sandbox="$(mktemp -d)"
mkdir -p "${sandbox}/project"
run_runner "${sandbox}" quick
assert_exit_code "${LAST_EXIT_CODE}" "0"
assert_contains "${LAST_OUTPUT}" "[RESULT] PASS"
assert_contains "${LAST_OUTPUT}" "[EXIT_CODE] 0"
assert_contains "${LAST_OUTPUT}" "[RUN_ID]"
assert_contains "${LAST_OUTPUT}" "[DURATION]"

echo "[TEST] quick mode failure path"
sandbox="$(mktemp -d)"
mkdir -p "${sandbox}/project"
MCP_REMOTE_TEST_QUICK_CMD="echo quick-fail && exit 7" run_runner "${sandbox}" quick
assert_exit_code "${LAST_EXIT_CODE}" "7"
assert_contains "${LAST_OUTPUT}" "[RESULT] FAIL"
assert_contains "${LAST_OUTPUT}" "[EXIT_CODE] 7"

echo "[TEST] run mode whitelist enforcement"
sandbox="$(mktemp -d)"
mkdir -p "${sandbox}/project"
MCP_REMOTE_RUN_WHITELIST='^echo .+$' run_runner "${sandbox}" run "echo hello"
assert_exit_code "${LAST_EXIT_CODE}" "0"
assert_contains "${LAST_OUTPUT}" "[RESULT] PASS"

MCP_REMOTE_RUN_WHITELIST='^echo .+$' run_runner "${sandbox}" run "ls -la"
assert_exit_code "${LAST_EXIT_CODE}" "4"
assert_contains "${LAST_OUTPUT}" "not allowed by MCP_REMOTE_RUN_WHITELIST"
assert_contains "${LAST_OUTPUT}" "[RESULT] FAIL"

echo "[PASS] remote mcp runner behavior checks"
