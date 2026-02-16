# Offline Remote Codex Workflow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a local `ops/remote` interface that syncs code to a LAN-only remote server and runs remote tests through SSH with structured output.

**Architecture:** A single Bash entrypoint (`ops/remote`) will load local config, run `rsync` for sync, use `ssh` for remote commands, and enforce a stable output protocol (`[PHASE]`, `[CMD]`, `[RESULT]`, `[DURATION]`). Tests use local mock binaries for `ssh`/`rsync` to validate behavior without remote dependencies.

**Tech Stack:** Bash, rsync, ssh, tmux (optional), shell-based test harness.

---

### Task 1: Create failing tests for CLI contract

**Files:**
- Create: `tests/test_ops_remote.sh`

**Steps:**
1. Write tests that assert required commands and output conventions.
2. Run tests before implementation and confirm they fail.

### Task 2: Implement `ops/remote` command

**Files:**
- Create: `ops/remote`

**Steps:**
1. Add command routing (`sync`, `test quick`, `test full`, `run`, `logs`).
2. Implement config loading and required environment validation.
3. Implement remote clean-worktree protection before destructive rsync sync.
4. Implement structured logging and strict exit code behavior.
5. Add remote log capture and retrieval by run id.

### Task 3: Add defaults and docs

**Files:**
- Create: `ops/remote.env.example`
- Create: `.rsyncignore`
- Create: `README.md`

**Steps:**
1. Provide safe configuration defaults and example commands.
2. Document quick/full test behavior and Codex integration usage.
3. Document optional local SSH MCP mapping as non-blocking enhancement.

### Task 4: Verify behavior end-to-end locally

**Files:**
- Modify: `tests/test_ops_remote.sh` (if needed)

**Steps:**
1. Run tests after implementation and confirm all pass.
2. Ensure script executable bits and shebangs are correct.
3. Record verification evidence in final handoff.
