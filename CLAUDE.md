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

## Dependencies

Elixir, Erlang, Node (versions managed via mise.toml)
