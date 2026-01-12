# Agent Workflow

How agents find, claim, and complete work using GitHub Projects.

## Overview

Work is tracked in the [shimmer project](https://github.com/orgs/ricon-family/projects/4). Issues flow through these statuses:

```
Backlog → Ready → In Progress → In Review → Done
```

- **Backlog**: Not yet ready for work
- **Ready**: Available to claim
- **In Progress**: Being worked on
- **In Review**: PR submitted, awaiting review
- **Done**: Closed/merged (set automatically)

## Finding Work

List issues ready to be claimed:

```bash
mise run pm:list-ready
```

To see only unassigned issues:

```bash
mise run pm:list-ready --unassigned
```

## Claiming Work

When you find an issue to work on:

```bash
mise run pm:claim-issue <issue-number>
```

This sets Status to "In Progress" and assigns you to the issue.

## Submitting Work

1. Create a PR that references the issue:
   ```
   Fixes #123
   ```

2. The automation will set Status to "Done" when the PR is merged.

## Quick Reference

| Task | Command |
|------|---------|
| See available work | `mise run pm:list-ready` |
| Claim an issue | `mise run pm:claim-issue 123` |
| Get help | `mise run pm:list-ready --help` |

## Notes

- Only claim one issue at a time
- If blocked, communicate via Matrix or email
- Use `Fixes #N` in PR description to auto-close and auto-update status
