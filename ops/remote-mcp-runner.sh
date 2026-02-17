#!/usr/bin/env bash
set -Eeuo pipefail

phase() {
  echo "[PHASE] $*"
}

cmd_log() {
  echo "[CMD] $*"
}

run_id_log() {
  echo "[RUN_ID] $*"
}

result_log() {
  echo "[RESULT] $*"
}

duration_log() {
  echo "[DURATION] $*"
}

exit_code_log() {
  echo "[EXIT_CODE] $*"
}

usage() {
  cat <<'EOF'
Usage:
  remote-mcp-runner.sh quick
  remote-mcp-runner.sh full
  remote-mcp-runner.sh run <command...>

Environment:
  MCP_REMOTE_PROJECT_DIR      Remote project directory (default: current directory)
  MCP_REMOTE_LOG_DIR          Log directory (default: $MCP_REMOTE_PROJECT_DIR/.codex-remote-logs)
  MCP_REMOTE_TEST_QUICK_CMD   Command for quick mode
  MCP_REMOTE_TEST_FULL_CMD    Command for full mode
  MCP_REMOTE_RUN_WHITELIST    Optional regex to allow run-mode commands
  MCP_REMOTE_ENV_FILE         Optional env file path (default: $MCP_REMOTE_PROJECT_DIR/ops/remote-mcp-runner.env)
EOF
}

now_epoch() {
  date +%s
}

finish() {
  local rc="$1"
  local started_at="$2"
  local elapsed=$(( $(now_epoch) - started_at ))
  if (( rc == 0 )); then
    result_log "PASS"
  else
    result_log "FAIL"
  fi
  exit_code_log "${rc}"
  duration_log "${elapsed}s"
  return "${rc}"
}

build_run_id() {
  local mode="$1"
  printf "%s-%s-%04d" "${mode}" "$(date +%Y%m%d-%H%M%S)" "$((RANDOM % 10000))"
}

main() {
  local started_at
  started_at="$(now_epoch)"
  local mode="${1:-}"

  local project_dir="${MCP_REMOTE_PROJECT_DIR:-$(pwd)}"
  local env_file="${MCP_REMOTE_ENV_FILE:-${project_dir%/}/ops/remote-mcp-runner.env}"

  if [[ -f "${env_file}" ]]; then
    # shellcheck disable=SC1090
    source "${env_file}"
  fi

  project_dir="${MCP_REMOTE_PROJECT_DIR:-${project_dir}}"
  local log_dir="${MCP_REMOTE_LOG_DIR:-${project_dir%/}/.codex-remote-logs}"

  if [[ -z "${mode}" || "${mode}" == "--help" || "${mode}" == "-h" ]]; then
    usage
    return 0
  fi

  shift || true
  local run_id
  run_id="$(build_run_id "${mode}")"
  run_id_log "${run_id}"
  phase "Remote MCP runner start"

  local remote_cmd=""
  case "${mode}" in
    quick)
      remote_cmd="${MCP_REMOTE_TEST_QUICK_CMD:-}"
      ;;
    full)
      remote_cmd="${MCP_REMOTE_TEST_FULL_CMD:-}"
      ;;
    run)
      if [[ "$#" -lt 1 ]]; then
        echo "run mode requires a command" >&2
        finish 2 "${started_at}"
        return 2
      fi
      remote_cmd="$*"
      local whitelist="${MCP_REMOTE_RUN_WHITELIST:-}"
      if [[ -n "${whitelist}" && ! "${remote_cmd}" =~ ${whitelist} ]]; then
        echo "Command not allowed by MCP_REMOTE_RUN_WHITELIST: ${remote_cmd}" >&2
        finish 4 "${started_at}"
        return 4
      fi
      ;;
    *)
      usage >&2
      finish 2 "${started_at}"
      return 2
      ;;
  esac

  if [[ -z "${remote_cmd}" ]]; then
    echo "Command for mode '${mode}' is empty." >&2
    finish 2 "${started_at}"
    return 2
  fi

  if ! mkdir -p "${log_dir}"; then
    echo "Failed to create log directory: ${log_dir}" >&2
    finish 5 "${started_at}"
    return 5
  fi

  local log_file="${log_dir%/}/${run_id}.log"
  phase "Running command in ${project_dir}"
  cmd_log "${remote_cmd}"

  set +e
  (
    cd "${project_dir}" || exit 10
    bash -lc "${remote_cmd}"
  ) 2>&1 | tee "${log_file}"
  local pipe_status=("${PIPESTATUS[@]}")
  set -e

  local rc_cmd="${pipe_status[0]:-1}"
  local rc_tee="${pipe_status[1]:-0}"
  local rc=0
  if (( rc_cmd != 0 )); then
    rc="${rc_cmd}"
  elif (( rc_tee != 0 )); then
    rc="${rc_tee}"
  fi

  finish "${rc}" "${started_at}"
}

main "$@"
