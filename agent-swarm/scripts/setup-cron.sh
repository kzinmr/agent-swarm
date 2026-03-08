#!/bin/bash
# =============================================================================
# setup-cron.sh - Set up cron jobs for agent monitoring
# =============================================================================
# Usage: setup-cron.sh [--install] [--uninstall] [--show]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/swarm.config.sh"

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------
ACTION="show"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install) ACTION="install"; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --show) ACTION="show"; shift ;;
    *) shift ;;
  esac
done

# -----------------------------------------------------------------------------
# Cron entries
# -----------------------------------------------------------------------------
MONITOR_SCRIPT="$SCRIPT_DIR/monitor-agents.sh"
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup.sh"

# Cron schedule expressions
MONITOR_CRON="*/10 * * * *"   # Every 10 minutes
CLEANUP_CRON="0 2 * * *"      # Daily at 2 AM

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
get_current_cron() {
  crontab -l 2>/dev/null || echo ""
}

add_cron_entry() {
  local entry="$1"
  local current
  current=$(get_current_cron)
  
  if echo "$current" | grep -qF "$entry"; then
    echo "Cron entry already exists:"
    echo "  $entry"
    return 0
  fi
  
  echo "Adding cron entry:"
  echo "  $entry"
  
  (echo "$current"; echo "$entry") | crontab -
}

remove_cron_entry() {
  local marker="$1"
  local current
  current=$(get_current_cron)
  
  if ! echo "$current" | grep -qF "$marker"; then
    echo "Cron entry not found for: $marker"
    return 0
  fi
  
  echo "Removing cron entry containing: $marker"
  echo "$current" | grep -vF "$marker" | crontab -
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
case "$ACTION" in
  install)
    echo "=============================================="
    echo "Installing Agent Swarm cron jobs"
    echo "=============================================="
    echo ""
    
    # Make scripts executable
    chmod +x "$MONITOR_SCRIPT" "$CLEANUP_SCRIPT"
    
    # Add monitor cron (every 10 minutes)
    MONITOR_ENTRY="$MONITOR_CRON $MONITOR_SCRIPT --json >> $LOGS_DIR/monitor.log 2>&1 # agent-swarm-monitor"
    add_cron_entry "$MONITOR_ENTRY"
    
    # Add cleanup cron (daily at 2 AM)
    CLEANUP_ENTRY="$CLEANUP_CRON $CLEANUP_SCRIPT >> $LOGS_DIR/cleanup.log 2>&1 # agent-swarm-cleanup"
    add_cron_entry "$CLEANUP_ENTRY"
    
    # Ensure log directory exists
    mkdir -p "$LOGS_DIR"
    
    echo ""
    echo "Cron jobs installed successfully!"
    echo ""
    echo "Monitor schedule: Every 10 minutes"
    echo "Cleanup schedule: Daily at 2:00 AM"
    echo ""
    echo "Logs: $LOGS_DIR/"
    ;;
    
  uninstall)
    echo "=============================================="
    echo "Removing Agent Swarm cron jobs"
    echo "=============================================="
    echo ""
    
    remove_cron_entry "agent-swarm-monitor"
    remove_cron_entry "agent-swarm-cleanup"
    
    echo ""
    echo "Cron jobs removed."
    ;;
    
  show)
    echo "=============================================="
    echo "Current Agent Swarm cron jobs"
    echo "=============================================="
    echo ""
    
    current=$(get_current_cron)
    
    if echo "$current" | grep -qF "agent-swarm"; then
      echo "$current" | grep -F "agent-swarm"
    else
      echo "No agent-swarm cron jobs installed."
    fi
    
    echo ""
    echo "To install: $0 --install"
    echo "To uninstall: $0 --uninstall"
    ;;
    
  *)
    echo "Usage: $0 [--install] [--uninstall] [--show]"
    exit 1
    ;;
esac