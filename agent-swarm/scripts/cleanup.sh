#!/bin/bash
# =============================================================================
# cleanup.sh - Clean up completed tasks and orphaned worktrees
# =============================================================================
# Usage: cleanup.sh [--age-days N] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/swarm.config.sh"

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------
AGE_DAYS="${GIT_CLEANUP_AGE_DAYS:-1}"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --age-days) AGE_DAYS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

# -----------------------------------------------------------------------------
# Initialize
# -----------------------------------------------------------------------------
init_registry

echo "=============================================="
echo "Agent Swarm Cleanup"
echo "=============================================="
echo "Age threshold: $AGE_DAYS days"
echo "Dry run: $DRY_RUN"
echo "=============================================="
echo ""

# -----------------------------------------------------------------------------
# Clean up completed tasks
# -----------------------------------------------------------------------------
COMPLETED_TASKS=$(jq -c --argjson ageDays "$AGE_DAYS" '
  .tasks[] | select(
    (.status == "done" or .status == "cancelled" or .status == "failed") and
    ((.completedAt // .startedAt) < ((now - ($ageDays * 86400 * 1000)) * 1000000))
  )
' "$TASK_REGISTRY" 2>/dev/null || echo "")

CLEANED_COUNT=0

if [[ -n "$COMPLETED_TASKS" ]]; then
  echo "Cleaning up completed tasks..."
  
  while IFS= read -r task; do
    TASK_ID=$(echo "$task" | jq -r '.id')
    WORKTREE=$(echo "$task" | jq -r '.worktreePath')
    BRANCH=$(echo "$task" | jq -r '.branch')
    TMUX_SESSION=$(echo "$task" | jq -r '.tmuxSession')
    
    echo "  Task: $TASK_ID"
    
    # Kill tmux session if still running
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
      echo "    - Killing tmux session: $TMUX_SESSION"
      [[ "$DRY_RUN" == "false" ]] && tmux kill-session -t "$TMUX_SESSION"
    fi
    
    # Remove worktree
    if [[ -d "$WORKTREE" ]]; then
      echo "    - Removing worktree: $WORKTREE"
      if [[ "$DRY_RUN" == "false" ]]; then
        rm -rf "$WORKTREE"
        # Also remove from git worktree list
        git worktree remove "$WORKTREE" --force 2>/dev/null || true
      fi
    fi
    
    # Delete branch (optional)
    if [[ "$GIT_AUTO_CLEANUP" == "true" ]]; then
      echo "    - Deleting branch: $BRANCH"
      if [[ "$DRY_RUN" == "false" ]]; then
        git branch -D "$BRANCH" 2>/dev/null || true
        git push origin --delete "$BRANCH" 2>/dev/null || true
      fi
    fi
    
    # Remove from registry
    if [[ "$DRY_RUN" == "false" ]]; then
      jq --arg id "$TASK_ID" 'del(.tasks[] | select(.id == $id))' \
        "$TASK_REGISTRY" > "${TASK_REGISTRY}.tmp" && mv "${TASK_REGISTRY}.tmp" "$TASK_REGISTRY"
    fi
    
    CLEANED_COUNT=$((CLEANED_COUNT + 1))
    echo ""
  done <<< "$COMPLETED_TASKS"
fi

# -----------------------------------------------------------------------------
# Clean up orphaned worktrees
# -----------------------------------------------------------------------------
echo "Checking for orphaned worktrees..."

if [[ -d "$WORKTREES_DIR" ]]; then
  for worktree in "$WORKTREES_DIR"/*; do
    [[ -d "$worktree" ]] || continue
    
    WORKTREE_NAME=$(basename "$worktree")
    
    # Check if this worktree is tracked
    TRACKED=$(jq -r --arg wt "$WORKTREE_NAME" '.tasks[] | select(.worktree == $wt) | .id' "$TASK_REGISTRY" 2>/dev/null || echo "")
    
    if [[ -z "$TRACKED" ]]; then
      # Check age
      WORKTREE_AGE=$(( ($(date +%s) - $(stat -f %m "$worktree" 2>/dev/null || stat -c %Y "$worktree" 2>/dev/null || echo 0)) / 86400 ))
      
      if [[ "$WORKTREE_AGE" -ge "$AGE_DAYS" ]]; then
        echo "  Orphaned worktree: $worktree (age: ${WORKTREE_AGE}d)"
        if [[ "$DRY_RUN" == "false" ]]; then
          rm -rf "$worktree"
          git worktree remove "$worktree" --force 2>/dev/null || true
        fi
        CLEANED_COUNT=$((CLEANED_COUNT + 1))
      fi
    fi
  done
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "Cleanup complete"
echo "=============================================="
echo "Items cleaned: $CLEANED_COUNT"
[[ "$DRY_RUN" == "true" ]] && echo "(Dry run - no changes made)"
echo ""

# Update stats
jq '.stats.lastCleanup = (now | todate)' \
  "$TASK_REGISTRY" > "${TASK_REGISTRY}.tmp" && mv "${TASK_REGISTRY}.tmp" "$TASK_REGISTRY"