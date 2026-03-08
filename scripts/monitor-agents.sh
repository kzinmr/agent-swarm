#!/bin/bash
# =============================================================================
# monitor-agents.sh - Monitor all active agent tasks
# =============================================================================
# Runs periodically (via cron) to check:
#   - tmux session health
#   - PR status (created, open)
#   - CI status (passing/failing)
#   - Review status
#   - Auto-respawn failed agents (up to max attempts)
#
# Usage: monitor-agents.sh [--json] [--notify]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/swarm.config.sh"

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------
OUTPUT_JSON=false
NOTIFY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) OUTPUT_JSON=true; shift ;;
    --notify) NOTIFY=true; shift ;;
    *) shift ;;
  esac
done

# -----------------------------------------------------------------------------
# Initialize
# -----------------------------------------------------------------------------
init_registry

if [[ ! -f "$TASK_REGISTRY" ]]; then
  log_info "No task registry found. Nothing to monitor."
  exit 0
fi

# -----------------------------------------------------------------------------
# Helper: Check if tmux session is alive
# -----------------------------------------------------------------------------
check_tmux_alive() {
  local session="$1"
  tmux has-session -t "$session" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Helper: Get last activity from tmux (simple heuristic)
# -----------------------------------------------------------------------------
get_tmux_activity() {
  local session="$1"
  # Capture the last line of output from the session
  tmux capture-pane -t "$session" -p -S -1 2>/dev/null || echo ""
}

# -----------------------------------------------------------------------------
# Helper: Check for open PR on branch
# -----------------------------------------------------------------------------
check_pr_status() {
  local branch="$1"
  local worktree="$2"
  
  cd "$worktree" 2>/dev/null || return 1
  
  # Get PR number for this branch
  gh pr list --head "$branch" --json number,state,url,mergeable,statusCheckRollup 2>/dev/null | jq -r '.[0] // empty'
}

# -----------------------------------------------------------------------------
# Helper: Check CI status from PR data
# -----------------------------------------------------------------------------
parse_ci_status() {
  local pr_data="$1"
  
  if [[ -z "$pr_data" ]]; then
    echo "no_pr"
    return
  fi
  
  local status=$(echo "$pr_data" | jq -r '.statusCheckRollup // []')
  
  # Check for any failing checks
  local failing=$(echo "$status" | jq -r '[.[] | select(.conclusion == "failure")] | length')
  local pending=$(echo "$status" | jq -r '[.[] | select(.conclusion == null or .status == "in_progress")] | length')
  local passing=$(echo "$status" | jq -r '[.[] | select(.conclusion == "success")] | length')
  
  if [[ "$failing" -gt 0 ]]; then
    echo "failing"
  elif [[ "$pending" -gt 0 ]]; then
    echo "pending"
  elif [[ "$passing" -gt 0 ]]; then
    echo "passing"
  else
    echo "unknown"
  fi
}

# -----------------------------------------------------------------------------
# Helper: Send notification via OpenClaw
# -----------------------------------------------------------------------------
send_notification() {
  local task_id="$1"
  local message="$2"
  local priority="${3:-normal}"
  
  # Use OpenClaw's notification system
  # This can be called via OpenClaw's sessions_send or message tool
  # For now, we'll output in a format OpenClaw can parse
  echo "NOTIFY|$priority|$task_id|$message"
}

# -----------------------------------------------------------------------------
# Main monitoring loop
# -----------------------------------------------------------------------------
RESULTS=()
NOTIFICATIONS=()
TASKS=$(jq -c '.tasks[] | select(.status != "done" and .status != "cancelled")' "$TASK_REGISTRY" 2>/dev/null || echo "")

if [[ -z "$TASKS" ]]; then
  log_info "No active tasks to monitor."
  [[ "$OUTPUT_JSON" == "true" ]] && echo '{"status": "ok", "tasks": []}'
  exit 0
fi

while IFS= read -r task; do
  TASK_ID=$(echo "$task" | jq -r '.id')
  TMUX_SESSION=$(echo "$task" | jq -r '.tmuxSession')
  WORKTREE_PATH=$(echo "$task" | jq -r '.worktreePath')
  BRANCH=$(echo "$task" | jq -r '.branch')
  STATUS=$(echo "$task" | jq -r '.status')
  ATTEMPT=$(echo "$task" | jq -r '.attempt')
  MAX_ATTEMPTS=$(echo "$task" | jq -r '.maxAttempts')
  
  log_debug "Checking task: $TASK_ID (status: $STATUS, attempt: $ATTEMPT/$MAX_ATTEMPTS)"
  
  RESULT=$(jq -n \
    --arg id "$TASK_ID" \
    --arg status "$STATUS" \
    --argjson attempt "$ATTEMPT" \
    '{id: $id, status: $status, attempt: $attempt}')
  
  # Check tmux session
  if check_tmux_alive "$TMUX_SESSION"; then
    log_debug "  tmux session alive: $TMUX_SESSION"
    RESULT=$(echo "$RESULT" | jq '.tmuxAlive = true')
  else
    log_debug "  tmux session dead: $TMUX_SESSION"
    RESULT=$(echo "$RESULT" | jq '.tmuxAlive = false')
  fi
  
  # Check PR status
  PR_DATA=$(check_pr_status "$BRANCH" "$WORKTREE_PATH")
  if [[ -n "$PR_DATA" ]]; then
    PR_NUMBER=$(echo "$PR_DATA" | jq -r '.number // empty')
    PR_STATE=$(echo "$PR_DATA" | jq -r '.state // empty')
    CI_STATUS=$(parse_ci_status "$PR_DATA")
    
    RESULT=$(echo "$RESULT" | jq \
      --argjson prNumber "$PR_NUMBER" \
      --arg prState "$PR_STATE" \
      --arg ciStatus "$CI_STATUS" \
      '.checks.prNumber = $prNumber | .checks.prState = $prState | .checks.ciStatus = $ciStatus')
    
    # Update registry with PR info
    if [[ -n "$PR_NUMBER" ]]; then
      jq --arg id "$TASK_ID" --argjson prNum "$PR_NUMBER" \
        '(.tasks[] | select(.id == $id) | .checks.prCreated) = true |
         (.tasks[] | select(.id == $id) | .checks.prNumber) = $prNum' \
        "$TASK_REGISTRY" > "${TASK_REGISTRY}.tmp" && mv "${TASK_REGISTRY}.tmp" "$TASK_REGISTRY"
    fi
    
    # Check if CI passed
    if [[ "$CI_STATUS" == "passing" ]]; then
      jq --arg id "$TASK_ID" \
        '(.tasks[] | select(.id == $id) | .checks.ciPassed) = true' \
        "$TASK_REGISTRY" > "${TASK_REGISTRY}.tmp" && mv "${TASK_REGISTRY}.tmp" "$TASK_REGISTRY"
    fi
    
    # Check if ready for human review
    if [[ "$PR_STATE" == "OPEN" ]] && [[ "$CI_STATUS" == "passing" ]]; then
      RESULT=$(echo "$RESULT" | jq '.readyForReview = true')
      
      # Notify if this is new
      if [[ "$(echo "$task" | jq -r '.checks.ciPassed')" != "true" ]]; then
        NOTIFICATIONS+=("PR #$PR_NUMBER is ready for review ($TASK_ID)")
      fi
    fi
  fi
  
  # Handle dead sessions
  if [[ "$(echo "$RESULT" | jq -r '.tmuxAlive')" == "false" ]]; then
    # Check if we should respawn
    if [[ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]]; then
      log_info "Task $TASK_ID: tmux session dead, will respawn (attempt $((ATTEMPT + 1))/$MAX_ATTEMPTS)"
      # The respawn logic would be handled by OpenClaw orchestrator
      # We just flag it here
      RESULT=$(echo "$RESULT" | jq '.needsRespawn = true')
    else
      log_info "Task $TASK_ID: max attempts reached, marking as failed"
      jq --arg id "$TASK_ID" --arg status "failed" \
        '(.tasks[] | select(.id == $id) | .status) = $status' \
        "$TASK_REGISTRY" > "${TASK_REGISTRY}.tmp" && mv "${TASK_REGISTRY}.tmp" "$TASK_REGISTRY"
      NOTIFICATIONS+=("Task $TASK_ID failed after $MAX_ATTEMPTS attempts")
    fi
  fi
  
  RESULTS+=("$RESULT")
  
done <<< "$TASKS"

# -----------------------------------------------------------------------------
# Output results
# -----------------------------------------------------------------------------
if [[ "$OUTPUT_JSON" == "true" ]]; then
  echo "{}" | jq --argjson results "$(printf '%s\n' "${RESULTS[@]}" | jq -s '.')" \
    '. + {status: "ok", tasks: $results, checkedAt: (now | todate)}'
else
  log_info "Checked ${#RESULTS[@]} tasks"
  for r in "${RESULTS[@]}"; do
    echo "$r" | jq -r '"  \(.id): \(.status) (tmux: \(.tmuxAlive), ready: \(.readyForReview // false))"'
  done
fi

# -----------------------------------------------------------------------------
# Send notifications
# -----------------------------------------------------------------------------
if [[ "$NOTIFY" == "true" ]] && [[ ${#NOTIFICATIONS[@]} -gt 0 ]]; then
  for n in "${NOTIFICATIONS[@]}"; do
    send_notification "system" "$n" "high"
  done
fi

# Update stats
TOTAL_TASKS=$(jq '.tasks | length' "$TASK_REGISTRY")
RUNNING_TASKS=$(jq '[.tasks[] | select(.status == "running")] | length' "$TASK_REGISTRY")
jq --argjson total "$TOTAL_TASKS" --argjson running "$RUNNING_TASKS" \
  '.stats.totalTasks = $total | .stats.runningTasks = $running' \
  "$TASK_REGISTRY" > "${TASK_REGISTRY}.tmp" && mv "${TASK_REGISTRY}.tmp" "$TASK_REGISTRY"