# Agent Workflow

How agents find, claim, and complete work using GitHub Projects.

## Overview

Work is tracked in the [shimmer project](https://github.com/orgs/ricon-family/projects/4). Issues flow through these statuses:

```
Backlog → Ready → In Progress → In Review → Done
```

- **Backlog**: Triaged but not yet approved for work
- **Ready**: Available to claim
- **In Progress**: Being worked on
- **In Review**: PR submitted, awaiting review
- **Done**: Closed/merged (set automatically)

**Important**: Only work on issues that are **Ready**. Issues in Backlog haven't been approved yet.

## Finding Work

List tasks available to work on:

```bash
mise run issue:list
```

To see only unassigned tasks:

```bash
mise run issue:list --unassigned
```

## Claiming Work

When you find a task to work on:

```bash
mise run issue:claim <issue-number>
```

This sets Status to "In Progress" and assigns you to the issue.

## Proposing New Work

Found something that should be done? Propose it:

```bash
mise run issue:propose "Fix typo in README"
mise run issue:propose "Add caching to API" --body "Detailed description here"
```

This creates an issue for PM to triage. You can't work on it until PM moves it to Ready.

## Submitting Work

1. Create a PR that references the issue:
   ```
   Fixes #123
   ```

2. The automation will set Status to "Done" when the PR is merged.

## Quick Reference

| Task | Command |
|------|---------|
| See available work | `mise run issue:list` |
| Claim an issue | `mise run issue:claim 123` |
| Propose new work | `mise run issue:propose "Title"` |

## Sub-Issues

For complex work that breaks into multiple tasks, use GitHub's sub-issue feature:

```bash
# List sub-issues of a parent
mise run issue:sub-list 123

# Link existing issue as sub-issue
mise run issue:sub-add 123 456

# Create new sub-issue under parent
mise run issue:sub-create 123 "Implement feature X" --body "Details..."
```

**When to use sub-issues:**
- Work naturally decomposes into 3+ distinct tasks
- Tasks could be done in parallel or by different agents
- Progress tracking on parent is valuable

Parent issues show progress as sub-issues are completed.

## Cross-Repo Project Management

Shimmer's tasks can manage projects in other repos using `PROJECT_DIR`:

```bash
# Issue tasks
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run issue:list
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run issue:claim 123
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run issue:propose "Title"
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run issue:view 123
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run issue:sub-list 123
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run issue:sub-add 123 456
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run issue:sub-create 123 "Task"

# PR tasks
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run pr:list
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run pr:view 456
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run pr:approve 456
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run pr:merge 456

# PM tasks
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run pm:list-issues
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run pm:edit-issue 123 --status Ready
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run pm:wip

# CI tasks
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run ci:wait-for-checks 456
PROJECT_DIR=/path/to/other-repo mise -C $SHIMMER_DIR run ci:logs pr-check.yml
```

### Setting Up a New Repo

1. Initialize a GitHub Project (creates project, configures Status field):
   ```bash
   PROJECT_DIR=/path/to/repo mise -C $SHIMMER_DIR run pm:init
   ```

2. Add custom fields if needed:
   ```bash
   PROJECT_DIR=/path/to/repo mise -C $SHIMMER_DIR run pm:field-options Priority 'High,Medium,Low' 'RED,YELLOW,GREEN'
   ```

Convention: Project name matches repo name. No `.project.toml` needed - repo is inferred from git remote.

### Meta: Shimmer Managing Shimmer

An agent can use their shimmer clone to manage *another* shimmer clone. For example, an agent with shimmer at `~/agents/x1f9/shimmer` could manage the main shimmer repo:

```bash
PROJECT_DIR=/path/to/main/shimmer mise -C ~/agents/x1f9/shimmer run pm:list-issues
```

This enables agents to use one "instance" of shimmer as their tooling while working on another instance of shimmer as the target repo.

## Notes

- Only work on **Ready** issues — don't work on Backlog items
- Only claim one issue at a time
- If blocked, communicate via Matrix or email
- Use `Fixes #N` in PR description to auto-close and auto-update status
