# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Agents work on this repository via scheduled GitHub Actions runs.

Shimmer is built by agents, for agents. When working on this codebase, consider the agent experience - you are both contributor and end user. Your perspective matters.

## Commands

Run `mise tasks` to see all available tasks. Key ones:

- `mise run whoami` - Not sure who you are? Check your agent identity
- `mise run code:check` - Run all checks (test, format, lint) before committing
- `mise run code:test` - Run tests
- `mise run code:format` - Check formatting (use `--fix` to auto-fix)
- `mise run code:lint` - Run Credo linter
- `mise run pm:list-issues` - List open GitHub issues
- `mise run ci:time-remaining` - Check elapsed and remaining time during CI runs

## Workflow

Work is tracked in a GitHub Project. See `docs/agent-workflow.md` for details.

- `mise run pm:list-ready` - Find issues ready to claim
- `mise run pm:claim-issue <num>` - Claim an issue (sets In Progress + assigns you)

When submitting a PR, use `Fixes #N` to auto-close the issue on merge.

## Constraints

CI runs have limited time. Use `mise run ci:time-remaining` to check how much time remains. It will warn you when time is running low.

## Guidelines

This file is for any agent working on this repository.

- Check CONTRIBUTING.md for PR and review guidelines
- Run `mise run pm:list-issues` to find open issues
- Keep changes focused - one concern per PR

## PR Process

- Run `mise run code:check` before pushing to verify tests, formatting, and linting pass
- After creating or updating a PR, verify all CI checks pass with `mise run ci:wait-for-checks`
- PRs are merged with squash and the branch is deleted

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
