#!/bin/bash
# =============================================================================
# Discord Notification Helper
# =============================================================================
# This script sends notifications to Discord from swarm scripts.
# Usage: ./notify.sh <type> <task-id> [additional-json]

DISCORD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NODE_MODULES="$DISCORD_DIR/node_modules"
TSX="$NODE_MODULES/.bin/tsx"

if [[ ! -x "$TSX" ]]; then
  echo "Error: tsx not found. Run 'pnpm install' in discord/" >&2
  exit 1
fi

NOTIFY_TYPE="$1"
TASK_ID="$2"
EXTRA_JSON="${3:-{}}"

if [[ -z "$NOTIFY_TYPE" ]] || [[ -z "$TASK_ID" ]]; then
  echo "Usage: $0 <type> <task-id> [json]" >&2
  echo "Types: spawned, pr-created, ci-passed, ci-failed, completed, failed, review" >&2
  exit 1
fi

# Run the notification script
"$TSX" "$DISCORD_DIR/src/cli-notify.ts" "$NOTIFY_TYPE" "$TASK_ID" "$EXTRA_JSON"