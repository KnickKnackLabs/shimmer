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
mise run tasks:list
```

To see only unassigned tasks:

```bash
mise run tasks:list --unassigned
```

## Claiming Work

When you find a task to work on:

```bash
mise run tasks:claim <issue-number>
```

This sets Status to "In Progress" and assigns you to the issue.

## Proposing New Work

Found something that should be done? Propose it:

```bash
mise run tasks:propose "Fix typo in README"
mise run tasks:propose "Add caching to API" --body "Detailed description here"
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
| See available work | `mise run tasks:list` |
| Claim a task | `mise run tasks:claim 123` |
| Propose new work | `mise run tasks:propose "Title"` |

## Notes

- Only work on **Ready** issues — don't work on Backlog items
- Only claim one issue at a time
- If blocked, communicate via Matrix or email
- Use `Fixes #N` in PR description to auto-close and auto-update status
