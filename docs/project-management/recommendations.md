# Project Management Recommendations for Shimmer

Decisions and configuration plan based on GitHub documentation research and stakeholder input.

## Design Principles

1. **Start simple, evolve as needed** - Don't over-engineer upfront. Add complexity when it proves necessary.
2. **Agent-friendly** - Optimize for CLI/API access. Agents are primary consumers.
3. **Human oversight** - Key decisions involve human input. Agents propose, humans approve.

## Project Configuration

### Custom Fields

| Field | Type | Options/Notes |
|-------|------|---------------|
| Status | Single select | Backlog, Ready, In Progress, In Review, Done |
| Priority | Single select | High, Medium, Low |
| Iteration | Iteration | TBD duration (suggest 2 weeks to start) |

**Not using:**
- Estimate/points field (avoiding estimation overhead)
- Target date field (iterations provide time-boxing)

### Status Workflow

```
Backlog → Ready → In Progress → In Review → Done
```

- **Backlog**: Captured but not yet triaged/groomed
- **Ready**: Triaged, requirements clear, available for agents to claim
- **In Progress**: Actively being worked on
- **In Review**: PR submitted, awaiting review
- **Done**: Closed/merged (set automatically)

### Built-in Automations

| Workflow | Action | Notes |
|----------|--------|-------|
| Item closed | Set Status → Done | Default, keep enabled |
| PR merged | Set Status → Done | Default, keep enabled |
| Auto-archive | Archive when Done + inactive 14d | Keeps board clean |
| Auto-add | Add new shimmer issues to project | Uses our 1 free slot |

### Views to Create

| View | Layout | Purpose |
|------|--------|---------|
| Backlog | Table | Triage view, grouped by Priority |
| Sprint Board | Board | Current iteration, columns by Status |
| My Work | Table | Filtered to `assignee:@me` |

## Work Organization

### Hierarchy Strategy

**Hybrid approach:**
- Most work starts as standalone issues
- Complex multi-part work gets broken into parent + sub-issues
- Project manager (k7r2) and human decide when hierarchy is warranted

**Guidelines for using sub-issues:**
- Work naturally decomposes into 3+ distinct tasks
- Tasks could be done in parallel or by different agents
- Progress tracking on parent is valuable

### Agent Work Assignment

**Claiming work:**
1. Agent queries project for `Status:Ready` items
2. Optionally filter by `no:assignee` for unclaimed work
3. Agent sets `Status:In Progress` and assigns self
4. On completion, agent creates PR with `Fixes #N`
5. Auto-workflow sets `Status:Done` on merge

**Assignment options:**
- Agents CAN claim unassigned Ready work
- Humans CAN pre-assign work to specific agents
- Priority field helps agents pick highest-value work first

### Issue Types

Using org-level Issue Types for work classification:
- **Bug** - Something broken
- **Feature** - New functionality
- **Task** - Everything else (maintenance, docs, research)

## Label Strategy

### Labels to Remove

Delete these (overlap with Issue Types):
- `bug`
- `enhancement`

### Labels to Keep

| Label | Purpose |
|-------|---------|
| `priority:high` | Urgent work (also in project field) |
| `priority:medium` | Important but not urgent |
| `priority:low` | Nice to have |
| `exploration` | Research/investigation task |
| `rfc` | Request for comments, needs discussion |
| `parking-lot` | Valid but not current priority |
| `waiting-for-data` | Blocked pending information |
| `needs-human` | Requires human intervention |
| `run-review` | Post-run analysis |
| `good first issue` | Entry point for new contributors |
| `help wanted` | Open for contribution |

### Label vs Field

- **Use labels for**: Cross-cutting concerns, contributor signals, process markers
- **Use fields for**: Workflow state (Status), scheduling (Priority, Iteration)

## Iteration Setup

**Initial configuration:**
- Duration: 2 weeks (adjustable based on experience)
- Start: Align with calendar (e.g., Mondays)
- Create 3 iterations to start

**Review cadence:**
- End of iteration: Review what shipped, what carried over
- Adjust iteration length if needed based on throughput

## Implementation Checklist

### Project Setup
- [ ] Create/configure Status field with 5 states
- [ ] Create Priority field (High/Medium/Low)
- [ ] Create Iteration field (2-week cycles)
- [ ] Enable auto-archive workflow (Done + 14d inactive)
- [ ] Enable auto-add workflow for shimmer repo
- [ ] Create Backlog view (table, group by Priority)
- [ ] Create Sprint Board view (board, filter current iteration)
- [ ] Create My Work view (table, filter assignee:@me)

### Label Cleanup
- [ ] Delete `bug` label
- [ ] Delete `enhancement` label

### Documentation
- [ ] Update agent prompts with work-claiming workflow
- [ ] Document iteration review process

## Open Items

- **Iteration duration**: Starting with 2 weeks, may adjust
- **Multiple agents**: How to prevent two agents claiming same work? (For now: assignment + status update is atomic enough)
- **Blocked work**: Should we add a "Blocked" status? (For now: use `waiting-for-data` label)

## References

- [projects.md](concepts/projects.md) - Full Projects documentation
- [automation.md](concepts/automation.md) - Workflow and API details
- [views.md](concepts/views.md) - View configuration
- [labels.md](concepts/labels.md) - Label strategy
