# Analyst Agent Design Exploration

Issue: #29

## Purpose

A dedicated agent that reviews workflow run logs from all agents (including itself) to identify patterns, inefficiencies, and improvement opportunities.

## Key Responsibilities

1. **Log Analysis** - Review GitHub Actions run logs
2. **Pattern Detection** - Find repeated operations across runs
3. **Efficiency Recommendations** - Suggest optimizations
4. **System Health Reporting** - Track success rates, duration trends

## Data Sources

### GitHub Actions API

The analyst can access run data via `gh` CLI:

```bash
# List recent runs for a workflow
gh run list --workflow probe-1.yml --limit 10 --json databaseId,status,conclusion,createdAt

# Get detailed run logs
gh run view <run-id> --log

# Get run timing
gh run view <run-id> --json createdAt,updatedAt
```

### Agent Notepads

Agents leave notes in `notepads/<agent>.md`. The analyst can read these for context.

## Potential Analysis Types

### 1. Duration Trends

Track how long runs take over time. Flag runs that are unusually long or short.

```
Average run duration: 4m 32s
Last run: 6m 15s (37% slower than average)
```

### 2. Failure Patterns

Identify common failure reasons:
- Token expiration
- Rate limiting
- Test failures
- Timeout

### 3. Tool Usage Patterns

Count tool invocations from logs to understand agent behavior:
- Which tools are used most?
- Are there tools that frequently fail?
- Could operations be batched?

### 4. PR Analysis

Track PR lifecycle:
- Time from creation to merge
- Common review feedback
- Stale PRs needing attention

## Output Formats

### Option A: Issue Creation

Analyst creates GitHub issues with findings:
- "Weekly Analysis Report: Dec 23-30"
- "Detected: Repeated token refresh failures"

### Option B: Markdown Report

Write analysis to a file like `reports/weekly-analysis.md`.

### Option C: Comments on Runs

Post comments on workflow runs with suggestions.

## Workflow Design

```yaml
name: analyst
on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM
  workflow_dispatch:
    inputs:
      message:
        description: 'Analysis focus'
        required: false
        type: string
```

### Default Prompt

```
Read your notepad. Review the last 24 hours of workflow runs for all agents.
Analyze patterns and create an issue with findings and recommendations.
Focus on: duration trends, failure patterns, repeated operations.
```

## Implementation Steps

1. **Phase 1: Basic Analysis**
   - Create analyst workflow file (requires human intervention per #34)
   - Create analyst notepad
   - Implement log fetching via `gh run list` and `gh run view`

2. **Phase 2: Pattern Detection**
   - Parse log output for tool usage
   - Track duration metrics
   - Identify failure patterns

3. **Phase 3: Recommendations**
   - Generate actionable suggestions
   - Create issues for significant findings
   - Update shared notepad with insights

## Constraints

- Cannot modify workflow files (agents lack workflows permission)
- API rate limits apply to `gh` commands
- Log data is only retained for 90 days

## Open Questions

1. How often should the analyst run? Daily seems appropriate for a project this size.
2. Should it have its own branch or work on main?
3. Should analysis reports be committed to the repo or only posted as issues?
4. How to avoid noise - when are patterns significant enough to report?

## Next Steps

- [ ] Human creates `.github/workflows/analyst.yml`
- [ ] Create `notepads/analyst.md`
- [ ] Test log fetching with `gh run list/view`
- [ ] Prototype pattern detection logic
