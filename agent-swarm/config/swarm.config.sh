#!/bin/bash
# =============================================================================
# Agent Swarm Configuration
 =============================================================================
# This config should work on any environment with OpenClaw, OpenCode, and
# Alibaba Cloud Model Studio (or other LLM providers) set up.

# -----------------------------------------------------------------------------
# Directory Paths
# -----------------------------------------------------------------------------
SWARM_ROOT="${SWARM_ROOT:-$HOME/.agent-swarm}"
TASK_REGISTRY="${SWARM_ROOT}/active-tasks.json"
WORKTREES_DIR="${WORKTREES_DIR:-$HOME/worktrees}"
LOGS_DIR="${SWARM_ROOT}/logs"

# -----------------------------------------------------------------------------
# Agent Types
# -----------------------------------------------------------------------------
# opencode: Uses OpenCode CLI with Qwen/other models
# codex: Uses OpenAI Codex (if available)
# claude: Uses Claude Code CLI (if available)
AGENT_TYPES=("opencode" "codex" "claude")

# -----------------------------------------------------------------------------
# Model Configuration (Alibaba Cloud Model Studio / Qwen)
# -----------------------------------------------------------------------------
# OpenCode supports multiple providers. Configure your default models here.
OPENCODE_DEFAULT_MODEL="${OPENCODE_DEFAULT_MODEL:-qwen-coder-plus}"
OPENCODE_REASONING_MODEL="${OPENCODE_REASONING_MODEL:-qwen-coder-plus}"

# For high-complexity tasks
OPENCODE_HIGH_EFFORT_MODEL="${OPENCODE_HIGH_EFFORT_MODEL:-qwen-coder-max}"

# Review models
REVIEW_MODEL_OPENCODE="${REVIEW_MODEL_OPENCODE:-qwen-coder-plus}"
REVIEW_MODEL_GEMINI="${REVIEW_MODEL_GEMINI:-gemini-2.0-flash}"  # If available
REVIEW_MODEL_CLAUDE="${REVIEW_MODEL_CLAUDE:-claude-sonnet-4}"   # If available

# -----------------------------------------------------------------------------
# tmux Configuration
# -----------------------------------------------------------------------------
TMUX_PREFIX="${TMUX_PREFIX:-agent}"
TMUX_SHELL="${TMUX_SHELL:-/bin/zsh}"

# -----------------------------------------------------------------------------
# Monitoring Configuration
# -----------------------------------------------------------------------------
CHECK_INTERVAL_SECONDS="${CHECK_INTERVAL_SECONDS:-600}"  # 10 minutes
MAX_RETRY_ATTEMPTS="${MAX_RETRY_ATTEMPTS:-3}"
CI_TIMEOUT_MINUTES="${CI_TIMEOUT_MINUTES:-30}"

# -----------------------------------------------------------------------------
# Notification Configuration
# -----------------------------------------------------------------------------
# OpenClaw handles notifications via sessions_send or message tool
# Configure your notification preferences here
NOTIFY_ON_PR_READY="${NOTIFY_ON_PR_READY:-true}"
NOTIFY_ON_FAILURE="${NOTIFY_ON_FAILURE:-true}"
NOTIFY_CHANNEL="${NOTIFY_CHANNEL:-}"  # telegram/discord/signal/etc.

# -----------------------------------------------------------------------------
# Git Configuration
# -----------------------------------------------------------------------------
GIT_DEFAULT_BRANCH="${GIT_DEFAULT_BRANCH:-main}"
GIT_AUTO_CLEANUP="${GIT_AUTO_CLEANUP:-true}"
GIT_CLEANUP_AGE_DAYS="${GIT_CLEANUP_AGE_DAYS:-1}"

# -----------------------------------------------------------------------------
# Review Configuration
# -----------------------------------------------------------------------------
ENABLE_AUTO_REVIEW="${ENABLE_AUTO_REVIEW:-true}"
REVIEW_MODELS="${REVIEW_MODELS:-opencode,gemini,claude}"  # Comma-separated
REQUIRE_ALL_REVIEWS_PASS="${REQUIRE_ALL_REVIEWS_PASS:-false}"
REQUIRE_SCREENSHOT_FOR_UI="${REQUIRE_SCREENSHOT_FOR_UI:-true}"

# -----------------------------------------------------------------------------
# CI Configuration
# -----------------------------------------------------------------------------
CI_COMMANDS="${CI_COMMANDS:-lint,typecheck,test,e2e}"
CI_LINT_CMD="${CI_LINT_CMD:-pnpm lint}"
CI_TYPECHECK_CMD="${CI_TYPECHECK_CMD:-pnpm typecheck}"
CI_TEST_CMD="${CI_TEST_CMD:-pnpm test}"
CI_E2E_CMD="${CI_E2E_CMD:-pnpm e2e}"

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
log_info() {
  echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
  echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1" >&2
}

log_debug() {
  if [[ "${DEBUG:-false}" == "true" ]]; then
    echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $1"
  fi
}

ensure_dirs() {
  mkdir -p "$SWARM_ROOT" "$WORKTREES_DIR" "$LOGS_DIR"
}

# Initialize task registry if it doesn't exist
init_registry() {
  ensure_dirs
  if [[ ! -f "$TASK_REGISTRY" ]]; then
    echo '{"tasks": [], "lastUpdated": "'$(date -Iseconds)'"}' > "$TASK_REGISTRY"
    log_info "Initialized task registry at $TASK_REGISTRY"
  fi
}