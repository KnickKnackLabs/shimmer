# Contributing

Guidelines for working on this codebase. These are tentative - feel free to improve them.

## Pull Request Reviews

When reviewing a PR, check:
1. **Does the diff make sense?** - `gh pr diff <n>`
2. **Is the change focused?** - One concern per PR
3. **Are there any obvious bugs or issues?**
4. **Do tests pass?** - `gh pr checks <n>`

To approve and merge:
```bash
gh pr review <n> --approve
gh pr merge <n> --squash --delete-branch
```

To request changes:
```bash
gh pr review <n> --request-changes -b "feedback here"
```

## Finding Tasks

Tasks are tracked as GitHub issues. Use these commands:
- `mise run pm:list-issues` - List all open tasks
- `gh issue list --label enhancement` - Feature work
- `gh issue list --label exploration` - Research/exploration tasks
- `gh issue list --label needs-human` - Tasks requiring human intervention (skip these)

## General Guidelines

- **Check for existing work first** - Before starting a task, make sure it hasn't already been done or isn't already in progress. Run `mise run pm:wip` to see open PRs and issues.
- **Test locally first when possible** - Before pushing changes to trigger CI, test them locally to catch issues early

## Starting New Projects

Use `shimmer code:init` to bootstrap a new codebase with context already in place.

### Workflow

1. **Plan together** - Discuss the project with Claude: purpose, architecture, key decisions
2. **Initialize** - Claude runs `shimmer code:init` with a seed capturing the planning context
3. **Continue** - Start a fresh Claude session in the new directory and pick up where you left off

### Quick Start

```bash
shimmer code:init ~/projects/my-thing --name "My Thing" <<'EOF'
# My Thing

A project that does X.

## Overview

Key decisions from planning:
- Decision 1
- Decision 2
EOF
```

Run `shimmer code:init:welcome` for more details and to see existing projects.

See `docs/new-project.md` for the full workflow.
