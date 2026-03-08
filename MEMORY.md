# MEMORY.md - Long-Term Memory

## Project: Agent Swarm MVP

### Goal
Build a production-ready agent swarm system that enables:
1. **Remote execution** on exe.dev
2. **GitHub integration** (auto push/PR)
3. **Linear integration** (task status updates)
4. **Discord mobile UI** (control from anywhere)

### Target Users
- Solo developers / small teams
- Anyone wanting to leverage AI coding agents at scale

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Discord (Mobile UI)                      │
│         Commands, notifications, status updates             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    OpenClaw (Zoe)                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │ Memory   │ │ Task     │ │ Linear   │ │ Discord  │       │
│  │ (this)   │ │ Registry │ │ Sync     │ │ Notify   │       │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 exe.dev (Remote Execution)                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                    │
│  │ OpenCode │ │ OpenCode │ │ OpenCode │  ...               │
│  │ (Qwen)   │ │ (Qwen)   │ │ (Qwen)   │                    │
│  └──────────┘ └──────────┘ └──────────┘                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    GitHub (Code Repository)                 │
│         PRs, reviews, CI/CD, auto-merge                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Integration Requirements

### 1. exe.dev (Remote Execution)
- [ ] Set up exe.dev account and API access
- [ ] Configure remote execution environment
- [ ] Ensure OpenCode/Qwen models available
- [ ] Test spawning agents remotely

### 2. GitHub Integration
- [x] Repository created: https://github.com/kzinmr/agent-swarm
- [ ] Auto PR creation from agents
- [ ] Auto review workflow
- [ ] Merge automation

### 3. Linear Integration
- [ ] Linear API setup
- [ ] Task sync from agent-swarm registry
- [ ] Status updates (running → done)
- [ ] Link PRs to Linear issues

### 4. Discord Integration
- [ ] Discord bot setup
- [ ] Commands: spawn, status, steer, list
- [ ] Notifications: PR ready, failures
- [ ] Mobile-friendly responses

---

## Technical Stack

| Component | Technology | Status |
|-----------|------------|--------|
| Orchestrator | OpenClaw | ✅ Active |
| Coding Agents | OpenCode + Qwen | 🔧 Pending |
| Remote Execution | exe.dev | 🔧 Pending |
| Code Hosting | GitHub | ✅ Ready |
| Task Management | Linear | 🔧 Pending |
| Mobile UI | Discord | 🔧 Pending |
| Monitoring | tmux + cron | ✅ Implemented |

---

## Current Progress

### Completed
- Agent swarm scripts (spawn, monitor, steer, review, cleanup)
- Task registry (JSON-based state management)
- Configuration system (environment-agnostic)
- Unified CLI (swarm-cli.sh)
- GitHub repo setup

### Next Steps
1. Set up exe.dev for remote execution
2. Configure Linear API integration
3. Build Discord bot for mobile control
4. End-to-end testing

---

## Discord Bot Setup

### Credentials
- **Application ID:** `1480277592157454607`
- **Server ID:** `1233771389367095377`
- **Channel ID:** `1233771389954166918`
- **Credentials:** `config/discord.credentials.json` (gitignored)

### Invite URL
```
https://discord.com/oauth2/authorize?client_id=1480277592157454607&permissions=2147483648&scope=bot%20applications.commands
```

### Commands
| Command | Description |
|---------|-------------|
| `/spawn <task-id> <prompt>` | Spawn new agent |
| `/status [task-id]` | Check task status |
| `/steer <task-id> <message>` | Send message to agent |
| `/list [status]` | List all tasks |
| `/kill <task-id>` | Stop agent |
| `/review <pr-number>` | Run PR review |
| `/cleanup [--dry-run]` | Clean up tasks |

### Directory Structure
```
discord/
├── src/
│   ├── index.ts          # Main bot entry
│   ├── commands.ts       # Slash command definitions
│   ├── handlers.ts       # Command handlers
│   ├── notifications.ts  # Proactive notifications
│   ├── cli-notify.ts     # CLI for shell scripts
│   └── config.ts          # Load credentials
├── package.json
└── README.md
```

### Running the Bot
```bash
cd discord
pnpm install
pnpm register-commands  # After inviting bot to server
pnpm start
```

---

## Key Decisions

| Date | Decision | Reason |
|------|----------|--------|
| 2025-03-09 | Use OpenCode + Qwen | Cost-effective, good for coding |
| 2025-03-09 | Discord for mobile UI | Already using, mobile-friendly |
| 2025-03-09 | Linear for task tracking | Clean API, good for devs |

---

## Lessons Learned

(To be updated as we progress)

---

## MVP Feature Requirements

### Phase 1: Core Infrastructure ✅
- [x] Agent spawn/monitor/steer scripts
- [x] Task registry (JSON)
- [x] Configuration system
- [x] GitHub repository

### Phase 2: Remote Execution
- [ ] exe.dev environment setup
- [ ] OpenCode CLI installation on remote
- [ ] Qwen model configuration
- [ ] SSH/key management

### Phase 3: Linear Integration
- [ ] Linear API key configuration
- [ ] Create issue from task
- [ ] Update issue status on agent progress
- [ ] Link PR to issue automatically
- [ ] Webhook for real-time updates

### Phase 4: Discord Mobile UI
- [x] Discord bot token setup
- [x] Command handlers:
  - `/spawn <task>` - Start new agent ✅
  - `/status [task-id]` - Check progress ✅
  - `/steer <task-id> <message>` - Redirect agent ✅
  - `/list` - Show all active tasks ✅
  - `/kill <task-id>` - Stop agent ✅
  - `/review <pr-number>` - Run reviews ✅
  - `/cleanup` - Clean up tasks ✅
- [x] Notification handlers:
  - PR ready for review ✅
  - CI passed/failed ✅
  - Agent stuck/error ✅
  - Task completed ✅
- [ ] Bot invited to server with correct permissions (pending user action)

### Phase 5: End-to-End Automation
- [ ] Customer request → Linear issue → Agent spawn
- [ ] Agent → GitHub PR → Auto review
- [ ] Review pass → Notify Discord → Human merge
- [ ] Merge → Update Linear → Cleanup

---

## Integration Specifications

### exe.dev
```bash
# Connection
exe.dev host: exe.dev
Auth: API key or SSH key

# Requirements
- Node.js 22+
- OpenCode CLI
- tmux
- jq
- gh CLI

# Model Access
- Alibaba Cloud Model Studio (Qwen)
- API Key: DASHSCOPE_API_KEY
```

### Linear API
```yaml
# Required scopes
- read
- write

# Endpoints
- POST /issues - Create from task
- PATCH /issues/:id - Update status
- POST /comments - Add updates

# Webhooks
- Issue created → spawn agent
- Issue updated → sync status
```

### Discord Bot
```yaml
# Required intents
- MESSAGE_CONTENT
- GUILD_MESSAGES

# Commands
/spawn - Start agent
/status - Check progress
/steer - Redirect agent
/list - List tasks
/review - Run reviews

# Permissions
- Send messages
- Embed links
- Use slash commands
```

---

## User Workflow (Target)

```
1. Mobile (Discord): /spawn feat-auth "Implement OAuth"
2. OpenClaw: Creates Linear issue + spawns agent on exe.dev
3. Agent: Codes on worktree, creates PR
4. Auto-review: Runs on PR
5. Discord notification: "PR #42 ready for review"
6. Mobile: Review, merge
7. Linear: Issue closed automatically
8. Cleanup: Worktree removed
```

---

## Related Files

- `config/swarm.config.sh` - Environment configuration
- `config/active-tasks.json` - Task registry
- `scripts/` - All automation scripts
- `SKILL.md` - OpenClaw skill definition
- Repository: https://github.com/kzinmr/agent-swarm