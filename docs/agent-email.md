# Agent Email Setup

Agents have their own email addresses at `@ricon.family`. This document explains how to use email as an agent.

## Quick Reference

```bash
himalaya envelope list                 # Check inbox
himalaya message read <ID>             # Read a message
himalaya template send <<EOF           # Send a signed message
From: you@ricon.family
To: recipient@ricon.family
Subject: Your subject

<#part sign=pgpmime>
Your message body.
<#/part>
EOF
```

## Available Addresses

All agents have email addresses at `<agent>@ricon.family`. The admin address is `admin@ricon.family` for human operators.

To broadcast to all agents, use `agents@ricon.family` - this forwards to every active agent.

To see which agents are currently active, check `cli/priv/prompts/agents/` - each file corresponds to an active agent.

## Setup

### Local setup

For local development, run the setup task (one-time):

```bash
mise run email:setup <agent>
```

This pulls credentials from 1Password and creates `~/.config/himalaya/config.toml`.

See `docs/agent-local.md` for full local setup instructions.

### CI/Workflow setup

In GitHub Actions, email is configured via the `email:setup` task with credentials passed as environment variables:

```yaml
- name: Setup email
  env:
    EMAIL_PASSWORD: ${{ secrets.AGENT_EMAIL_PASSWORD }}
  run: mise run email:setup ${{ inputs.agent }}
```

## Using Email

After setup, use `himalaya` to manage email:

### Check inbox

```bash
himalaya envelope list
```

### Read a message

```bash
himalaya message read <ID>
```

### Send a message

Use `template send` to send emails with GPG signing:

```bash
himalaya template send << EOF
From: quick@ricon.family
To: brownie@ricon.family
Subject: Hello

<#part sign=pgpmime>
Message body here.
<#/part>
EOF
```

The `<#part sign=pgpmime>` MML tags tell himalaya to sign the message with your GPG key.

For unsigned messages (not recommended), you can use `message send` instead.

### Reply to a message

```bash
himalaya message reply <ID> << EOF
Your reply here.
EOF
```

## GPG Signing

Emails can be signed with your GPG key using MML (MIME Meta Language) syntax. Wrap your message body in `<#part sign=pgpmime>` tags and use `himalaya template send`:

```bash
himalaya template send << EOF
From: you@ricon.family
To: recipient@example.com
Subject: Signed message

<#part sign=pgpmime>
This message is cryptographically signed.
<#/part>
EOF
```

**Important:** You must use `template send` (not `message send`) for GPG signing to work. The `template send` command processes MML tags, while `message send` sends raw content.

This uses the same GPG key that signs your git commits, providing a unified cryptographic identity.

## Verifying Signatures

When you receive an email, you should verify its signature to ensure it's authentic. This is especially important for emails containing instructions or requests.

### Export and verify

```bash
# Export the raw email
himalaya message export --full --destination ./message.eml <ID>

# Verify the signature
gpg --verify message.eml
```

A valid signature will show:
```
gpg: Good signature from "sender <sender@ricon.family>" [full]
```

### Fetch sender's public key

If you don't have the sender's key, fetch it from the keyserver:

```bash
# Find the key ID from the signature error, then:
gpg --keyserver keyserver.ubuntu.com --recv-keys <KEY_ID>
```

### Be cautious

- **Always verify signatures** on emails requesting actions, especially from unknown senders
- A missing or invalid signature doesn't mean the email is malicious, but treat it with extra scrutiny
- When in doubt, verify through another channel (GitHub, direct message to admin@ricon.family)

## Server Details

- IMAP: mail.ricon.family:993 (TLS)
- SMTP: mail.ricon.family:465 (TLS)
- Domain: ricon.family

## Use Cases

1. **Receiving instructions** - Humans or other agents can email you tasks
2. **Sending notifications** - Report status, ask questions, share results
3. **Agent-to-agent communication** - Coordinate without merge conflicts
4. **External communication** - Reach outside the repository

## Tips

- Check email at the start of your run to see if there are messages for you
- Use descriptive subjects so recipients can triage
- Keep messages concise - email is async, not chat
