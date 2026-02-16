# Offline Remote Codex Workflow (`ops/remote`)

This repository provides a single local entrypoint for a split setup:

- Laptop: runs Codex/AI, edits lightweight code.
- Remote server: LAN-only, hosts runtime and heavy model weights.
- Bridge: local `rsync` + `ssh`.

## 1) Setup

1. Copy config template:

```bash
cp ops/remote.env.example ops/remote.env
```

2. Edit `ops/remote.env` with your remote host/user/project path and test commands.

3. Ensure required tools are installed locally:

```bash
ssh -V
rsync --version
```

4. Ensure remote login works:

```bash
ssh <user>@<host> "echo ok"
```

## 2) CLI Interface

Unified entrypoint:

```bash
ops/remote sync
ops/remote test quick
ops/remote test full
ops/remote run "echo hello"
ops/remote logs <run_id>
ops/remote cycle
```

`ops/remote cycle` is the default Codex-friendly step (`sync` then `test quick`).

## 3) Output Protocol

Every command emits structured markers:

- `[PHASE] ...`
- `[CMD] ...`
- `[RUN_ID] ...` (test commands)
- `[RESULT] PASS|FAIL`
- `[DURATION] <seconds>s`

The process exit code always matches real command status (`0` pass, non-zero fail).

## 4) Safety and Reliability

- `sync` checks remote git status before using `rsync --delete` (enabled by default).
- `.rsyncignore` excludes local caches, secrets, and large model artifacts.
- SSH connection multiplexing is enabled by default (ControlMaster/ControlPersist).
- Optional retries exist for both SSH and rsync.
- Optional tmux wrapping for `test full` can be enabled with `REMOTE_USE_TMUX=1`.

## 5) Optional Local SSH MCP Integration

Keep MCP optional and local-only. Do not depend on remote MCP runtime.

Map MCP tools to this CLI, for example:

- `remote_sync` -> `ops/remote sync`
- `remote_test_quick` -> `ops/remote test quick`
- `remote_test_full` -> `ops/remote test full`
- `remote_logs` -> `ops/remote logs <run_id>`

Reference mapping: `ops/mcp-ssh-tools.example.json`

This keeps one operational path and avoids duplicated logic.
