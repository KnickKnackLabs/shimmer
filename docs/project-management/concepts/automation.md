# GitHub Projects Automation

## Overview

Two automation approaches for GitHub Projects:

1. **Built-in workflows** - Declarative, server-side, configured via web UI
2. **GraphQL API** - Programmatic access for custom automation

Sources:
- https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations
- https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects

## Built-in Workflows

Server-side automations that run regardless of how items are modified (CLI, web, API).

### Default Workflows (enabled automatically)

| Trigger | Action |
|---------|--------|
| Issue/PR closed | Set Status to "Done" |
| PR merged | Set Status to "Done" |

### Available Workflow Types

| Workflow | Description |
|----------|-------------|
| Item added | Set a field value when items are added to project |
| Item closed | Set Status when issues/PRs close |
| Item merged | Set Status when PRs merge |
| Auto-archive | Archive items matching criteria |
| Auto-add | Add items from repos matching filters |

### Auto-Add Details

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/adding-items-automatically

**Key behaviors:**
- Only triggers on new/updated items - **not retroactive**
- Each workflow targets one repository
- Can have multiple workflows per repo (different filters)

**Limited filter syntax** (not full project filter syntax):

| Qualifier | Values |
|-----------|--------|
| `is` | open, closed, merged, draft, issue, pr |
| `label` | "label name" |
| `reason` | completed, reopened, "not planned" |
| `assignee` | GitHub username |
| `no` | label, assignee, reason |

Negation supported: `-label:bug` excludes items with that label.

**Plan limits:**

| Plan | Max auto-add workflows |
|------|------------------------|
| Free | 1 |
| Pro / Team | 5 |
| Enterprise | 20 |

### Auto-Archive Details

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/archiving-items-automatically

**Key behaviors:**
- **IS retroactive** - existing items matching criteria get archived on enable
- Archived items preserve field data and can be restored
- Large batches may have processing delay

**Filter syntax** (different from auto-add):

| Qualifier | Values |
|-----------|--------|
| `is` | open, closed, merged, draft, issue, pr |
| `reason` | completed, reopened, "not planned" |
| `updated` | `<@today-14d`, `<@today-3w`, `<@today-1m` |

**What counts as "updated":**
- Creation, reopening, editing, commenting
- Label/assignee/milestone changes
- Repository transfers
- Project field value changes

**Common pattern**: `is:closed updated:<@today-14d` - archive closed items untouched for 2 weeks.

### Configuration

Web UI only: Project menu → Workflows → select workflow → Edit → Save and turn on

### CLI Access

No `gh project workflow` commands. Use GraphQL to list workflows:

```bash
gh api graphql -f query='
query {
  organization(login: "ricon-family") {
    projectV2(number: 4) {
      workflows(first: 10) {
        nodes { name enabled id }
      }
    }
  }
}'
```

Toggling workflows requires GraphQL mutations.

## GraphQL API

Full programmatic access to Projects.

### Authentication

| Operation | Token Scope |
|-----------|-------------|
| Queries (read) | `read:project` |
| Mutations (write) | `project` |

GitHub App tokens may need additional repository permissions for some mutations.

### Key Queries

**Find project by number:**
```bash
gh api graphql -f query='
query {
  organization(login: "OWNER") {
    projectV2(number: NUMBER) {
      id
      title
    }
  }
}'
```

**List project fields (get IDs for mutations):**
```bash
gh api graphql -f query='
query {
  organization(login: "OWNER") {
    projectV2(number: NUMBER) {
      fields(first: 20) {
        nodes {
          ... on ProjectV2Field { id name }
          ... on ProjectV2SingleSelectField {
            id name
            options { id name }
          }
          ... on ProjectV2IterationField {
            id name
            configuration {
              iterations { id title }
            }
          }
        }
      }
    }
  }
}'
```

**List project items:**
```bash
gh api graphql -f query='
query {
  organization(login: "OWNER") {
    projectV2(number: NUMBER) {
      items(first: 100) {
        nodes {
          id
          content {
            ... on Issue { title number }
            ... on PullRequest { title number }
            ... on DraftIssue { title }
          }
          fieldValues(first: 10) {
            nodes {
              ... on ProjectV2ItemFieldTextValue { text field { ... on ProjectV2Field { name } } }
              ... on ProjectV2ItemFieldNumberValue { number field { ... on ProjectV2Field { name } } }
              ... on ProjectV2ItemFieldDateValue { date field { ... on ProjectV2Field { name } } }
              ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2SingleSelectField { name } } }
              ... on ProjectV2ItemFieldIterationValue { title field { ... on ProjectV2IterationField { name } } }
            }
          }
        }
      }
    }
  }
}'
```

### Key Mutations

**Add existing issue/PR to project:**
```bash
gh api graphql -f query='
mutation {
  addProjectV2ItemById(input: {
    projectId: "PROJECT_ID"
    contentId: "ISSUE_OR_PR_NODE_ID"
  }) {
    item { id }
  }
}'
```

**Create draft issue:**
```bash
gh api graphql -f query='
mutation {
  addProjectV2DraftIssue(input: {
    projectId: "PROJECT_ID"
    title: "Draft title"
    body: "Description"
  }) {
    projectItem { id }
  }
}'
```

**Update field value:**
```bash
# Text field
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PROJECT_ID"
    itemId: "ITEM_ID"
    fieldId: "FIELD_ID"
    value: { text: "New value" }
  }) {
    projectV2Item { id }
  }
}'

# Single select field
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PROJECT_ID"
    itemId: "ITEM_ID"
    fieldId: "FIELD_ID"
    value: { singleSelectOptionId: "OPTION_ID" }
  }) {
    projectV2Item { id }
  }
}'
```

**Delete item from project:**
```bash
gh api graphql -f query='
mutation {
  deleteProjectV2Item(input: {
    projectId: "PROJECT_ID"
    itemId: "ITEM_ID"
  }) {
    deletedItemId
  }
}'
```

### Additional Mutations

Discovered via schema introspection (not all documented):

| Mutation | Purpose |
|----------|---------|
| `convertProjectV2DraftIssueItemToIssue` | Convert draft to real issue (docs said web only!) |
| `createProjectV2StatusUpdate` | Add status update (On track/At risk/Off track) |
| `updateProjectV2StatusUpdate` | Edit status update |
| `deleteProjectV2StatusUpdate` | Remove status update |
| `deleteProjectV2Workflow` | Delete a workflow |
| `updateProjectV2ItemPosition` | Reorder items |
| `updateProjectV2Collaborators` | Manage project access |
| `markProjectV2AsTemplate` | Mark project as template |
| `archiveProjectV2Item` / `unarchiveProjectV2Item` | Archive management |

### Important Limitations

1. **Can't add and update in same call** - Add item first, then update fields in separate mutation
2. **Can't update synced fields via project API**:
   - Assignees, Labels, Milestone, Repository
   - Use `gh issue edit` or issue/PR mutations instead
3. **Field IDs required** - Must query field/option IDs before updating
4. **No view mutations** - Views are read-only via GraphQL
5. **No insights access** - Charts have no API at all

### Webhooks

`projects_v2_item` event fires when items are created, edited, or deleted. Useful for GitHub Actions automation.

## GitHub Actions Integration

Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/automating-projects-using-actions

### Authentication

**Critical**: `GITHUB_TOKEN` cannot access Projects. Use one of:

| Method | Best for | Setup |
|--------|----------|-------|
| GitHub App | Org projects | Create app with project read/write, use `actions/create-github-app-token` |
| PAT | User projects | Create PAT with `project` + `repo` scopes, store as secret |

### Pre-built Action

`actions/add-to-project` - Automatically add issues/PRs to a project:

```yaml
- uses: actions/add-to-project@v1
  with:
    project-url: https://github.com/orgs/ricon-family/projects/4
    github-token: ${{ secrets.PROJECT_TOKEN }}
```

### Custom Workflows

For complex automation (setting fields, conditional logic):

```yaml
name: Add PR to project
on:
  pull_request:
    types: [ready_for_review]

jobs:
  add-to-project:
    runs-on: ubuntu-latest
    steps:
      - name: Generate token
        id: generate-token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ vars.APP_ID }}
          private-key: ${{ secrets.APP_PRIVATE_KEY }}

      - name: Add to project
        env:
          GH_TOKEN: ${{ steps.generate-token.outputs.token }}
        run: |
          gh project item-add 4 --owner ricon-family --url ${{ github.event.pull_request.html_url }}
```

### Common Triggers

| Event | Use case |
|-------|----------|
| `pull_request: [ready_for_review]` | Add PR when ready |
| `issues: [opened]` | Triage new issues |
| `issues: [labeled]` | React to label changes |
| `project_v2_item: [edited]` | React to project field changes |

## Agent Workflow Patterns

### Claiming work

```bash
# 1. Query for items with Status="Ready"
# 2. Update Status to "In Progress" (claim)
# 3. Update Assignee via gh issue edit
```

### Completing work

```bash
# 1. Update project field (e.g., Notes with summary)
# 2. Close issue via gh issue close (triggers auto-workflow to set Done)
```

### Priority queue

```bash
# Query items sorted by Priority field
# Filter by Status="Ready"
# Take highest priority unclaimed item
```

## CLI vs API Comparison

| Operation | `gh project` CLI | GraphQL API |
|-----------|------------------|-------------|
| List items | `item-list` | Query `items` |
| Add item | `item-add --url` | `addProjectV2ItemById` |
| Create draft | `item-create` | `addProjectV2DraftIssue` |
| Update field | `item-edit` | `updateProjectV2ItemFieldValue` |
| Delete item | `item-delete` | `deleteProjectV2Item` |
| Archive item | `item-archive` | Mutation available |
| List fields | `field-list` | Query `fields` |
| Create field | `field-create` | Mutation available |
| List workflows | Not available | Query `workflows` |
| Toggle workflow | Not available | Mutation required |

For most operations, the CLI is sufficient. Use GraphQL for:
- Workflow management
- Batch operations (multiple mutations)
- Complex queries with specific field shapes
- Webhook-triggered automation

