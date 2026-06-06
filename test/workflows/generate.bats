#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load ../helpers
}

ROSTER="tinef schmendrik nudnik"

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
for arg in "$@"; do
  if [ "$arg" = "--json" ]; then
    cat <<'JSON'
[
  {"name":"tinef","ci":true,"github_login":"dreckbot"},
  {"name":"schmendrik","ci":true,"github_login":"shmegegge"}
]
JSON
    exit 0
  fi
done
printf 'tinef\n'
printf 'schmendrik\n'
EOF
  chmod +x "$TARGET_REPO/.mise/tasks/agent/list"

  cat > "$TARGET_REPO/workflows.yaml" <<'EOF'
workflows:
  - name: daily-probe
    agent: tinef
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

github_output_get() {
  local key="$1"
  local file="$2"
  local line delimiter value

  while IFS= read -r line; do
    case "$line" in
      "$key="*)
        printf '%s\n' "${line#*=}"
        return 0
        ;;
      "$key<<"*)
        delimiter="${line#*<<}"
        value=""
        while IFS= read -r line; do
          if [ "$line" = "$delimiter" ]; then
            printf '%s\n' "$value"
            return 0
          fi
          if [ -n "$value" ]; then
            value="$value"$'\n'"$line"
          else
            value="$line"
          fi
        done
        ;;
    esac
  done < "$file"

  return 1
}

expected_agents_json() {
  if [ "$#" -eq 0 ]; then
    printf '[]\n'
    return 0
  fi
  printf '%s\n' "$@" | jq -R . | jq -s -c .
}

agent_expected() {
  local agent="$1"
  shift
  local expected
  for expected in "$@"; do
    [ "$agent" = "$expected" ] && return 0
  done
  return 1
}

agent_login() {
  case "$1" in
    tinef) printf 'dreckbot\n' ;;
    schmendrik) printf 'shmegegge\n' ;;
    nudnik) printf 'kvetch-master\n' ;;
    *) return 1 ;;
  esac
}

agent_login_map_json() {
  jq -n -c '{tinef: "dreckbot", schmendrik: "shmegegge", nudnik: "kvetch-master"}'
}

run_detector() {
  local body="$1"
  local association="${2:-MEMBER}"
  local event_path="$BATS_TEST_TMPDIR/event.json"
  DETECTOR_OUTPUT="$BATS_TEST_TMPDIR/github-output.txt"
  export DETECTOR_OUTPUT

  jq -n \
    --arg body "$body" \
    --arg association "$association" \
    '{
      repository: {full_name: "ricon-family/fold"},
      issue: {number: 72, html_url: "https://github.com/ricon-family/fold/issues/72"},
      comment: {
        html_url: "https://github.com/ricon-family/fold/issues/72#issuecomment-test",
        author_association: $association,
        user: {login: "dreckbot"},
        body: $body
      }
    }' > "$event_path"

  : > "$DETECTOR_OUTPUT"
  GITHUB_EVENT_PATH="$event_path" \
    GITHUB_OUTPUT="$DETECTOR_OUTPUT" \
    AGENT_ROSTER="${ROSTER// /,}" \
    AGENT_GITHUB_LOGINS="$(agent_login_map_json)" \
    TEAM_ALIASES="" \
    ALLOWED_ASSOCIATIONS="OWNER,MEMBER" \
    python3 "$SHIMMER_DIR/.github/templates/agent-mention-detect.py"
}

assert_detector_case() {
  local name="$1"
  local body="$2"
  local association="$3"
  shift 3
  local expected_agents=("$@")
  local expected_wake="false"
  local agent key expected actual

  if [ "${#expected_agents[@]}" -gt 0 ]; then
    expected_wake="true"
  fi

  run_detector "$body" "$association"

  actual=$(github_output_get should_wake "$DETECTOR_OUTPUT")
  [ "$actual" = "$expected_wake" ] || {
    echo "$name: expected should_wake=$expected_wake, got $actual" >&2
    cat "$DETECTOR_OUTPUT" >&2
    return 1
  }

  for agent in $ROSTER; do
    key="agent_${agent//-/_}"
    expected="false"
    if agent_expected "$agent" "${expected_agents[@]}"; then
      expected="true"
    fi
    actual=$(github_output_get "$key" "$DETECTOR_OUTPUT")
    [ "$actual" = "$expected" ] || {
      echo "$name: expected $key=$expected, got $actual" >&2
      cat "$DETECTOR_OUTPUT" >&2
      return 1
    }
  done

  if [ "${#expected_agents[@]}" -gt 0 ]; then
    actual=$(github_output_get matched_agents "$DETECTOR_OUTPUT")
    expected=$(expected_agents_json "${expected_agents[@]}")
    [ "$actual" = "$expected" ] || {
      echo "$name: expected matched_agents=$expected, got $actual" >&2
      cat "$DETECTOR_OUTPUT" >&2
      return 1
    }
  fi
}

@test "workflows:generate composes scheduled and mention wakes through per-agent wrappers" {
  make_target_repo

  run generate_workflows
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }

  tinef_workflow="$TARGET_REPO/.github/workflows/tinef.yml"
  schmendrik_workflow="$TARGET_REPO/.github/workflows/schmendrik.yml"
  scheduled_workflow="$TARGET_REPO/.github/workflows/daily-probe.yml"
  mention_workflow="$TARGET_REPO/.github/workflows/agent-mention.yml"
  mention_script="$TARGET_REPO/.github/scripts/agent-mention-detect.py"

  [ -f "$tinef_workflow" ]
  [ -f "$schmendrik_workflow" ]
  [ -f "$scheduled_workflow" ]
  [ -f "$mention_workflow" ]
  [ -f "$mention_script" ]

  [ "$(yq -r '.on.workflow_dispatch.inputs.message.required' "$tinef_workflow")" = "true" ]
  [ "$(yq -r '.on.workflow_call.inputs.message.required' "$tinef_workflow")" = "true" ]
  [ "$(yq -r '.on.workflow_call.secrets.TINEF_GITHUB_PAT.required' "$tinef_workflow")" = "true" ]
  [ "$(yq -r '.jobs.run.uses' "$tinef_workflow")" = "./.github/workflows/agent-run.yml" ]
  [ "$(yq -r '.jobs.run.with.agent' "$tinef_workflow")" = "tinef" ]
  [ "$(yq -r '.jobs.run.secrets.AGENT_GITHUB_PAT' "$tinef_workflow")" = '${{ secrets.TINEF_GITHUB_PAT }}' ]
  [ "$(yq -r '.jobs.run.secrets.AGENT_B2_ENDPOINT' "$tinef_workflow")" = '${{ secrets.TINEF_B2_ENDPOINT }}' ]

  [ "$(yq -r '.on.workflow_call.secrets.SCHMENDRIK_GITHUB_PAT.required' "$schmendrik_workflow")" = "true" ]
  [ "$(yq -r '.jobs.run.secrets.AGENT_GITHUB_PAT' "$schmendrik_workflow")" = '${{ secrets.SCHMENDRIK_GITHUB_PAT }}' ]

  [ "$(yq -r '.jobs.run.uses' "$scheduled_workflow")" = "./.github/workflows/tinef.yml" ]
  [ "$(yq -r '.jobs.run.secrets' "$scheduled_workflow")" = "inherit" ]
  ! grep -q 'AGENT_GITHUB_PAT' "$scheduled_workflow"

  [ "$(yq -r '.on.issue_comment.types[0]' "$mention_workflow")" = "created" ]
  ! grep -q 'jdx/mise-action' "$mention_workflow"
  [ "$(yq -r '.jobs.detect.outputs.agent_tinef' "$mention_workflow")" = '${{ steps.detect.outputs.agent_tinef }}' ]
  [ "$(yq -r '.jobs.detect.outputs.agent_schmendrik' "$mention_workflow")" = '${{ steps.detect.outputs.agent_schmendrik }}' ]
  [ "$(yq -r '.jobs."wake-tinef".uses' "$mention_workflow")" = "./.github/workflows/tinef.yml" ]
  [ "$(yq -r '.jobs."wake-schmendrik".uses' "$mention_workflow")" = "./.github/workflows/schmendrik.yml" ]
  [ "$(yq -r '.jobs."wake-tinef".secrets' "$mention_workflow")" = "inherit" ]
  [ "$(yq -r '.jobs."wake-tinef".with.model' "$mention_workflow")" = "openai-codex/gpt-5.5" ]
  [ "$(yq -r '.jobs.detect.steps[] | select(.id == "detect") | .env.AGENT_ROSTER' "$mention_workflow")" = "tinef,schmendrik" ]
  yq -r '.jobs.detect.steps[] | select(.id == "detect") | .env.AGENT_GITHUB_LOGINS' "$mention_workflow" \
    | jq -e '.tinef == "dreckbot" and .schmendrik == "shmegegge"' >/dev/null
  [ "$(yq -r '.jobs.detect.steps[] | select(.id == "detect") | .env.ALLOWED_ASSOCIATIONS' "$mention_workflow")" = "OWNER,MEMBER" ]
  [ "$(yq -r '.jobs.detect.steps[] | select(.id == "detect") | .run' "$mention_workflow")" = "python3 .github/scripts/agent-mention-detect.py" ]
}

@test "workflows:generate requires JSON GitHub logins for mention wakes" {
  make_target_repo

  cat > "$TARGET_REPO/.mise/tasks/agent/list" <<'EOF'
#!/usr/bin/env bash
printf 'tinef\n'
printf 'schmendrik\n'
EOF
  chmod +x "$TARGET_REPO/.mise/tasks/agent/list"

  run generate_workflows
  [ "$status" -ne 0 ]
  [[ "$output" == *"mention_wakes requires agent:list --ci --json records with github_login"* ]]

  cat > "$TARGET_REPO/.mise/tasks/agent/list" <<'EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  if [ "$arg" = "--json" ]; then
    printf '[{"name":"tinef","ci":true}]\n'
    exit 0
  fi
done
printf 'tinef\n'
EOF
  chmod +x "$TARGET_REPO/.mise/tasks/agent/list"

  run generate_workflows
  [ "$status" -ne 0 ]
  [[ "$output" == *"mention_wakes requires github_login for every agent"* ]]

  cat > "$TARGET_REPO/.mise/tasks/agent/list" <<'EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  if [ "$arg" = "--json" ]; then
    printf '[{"name":"tinef","ci":true,"github_login":["dreckbot"]}]\n'
    exit 0
  fi
done
printf 'tinef\n'
EOF
  chmod +x "$TARGET_REPO/.mise/tasks/agent/list"

  run generate_workflows
  [ "$status" -ne 0 ]
  [[ "$output" == *"mention_wakes requires github_login for every agent"* ]]
}

@test "workflows:generate uses agent:list JSON GitHub logins for mention wakes" {
  make_target_repo

  cat > "$TARGET_REPO/.mise/tasks/agent/list" <<'EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  if [ "$arg" = "--json" ]; then
    cat <<'JSON'
[
  {"name":"nudnik","ci":true,"github_login":"kvetch-master"},
  {"name":"tinef","ci":true,"github_login":"dreckbot"}
]
JSON
    exit 0
  fi
done
printf 'nudnik\n'
printf 'tinef\n'
EOF
  chmod +x "$TARGET_REPO/.mise/tasks/agent/list"

  cat > "$TARGET_REPO/workflows.yaml" <<'EOF'
workflows:
  - name: daily-probe
    agent: nudnik
    model: openai-codex/gpt-5.5
    schedule:
      - "0 15 * * *"
    message: "Review the daily probe."
mention_wakes:
  enabled: true
  model: openai-codex/gpt-5.5
EOF

  run generate_workflows
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }

  mention_workflow="$TARGET_REPO/.github/workflows/agent-mention.yml"
  [ "$(yq -r '.jobs.detect.steps[] | select(.id == "detect") | .env.AGENT_ROSTER' "$mention_workflow")" = "nudnik,tinef" ]
  yq -r '.jobs.detect.steps[] | select(.id == "detect") | .env.AGENT_GITHUB_LOGINS' "$mention_workflow" \
    | jq -e '.nudnik == "kvetch-master" and .tinef == "dreckbot"' >/dev/null
  [ "$(yq -r '.jobs."wake-nudnik".uses' "$mention_workflow")" = "./.github/workflows/nudnik.yml" ]
}

@test "workflows:generate --check covers mention workflow and detector script" {
  make_target_repo
  generate_workflows

  run generate_workflows --check
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }

  printf 'legacy detector\n' > "$TARGET_REPO/.github/scripts/agent-mention-detect.nu"

  run generate_workflows --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unexpected: .github/scripts/agent-mention-detect.nu (legacy Nushell mention detector"* ]]

  rm "$TARGET_REPO/.github/scripts/agent-mention-detect.nu"
  printf '\n# drift\n' >> "$TARGET_REPO/.github/scripts/agent-mention-detect.py"

  run generate_workflows --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"Differs: .github/scripts/agent-mention-detect.py"* ]]
}

@test "workflows:generate quotes scheduled message and model as YAML scalars" {
  make_target_repo

  cat > "$TARGET_REPO/workflows.yaml" <<'EOF'
workflows:
  - name: weird-message
    agent: tinef
    model: huggingface/moonshotai/Kimi-K2.6:novita
    schedule:
      - "0 15 * * *"
    message: |
      line one
      permissions: write-all
      jobs:
        pwn:
          runs-on: ubuntu-latest
mention_wakes:
  enabled: true
  model: huggingface/moonshotai/Kimi-K2.6:novita
EOF

  run generate_workflows
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }

  scheduled_workflow="$TARGET_REPO/.github/workflows/weird-message.yml"
  mention_workflow="$TARGET_REPO/.github/workflows/agent-mention.yml"

  [ "$(yq -r '.jobs.run.with.message' "$scheduled_workflow")" = $'line one\npermissions: write-all\njobs:\n  pwn:\n    runs-on: ubuntu-latest' ]
  [ "$(yq -r '.jobs.run.with.model' "$scheduled_workflow")" = "huggingface/moonshotai/Kimi-K2.6:novita" ]
  [ "$(yq -r '.jobs.run' "$scheduled_workflow")" != "null" ]
  [ "$(yq -r '.jobs.pwn' "$scheduled_workflow")" = "null" ]
  [ "$(yq -r '.permissions' "$scheduled_workflow")" = "null" ]
  [ "$(yq -r '.jobs."wake-tinef".with.model' "$mention_workflow")" = "huggingface/moonshotai/Kimi-K2.6:novita" ]
}

@test "workflows:generate rejects unsafe or duplicate agent names" {
  make_target_repo

  cat > "$TARGET_REPO/.mise/tasks/agent/list" <<'EOF'
#!/usr/bin/env bash
printf 'tinef\n'
printf '../scripts/owned\n'
EOF
  chmod +x "$TARGET_REPO/.mise/tasks/agent/list"

  run generate_workflows
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid agent name '../scripts/owned'"* ]]

  cat > "$TARGET_REPO/.mise/tasks/agent/list" <<'EOF'
#!/usr/bin/env bash
printf '123\n'
EOF
  chmod +x "$TARGET_REPO/.mise/tasks/agent/list"

  run generate_workflows
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid agent name '123'"* ]]

  cat > "$TARGET_REPO/.mise/tasks/agent/list" <<'EOF'
#!/usr/bin/env bash
printf 'tinef\n'
printf 'tinef\n'
EOF
  chmod +x "$TARGET_REPO/.mise/tasks/agent/list"

  run generate_workflows
  [ "$status" -ne 0 ]
  [[ "$output" == *"generated workflow name 'tinef' from agent:list entry 'tinef' conflicts"* ]]
}

@test "workflows:generate rejects scheduled workflow name collisions and unknown agents" {
  make_target_repo

  cat > "$TARGET_REPO/workflows.yaml" <<'EOF'
workflows:
  - name: tinef
    agent: tinef
    model: openai-codex/gpt-5.5
    schedule:
      - "0 15 * * *"
    message: "Do not overwrite the tinef wrapper."
EOF

  run generate_workflows
  [ "$status" -ne 0 ]
  [[ "$output" == *"generated workflow name 'tinef' from workflow 'tinef' conflicts"* ]]

  cat > "$TARGET_REPO/workflows.yaml" <<'EOF'
workflows:
  - name: agent-run
    agent: tinef
    model: openai-codex/gpt-5.5
    schedule:
      - "0 15 * * *"
    message: "Do not overwrite the reusable runner."
EOF

  run generate_workflows
  [ "$status" -ne 0 ]
  [[ "$output" == *"generated workflow name 'agent-run' from workflow 'agent-run' conflicts"* ]]

  cat > "$TARGET_REPO/workflows.yaml" <<'EOF'
workflows:
  - name: repeated
    agent: tinef
    model: openai-codex/gpt-5.5
    schedule:
      - "0 15 * * *"
    message: "First."
  - name: repeated
    agent: tinef
    model: openai-codex/gpt-5.5
    schedule:
      - "0 16 * * *"
    message: "Second."
EOF

  run generate_workflows
  [ "$status" -ne 0 ]
  [[ "$output" == *"generated workflow name 'repeated' from workflow 'repeated' conflicts"* ]]

  cat > "$TARGET_REPO/.mise/tasks/agent/list" <<'EOF'
#!/usr/bin/env bash
printf 'tinef\n'
EOF
  chmod +x "$TARGET_REPO/.mise/tasks/agent/list"

  cat > "$TARGET_REPO/workflows.yaml" <<'EOF'
workflows:
  - name: daily-probe
    agent: schmendrik
    model: openai-codex/gpt-5.5
    schedule:
      - "0 15 * * *"
    message: "Review the daily probe."
EOF

  run generate_workflows
  [ "$status" -ne 0 ]
  [[ "$output" == *"workflow 'daily-probe' references agent 'schmendrik', but agent:list did not report that agent"* ]]
}

@test "workflows:generate removes stale mention files when mention_wakes is disabled" {
  make_target_repo
  generate_workflows

  cat > "$TARGET_REPO/workflows.yaml" <<'EOF'
workflows:
  - name: daily-probe
    agent: tinef
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
  [ ! -f "$TARGET_REPO/.github/scripts/agent-mention-detect.nu" ]

  printf 'stale workflow\n' > "$TARGET_REPO/.github/workflows/agent-mention.yml"
  mkdir -p "$TARGET_REPO/.github/scripts"
  printf 'stale detector\n' > "$TARGET_REPO/.github/scripts/agent-mention-detect.py"
  printf 'stale detector\n' > "$TARGET_REPO/.github/scripts/agent-mention-detect.nu"

  run generate_workflows --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unexpected: .github/workflows/agent-mention.yml"* ]]
  [[ "$output" == *"Unexpected: .github/scripts/agent-mention-detect.py"* ]]
  [[ "$output" == *"Unexpected: .github/scripts/agent-mention-detect.nu"* ]]
}

@test "workflows:generate removes stale generated workflow files" {
  make_target_repo
  generate_workflows

  [ -f "$TARGET_REPO/.github/workflows/daily-probe.yml" ]
  [ -f "$TARGET_REPO/.github/workflows/schmendrik.yml" ]

  cat > "$TARGET_REPO/.github/workflows/manual.yml" <<'EOF'
name: manual
on: workflow_dispatch
jobs: {}
EOF

  cat > "$TARGET_REPO/workflows.yaml" <<'EOF'
workflows:
  - name: renamed-probe
    agent: tinef
    model: openai-codex/gpt-5.5
    schedule:
      - "0 16 * * *"
    message: "Review the renamed probe."
EOF

  cat > "$TARGET_REPO/.mise/tasks/agent/list" <<'EOF'
#!/usr/bin/env bash
printf 'tinef\n'
EOF
  chmod +x "$TARGET_REPO/.mise/tasks/agent/list"

  run generate_workflows --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unexpected: .github/workflows/daily-probe.yml (stale generated workflow"* ]]
  [[ "$output" == *"Unexpected: .github/workflows/schmendrik.yml (stale generated workflow"* ]]

  run generate_workflows
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }

  [ -f "$TARGET_REPO/.github/workflows/renamed-probe.yml" ]
  [ -f "$TARGET_REPO/.github/workflows/tinef.yml" ]
  [ ! -f "$TARGET_REPO/.github/workflows/daily-probe.yml" ]
  [ ! -f "$TARGET_REPO/.github/workflows/schmendrik.yml" ]
  [ -f "$TARGET_REPO/.github/workflows/manual.yml" ]
}

@test "agent mention detector ignores non-waking text and maps handles" {
  local agent
  for agent in $ROSTER; do
    assert_detector_case "$agent configured login" "@$(agent_login "$agent") hello" MEMBER "$agent"
  done

  assert_detector_case "configured login is exact" "@tinef-gh hello" MEMBER
  assert_detector_case "multiple individual handles" "@dreckbot @shmegegge" MEMBER tinef schmendrik
  assert_detector_case "naked tinef does not match" "@tinef hello" MEMBER
  assert_detector_case "naked agents does not match" "@agents hello" MEMBER
  assert_detector_case "team alias disabled" "@faketown/agents hello" MEMBER
  assert_detector_case "quoted handle ignored" "> @dreckbot quoted" MEMBER
  assert_detector_case "fenced handle ignored" $'```\n@dreckbot fenced\n```' MEMBER
  assert_detector_case "inline code handle ignored" 'Type `@dreckbot` only when waking tinef.' MEMBER
  assert_detector_case "nested path does not partial match" "@dreckbot/foo no" MEMBER
  assert_detector_case "collaborator association ignored" "@dreckbot hello" COLLABORATOR
  assert_detector_case "untrusted association ignored" "@dreckbot hello" NONE
}
