# Local Agent Setup

This guide covers setting up an agent identity for local development work.

## Prerequisites

- [mise](https://mise.jdx.dev/) installed
- [1Password CLI](https://developer.1password.com/docs/cli/) installed and signed in (`op signin`)
- Agent credentials stored in 1Password (done during agent provisioning)

## One-Time Setup

These steps only need to be done once per machine.

### 1. GPG Key

Import the agent's GPG key and configure git signing:

```bash
mise run gpg:setup <agent>
```

This:
- Imports the GPG private key from 1Password
- Configures git to sign commits with this key
- Trusts the key locally

### 2. Email

Configure himalaya for agent email:

```bash
mise run email:setup <agent>
```

This:
- Creates `~/.config/himalaya/config.toml`
- Configures IMAP/SMTP for `<agent>@ricon.family`
- Enables GPG signing for emails

## Working on Repositories

When working on any repository (including shimmer itself), clone it to your workspace:

```bash
cd ~/agents/<agent>/
git clone https://github.com/KnickKnackLabs/shimmer.git
cd shimmer
```

This separation is important:

- **`~/shimmer`** - The "installed" shimmer. Stays on main, provides the `shimmer` commands. Don't edit directly.
- **`~/agents/<agent>/shimmer`** - Your working copy. Clone here, make branches, edit files, push PRs.

The `shimmer` command works from anywhere. It runs tasks from `~/shimmer` but operates on your current directory. So running `shimmer issue:list` from your working copy shows issues for that repo.

This allows multiple agents to work on the same repository simultaneously without conflicts.

## Per-Session Setup

Each terminal session needs the agent's identity configured:

```bash
eval $(mise run as <agent>)
```

This sets:
- `GH_TOKEN` - GitHub personal access token
- `GIT_AUTHOR_NAME` / `GIT_COMMITTER_NAME` - Agent name
- `GIT_AUTHOR_EMAIL` / `GIT_COMMITTER_EMAIL` - Agent email

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
| Setup email | Once per machine | `mise run email:setup <agent>` |
| Set identity | Each session | `eval $(mise run as <agent>)` |
| Verify setup | As needed | `mise run whoami` |

## Troubleshooting

### GPG signing fails

Check that the key is imported and trusted:
```bash
gpg --list-secret-keys <agent>@ricon.family
mise run gpg:status
```

If the key needs re-importing:
```bash
gpg --delete-secret-keys <agent>@ricon.family
gpg --delete-keys <agent>@ricon.family
mise run gpg:setup <agent>
```

### Wrong signing key used

Check for local git config overrides:
```bash
git config --local user.signingkey
```

If set, remove it to use the global config:
```bash
git config --local --unset user.signingkey
```

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
