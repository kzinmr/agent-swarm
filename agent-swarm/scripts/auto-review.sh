#!/bin/bash
# =============================================================================
# auto-review.sh - Run automated code reviews on a PR
# =============================================================================
# Uses multiple AI models to review code:
#   - OpenCode (Qwen): Edge cases, logic errors, missing error handling
#   - Gemini (if available): Security issues, scalability
#   - Claude Code (if available): Overall validation
#
# Usage: auto-review.sh <pr-number> [--models opencode,gemini,claude]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/swarm.config.sh"

# -----------------------------------------------------------------------------
# Arguments
# -----------------------------------------------------------------------------
PR_NUMBER="${1:-}"
MODELS="${2:-$REVIEW_MODELS}"

if [[ -z "$PR_NUMBER" ]]; then
  echo "Usage: $0 <pr-number> [--models opencode,gemini,claude]"
  echo ""
  echo "Examples:"
  echo "  $0 341"
  echo "  $0 341 --models opencode,claude"
  exit 1
fi

# Parse --models argument
if [[ "$2" == "--models" ]] && [[ -n "${3:-}" ]]; then
  MODELS="$3"
fi

IFS=',' read -ra MODEL_LIST <<< "$MODELS"

# -----------------------------------------------------------------------------
# Get PR info
# -----------------------------------------------------------------------------
PR_INFO=$(gh pr view "$PR_NUMBER" --json number,title,headRefName,baseRefName,files,additions,deletions,url 2>/dev/null || echo "")

if [[ -z "$PR_INFO" ]]; then
  echo "Error: Could not fetch PR #$PR_NUMBER"
  exit 1
fi

PR_TITLE=$(echo "$PR_INFO" | jq -r '.title')
PR_BRANCH=$(echo "$PR_INFO" | jq -r '.headRefName')
PR_URL=$(echo "$PR_INFO" | jq -r '.url')
PR_FILES=$(echo "$PR_INFO" | jq -r '.files[].path' | tr '\n' ' ')

echo "=============================================="
echo "Auto-Review: PR #$PR_NUMBER"
echo "=============================================="
echo "Title:   $PR_TITLE"
echo "Branch:  $PR_BRANCH"
echo "URL:     $PR_URL"
echo "Files:   $PR_FILES"
echo "Models:  ${MODEL_LIST[*]}"
echo "=============================================="
echo ""

# -----------------------------------------------------------------------------
# Review prompt template
# -----------------------------------------------------------------------------
REVIEW_PROMPT=$(cat <<'EOF'
You are a senior code reviewer. Review the following pull request and provide actionable feedback.

Focus on:
1. **Correctness**: Logic errors, race conditions, edge cases
2. **Security**: Potential vulnerabilities, data exposure
3. **Performance**: N+1 queries, memory leaks, inefficient algorithms
4. **Maintainability**: Code clarity, naming, documentation
5. **Testing**: Missing tests, edge case coverage

For each issue, provide:
- Severity: CRITICAL / HIGH / MEDIUM / LOW
- File and line reference
- Suggested fix

PR Title: {{PR_TITLE}}
PR Branch: {{PR_BRANCH}}
PR URL: {{PR_URL}}

Files changed:
{{PR_FILES}}

Please review and comment on the PR.
EOF
)

# -----------------------------------------------------------------------------
# Run reviews
# -----------------------------------------------------------------------------
RESULTS=()

for model in "${MODEL_LIST[@]}"; do
  echo ""
  echo "Running review with $model..."
  echo "----------------------------------------------"
  
  REVIEW_START=$(date +%s)
  
  case "$model" in
    opencode)
      # OpenCode with Qwen model
      REVIEW_CMD="opencode --model $REVIEW_MODEL_OPENCODE -p"
      
      # Create review prompt
      PROMPT="${REVIEW_PROMPT//\{\{PR_TITLE\}\}/$PR_TITLE}"
      PROMPT="${PROMPT//\{\{PR_BRANCH\}\}/$PR_BRANCH}"
      PROMPT="${PROMPT//\{\{PR_URL\}\}/$PR_URL}"
      PROMPT="${PROMPT//\{\{PR_FILES\}\}/$PR_FILES}"
      
      # Run review (this would typically run in a temp directory)
      echo "Would run: $REVIEW_CMD \"$PROMPT\""
      echo "(Actual implementation requires PR checkout)"
      
      # Simulated result
      REVIEW_RESULT='{"model": "opencode", "status": "pending", "issues": 0}'
      ;;
      
    gemini)
      # Gemini Code Assist (if available)
      if command -v gemini &> /dev/null; then
        echo "Running Gemini review..."
        # gemini review --pr "$PR_NUMBER"
        REVIEW_RESULT='{"model": "gemini", "status": "pending", "issues": 0}'
      else
        echo "Gemini CLI not available, skipping..."
        REVIEW_RESULT='{"model": "gemini", "status": "skipped", "issues": 0}'
      fi
      ;;
      
    claude)
      # Claude Code (if available)
      if command -v claude &> /dev/null; then
        echo "Running Claude Code review..."
        # claude --model $REVIEW_MODEL_CLAUDE "Review PR #$PR_NUMBER"
        REVIEW_RESULT='{"model": "claude", "status": "pending", "issues": 0}'
      else
        echo "Claude Code not available, skipping..."
        REVIEW_RESULT='{"model": "claude", "status": "skipped", "issues": 0}'
      fi
      ;;
      
    *)
      echo "Unknown model: $model, skipping..."
      REVIEW_RESULT='{"model": "'"$model"'", "status": "unknown", "issues": 0}'
      ;;
  esac
  
  REVIEW_END=$(date +%s)
  REVIEW_DURATION=$((REVIEW_END - REVIEW_START))
  
  echo "Duration: ${REVIEW_DURATION}s"
  
  RESULTS+=("$REVIEW_RESULT")
done

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "Review Summary"
echo "=============================================="

for r in "${RESULTS[@]}"; do
  MODEL=$(echo "$r" | jq -r '.model')
  STATUS=$(echo "$r" | jq -r '.status')
  ISSUES=$(echo "$r" | jq -r '.issues')
  
  case "$STATUS" in
    passed) echo "  ✅ $MODEL: Passed ($ISSUES issues resolved)" ;;
    pending) echo "  ⏳ $MODEL: Pending review" ;;
    failed) echo "  ❌ $MODEL: Found issues ($ISSUES)" ;;
    skipped) echo "  ⏭️  $MODEL: Skipped" ;;
    *) echo "  ❓ $MODEL: Unknown status" ;;
  esac
done

echo "=============================================="

# -----------------------------------------------------------------------------
# Update task registry
# -----------------------------------------------------------------------------
TASK_ID=$(jq -r --argjson pr "$PR_NUMBER" '.tasks[] | select(.checks.prNumber == $pr) | .id' "$TASK_REGISTRY" 2>/dev/null || echo "")

if [[ -n "$TASK_ID" ]]; then
  for r in "${RESULTS[@]}"; do
    MODEL=$(echo "$r" | jq -r '.model')
    STATUS=$(echo "$r" | jq -r '.status')
    
    jq --arg id "$TASK_ID" --arg model "$MODEL" --arg status "$STATUS" \
      '(.tasks[] | select(.id == $id) | .checks.reviews[$model]) = $status' \
      "$TASK_REGISTRY" > "${TASK_REGISTRY}.tmp" && mv "${TASK_REGISTRY}.tmp" "$TASK_REGISTRY"
  done
  
  log_info "Updated task registry with review results"
fi