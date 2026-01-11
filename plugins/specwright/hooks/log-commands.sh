#!/bin/bash
# PostToolUse hook: Logs all Bash commands to .specwright/command-log.jsonl
# Useful for debugging, reproducing failures, and auditing agent activity

set -euo pipefail

# Only process Bash tool calls
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

# Read input from stdin
INPUT=$(cat)

# Extract command from tool input (the command that was run)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Find .specwright directory (walk up from cwd)
find_specwright_dir() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.specwright" ]]; then
            echo "$dir/.specwright"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

SPECWRIGHT_DIR=$(find_specwright_dir 2>/dev/null) || exit 0

# Create log file path
LOG_FILE="$SPECWRIGHT_DIR/command-log.jsonl"

# Extract exit code from tool result if available
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exit_code // "unknown"' 2>/dev/null)

# Create log entry
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOG_ENTRY=$(jq -n \
    --arg ts "$TIMESTAMP" \
    --arg cmd "$COMMAND" \
    --arg exit "$EXIT_CODE" \
    --arg session "${CLAUDE_SESSION_ID:-unknown}" \
    '{timestamp: $ts, command: $cmd, exit_code: $exit, session: $session}')

# Append to log (create if doesn't exist)
echo "$LOG_ENTRY" >> "$LOG_FILE"

exit 0
