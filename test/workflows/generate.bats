#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load ../helpers
}

make_target_repo() {
  TARGET_REPO="$BATS_TEST_TMPDIR/target-repo"
  mkdir -p "$TARGET_REPO/.mise/tasks/agent"

  cat > "$TARGET_REPO/mise.toml" <<'EOF'
[settings]
quiet = true
task_output = "interleave"
EOF
  mise trust "$TARGET_REPO/mise.toml" >/dev/null 2>&1

  cat > "$TARGET_REPO/.mise/tasks/agent/list" <<'EOF'
#!/usr/bin/env bash
printf 'quick\n'
printf 'c0da\n'
EOF
  chmod +x "$TARGET_REPO/.mise/tasks/agent/list"

  cat > "$TARGET_REPO/workflows.yaml" <<'EOF'
workflows:
  - name: daily-probe
    agent: quick
    model: openai-codex/gpt-5.5
    schedule:
      - "0 15 * * *"
    message: "Review the daily probe."

mention_wakes:
  enabled: true
  model: openai-codex/gpt-5.5
  allowed_associations: [OWNER, MEMBER]
EOF
}

generate_workflows() {
  PROJECT_DIR="$TARGET_REPO" mise -C "$SHIMMER_DIR" run -q workflows:generate "$@"
}

@test "workflows:generate composes scheduled and mention wakes through per-agent wrappers" {
  make_target_repo

  run generate_workflows
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }

  quick_workflow="$TARGET_REPO/.github/workflows/quick.yml"
  c0da_workflow="$TARGET_REPO/.github/workflows/c0da.yml"
  scheduled_workflow="$TARGET_REPO/.github/workflows/daily-probe.yml"
  mention_workflow="$TARGET_REPO/.github/workflows/agent-mention.yml"
  mention_script="$TARGET_REPO/.github/scripts/agent-mention-detect.py"

  [ -f "$quick_workflow" ]
  [ -f "$c0da_workflow" ]
  [ -f "$scheduled_workflow" ]
  [ -f "$mention_workflow" ]
  [ -f "$mention_script" ]

  [ "$(yq -r '.on.workflow_dispatch.inputs.message.required' "$quick_workflow")" = "true" ]
  [ "$(yq -r '.on.workflow_call.inputs.message.required' "$quick_workflow")" = "true" ]
  [ "$(yq -r '.on.workflow_call.secrets.QUICK_GITHUB_PAT.required' "$quick_workflow")" = "true" ]
  [ "$(yq -r '.jobs.run.uses' "$quick_workflow")" = "./.github/workflows/agent-run.yml" ]
  [ "$(yq -r '.jobs.run.with.agent' "$quick_workflow")" = "quick" ]
  [ "$(yq -r '.jobs.run.secrets.AGENT_GITHUB_PAT' "$quick_workflow")" = '${{ secrets.QUICK_GITHUB_PAT }}' ]
  [ "$(yq -r '.jobs.run.secrets.AGENT_B2_ENDPOINT' "$quick_workflow")" = '${{ secrets.QUICK_B2_ENDPOINT }}' ]

  [ "$(yq -r '.on.workflow_call.secrets.C0DA_GITHUB_PAT.required' "$c0da_workflow")" = "true" ]
  [ "$(yq -r '.jobs.run.secrets.AGENT_GITHUB_PAT' "$c0da_workflow")" = '${{ secrets.C0DA_GITHUB_PAT }}' ]

  [ "$(yq -r '.jobs.run.uses' "$scheduled_workflow")" = "./.github/workflows/quick.yml" ]
  [ "$(yq -r '.jobs.run.secrets' "$scheduled_workflow")" = "inherit" ]
  ! grep -q 'AGENT_GITHUB_PAT' "$scheduled_workflow"

  [ "$(yq -r '.on.issue_comment.types[0]' "$mention_workflow")" = "created" ]
  [ "$(yq -r '.jobs.detect.outputs.agent_quick' "$mention_workflow")" = '${{ steps.detect.outputs.agent_quick }}' ]
  [ "$(yq -r '.jobs.detect.outputs.agent_c0da' "$mention_workflow")" = '${{ steps.detect.outputs.agent_c0da }}' ]
  [ "$(yq -r '.jobs."wake-quick".uses' "$mention_workflow")" = "./.github/workflows/quick.yml" ]
  [ "$(yq -r '.jobs."wake-c0da".uses' "$mention_workflow")" = "./.github/workflows/c0da.yml" ]
  [ "$(yq -r '.jobs."wake-quick".secrets' "$mention_workflow")" = "inherit" ]
  [ "$(yq -r '.jobs."wake-quick".with.model' "$mention_workflow")" = "openai-codex/gpt-5.5" ]
  [ "$(yq -r '.jobs.detect.steps[] | select(.id == "detect") | .env.AGENT_ROSTER' "$mention_workflow")" = "quick,c0da" ]
  [ "$(yq -r '.jobs.detect.steps[] | select(.id == "detect") | .env.ALLOWED_ASSOCIATIONS' "$mention_workflow")" = "OWNER,MEMBER" ]
}

@test "workflows:generate --check covers mention workflow and detector script" {
  make_target_repo
  generate_workflows

  run generate_workflows --check
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }

  printf '\n# drift\n' >> "$TARGET_REPO/.github/scripts/agent-mention-detect.py"

  run generate_workflows --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"Differs: .github/scripts/agent-mention-detect.py"* ]]
}

@test "workflows:generate removes stale mention files when mention_wakes is disabled" {
  make_target_repo
  generate_workflows

  cat > "$TARGET_REPO/workflows.yaml" <<'EOF'
workflows:
  - name: daily-probe
    agent: quick
    model: openai-codex/gpt-5.5
    schedule:
      - "0 15 * * *"
    message: "Review the daily probe."
EOF

  run generate_workflows
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }

  [ ! -f "$TARGET_REPO/.github/workflows/agent-mention.yml" ]
  [ ! -f "$TARGET_REPO/.github/scripts/agent-mention-detect.py" ]

  printf 'stale workflow\n' > "$TARGET_REPO/.github/workflows/agent-mention.yml"
  mkdir -p "$TARGET_REPO/.github/scripts"
  printf 'stale detector\n' > "$TARGET_REPO/.github/scripts/agent-mention-detect.py"

  run generate_workflows --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unexpected: .github/workflows/agent-mention.yml"* ]]
  [[ "$output" == *"Unexpected: .github/scripts/agent-mention-detect.py"* ]]
}

@test "agent mention detector smoke tests pass" {
  run python3 "$BATS_TEST_DIRNAME/agent_mention_detect_test.py"
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }
  [[ "$output" == *"agent mention detector tests: ok"* ]]
}
