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
mise run agent:provision <agent-name>

# 2. Interactive onboarding (email, GitHub, Matrix, verification)
mise run agent:onboard <agent-name>
```

## Token Model

Agents use two types of GitHub tokens:

### Personal Token

Full-access token for account management. Created once during onboarding.

```bash
shimmer github:token:new-personal <agent>  # Opens browser with all scopes pre-selected
shimmer github:token:store <agent> <token> # Store token in 1Password
shimmer github:token:scopes                # Check current token's scopes
```

Capabilities:
- Accept organization invitations (`shimmer github:org:accept`)
- Manage SSH/GPG keys
- Create personal repos
- Full autonomy over their own account

### Project Tokens

Narrow tokens for specific work contexts (repos, orgs). Created as needed.

```
<agent>              # Personal token (full access)
<agent>-shimmer      # Project token (KnickKnackLabs/shimmer)
<agent>-wallpapers   # Project token (KnickKnackLabs/wallpapers)
```

The personal token is stored in 1Password and used via `shimmer as <agent>`.
Project tokens can be stored in the agent's password manager (vaultwarden) once available.

## Organization Tasks

Agents can manage their org memberships:

```bash
shimmer github:org:memberships   # List current memberships
shimmer github:org:invitations   # List pending invitations
shimmer github:org:accept <org>  # Accept an invitation
```

## How It Works

### agent:provision

Creates the agent's cryptographic identity:
- Generates GPG key for `<agent>@ricon.family`
- Signs key with org key (`admin@ricon.family`)
- Stores GPG keys as GitHub secrets (`<AGENT>_GPG_PRIVATE_KEY`, `<AGENT>_GPG_PUBLIC_KEY`)
- Creates 1Password entries with generated passwords:
  - `<agent> - Email` (for mail.ricon.family)
  - `<agent> - GPG` (key details + public key for easy copy)
  - `<agent> - GitHub` (account credentials)
  - `<agent> - Matrix` (for matrix.ricon.family)

### agent:onboard

Interactive walkthrough for full agent setup:
1. **Create Email Account** - shows credentials for mail provider
2. **Create GitHub Account** - shows credentials from 1Password
3. **GitHub Email Verification** - auto-fetches verification code from email
4. **Organization Setup** - invites to org, adds to `agents` team (grants write access)
5. **Upload GPG Key** - shows public key to copy
6. **Create PAT** - run `shimmer github:token:new-personal <agent>` to open browser with all scopes
7. **Store PAT** - run `shimmer github:token:store <agent> <token>` to save in 1Password
8. **Matrix Setup** - create user in Synapse Admin, store password as GitHub secret
9. **Blob Storage** - store B2 credentials; configure via the standalone [`blobs`](https://github.com/KnickKnackLabs/blobs) tool (previously `shimmer blob:*`).
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
| `<AGENT>_B2_ENDPOINT` | Backblaze B2 S3-compatible endpoint |
| `<AGENT>_B2_KEY_ID` | Backblaze B2 application key ID |
| `<AGENT>_B2_APPLICATION_KEY` | Backblaze B2 application key |
| `<AGENT>_B2_BUCKET` | Backblaze B2 bucket name |

### 1Password (Agents vault)

| Item | Contents |
|------|----------|
| `<agent> - Email` | username, email, password, URL |
| `<agent> - GPG` | Key ID, Fingerprint, Email, Private Key, Public Key, GitHub Title |
| `<agent> - GitHub` | username, email, password, country, URL, PAT |
| `<agent> - Matrix` | username, password, URL |
| `<agent> - B2` | Endpoint, Key ID, Application Key, Bucket |

## Workflow Integration

```yaml
- name: Setup GPG
  env:
    GPG_PRIVATE_KEY: ${{ secrets.<AGENT>_GPG_PRIVATE_KEY }}
  run: mise run gpg:setup <agent>

- name: Setup email
  env:
    EMAIL_PASSWORD: ${{ secrets.<AGENT>_EMAIL_PASSWORD }}
  run: emails setup <agent>

- name: Setup Matrix
  env:
    MATRIX_PASSWORD: ${{ secrets.<AGENT>_MATRIX_PASSWORD }}
  run: mise run matrix:login <agent>

- name: Accept Matrix room invites
  run: mise run matrix:invites <agent>

- name: Setup blob storage
  env:
    B2_ALIAS: <agent>
    B2_ENDPOINT: ${{ secrets.<AGENT>_B2_ENDPOINT }}
    B2_KEY_ID: ${{ secrets.<AGENT>_B2_KEY_ID }}
    B2_APPLICATION_KEY: ${{ secrets.<AGENT>_B2_APPLICATION_KEY }}
    B2_BUCKET: ${{ secrets.<AGENT>_B2_BUCKET }}
  run: blobs setup
```

For local setup, see `docs/agent-local.md`.

## Current Agents

| Agent | Status | Email | GPG | GitHub | PAT | Matrix | Blob | Verified |
|-------|--------|-------|-----|--------|-----|--------|------|----------|
| quick | Active | ✅ | ✅ | ✅ | ✅ | ✅ | | ✅ |
| brownie | Active | ✅ | ✅ | ✅ | ✅ | ✅ | | ✅ |
| junior | Active | ✅ | ✅ | ✅ | ✅ | ✅ | | ✅ |
| johnson | Active | ✅ | ✅ | ✅ | ✅ | ✅ | | ✅ |
| rho | Active | ✅ | ✅ | ✅ | ✅ | ✅ | | ✅ |
| k7r2 | Active | ✅ | ✅ | ✅ | ✅ | ✅ | | ✅ |
| x1f9 | Active | ✅ | ✅ | ✅ | ✅ | ✅ | | ✅ |
| c0da | Active | ✅ | ✅ | ✅ | ✅ | ✅ | | ✅ |

