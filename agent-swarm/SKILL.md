# Agent Swarm Skill

## Description

Orchestrate a fleet of coding agents (OpenCode, Codex, Claude Code) using tmux sessions with automated monitoring, review, and cleanup.

## When to Use

- Implementing multiple features in parallel
- Customer requests that need coding work
- Bug fixes that can run independently
- Any task that benefits from agent orchestration

## Scripts

### spawn-agent.sh

Spawn a new coding agent in an isolated worktree.

```bash
./scripts/spawn-agent.sh <task-id> [agent-type] [model] [priority]
```

**Arguments:**
- `task-id`: Unique identifier (e.g., `feat-templates`, `fix-billing`)
- `agent-type`: `opencode` (default), `codex`, `claude`
- `model`: Model to use (default: from config)
- `priority`: `low`, `normal`, `high`

**Example:**
```bash
spawn-agent.sh feat-auth opencode qwen-coder-plus high
```

### monitor-agents.sh

Check all active agents (run via cron every 10 minutes).

```bash
./scripts/monitor-agents.sh [--json] [--notify]
```

### steer-agent.sh

Send a message to a running agent.

```bash
./scripts/steer-agent.sh <task-id> "message"
```

**Examples:**
```bash
steer-agent.sh feat-auth "Focus on the API layer first."
steer-agent.sh fix-billing "The schema is in src/types/billing.ts"
```

### auto-review.sh

Run automated code review on a PR.

```bash
./scripts/auto-review.sh <pr-number> [--models opencode,gemini,claude]
```

### cleanup.sh

Remove completed tasks and orphaned worktrees.

```bash
./scripts/cleanup.sh [--age-days N] [--dry-run]
```

## Configuration

Edit `config/swarm.config.sh` to customize:

- Model selection (Qwen models for OpenCode)
- Worktree locations
- Retry attempts
- CI commands
- Notification settings

## Task Registry

All tasks are tracked in `config/active-tasks.json`:

```json
{
  "id": "feat-auth",
  "tmuxSession": "agent-feat-auth",
  "status": "running",
  "checks": {
    "prCreated": false,
    "ciPassed": null,
    "reviews": { ... }
  }
}
```

## Integration with OpenClaw

### Spawning from OpenClaw

Use `sessions_spawn` with `runtime: "acp"` to spawn coding agents:

```json
{
  "runtime": "acp",
  "agentId": "opencode",
  "task": "Implement feature X...",
  "cwd": "/path/to/worktree"
}
```

### Monitoring from OpenClaw

The cron job runs automatically. To check manually:

```bash
./scripts/monitor-agents.sh --json
```

### Steering from OpenClaw

Use `sessions_send` to steer agents, or call the steer script directly.

## Definition of Done

A task is complete when:
1. PR created
2. CI passing
3. All code reviews passed
4. Screenshots included (for UI changes)

## Best Practices

1. **One task per agent**: Keep tasks focused and independent
2. **Clear task IDs**: Use descriptive names like `feat-auth-oauth` or `fix-billing-race`
3. **Steer early**: If an agent goes wrong direction, steer immediately
4. **Review thoroughly**: Use all three reviewers before merging
5. **Clean up regularly**: Run cleanup daily to free resources

## Troubleshooting

### Dead tmux session

```bash
tmux kill-session -t agent-<task-id>
# Respawn will happen on next monitor cycle
```

### Stuck agent

```bash
./scripts/steer-agent.sh <task-id> "Stop. What's the blocker?"
```

### Conflicting worktrees

```bash
git worktree remove --force /path/to/worktree
```