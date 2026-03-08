# Agent Swarm Discord Bot

Mobile UI for controlling your agent swarm from Discord.

## Setup

### 1. Invite Bot to Server

Open this URL to invite the bot with required permissions:

```
https://discord.com/oauth2/authorize?client_id=1480277592157454607&permissions=2147483648&scope=bot%20applications.commands
```

Required scopes:
- `bot` - Bot can join server
- `applications.commands` - Bot can register slash commands

### 2. Install Dependencies

```bash
pnpm install
```

### 3. Register Commands

```bash
pnpm register-commands
```

### 4. Start Bot

```bash
pnpm start
# or
./start.sh
```

## Commands

| Command | Description |
|---------|-------------|
| `/spawn <task-id> <prompt>` | Spawn a new coding agent |
| `/status [task-id]` | Check task status |
| `/steer <task-id> <message>` | Send message to running agent |
| `/list [status]` | List all tasks |
| `/kill <task-id>` | Stop a running agent |
| `/review <pr-number>` | Run automated PR review |
| `/cleanup [--dry-run]` | Clean up completed tasks |

## Examples

```
/spawn feat-auth "Implement OAuth authentication with Google provider"
/status feat-auth
/steer feat-auth "Focus on the API layer first"
/list
/kill feat-auth
/review 42
```

## Architecture

```
Discord Command → Bot Handler → Swarm Scripts → tmux/OpenCode
                                      ↓
                              Task Registry (JSON)
```

## Files

- `src/index.ts` - Main bot entry point
- `src/commands.ts` - Slash command definitions
- `src/handlers.ts` - Command handlers (call swarm scripts)
- `src/config.ts` - Load credentials and task registry
- `src/register-commands.ts` - Register slash commands with Discord

## Configuration

Credentials are stored in `../config/discord.credentials.json`:

```json
{
  "botToken": "...",
  "applicationId": "...",
  "publicKey": "...",
  "serverId": "...",
  "channelId": "..."
}
```

## Running as a Service

For production, run with a process manager:

```bash
# Using pm2
pm2 start "pnpm start" --name agent-swarm-discord

# Using systemd
# Create a service file at /etc/systemd/system/agent-swarm-discord.service
```

## Notifications

The bot can send proactive notifications when:
- PR is ready for review
- CI passes/fails
- Agent encounters errors
- Task completes

See `src/notifications.ts` (to be implemented).