# Offline Remote Codex Workflow (`ops/remote`)

English | [中文](README_ZH.md)

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

### 5.1 Keep Sync on `ops/remote`

Continue to use local sync:

```bash
ops/remote sync
```

### 5.2 Use SSH MCP as the execution window

1. Put the runner env file on remote host:

```bash
cp /srv/project/ops/remote-mcp-runner.env.example /srv/project/ops/remote-mcp-runner.env
```

2. Edit `/srv/project/ops/remote-mcp-runner.env` for your project commands.

3. Configure local MCP client with:

- MCP client config template: `ops/ssh-mcp-config.example.json`
- SSH target config template: `ops/ssh-mcp-targets.example.json`

4. Allow only runner-based commands in whitelist.

### 5.3 Call patterns (from MCP `execute-command`)

```bash
bash /srv/project/ops/remote-mcp-runner.sh quick
bash /srv/project/ops/remote-mcp-runner.sh full
bash /srv/project/ops/remote-mcp-runner.sh run "echo hello"
cat /srv/project/.codex-remote-logs/<run_id>.log
```

The runner emits structured markers:

- `[RUN_ID] ...`
- `[RESULT] PASS|FAIL`
- `[EXIT_CODE] <n>`
- `[DURATION] ...`

LLM can parse these markers from command output text.

## 6) Comparison with Pure MCP Approach

| Scenario | `ops/remote` Standard Workflow | SSH MCP Direct Execution |
|----------|-------------------------------|-------------------------|
| Bulk code sync | ✅ `rsync` incremental sync | ❌ Must upload files individually |
| Execution history | ✅ `logs <id>` for historical lookup | ❌ Only real-time output |
| Long-running tasks | ✅ `tmux` support, disconnect-resume | ❌ Limited by MCP call timeout |
| One-shot operation | ✅ `cycle` command (sync+test) | ❌ Requires multiple calls |
| Interactive exploration | ❌ Non-interactive | ✅ Good for AI Q&A |

**Recommendation**: Use `ops/remote cycle` for development iterations, use MCP for AI-assisted debugging.
