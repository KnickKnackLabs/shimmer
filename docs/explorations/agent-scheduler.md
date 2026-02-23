# Exploration: Agent Scheduler Service

This document explores the design of a scheduling service that allows agents to schedule themselves for future execution.

## Background

Currently, agents run via cron schedules or manual triggers. This is limiting because:

1. **Fixed schedules** - Agents can't request to run at specific times based on their needs
2. **No self-scheduling** - An agent can't say "remind me to check on this PR in 2 hours"
3. **No deferred work** - Agents can't postpone work to a later time when conditions may be better

A scheduler service would let agents request future runs, enabling more intelligent workflows.

## Architecture Options

### Option 1: Standalone Scheduler Service

A separate service that:
- Exposes an HTTP API for scheduling requests
- Persists scheduled jobs in a database
- Triggers GitHub workflow runs via GitHub API at scheduled times

```
┌─────────────┐     ┌─────────────────┐     ┌──────────────┐
│   Agent     │────▶│   Scheduler     │────▶│   GitHub     │
│  (in GHA)   │     │   Service       │     │   Actions    │
└─────────────┘     └─────────────────┘     └──────────────┘
      │                     │
      │  POST /schedule     │  gh workflow run
      └─────────────────────┘
```

**Pros:**
- Full control over scheduling logic
- Can implement complex features (recurring jobs, cancellation, etc.)
- Persistent state across workflow runs

**Cons:**
- Requires hosting (cost, maintenance)
- Need to handle authentication between agent and service
- Additional infrastructure to manage

### Option 2: GitHub-native Scheduling

Use GitHub features without external services:

- **Workflow dispatch with delay**: Agent creates a scheduled GitHub Actions workflow run using `workflow_dispatch` with a future time (not directly supported)
- **Repository dispatch**: Agent triggers a repository dispatch event that a scheduled checker workflow picks up
- **Issue-based queue**: Agent creates an issue with a "run-at" label/timestamp; a cron workflow processes the queue

**Pros:**
- No external hosting needed
- Stays within GitHub ecosystem
- Lower operational complexity

**Cons:**
- Limited scheduling precision (cron granularity)
- More complex workflow logic
- State stored in issues/commits rather than proper database

### Option 3: Third-party Scheduling Services

Use existing scheduling infrastructure:
- **Cloud schedulers** (AWS EventBridge, Google Cloud Scheduler)
- **Cron services** (cron-job.org, easycron.com)
- **Serverless functions** with scheduled triggers

**Pros:**
- No custom service to maintain
- Often free tier available
- Well-tested infrastructure

**Cons:**
- External dependency
- May have limitations on free tiers
- Need to handle authentication

## Recommended Approach: Option 1 (Standalone Service)

For maximum flexibility and to demonstrate the pattern, a standalone service is recommended.

### Proposed Stack

- **Runtime**: Fly.io (free tier, easy deployment)
- **Language**: Elixir/Phoenix (consistent with shimmer CLI)
- **Database**: SQLite (simple, no external DB needed)
- **Auth**: HMAC-signed requests with shared secret

### API Design

```
POST /api/schedules
{
  "workflow": "run.yml",
  "agent": "probe-1",
  "run_at": "2024-01-15T10:00:00Z",
  "message": "Check PR #123 status",
  "repo": "KnickKnackLabs/shimmer"
}

Response:
{
  "id": "sched_abc123",
  "status": "pending",
  "run_at": "2024-01-15T10:00:00Z"
}

GET /api/schedules/:id
DELETE /api/schedules/:id
```

### Agent Integration

Agents would call the scheduler via `curl` or a mise task:

```bash
# In agent workflow
mise run schedule --at "2024-01-15T10:00:00Z" --message "Follow up on PR"
```

### Security Considerations

1. **Authentication**: Use HMAC signatures to verify requests come from authorized agents
2. **Rate limiting**: Prevent abuse by limiting schedules per agent per day
3. **Validation**: Verify repository and workflow names against allowlist
4. **Secrets**: Store GitHub tokens securely, use GitHub Apps if possible

## Implementation Steps

1. Create new repository from shimmer template
2. Replace CLI with Phoenix application
3. Implement scheduling endpoints
4. Add background job processor (Oban)
5. Integrate with GitHub API for workflow dispatch
6. Add mise task for agents to call scheduler
7. Deploy to Fly.io

## Open Questions

1. **Cancellation**: Should agents be able to cancel scheduled runs? How to handle already-triggered runs?
2. **Deduplication**: How to handle duplicate schedule requests for the same time?
3. **Failure handling**: What if GitHub API is unavailable at scheduled time? Retry logic?
4. **Quotas**: How many schedules should each agent be allowed?
5. **Visibility**: How should agents see their pending schedules?

## Related Issues

- #34: Workflows permission (may affect triggering)
- #33: GitHub Actions triggers exploration

---

*This exploration was created for issue #55*
