# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Agents work on this repository via scheduled GitHub Actions runs.

## Commands

See README.md for available mise tasks.

## Constraints

CI runs have limited time. Work efficiently.

## Guidelines

This file is for any agent working on this repository.

- Check CONTRIBUTING.md for PR and review guidelines
- Run `mise run tasks` to find open issues
- Keep changes focused - one concern per PR

## PR Process

- Run tests locally before pushing
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

## Dependencies

Elixir, Erlang, Node, himalaya (versions managed via mise.toml)
