#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_CLI="${ROOT_DIR}/ops/remote"
BASE_PATH="${PATH}"

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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "${haystack}" == *"${needle}"* ]]; then
    fail "expected output not to contain '${needle}', got: ${haystack}"
  fi
}

assert_exit_code() {
  local actual="$1"
  local expected="$2"
  if [[ "${actual}" != "${expected}" ]]; then
    fail "expected exit code ${expected}, got ${actual}"
  fi
}

LAST_OUTPUT=""
LAST_EXIT_CODE=0

run_cli_capture() {
  local sandbox="$1"
  shift
  local cmd_output
  set +e
  cmd_output="$(
    PATH="${sandbox}/bin:${BASE_PATH}" \
    MOCK_SSH_LOG="${sandbox}/ssh.log" \
    MOCK_RSYNC_LOG="${sandbox}/rsync.log" \
    MOCK_GIT_STATUS="${MOCK_GIT_STATUS:-}" \
    MOCK_TEST_EXIT="${MOCK_TEST_EXIT:-0}" \
    MOCK_RSYNC_EXIT="${MOCK_RSYNC_EXIT:-0}" \
    REMOTE_HOST="remote.lan" \
    REMOTE_USER="coder" \
    REMOTE_PROJECT_DIR="/srv/project" \
    REMOTE_LOG_DIR="/srv/project/.codex-remote-logs" \
    REMOTE_TEST_QUICK_CMD="echo quick-pass" \
    REMOTE_TEST_FULL_CMD="echo full-pass" \
    REMOTE_ALLOWED_RUN_REGEX="^(make|pytest|echo).*" \
    REMOTE_SSH_RETRIES="1" \
    REMOTE_RSYNC_RETRIES="1" \
    "${REMOTE_CLI}" "$@" 2>&1
  )"
  LAST_EXIT_CODE=$?
  set -e
  LAST_OUTPUT="${cmd_output}"
}

setup_sandbox() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin"

cat > "${sandbox}/bin/ssh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${MOCK_SSH_LOG:?missing MOCK_SSH_LOG}"
cmd="${!#}"

if [[ "${cmd}" == *"status --porcelain"* ]]; then
  printf "%s" "${MOCK_GIT_STATUS:-}"
  exit 0
fi

if [[ "${cmd}" == *"mkdir -p"* ]]; then
  exit 0
fi

if [[ "${cmd}" == *"tee"* ]]; then
  if [[ "${MOCK_TEST_EXIT:-0}" != "0" ]]; then
    echo "simulated remote test failure"
    exit "${MOCK_TEST_EXIT}"
  fi
  echo "simulated remote test pass"
  exit 0
fi

if [[ "${cmd}" == *"cat"* ]]; then
  echo "retrieved remote log"
  exit 0
fi

if [[ "${cmd}" == *"cd '/srv/project'"* ]]; then
  echo "remote run command ok"
  exit 0
fi

exit 0
EOF

  cat > "${sandbox}/bin/rsync" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${MOCK_RSYNC_LOG:?missing MOCK_RSYNC_LOG}"
if [[ "${MOCK_RSYNC_EXIT:-0}" != "0" ]]; then
  exit "${MOCK_RSYNC_EXIT}"
fi
exit 0
EOF

  chmod +x "${sandbox}/bin/ssh" "${sandbox}/bin/rsync"
  echo "${sandbox}"
}

echo "[TEST] CLI exists and prints usage"
if [[ ! -x "${REMOTE_CLI}" ]]; then
  fail "expected executable at ${REMOTE_CLI}"
fi

help_output="$("${REMOTE_CLI}" --help 2>&1)"
assert_contains "${help_output}" "sync"
assert_contains "${help_output}" "test quick"
assert_contains "${help_output}" "test full"
assert_contains "${help_output}" "run <cmd>"
assert_contains "${help_output}" "logs <run_id>"

echo "[TEST] sync success path with structured output"
sandbox="$(setup_sandbox)"
run_cli_capture "${sandbox}" sync
assert_exit_code "${LAST_EXIT_CODE}" "0"
assert_contains "${LAST_OUTPUT}" "[PHASE]"
assert_contains "${LAST_OUTPUT}" "[RESULT] PASS"
assert_contains "${LAST_OUTPUT}" "[DURATION]"
rsync_args="$(cat "${sandbox}/rsync.log")"
assert_contains "${rsync_args}" "--delete"

echo "[TEST] sync blocks dirty remote worktree"
sandbox="$(setup_sandbox)"
run_cli_capture "${sandbox}" sync
assert_exit_code "${LAST_EXIT_CODE}" "0"
MOCK_GIT_STATUS=" M tracked_file.py" run_cli_capture "${sandbox}" sync
assert_exit_code "${LAST_EXIT_CODE}" "3"
assert_contains "${LAST_OUTPUT}" "Remote worktree is dirty"
assert_contains "${LAST_OUTPUT}" "[RESULT] FAIL"
assert_not_contains "${LAST_OUTPUT}" "rsync completed"

echo "[TEST] quick test success and failure paths"
sandbox="$(setup_sandbox)"
run_cli_capture "${sandbox}" test quick
assert_exit_code "${LAST_EXIT_CODE}" "0"
assert_contains "${LAST_OUTPUT}" "[RUN_ID]"
assert_contains "${LAST_OUTPUT}" "[RESULT] PASS"

MOCK_TEST_EXIT="7" run_cli_capture "${sandbox}" test quick
assert_exit_code "${LAST_EXIT_CODE}" "7"
assert_contains "${LAST_OUTPUT}" "[RESULT] FAIL"

echo "[TEST] logs command fetches run log"
sandbox="$(setup_sandbox)"
run_cli_capture "${sandbox}" logs run-1234
assert_exit_code "${LAST_EXIT_CODE}" "0"
assert_contains "${LAST_OUTPUT}" "retrieved remote log"
assert_contains "${LAST_OUTPUT}" "[RESULT] PASS"

echo "[TEST] run command enforces whitelist"
sandbox="$(setup_sandbox)"
run_cli_capture "${sandbox}" run "echo hello"
assert_exit_code "${LAST_EXIT_CODE}" "0"
assert_contains "${LAST_OUTPUT}" "[RESULT] PASS"

run_cli_capture "${sandbox}" run "bash dangerous.sh"
assert_exit_code "${LAST_EXIT_CODE}" "4"
assert_contains "${LAST_OUTPUT}" "not allowed by REMOTE_ALLOWED_RUN_REGEX"
assert_contains "${LAST_OUTPUT}" "[RESULT] FAIL"

echo "[PASS] all CLI behavior checks"
