# Agent Provisioning

This document describes how to provision a new agent with a full identity.

## Prerequisites

- Access to `admin@ricon.family` GPG key (org signing key)
- Access to email provider to create accounts
- GitHub account with org admin access
- 1Password CLI (`op`) signed in: `op signin`

## Quick Start

```bash
# 1. Provision agent (GPG key, GitHub secrets, 1Password entries)
mise run provision-agent <agent-name>

# 2. Interactive onboarding (email, GitHub, Matrix, verification)
mise run onboard-agent <agent-name>
```

## How It Works

### provision-agent

Creates the agent's cryptographic identity:
- Generates GPG key for `<agent>@ricon.family`
- Signs key with org key (`admin@ricon.family`)
- Stores GPG keys as GitHub secrets (`<AGENT>_GPG_PRIVATE_KEY`, `<AGENT>_GPG_PUBLIC_KEY`)
- Creates 1Password entries with generated passwords:
  - `<agent> - Email` (for mail.ricon.family)
  - `<agent> - GPG` (key details + public key for easy copy)
  - `<agent> - GitHub` (account credentials)
  - `<agent> - Matrix` (for matrix.ricon.family)

### onboard-agent

Interactive walkthrough for full agent setup:
1. **Create Email Account** - shows credentials for mail provider
2. **Create GitHub Account** - shows credentials from 1Password
3. **GitHub Email Verification** - auto-fetches verification code from email
4. **Organization Setup** - invites to org, adds to `agents` team (grants write access)
5. **Upload GPG Key** - shows public key to copy
6. **Create PAT** - instructions for fine-grained token
7. **Approve PAT** - reminder for admin approval (web UI only)
8. **Store PAT** - commands to save in 1Password and GitHub secrets
9. **Matrix Setup** - create user in Synapse Admin, store password as GitHub secret
10. **Verify** - triggers test workflow to confirm signed commits work

## Organization Structure

### Teams

| Team | Access | Purpose |
|------|--------|---------|
| `agents` | Write on shimmer | All AI agents - grants repo access automatically |

### Trust Chain

```
rikonor@gmail.com (personal)
    └── signs → admin@ricon.family (org)
                    └── signs → <agent>@ricon.family
```

## Secrets Reference

### GitHub Secrets (for CI)

| Secret | Purpose |
|--------|---------|
| `<AGENT>_EMAIL_PASSWORD` | Email account access |
| `<AGENT>_GPG_PRIVATE_KEY` | Commit signing |
| `<AGENT>_GPG_PUBLIC_KEY` | Key verification |
| `<AGENT>_GITHUB_PAT` | GitHub API access with workflow permissions |
| `<AGENT>_MATRIX_PASSWORD` | Matrix messaging access |

### 1Password (Agents vault)

| Item | Contents |
|------|----------|
| `<agent> - Email` | username, email, password, URL |
| `<agent> - GPG` | Key ID, Fingerprint, Email, Private Key, Public Key, GitHub Title |
| `<agent> - GitHub` | username, email, password, country, URL, PAT |
| `<agent> - Matrix` | username, password, URL |

## Workflow Integration

```yaml
- name: Setup email
  env:
    EMAIL_PASSWORD: ${{ secrets.<AGENT>_EMAIL_PASSWORD }}
  run: ./scripts/setup-email.sh <agent>

- name: Setup GPG
  env:
    GPG_PRIVATE_KEY: ${{ secrets.<AGENT>_GPG_PRIVATE_KEY }}
  run: ./scripts/setup-gpg.sh <agent>

- name: Setup Matrix
  env:
    MATRIX_PASSWORD: ${{ secrets.<AGENT>_MATRIX_PASSWORD }}
  run: ./scripts/setup-matrix.sh <agent>
```

## Current Agents

| Agent | Status | Email | GPG | GitHub | PAT | Matrix | Verified |
|-------|--------|-------|-----|--------|-----|--------|----------|
| quick | Active | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| brownie | Active | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| junior | Active | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| johnson | Active | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| rho | Active | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| k7r2 | Active | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| x1f9 | Reserved | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| c0da | Active | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### Reserved Agents

x1f9 has a cryptographic identity provisioned but no assigned role.
This slot is available for a future specialized agent. To activate, add a prompt file
at `cli/priv/prompts/agents/<name>.txt` and create corresponding workflow(s).
