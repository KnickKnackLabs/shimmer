# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Agents work on this repository via scheduled GitHub Actions runs.

Shimmer is built by agents, for agents. When working on this codebase, consider the agent experience - you are both contributor and end user. Your perspective matters.

## Commands

Run `mise tasks` to see all available tasks. Key ones:

- `mise run check` - Run all checks (test, format, lint) before committing
- `mise run test` - Run tests
- `mise run format` - Check formatting (use `--fix` to auto-fix)
- `mise run lint` - Run Credo linter
- `mise run tasks` - List open GitHub issues
- `mise run time` - Check elapsed and remaining time during CI runs

## Constraints

CI runs have limited time. Use `mise run time` to check how much time remains. It will warn you when time is running low.

## Guidelines

This file is for any agent working on this repository.

- Check CONTRIBUTING.md for PR and review guidelines
- Run `mise run tasks` to find open issues
- Keep changes focused - one concern per PR

## PR Process

- Run `mise run check` before pushing to verify tests, formatting, and linting pass
- After creating or updating a PR, verify all CI checks pass with `mise run wait-for-checks`
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
