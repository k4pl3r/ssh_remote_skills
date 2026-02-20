# 离线远程 Codex 工作流 (`ops/remote`)

[English](README.md) | 中文

本仓库为分离式开发环境提供单一本地入口：

- **笔记本**：运行 Codex/AI，编辑轻量级代码
- **远程服务器**：仅内网访问，托管运行时环境和大型模型权重
- **桥梁**：本地 `rsync` + `ssh`

## 1) 快速开始

### 1.1 复制配置模板

```bash
cp ops/remote.env.example ops/remote.env
```

### 1.2 编辑配置文件

编辑 `ops/remote.env`，填入你的远程主机、用户名、项目路径和测试命令。

### 1.3 确保本地工具已安装

```bash
ssh -V
rsync --version
```

### 1.4 验证远程连接

```bash
ssh <user>@<host> "echo ok"
```

## 2) CLI 接口

统一入口：

```bash
ops/remote sync              # 增量同步代码到远程
ops/remote test quick        # 运行快速测试（结构化输出）
ops/remote test full         # 运行完整测试（结构化输出）
ops/remote run "echo hello"  # 执行临时命令（支持白名单）
ops/remote logs <run_id>     # 根据运行 ID 获取远程日志
ops/remote cycle             # 默认工作流：sync + test quick
```

`ops/remote cycle` 是面向 Codex 的默认推荐步骤。

## 3) 输出协议

所有命令输出结构化标记：

- `[PHASE] ...` — 阶段信息
- `[CMD] ...` — 执行的命令
- `[RUN_ID] ...` — 测试命令的运行 ID
- `[RESULT] PASS|FAIL` — 执行结果
- `[DURATION] <seconds>s` — 执行耗时

进程退出码始终与真实命令状态一致（`0` 为成功，非零为失败）。

## 4) 安全与可靠性

- **sync 安全检查**：使用 `rsync --delete` 前检查远程 Git 工作区是否干净（默认启用）
- **排除文件**：`.rsyncignore` 排除本地缓存、密钥和大型模型文件
- **SSH 连接复用**：默认启用 ControlMaster/ControlPersist
- **重试机制**：SSH 和 rsync 均支持配置重试次数
- **tmux 包装**：`test full` 可启用 tmux 包装（`REMOTE_USE_TMUX=1`），支持断开重连

## 5) 可选的本地 SSH MCP 集成

保持 MCP 为可选且仅本地使用，不依赖远程 MCP 运行时。

### 5.1 继续使用 ops/remote 进行同步

```bash
ops/remote sync
```

### 5.2 使用 SSH MCP 作为执行窗口

1. 将运行器环境文件放到远程主机：

```bash
cp /srv/project/ops/remote-mcp-runner.env.example /srv/project/ops/remote-mcp-runner.env
```

2. 编辑 `/srv/project/ops/remote-mcp-runner.env` 配置项目命令。

3. 使用以下模板配置本地 MCP 客户端：

- MCP 客户端配置模板：`ops/ssh-mcp-config.example.json`
- SSH 目标配置模板：`ops/ssh-mcp-targets.example.json`

4. 在白名单中仅允许基于运行器的命令。

### 5.3 从 MCP `execute-command` 调用

```bash
bash /srv/project/ops/remote-mcp-runner.sh quick
bash /srv/project/ops/remote-mcp-runner.sh full
bash /srv/project/ops/remote-mcp-runner.sh run "echo hello"
cat /srv/project/.codex-remote-logs/<run_id>.log
```

运行器输出结构化标记：

- `[RUN_ID] ...`
- `[RESULT] PASS|FAIL`
- `[EXIT_CODE] <n>`
- `[DURATION] ...`

LLM 可以从命令输出文本中解析这些标记。

## 6) 与纯 MCP 方式的对比

| 场景 | `ops/remote` 标准工作流 | SSH MCP 直接执行 |
|------|------------------------|------------------|
| 批量代码同步 | ✅ `rsync` 增量同步 | ❌ 需逐个上传文件 |
| 执行历史追溯 | ✅ `logs <id>` 可查历史 | ❌ 仅实时回显 |
| 长时间任务 | ✅ `tmux` 支持，可断开重连 | ❌ 受 MCP 超时限制 |
| 一键操作 | ✅ `cycle` 命令 sync+test | ❌ 需多次独立调用 |
| 交互式探索 | ❌ 非交互式 | ✅ 适合 AI 即时问答 |

**推荐**：开发迭代用 `ops/remote cycle`，AI 辅助调试用 MCP。
