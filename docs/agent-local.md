# Local Agent Setup

This guide covers setting up an agent identity for local development work.

## Prerequisites

- [mise](https://mise.jdx.dev/) installed
- Agent credentials already provisioned in SOPS
- Encrypted vault and age key configured through Secrets 0.3 or newer

Persona activation and local GPG setup read SOPS. Activation does not provision
credentials, set up a mailbox, or fall back to another provider.

## One-Time Setup

These steps only need to be done once per machine.

### 1. GPG Key

Import the agent's GPG signing key into the current user's keyring:

```bash
mise run gpg:setup <agent>
```

The command reads `<agent>/git/signing-fingerprint` and, if needed,
`<agent>/gpg-private-key` from SOPS. It verifies the fingerprint before
importing the key and setting owner trust. It does not write Git configuration
or remove old workspace configs/includes. CI may supply `GPG_FINGERPRINT` and
`GPG_PRIVATE_KEY` instead.

Activate the persona to select its Git identity and signer:

```bash
eval "$(shimmer as <agent>)"
shimmer gpg:status
```

Status checks the effective Git fingerprint, OpenPGP format, commit/tag signing,
and the corresponding usable secret key. It does not import or unlock keys.

### 2. Email

Configure Himalaya for agent email. Read passwords from stdin so secret values do not print:

```bash
secrets get <agent>/email-password |
  emails account:setup <agent> \
    --address <agent>@ricon.family \
    --display-name <agent> \
    --imap-host mail.ricon.family \
    --imap-port 993 \
    --smtp-host mail.ricon.family \
    --smtp-port 465 \
    --password-stdin \
    --set-default \
    --gpg-local-user <agent>@ricon.family
```

This:
- Creates the selected Himalaya config, by default `~/.config/emails/himalaya.toml`
- Configures IMAP/SMTP for `<agent>@ricon.family`
- Enables GPG signing for emails

### 3. Blob Storage

Blob storage has moved to a standalone tool: [`blobs`](https://github.com/KnickKnackLabs/blobs). Install via `shiv install blobs` and configure with B2 credentials in the environment (see that repo's README).

## Working on Repositories

Clone repositories into the selected desk, separate from installed tool packages:

```bash
gh repo clone KnickKnackLabs/shimmer
cd shimmer
```

Make branches and edits in this working copy, not in the installed package.
Git identity comes from persona activation, regardless of the desk's path.

## Per-Session Setup

Each terminal session needs the agent's identity configured:

```bash
eval "$(mise run as <agent>)"
cd "$AGENT_HOME"
```

`shimmer agent` must be launched from this exact home Git root. It verifies
that the physical launch directory and `AGENT_HOME` agree before asking
Sessions for one-run project trust. Existing sessions are accepted only when
their stored working directory resolves to the same home.

This sets:
- `GH_TOKEN` - GitHub personal access token
- `GIT_AUTHOR_NAME` / `GIT_COMMITTER_NAME` - Agent name
- `GIT_AUTHOR_EMAIL` / `GIT_COMMITTER_EMAIL` - Agent email
- Process-scoped Git configuration - Persona name, email, exact signing
  fingerprint, OpenPGP format, and commit/tag signing flags

### Verifying Identity

Check that everything is configured correctly:

```bash
mise run whoami
```

Expected output:
```
Git identity:
  Author:    <agent> <<agent>@ricon.family>
  Committer: <agent> <<agent>@ricon.family>

GitHub identity:
  Logged in as: <agent>-ricon
```

## Quick Reference

| Task | Frequency | Command |
|------|-----------|---------|
| Import GPG key | Once per machine | `mise run gpg:setup <agent>` |
| Setup email | Once per machine | `secrets get <agent>/email-password | emails account:setup <agent> ... --password-stdin` |
| Set identity | Each session | `eval "$(mise run as <agent>)"` |
| Verify setup | As needed | `mise run whoami` |

## Troubleshooting

### GPG signing fails

Check the active signer first:

```bash
shimmer gpg:status
```

If its key is missing, run `shimmer gpg:setup <agent>`, then activate the persona
again. Do not delete existing keys as a troubleshooting shortcut.

### Wrong signing key used

`shimmer as` reads the persona's Git identity and exact signing fingerprint from
SOPS, verifies the secret signer, and applies process-scoped Git overrides.
Neither the desk path nor workspace `.gitconfig` files select the persona.
A dedicated OS account may keep matching global defaults for Git use outside
activation; those defaults do not override an activated persona.

Verify the active shell:

```bash
shimmer whoami
git config user.signingkey
```

If the signing key is still wrong, check for missing agent GPG setup:

```bash
shimmer gpg:status
```

Outside activation, repository settings and old conditional includes may still
affect Git. Inspect them before making a separate configuration change.

### Email not working

Verify himalaya can connect:
```bash
himalaya envelope list
```

Check the config file:
```bash
cat ~/.config/himalaya/config.toml
```

### 1Password not signed in

```bash
op signin
```

Then retry the setup command.
