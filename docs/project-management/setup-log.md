# Project Setup Log

Commands executed to configure the shimmer GitHub Project. Run these to reproduce the setup.

## Prerequisites

- `gh` CLI authenticated with project write access
- Project number: 4
- Owner: ricon-family

## Changes

### 1. Update Status field options

**Date**: 2026-01-10

Replace default Status options (Todo, In Progress, Done) with 5-state workflow.

```bash
gh api graphql -f query='
mutation {
  updateProjectV2Field(input: {
    fieldId: "PVTSSF_lADODumhvM4BMSWkzg7nRgc"
    singleSelectOptions: [
      {name: "Backlog", color: GRAY, description: "Captured but not yet triaged"}
      {name: "Ready", color: BLUE, description: "Triaged, available for agents to claim"}
      {name: "In Progress", color: YELLOW, description: "Actively being worked on"}
      {name: "In Review", color: PURPLE, description: "PR submitted, awaiting review"}
      {name: "Done", color: GREEN, description: "Closed/merged"}
    ]
  }) {
    projectV2Field {
      ... on ProjectV2SingleSelectField {
        name
        options { name color description }
      }
    }
  }
}'
```

### 2. Create Priority field

**Date**: 2026-01-10

Add Priority single select field for work prioritization.

```bash
# Create field with options
gh project field-create 4 --owner ricon-family --name "Priority" --data-type SINGLE_SELECT --single-select-options "High,Medium,Low"

# Update colors and descriptions (field ID from creation)
gh api graphql -f query='
mutation {
  updateProjectV2Field(input: {
    fieldId: "PVTSSF_lADODumhvM4BMSWkzg7p3iw"
    singleSelectOptions: [
      {name: "High", color: RED, description: "Urgent work"}
      {name: "Medium", color: YELLOW, description: "Important but not urgent"}
      {name: "Low", color: BLUE, description: "Nice to have"}
    ]
  }) {
    projectV2Field {
      ... on ProjectV2SingleSelectField {
        name
        options { name color description }
      }
    }
  }
}'
```

### 3. Create Iteration field

**Date**: 2026-01-10

Add Iteration field for sprint planning (2-week cycles). CLI doesn't support ITERATION type, must use GraphQL.

```bash
# Get project ID first
gh api graphql -f query='
query {
  organization(login: "ricon-family") {
    projectV2(number: 4) { id }
  }
}'
# Returns: PVT_kwDODumhvM4BMSWk

# Create iteration field
gh api graphql -f query='
mutation {
  createProjectV2Field(input: {
    projectId: "PVT_kwDODumhvM4BMSWk"
    dataType: ITERATION
    name: "Iteration"
    iterationConfiguration: {
      startDate: "2026-01-13"
      duration: 14
      iterations: []
    }
  }) {
    projectV2Field {
      ... on ProjectV2IterationField { id name }
    }
  }
}'
# Returns field ID: PVTIF_lADODumhvM4BMSWkzg7p36M

# Add initial iterations
gh api graphql -f query='
mutation {
  updateProjectV2Field(input: {
    fieldId: "PVTIF_lADODumhvM4BMSWkzg7p36M"
    iterationConfiguration: {
      startDate: "2026-01-13"
      duration: 14
      iterations: [
        {title: "Iteration 1", startDate: "2026-01-13", duration: 14}
        {title: "Iteration 2", startDate: "2026-01-27", duration: 14}
        {title: "Iteration 3", startDate: "2026-02-10", duration: 14}
      ]
    }
  }) {
    projectV2Field {
      ... on ProjectV2IterationField {
        name
        configuration { iterations { title startDate duration } }
      }
    }
  }
}'
```

### 4. Workflows and Views (Web UI required)

**Date**: 2026-01-10

These cannot be configured via CLI/API - must use web UI at:
https://github.com/orgs/ricon-family/projects/4/settings

**Workflows to enable:**
- [ ] Item closed → Set Status to "Done"
- [ ] Pull request merged → Set Status to "Done"
- [ ] Auto-archive items: `is:closed updated:<@today-14d`
- [ ] Auto-add from repository: ricon-family/shimmer

**Views to create:**
- [ ] Backlog (table, group by Priority)
- [ ] Sprint Board (board, filter `iteration:@current`, columns by Status)
- [ ] My Work (table, filter `assignee:@me`)

### 5. Delete `bug` label

**Date**: 2026-01-10

Remove label that overlaps with Issue Types.

```bash
gh label delete bug --repo ricon-family/shimmer --yes
```

### 6. Delete `enhancement` label

**Date**: 2026-01-10

Remove label that overlaps with Issue Types (use "Feature" type instead).

```bash
gh label delete enhancement --repo ricon-family/shimmer --yes
```
