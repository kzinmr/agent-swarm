#!/bin/bash
# =============================================================================
# spawn-agent.sh - Spawn a coding agent in a tmux session
# =============================================================================
# Usage: spawn-agent.sh <task-id> <agent-type> <model> [priority]
#
# Examples:
#   spawn-agent.sh feat-templates opencode qwen-coder-plus high
#   spawn-agent.sh fix-billing opencode qwen-coder-plus normal

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/swarm.config.sh"

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------
TASK_ID="${1:-}"
AGENT_TYPE="${2:-opencode}"
MODEL="${3:-$OPENCODE_DEFAULT_MODEL}"
PRIORITY="${4:-normal}"

if [[ -z "$TASK_ID" ]]; then
  echo "Usage: $0 <task-id> [agent-type] [model] [priority]"
  echo ""
  echo "Arguments:"
  echo "  task-id      Unique identifier for this task (e.g., feat-templates)"
  echo "  agent-type   Agent type: opencode (default), codex, claude"
  echo "  model        Model to use (default: $OPENCODE_DEFAULT_MODEL)"
  echo "  priority     Task priority: low, normal, high (default: normal)"
  exit 1
fi

# -----------------------------------------------------------------------------
# Validate inputs
# -----------------------------------------------------------------------------
if [[ ! " ${AGENT_TYPES[*]} " =~ " ${AGENT_TYPE} " ]]; then
  log_error "Invalid agent type: $AGENT_TYPE. Valid types: ${AGENT_TYPES[*]}"
  exit 1
fi

# -----------------------------------------------------------------------------
# Generate session and branch names
# -----------------------------------------------------------------------------
TMUX_SESSION="${TMUX_PREFIX}-${TASK_ID}"
BRANCH_NAME="feat/${TASK_ID}"
WORKTREE_NAME="${TASK_ID}"
WORKTREE_PATH="${WORKTREES_DIR}/${WORKTREE_NAME}"

# -----------------------------------------------------------------------------
# Check if task already exists
# -----------------------------------------------------------------------------
init_registry
if command -v jq &> /dev/null; then
  EXISTING=$(jq -r --arg id "$TASK_ID" '.tasks[] | select(.id == $id) | .id' "$TASK_REGISTRY" 2>/dev/null || echo "")
  if [[ -n "$EXISTING" ]]; then
    log_error "Task '$TASK_ID' already exists. Use resume-agent.sh to resume or remove it first."
    exit 1
  fi
fi

# -----------------------------------------------------------------------------
# Detect repository
# -----------------------------------------------------------------------------
REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [[ -z "$REPO_PATH" ]]; then
  log_error "Not in a git repository. Please run from within a repo or specify REPO_PATH."
  exit 1
fi

REPO_NAME=$(basename "$REPO_PATH")
BASE_BRANCH="${GIT_DEFAULT_BRANCH}"

log_info "Repository: $REPO_NAME at $REPO_PATH"
log_info "Task: $TASK_ID"
log_info "Agent: $AGENT_TYPE with model $MODEL"
log_info "Branch: $BRANCH_NAME (from $BASE_BRANCH)"

# -----------------------------------------------------------------------------
# Create worktree
# -----------------------------------------------------------------------------
log_info "Creating worktree at $WORKTREE_PATH..."

# Check if worktree already exists
if [[ -d "$WORKTREE_PATH" ]]; then
  log_info "Worktree already exists. Reusing..."
else
  git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" "origin/$BASE_BRANCH" 2>/dev/null || {
    log_info "Branch might exist locally, trying alternative..."
    git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" "$BASE_BRANCH"
  }
fi

# Install dependencies if needed
cd "$WORKTREE_PATH"
if [[ -f "package.json" ]] && [[ ! -d "node_modules" ]]; then
  log_info "Installing dependencies..."
  pnpm install --frozen-lockfile 2>/dev/null || npm install --frozen-lockfile 2>/dev/null || {
    log_error "Failed to install dependencies"
  }
fi

# -----------------------------------------------------------------------------
# Register task
# -----------------------------------------------------------------------------
TIMESTAMP=$(date +%s%3N)
TASK_ENTRY=$(cat <<EOF
{
  "id": "$TASK_ID",
  "tmuxSession": "$TMUX_SESSION",
  "agent": "$AGENT_TYPE",
  "model": "$MODEL",
  "description": "",
  "repo": "$REPO_NAME",
  "repoPath": "$REPO_PATH",
  "worktree": "$WORKTREE_NAME",
  "worktreePath": "$WORKTREE_PATH",
  "branch": "$BRANCH_NAME",
  "baseBranch": "$BASE_BRANCH",
  "startedAt": $TIMESTAMP,
  "status": "spawning",
  "attempt": 1,
  "maxAttempts": $MAX_RETRY_ATTEMPTS,
  "notifyOnComplete": true,
  "priority": "$PRIORITY",
  "tags": [],
  "prompt": "",
  "context": {},
  "checks": {
    "prCreated": false,
    "prNumber": null,
    "ciPassed": null,
    "reviews": {
      "opencode": null,
      "gemini": null,
      "claude": null
    },
    "screenshotIncluded": null
  },
  "completedAt": null,
  "note": null
}
EOF
)

if command -v jq &> /dev/null; then
  jq --argjson task "$TASK_ENTRY" --arg updated "$(date -Iseconds)" \
    '.tasks += [$task] | .lastUpdated = $updated' \
    "$TASK_REGISTRY" > "${TASK_REGISTRY}.tmp" && mv "${TASK_REGISTRY}.tmp" "$TASK_REGISTRY"
  log_info "Task registered in $TASK_REGISTRY"
fi

# -----------------------------------------------------------------------------
# Create tmux session
# -----------------------------------------------------------------------------
log_info "Creating tmux session: $TMUX_SESSION"

# Check if session already exists
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  log_info "Session exists. Attaching..."
  tmux attach-session -t "$TMUX_SESSION"
  exit 0
fi

# Create new session
tmux new-session -d -s "$TMUX_SESSION" -c "$WORKTREE_PATH" "$TMUX_SHELL"

# Set environment in tmux
tmux set-environment -t "$TMUX_SESSION" TASK_ID "$TASK_ID"
tmux set-environment -t "$TMUX_SESSION" AGENT_TYPE "$AGENT_TYPE"
tmux set-environment -t "$TMUX_SESSION" MODEL "$MODEL"

# Update status to running
if command -v jq &> /dev/null; then
  jq --arg id "$TASK_ID" --arg status "running" \
    '(.tasks[] | select(.id == $id) | .status) = $status' \
    "$TASK_REGISTRY" > "${TASK_REGISTRY}.tmp" && mv "${TASK_REGISTRY}.tmp" "$TASK_REGISTRY"
fi

# -----------------------------------------------------------------------------
# Launch agent
# -----------------------------------------------------------------------------
log_info "Launching $AGENT_TYPE agent..."

case "$AGENT_TYPE" in
  opencode)
    # OpenCode with Qwen model
    LAUNCH_CMD="opencode --model $MODEL"
    if [[ "$PRIORITY" == "high" ]]; then
      LAUNCH_CMD="opencode --model ${OPENCODE_HIGH_EFFORT_MODEL}"
    fi
    ;;
  codex)
    # OpenAI Codex (if available)
    LAUNCH_CMD="codex --model ${CODEX_MODEL:-o1} --dangerously-bypass-approvals-and-sandbox"
    ;;
  claude)
    # Claude Code (if available)
    LAUNCH_CMD="claude --model ${CLAUDE_MODEL:-claude-sonnet-4} --dangerously-skip-permissions"
    ;;
  *)
    log_error "Unknown agent type: $AGENT_TYPE"
    exit 1
    ;;
esac

# Send the launch command to tmux
tmux send-keys -t "$TMUX_SESSION" "$LAUNCH_CMD" Enter

log_info "Agent spawned successfully!"
echo ""
echo "=========================================="
echo "Task ID:     $TASK_ID"
echo "Session:     $TMUX_SESSION"
echo "Worktree:    $WORKTREE_PATH"
echo "Branch:      $BRANCH_NAME"
echo "=========================================="
echo ""
echo "To attach:   tmux attach -t $TMUX_SESSION"
echo "To monitor:  $SCRIPT_DIR/monitor-agents.sh"
echo "To steer:    $SCRIPT_DIR/steer-agent.sh $TASK_ID \"your message\""
echo ""