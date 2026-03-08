#!/bin/bash
# =============================================================================
# steer-agent.sh - Send messages to a running agent
# =============================================================================
# Usage: steer-agent.sh <task-id> "message"
#
# Examples:
#   steer-agent.sh feat-templates "Stop. Focus on the API layer first."
#   steer-agent.sh fix-billing "The schema is in src/types/billing.ts"
#   steer-agent.sh feat-auth "Customer wants OAuth, not password auth."

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/swarm.config.sh"

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------
TASK_ID="${1:-}"
MESSAGE="${2:-}"

if [[ -z "$TASK_ID" ]] || [[ -z "$MESSAGE" ]]; then
  echo "Usage: $0 <task-id> \"message\""
  echo ""
  echo "Examples:"
  echo "  $0 feat-templates \"Stop. Focus on the API layer first.\""
  echo "  $0 fix-billing \"The schema is in src/types/billing.ts\""
  exit 1
fi

# -----------------------------------------------------------------------------
# Find task
# -----------------------------------------------------------------------------
init_registry

TASK=$(jq -c --arg id "$TASK_ID" '.tasks[] | select(.id == $id)' "$TASK_REGISTRY" 2>/dev/null || echo "")

if [[ -z "$TASK" ]]; then
  echo "Error: Task '$TASK_ID' not found in registry."
  echo "Active tasks:"
  jq -r '.tasks[] | select(.status != "done" and .status != "cancelled") | "  - \(.id) (\(.status))"' "$TASK_REGISTRY" 2>/dev/null || echo "  (none)"
  exit 1
fi

TMUX_SESSION=$(echo "$TASK" | jq -r '.tmuxSession')
WORKTREE=$(echo "$TASK" | jq -r '.worktreePath')
AGENT=$(echo "$TASK" | jq -r '.agent')

# -----------------------------------------------------------------------------
# Check tmux session
# -----------------------------------------------------------------------------
if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  echo "Error: tmux session '$TMUX_SESSION' is not running."
  echo "The agent may have completed or crashed."
  exit 1
fi

# -----------------------------------------------------------------------------
# Send message
# -----------------------------------------------------------------------------
log_info "Sending message to $TASK_ID ($AGENT):"
echo ""
echo "  ┌─────────────────────────────────────────────────────────────"
echo "  │ $MESSAGE"
echo "  └─────────────────────────────────────────────────────────────"
echo ""

# Send the message with Enter key
tmux send-keys -t "$TMUX_SESSION" "$MESSAGE" Enter

log_info "Message sent to tmux session: $TMUX_SESSION"
echo ""
echo "To attach: tmux attach -t $TMUX_SESSION"
echo "To see output: tmux capture-pane -t $TMUX_SESSION -p"