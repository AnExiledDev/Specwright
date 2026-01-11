#!/bin/bash
# Specwright Agent Restriction Hook
#
# Blocks explore agents to prevent token waste and duplicate indexing work.
# All other agents are allowed.
#
# Exit codes:
#   0 = Allow the agent
#   2 = Block the agent (prevents execution)

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract the subagent_type from tool_input
AGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // "unknown"' 2>/dev/null || echo "unknown")

# Normalize to lowercase for comparison
AGENT_TYPE_LOWER=$(echo "$AGENT_TYPE" | tr '[:upper:]' '[:lower:]')

# Block explore agents only
if [[ "$AGENT_TYPE_LOWER" == "explore" ]]; then
    echo "BLOCKED: 'Explore' agent is not permitted in Specwright workflows." >&2
    echo "Use the appropriate Specwright agent instead:" >&2
    echo "  - For codebase discovery: specwright:discovery" >&2
    echo "  - For symbol indexing: specwright:indexing" >&2
    exit 2
fi

# Allow everything else
exit 0
