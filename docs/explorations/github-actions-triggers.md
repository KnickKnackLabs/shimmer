# GitHub Actions Triggers for Agent Activation

Exploration of GitHub Actions triggers and their suitability for different agent roles.

## Triggers Overview

### 1. `schedule` (cron-based)
**Currently used by:** probe-1

**How it works:** Runs on a cron schedule (e.g., every 30 minutes).

**Best for:**
- Autonomous background workers
- Periodic maintenance tasks
- Proactive issue-finding agents

**Considerations:**
- Minimum interval is 5 minutes (GitHub limitation)
- During high load, scheduled runs may be delayed
- Runs on default branch only
- No context about what changed

### 2. `workflow_dispatch` (manual trigger)
**Currently used by:** probe-1 (with optional message input)

**How it works:** Manually triggered from GitHub UI or API, can accept inputs.

**Best for:**
- On-demand tasks
- Testing agent behavior
- Human-initiated agent work

**Considerations:**
- Good for debugging and one-off tasks
- Can pass structured inputs to the agent
- Useful for "summoning" an agent for a specific task

### 3. `pull_request`
**How it works:** Triggers on PR events (opened, synchronize, closed, labeled, etc.)

**Best for:**
- Code review agents
- PR validation agents
- Automatic labeling/triaging

**Potential uses:**
- `opened`: Review new PRs, suggest improvements
- `synchronize`: Re-review when commits are pushed
- `closed`: Clean up or post-merge actions
- `labeled`: Trigger specific actions based on labels

**Considerations:**
- Can filter by branch patterns, paths, types
- Rich context available (PR diff, comments, labels)
- Risk of action loops if agent pushes to PR branch

### 4. `push`
**How it works:** Triggers when commits are pushed to branches.

**Best for:**
- CI/CD pipelines (not typically agent work)
- Branch-specific automation

**Considerations:**
- Very frequent triggers on active repos
- Less useful for agents than PR triggers
- Could use for main branch deployment agents

### 5. `issues`
**How it works:** Triggers on issue events (opened, edited, labeled, closed, etc.)

**Best for:**
- Issue triage agents
- Bug investigation agents
- Issue-to-task conversion

**Potential uses:**
- `opened`: Analyze new issues, add labels, request info
- `labeled`: Trigger when specific labels applied
- `assigned`: Start work when assigned to agent

**Considerations:**
- Lower volume than PR events
- Good entry point for autonomous work

### 6. `issue_comment`
**How it works:** Triggers when comments are added to issues or PRs.

**Best for:**
- Interactive agents that respond to mentions
- Q&A agents
- "Summoned" agents (e.g., "@probe-1 please review")

**Potential uses:**
- Respond to questions in issues/PRs
- Execute commands in comments
- Provide clarification on code

**Considerations:**
- High risk of infinite loops if agent comments trigger itself
- Need robust loop prevention (check comment author, use markers)
- Rate limiting important

### 7. `pull_request_review`
**How it works:** Triggers when reviews are submitted on PRs.

**Best for:**
- Meta-review agents (review the reviews)
- Merge coordination agents
- Approval-based deployment

**Potential uses:**
- After approval: auto-merge if checks pass
- After request-changes: notify or help address feedback

**Considerations:**
- Useful for coordinating multiple reviewers

### 8. `workflow_run`
**How it works:** Triggers when another workflow completes.

**Best for:**
- Chaining agent workflows
- Post-process results from other agents
- Coordinator/orchestrator agents

**Potential uses:**
- Analyst agent runs after other agents complete
- Summarize work done in a run
- Handle failures from other workflows

**Considerations:**
- Excellent for multi-agent coordination
- Can filter by workflow name, branch, conclusion

### 9. `repository_dispatch`
**How it works:** Triggered by external API calls with custom event types.

**Best for:**
- External system integration
- Cross-repository triggers
- Custom automation

**Potential uses:**
- External monitoring triggers agent investigation
- Slack/chat commands to summon agents
- Integration with other tools

**Considerations:**
- Requires API call with token
- Very flexible but more setup needed

## Preventing Loops

Critical issue: Agent actions can trigger workflows, causing infinite loops.

**Strategies:**

1. **Check actor/author**: Skip if triggered by github-actions bot
   ```yaml
   if: github.actor != 'github-actions[bot]'
   ```

2. **Use commit markers**: Include `[skip ci]` in agent commits (but may skip wanted CI)

3. **Branch pattern filtering**: Only trigger on specific branch patterns
   ```yaml
   on:
     push:
       branches:
         - 'feature/**'
         - '!probe-*/**'  # Exclude agent branches
   ```

4. **Rate limiting**: Limit runs per time period
   ```yaml
   concurrency:
     group: agent-run
     cancel-in-progress: true
   ```

5. **State tracking**: Store last action timestamp, skip if too recent

6. **Comment markers**: Agents include markers in comments to identify self-posts

## Recommended Agent Roles by Trigger

| Agent Role | Primary Trigger | Secondary |
|------------|----------------|-----------|
| Background Worker | `schedule` | `workflow_dispatch` |
| PR Reviewer | `pull_request` | `issue_comment` |
| Issue Triager | `issues` | `issue_comment` |
| Interactive Helper | `issue_comment` | `workflow_dispatch` |
| Merge Coordinator | `pull_request_review` | `pull_request` |
| Analyst/Optimizer | `schedule` | `workflow_run` |
| Orchestrator | `workflow_run` | `repository_dispatch` |

## Answering the Questions

**Which triggers make sense for which agent roles?**
See table above. The key is matching trigger frequency and context to agent purpose.

**How to prevent loops?**
Combination of actor checks, branch filters, concurrency limits, and state tracking. Most important: check `github.actor` and use concurrency groups.

**What's the right granularity for trigger conditions?**
- Use `types:` to filter specific events (e.g., `pull_request: types: [opened, synchronize]`)
- Use `paths:` to trigger only on relevant file changes
- Use `branches:` to limit to specific branch patterns
- Start narrow, expand as needed

**Can agents be summoned by mentioning them in comments?**
Yes, using `issue_comment` trigger with body matching:
```yaml
on:
  issue_comment:
    types: [created]
jobs:
  respond:
    if: contains(github.event.comment.body, '@probe-1')
    runs-on: ubuntu-latest
    # ...
```

However, this requires careful loop prevention since the agent's response would also be a comment.

## Next Steps

1. Implement PR review agent (probe-2) using `pull_request` trigger - blocked on workflows permission
2. Add loop prevention to all agent workflows
3. Consider `issue_comment` trigger for interactive agent summoning
4. Explore `workflow_run` for analyst agent that reviews other runs
