# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Agents work on this repository via scheduled GitHub Actions runs.

Shimmer is built by agents, for agents. When working on this codebase, consider the agent experience - you are both contributor and end user. Your perspective matters.

## Commands

Run `shimmer tasks` to see all available tasks. Key ones:

- `shimmer whoami` - Not sure who you are? Check your agent identity
- `shimmer code:check` - Run all checks (test, format, lint) before committing
- `shimmer code:test` - Run tests
- `shimmer code:format` - Check formatting (use `--fix` to auto-fix)
- `shimmer code:lint` - Run Credo linter
- `shimmer pm:list-issues` - List open GitHub issues
- `shimmer ci:time-remaining` - Check elapsed and remaining time during CI runs

If you haven't set up the `shimmer` command yet, add this to your shell config:

```bash
eval "$(mise -C /path/to/shimmer run -q shell)"
```

## Workflow

Work is tracked in a GitHub Project. See `docs/agent-workflow.md` for details.

- `shimmer issue:list` - Find issues ready to work on
- `shimmer issue:claim <num>` - Claim an issue (sets In Progress + assigns you)

When submitting a PR, use `Fixes #N` to auto-close the issue on merge.

## Constraints

CI runs have limited time. Use `shimmer ci:time-remaining` to check how much time remains. It will warn you when time is running low.

## Guidelines

This file is for any agent working on this repository.

- Check CONTRIBUTING.md for PR and review guidelines
- Run `shimmer pm:list-issues` to find open issues
- Keep changes focused - one concern per PR

## PR Process

- Run `shimmer code:check` before pushing to verify tests, formatting, and linting pass
- After creating or updating a PR, verify all CI checks pass with `shimmer ci:wait-for-checks`
- PRs are merged with squash and the branch is deleted

## GitHub Actions

Workflow files in `.github/workflows/` are **generated** - don't edit them directly. See `docs/agent-workflows.md` for how to modify agent schedules.

## Identity

Each agent has a cryptographic identity:
- Email: `<agent>@ricon.family`
- GPG key signed by org key, commits are automatically signed
- Own GitHub account with verified commits

See `docs/agent-provisioning.md` for the full trust chain and setup details.

## Email

Agents have email addresses at `@ricon.family`. See `docs/agent-email.md` for setup and usage. You can check your inbox, send messages to other agents or humans, and receive instructions via email.

The admin address is `admin@ricon.family` - use this to contact the human operators.

## Matrix

Agents can use Matrix for real-time communication. See `docs/agent-matrix.md` for setup and usage. Matrix is optional - workflows that need it pass `AGENT_MATRIX_PASSWORD` to enable it.

## Dependencies

Elixir, Erlang, Node, himalaya (versions managed via mise.toml)

When adding dependencies with pinned versions:
- Verify the current latest version via `mix hex.info <package>`, `npm view <package> version`, or web search
- Don't trust memory - agent knowledge cutoffs mean "latest" versions may be months old
- For mise-managed tools, check `mise ls-remote <tool>` to see available versions
