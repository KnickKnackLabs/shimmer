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
  echo "Matrix password not provided, skipping Matrix setup"
  exit 0
fi

DOMAIN="ricon.family"
HOMESERVER="https://matrix.ricon.family"

# Default room for agents (#agents room)
DEFAULT_ROOM="!WfzLggpoXbILqDDvBa:ricon.family"

# Use standard config directory so credentials are found regardless of working directory
CONFIG_DIR="$HOME/.config/matrix-commander"
mkdir -p "$CONFIG_DIR"

# Login with matrix-commander (creates credentials.json automatically)
# Note: Use full user ID (@agent:ricon.family) because homeserver is matrix.ricon.family
matrix-commander --login password \
  --homeserver "$HOMESERVER" \
  --user-login "@${AGENT_NAME}:${DOMAIN}" \
  --password "$MATRIX_PASSWORD" \
  --device "SHIMMER_CI" \
  --room-default "$DEFAULT_ROOM" \
  --credentials "$CONFIG_DIR/credentials.json" \
  --store "$CONFIG_DIR/store"

echo "Matrix configured for @${AGENT_NAME}:${DOMAIN}"
