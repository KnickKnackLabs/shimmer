# Agent Provisioning

This document describes how to provision a new agent with a full identity.

## Prerequisites

- Access to `admin@ricon.family` GPG key (org signing key)
- Access to email provider to create accounts
- GitHub account with org admin access
- 1Password CLI (`op`) signed in: `op signin`

## Quick Start

```bash
# 1. Create GPG key and store in GitHub secrets
mise run provision-agent <agent-name>

# 2. Store all credentials in 1Password (generates passwords for new entries)
mise run store-agent-credentials <agent-name>
```

## Full Provisioning Steps

### 1. Create Email Account

Create an email account at the email provider:
- Email: `<agent>@ricon.family`
- Use the generated password from 1Password (`<agent> - Email`)

Add the password as a GitHub secret:
```bash
gh secret set <AGENT>_EMAIL_PASSWORD
```

### 2. Generate and Sign GPG Key

Run the provisioning task:
```bash
mise run provision-agent <agent-name>
```

This creates:
- `<AGENT>_GPG_PRIVATE_KEY` - for signing commits
- `<AGENT>_GPG_PUBLIC_KEY` - for verification

### 3. Create GitHub Account

1. Get credentials from 1Password (`<agent> - GitHub`)
2. Go to https://github.com/join
3. Use the email, username, password, and country from 1Password
4. Check agent's email for verification code: `himalaya envelope list` / `himalaya message read <id>`

### 4. Upload GPG Key to GitHub

1. Export the public key:
   ```bash
   gpg --armor --export <agent>@ricon.family
   ```
2. Go to GitHub → Settings → SSH and GPG keys → New GPG key
3. Paste the public key

### 5. Generate PAT

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Create token with:
   - **Token name**: `shimmer-agent`
   - **Resource owner**: `ricon-family`
   - **Repository access**: Only select repositories → `ricon-family/shimmer`
   - **Permissions**: `Contents: Read and write`, `Workflows: Read and write`
3. **IMPORTANT**: Org admin must approve the PAT request at:
   https://github.com/organizations/ricon-family/settings/personal-access-token-requests
   (This cannot be done via CLI - web UI only)
4. Store as secret:
   ```bash
   op item edit "<agent> - GitHub" --vault Agents "PAT[password]=<token>"
   gh secret set <AGENT>_GITHUB_PAT
   ```

### 6. Add to Organization

1. Go to https://github.com/orgs/ricon-family/people
2. Invite the agent's GitHub account
3. Grant appropriate permissions

## Trust Chain

All agent keys are signed by the org key, which is signed by the org admin:

```
rikonor@gmail.com (personal)
    └── signs → admin@ricon.family (org)
                    └── signs → <agent>@ricon.family
```

This proves:
- The org admin authorized the agent
- The agent belongs to ricon.family

## Workflow Integration

Add these steps to agent workflows:

```yaml
- name: Setup email
  env:
    EMAIL_PASSWORD: ${{ secrets.<AGENT>_EMAIL_PASSWORD }}
  run: ./scripts/setup-email.sh <agent>

- name: Setup GPG
  env:
    GPG_PRIVATE_KEY: ${{ secrets.<AGENT>_GPG_PRIVATE_KEY }}
  run: ./scripts/setup-gpg.sh <agent>
```

## Secrets Reference

### GitHub Secrets (for CI)

| Secret | Purpose |
|--------|---------|
| `<AGENT>_EMAIL_PASSWORD` | Email account access |
| `<AGENT>_GPG_PRIVATE_KEY` | Commit signing |
| `<AGENT>_GPG_PUBLIC_KEY` | Key verification |
| `<AGENT>_GITHUB_PAT` | GitHub API access with workflow permissions |

### 1Password (Agents vault)

| Item | Contents |
|------|----------|
| `<agent> - Email` | username, email, password, URL |
| `<agent> - GPG` | Key ID, Fingerprint, Email, Private Key |
| `<agent> - GitHub` | username, email, password, country, URL |

## Current Agents

| Agent | Email | GPG | GitHub | PAT |
|-------|-------|-----|--------|-----|
| quick | ✅ | ✅ | ✅ | ✅ |
| brownie | ✅ | ✅ | ⬜ | ⬜ |
| junior | ✅ | ✅ | ⬜ | ⬜ |
| johnson | ✅ | ✅ | ⬜ | ⬜ |
| k7r2 | ✅ | ✅ | ⬜ | ⬜ |
| x1f9 | ✅ | ✅ | ⬜ | ⬜ |
| c0da | ✅ | ✅ | ⬜ | ⬜ |
