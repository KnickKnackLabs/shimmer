#!/bin/bash
# Setup himalaya email configuration for an agent
#
# Usage: EMAIL_PASSWORD=xxx ./scripts/setup-email.sh <agent-name>
# Example: EMAIL_PASSWORD=$QUICK_EMAIL_PASSWORD ./scripts/setup-email.sh quick
#
# Creates ~/.config/himalaya/config.toml with the agent's email configuration.
# GPG signing is enabled - run setup-gpg.sh first to import the agent's key.

set -e

AGENT_NAME="${1:?Usage: setup-email.sh <agent-name>}"

# Get password from environment or 1Password
if [ -z "$EMAIL_PASSWORD" ]; then
  if command -v op &> /dev/null && op account get &> /dev/null; then
    EMAIL_PASSWORD=$(op item get "${AGENT_NAME} - Email" --vault Agents --fields password --reveal 2>/dev/null)
  fi
fi

if [ -z "$EMAIL_PASSWORD" ]; then
  echo "ERROR: EMAIL_PASSWORD not set and could not fetch from 1Password"
  echo "Usage: EMAIL_PASSWORD=xxx ./scripts/setup-email.sh <agent-name>"
  exit 1
fi

DOMAIN="ricon.family"
MAIL_SERVER="mail.ricon.family"
EMAIL="${AGENT_NAME}@${DOMAIN}"

CONFIG_DIR="${HOME}/.config/himalaya"
CONFIG_FILE="${CONFIG_DIR}/config.toml"

mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" << EOF
[accounts.${AGENT_NAME}]
default = true
email = "${EMAIL}"
display-name = "${AGENT_NAME}"

backend.type = "imap"
backend.host = "${MAIL_SERVER}"
backend.port = 993
backend.encryption.type = "tls"
backend.login = "${EMAIL}"
backend.auth.type = "password"
backend.auth.raw = "${EMAIL_PASSWORD}"

message.send.backend.type = "smtp"
message.send.backend.host = "${MAIL_SERVER}"
message.send.backend.port = 465
message.send.backend.encryption.type = "tls"
message.send.backend.login = "${EMAIL}"
message.send.backend.auth.type = "password"
message.send.backend.auth.raw = "${EMAIL_PASSWORD}"

pgp.type = "commands"
pgp.sign.cmd = "gpg --sign --quiet --armor"
pgp.decrypt.cmd = "gpg --decrypt --quiet"
pgp.verify.cmd = "gpg --verify --quiet"
EOF

echo "Email configured for ${EMAIL} (GPG signing enabled)"
echo "Config written to ${CONFIG_FILE}"
