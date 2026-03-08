#!/bin/bash
# =============================================================================
# swarm-cli.sh - Unified CLI for Agent Swarm operations
# =============================================================================
# Usage: swarm-cli.sh <command> [args...]
#
# Commands:
#   spawn    <task-id> [model] [priority]  Spawn a new agent
#   monitor  [--json]                      Check all agents
#   steer    <task-id> "message"           Send message to agent
#   review   <pr-number>                   Run auto-review
#   list                                    List all tasks
#   status   <task-id>                     Show task details
#   kill     <task-id>                     Kill an agent
#   cleanup  [--dry-run]                   Clean up completed tasks
#   logs     <task-id>                     Show agent logs
#   init                                    Initialize swarm

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/swarm.config.sh"

# -----------------------------------------------------------------------------
# Color output
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}!${NC} $1"; }

# -----------------------------------------------------------------------------
# Commands
# -----------------------------------------------------------------------------
cmd_init() {
  ensure_dirs
  init_registry
  print_success "Agent Swarm initialized"
  print_info "Registry: $TASK_REGISTRY"
  print_info "Worktrees: $WORKTREES_DIR"
}

cmd_spawn() {
  local task_id="${1:-}"
  local model="${2:-$OPENCODE_DEFAULT_MODEL}"
  local priority="${3:-normal}"
  
  if [[ -z "$task_id" ]]; then
    print_error "Usage: swarm-cli.sh spawn <task-id> [model] [priority]"
    exit 1
  fi
  
  "$SCRIPT_DIR/spawn-agent.sh" "$task_id" opencode "$model" "$priority"
}

cmd_monitor() {
  local json_output=false
  [[ "${1:-}" == "--json" ]] && json_output=true
  
  "$SCRIPT_DIR/monitor-agents.sh" ${json_output:+--json}
}

cmd_steer() {
  local task_id="${1:-}"
  local message="${2:-}"
  
  if [[ -z "$task_id" ]] || [[ -z "$message" ]]; then
    print_error "Usage: swarm-cli.sh steer <task-id> \"message\""
    exit 1
  fi
  
  "$SCRIPT_DIR/steer-agent.sh" "$task_id" "$message"
}

cmd_review() {
  local pr_number="${1:-}"
  
  if [[ -z "$pr_number" ]]; then
    print_error "Usage: swarm-cli.sh review <pr-number>"
    exit 1
  fi
  
  "$SCRIPT_DIR/auto-review.sh" "$pr_number"
}

cmd_list() {
  init_registry
  
  local tasks
  tasks=$(jq -c '.tasks[]' "$TASK_REGISTRY" 2>/dev/null || echo "")
  
  if [[ -z "$tasks" ]]; then
    print_info "No tasks in registry"
    return
  fi
  
  echo ""
  echo "Agent Swarm Tasks"
  echo "================="
  echo ""
  
  while IFS= read -r task; do
    local id status agent model pr checks
    id=$(echo "$task" | jq -r '.id')
    status=$(echo "$task" | jq -r '.status')
    agent=$(echo "$task" | jq -r '.agent')
    model=$(echo "$task" | jq -r '.model')
    pr=$(echo "$task" | jq -r '.checks.prNumber // "-"')
    
    case "$status" in
      running) status="${GREEN}running${NC}" ;;
      done) status="${GREEN}done${NC}" ;;
      failed) status="${RED}failed${NC}" ;;
      *) status="${YELLOW}$status${NC}" ;;
    esac
    
    echo -e "  $id"
    echo -e "    Status: $status"
    echo -e "    Agent:  $agent ($model)"
    echo -e "    PR:     $pr"
    echo ""
  done <<< "$tasks"
}

cmd_status() {
  local task_id="${1:-}"
  
  if [[ -z "$task_id" ]]; then
    print_error "Usage: swarm-cli.sh status <task-id>"
    exit 1
  fi
  
  init_registry
  
  local task
  task=$(jq -c --arg id "$task_id" '.tasks[] | select(.id == $id)' "$TASK_REGISTRY" 2>/dev/null || echo "")
  
  if [[ -z "$task" ]]; then
    print_error "Task not found: $task_id"
    exit 1
  fi
  
  echo ""
  jq -r '
    "Task: " + .id,
    "Status: " + .status,
    "Agent: " + .agent + " (" + .model + ")",
    "Branch: " + .branch,
    "Worktree: " + .worktreePath,
    "Started: " + (.startedAt / 1000 | strftime("%Y-%m-%d %H:%M:%S")),
    "",
    "Checks:",
    "  PR Created: " + (if .checks.prCreated then "✓" else "✗" end),
    "  PR Number: " + (.checks.prNumber // "-"),
    "  CI Passed: " + (if .checks.ciPassed == true then "✓" elif .checks.ciPassed == false then "✗" else "-" end),
    "",
    "Reviews:",
    "  OpenCode: " + (.checks.reviews.opencode // "-"),
    "  Gemini: " + (.checks.reviews.gemini // "-"),
    "  Claude: " + (.checks.reviews.claude // "-")
  ' <<< "$task"
}

cmd_kill() {
  local task_id="${1:-}"
  
  if [[ -z "$task_id" ]]; then
    print_error "Usage: swarm-cli.sh kill <task-id>"
    exit 1
  fi
  
  init_registry
  
  local task session
  task=$(jq -c --arg id "$task_id" '.tasks[] | select(.id == $id)' "$TASK_REGISTRY" 2>/dev/null || echo "")
  
  if [[ -z "$task" ]]; then
    print_error "Task not found: $task_id"
    exit 1
  fi
  
  session=$(echo "$task" | jq -r '.tmuxSession')
  
  if tmux has-session -t "$session" 2>/dev/null; then
    tmux kill-session -t "$session"
    print_success "Killed tmux session: $session"
  else
    print_warning "Session not running: $session"
  fi
  
  # Update status
  jq --arg id "$task_id" --arg status "killed" \
    '(.tasks[] | select(.id == $id) | .status) = $status' \
    "$TASK_REGISTRY" > "${TASK_REGISTRY}.tmp" && mv "${TASK_REGISTRY}.tmp" "$TASK_REGISTRY"
  
  print_success "Task marked as killed: $task_id"
}

cmd_cleanup() {
  local dry_run=false
  [[ "${1:-}" == "--dry-run" ]] && dry_run=true
  
  "$SCRIPT_DIR/cleanup.sh" ${dry_run:+--dry-run}
}

cmd_logs() {
  local task_id="${1:-}"
  
  if [[ -z "$task_id" ]]; then
    print_error "Usage: swarm-cli.sh logs <task-id>"
    exit 1
  fi
  
  init_registry
  
  local session
  session=$(jq -r --arg id "$task_id" '.tasks[] | select(.id == $id) | .tmuxSession' "$TASK_REGISTRY" 2>/dev/null || echo "")
  
  if [[ -z "$session" ]]; then
    print_error "Task not found: $task_id"
    exit 1
  fi
  
  if ! tmux has-session -t "$session" 2>/dev/null; then
    print_error "Session not running: $session"
    exit 1
  fi
  
  echo "Last 50 lines from $session:"
  echo "---"
  tmux capture-pane -t "$session" -p -S -50
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
case "${1:-}" in
  init) shift; cmd_init "$@" ;;
  spawn) shift; cmd_spawn "$@" ;;
  monitor) shift; cmd_monitor "$@" ;;
  steer) shift; cmd_steer "$@" ;;
  review) shift; cmd_review "$@" ;;
  list) shift; cmd_list "$@" ;;
  status) shift; cmd_status "$@" ;;
  kill) shift; cmd_kill "$@" ;;
  cleanup) shift; cmd_cleanup "$@" ;;
  logs) shift; cmd_logs "$@" ;;
  *)
    echo "Agent Swarm CLI"
    echo ""
    echo "Usage: $0 <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  init                            Initialize swarm"
    echo "  spawn   <task-id> [model]       Spawn a new agent"
    echo "  monitor [--json]                Check all agents"
    echo "  steer   <task-id> \"message\"     Send message to agent"
    echo "  review  <pr-number>             Run auto-review"
    echo "  list                            List all tasks"
    echo "  status  <task-id>               Show task details"
    echo "  kill    <task-id>               Kill an agent"
    echo "  cleanup [--dry-run]             Clean up completed tasks"
    echo "  logs    <task-id>               Show agent logs"
    ;;
esac