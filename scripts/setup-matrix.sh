#!/bin/bash
# Setup matrix-commander configuration for an agent
#
# Usage: MATRIX_PASSWORD=xxx ./scripts/setup-matrix.sh <agent-name>
# Example: MATRIX_PASSWORD=$QUICK_MATRIX_PASSWORD ./scripts/setup-matrix.sh quick
#
# Logs in with matrix-commander to create credentials.json

set -e

AGENT_NAME="${1:?Usage: setup-matrix.sh <agent-name>}"

# Get password from environment or 1Password
if [ -z "$MATRIX_PASSWORD" ]; then
  if command -v op &> /dev/null && op account get &> /dev/null; then
    MATRIX_PASSWORD=$(op item get "${AGENT_NAME} - Matrix" --vault Agents --fields password --reveal 2>/dev/null)
  fi
fi

if [ -z "$MATRIX_PASSWORD" ]; then
  echo "ERROR: MATRIX_PASSWORD not set and could not fetch from 1Password"
  echo "Usage: MATRIX_PASSWORD=xxx ./scripts/setup-matrix.sh <agent-name>"
  exit 1
fi

DOMAIN="ricon.family"
HOMESERVER="https://matrix.ricon.family"

# Default room for agents (Welcome room)
DEFAULT_ROOM="!QpXvgUwQAdmpoOwrEe:ricon.family"

# Login with matrix-commander (creates credentials.json automatically)
matrix-commander --login password \
  --homeserver "$HOMESERVER" \
  --user-login "$AGENT_NAME" \
  --password "$MATRIX_PASSWORD" \
  --device "SHIMMER_CI" \
  --room-default "$DEFAULT_ROOM"

echo "Matrix configured for @${AGENT_NAME}:${DOMAIN}"
