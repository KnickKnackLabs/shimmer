#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load helpers
}

# --- Workflow template ---

@test "workflow: prepares repo env then runs repo agent with log markers" {
  template="$SHIMMER_DIR/.github/templates/agent-run.yml"

  agent=$(yq -r '.jobs.run.env.AGENT // ""' "$template")
  agent_home=$(yq -r '.jobs.run.env.AGENT_HOME // ""' "$template")
  dispatch_repo=$(yq -r '.jobs.run.env.DISPATCH_REPO // ""' "$template")
  input_message=$(yq -r '.jobs.run.env.INPUT_MESSAGE // ""' "$template")
  input_model=$(yq -r '.jobs.run.env.INPUT_MODEL // ""' "$template")
  run_timeout=$(yq -r '.jobs.run.env.RUN_TIMEOUT // ""' "$template")
  checkout_uses=$(yq -r '.jobs.run.steps[] | select(.name == "Checkout workflow repo") | .uses // ""' "$template")
  checkout_index=$(yq -r '.jobs.run.steps | to_entries[] | select(.value.name == "Checkout workflow repo") | .key' "$template")
  mise_index=$(yq -r '.jobs.run.steps | to_entries[] | select(.value.name == "Set up mise") | .key' "$template")
  secrets_index=$(yq -r '.jobs.run.steps | to_entries[] | select(.value.name == "Setup secrets for env provider") | .key' "$template")
  mise_install=$(yq -r '.jobs.run.steps[] | select(.name == "Set up mise") | .with.install' "$template")
  mise_cache=$(yq -r '.jobs.run.steps[] | select(.name == "Set up mise") | .with.cache' "$template")
  mise_cache_key=$(yq -r '.jobs.run.steps[] | select(.name == "Set up mise") | .with.cache_key // ""' "$template")
  mise_data_dir=$(yq -r '.jobs.run.env.MISE_DATA_DIR // ""' "$template")
  uv_python_dir=$(yq -r '.jobs.run.env.UV_PYTHON_INSTALL_DIR // ""' "$template")
  uv_managed_python=$(yq -r '.jobs.run.env.UV_MANAGED_PYTHON // ""' "$template")
  mise_jobs=$(yq -r '.jobs.run.env.MISE_JOBS // ""' "$template")
  env_run=$(yq -r '.jobs.run.steps[] | select(.name == "Prepare repo CI environment") | .run // ""' "$template")
  agent_run=$(yq -r '.jobs.run.steps[] | select(.name == "Run agent") | .run // ""' "$template")
  env_pi_auth=$(yq -r '.jobs.run.steps[] | select(.name == "Prepare repo CI environment") | .env.PI_AUTH_JSON // ""' "$template")
  agent_hf_token=$(yq -r '.jobs.run.steps[] | select(.name == "Run agent") | .env.HF_TOKEN // ""' "$template")

  [ "$agent" = '${{ inputs.agent }}' ]
  [ "$agent_home" = '/home/runner/agents/${{ inputs.agent }}/home' ]
  [ "$dispatch_repo" = '${{ github.repository }}' ]
  [ "$input_message" = '${{ inputs.message }}' ]
  [ "$input_model" = '${{ inputs.model }}' ]
  [ "$run_timeout" = "900" ]
  [ "$mise_install" = "true" ]
  [ "$mise_cache" = "true" ]
  [ "$mise_cache_key" = 'agent-mise-v1-{{platform}}-{{file_hash}}' ]
  [ "$checkout_uses" = "actions/checkout@v6" ]
  [ "$checkout_index" -lt "$mise_index" ]
  [ "$mise_index" -lt "$secrets_index" ]
  [ "$mise_data_dir" = "/home/runner/.local/share/mise" ]
  [ "$uv_python_dir" = "/home/runner/.local/share/mise/uv-python" ]
  [ "$uv_managed_python" = "1" ]
  [ "$mise_jobs" = "1" ]
  ! echo "$env_run" | grep -qF 'mise trust'
  ! echo "$env_run" | grep -qF 'mise install'
  [ "$env_run" = "mise run ci:env" ]
  [ "$env_pi_auth" = '${{ secrets.PI_AUTH_JSON }}' ]
  echo "$agent_run" | grep -qF '### AGENT SESSION START ###'
  echo "$agent_run" | grep -qF 'status=0'
  echo "$agent_run" | grep -qF 'mise agent || status=$?'
  echo "$agent_run" | grep -qF '### AGENT SESSION END ###'
  echo "$agent_run" | grep -qF 'exit "$status"'
  [ "$agent_hf_token" = '${{ secrets.HF_TOKEN }}' ]

  ! grep -qF 'mise run agent:prepare' "$template"
  ! grep -qF 'shimmer gpg:setup' "$template"
  ! grep -qF 'shimmer agent --headless' "$template"
  grep -qF 'du -sh "$AGENT_HOME"' "$template"
}

@test "workflow: mise cache keeps current-version resolution separate from the tool key" {
  template="$SHIMMER_DIR/.github/templates/agent-run.yml"

  resolve_step=$(yq -r '.jobs.run.steps[] | select(.name == "Resolve mise version") | .run // ""' "$template")
  resolve_id=$(yq -r '.jobs.run.steps[] | select(.name == "Resolve mise version") | .id // ""' "$template")
  mise_version=$(yq -r '.jobs.run.steps[] | select(.name == "Set up mise") | .with.version // ""' "$template")
  mise_cache_key=$(yq -r '.jobs.run.steps[] | select(.name == "Set up mise") | .with.cache_key // ""' "$template")

  [ "$resolve_id" = "mise-version" ]
  echo "$resolve_step" | grep -qF 'curl -fsSL --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 2 --retry-all-errors https://mise.jdx.dev/VERSION'
  echo "$resolve_step" | grep -qF 'version=${version%$'"'"'\r'"'"'}'
  echo "$resolve_step" | grep -qF 'Unexpected mise version'
  echo "$resolve_step" | grep -qF 'GITHUB_OUTPUT'
  [ "$mise_version" = '${{ steps.mise-version.outputs.version }}' ]
  [ "$mise_cache_key" = 'agent-mise-v1-{{platform}}-{{file_hash}}' ]
  [[ "$mise_cache_key" != *'{{version}}'* ]]
}

@test "workflow: exposes provider and pi auth to repo tasks" {
  template="$SHIMMER_DIR/.github/templates/agent-run.yml"

  hf_token_declared=$(yq -r '.on.workflow_call.secrets.HF_TOKEN | has("required")' "$template")
  hf_token_required=$(yq -r '.on.workflow_call.secrets.HF_TOKEN.required' "$template")
  pi_auth_declared=$(yq -r '.on.workflow_call.secrets.PI_AUTH_JSON | has("required")' "$template")
  pi_auth_required=$(yq -r '.on.workflow_call.secrets.PI_AUTH_JSON.required' "$template")
  env_pi_auth=$(yq -r '.jobs.run.steps[] | select(.name == "Prepare repo CI environment") | .env.PI_AUTH_JSON // ""' "$template")
  agent_hf_token=$(yq -r '.jobs.run.steps[] | select(.name == "Run agent") | .env.HF_TOKEN // ""' "$template")
  agent_anthropic=$(yq -r '.jobs.run.steps[] | select(.name == "Run agent") | .env.ANTHROPIC_API_KEY // ""' "$template")

  [ "$hf_token_declared" = "true" ]
  [ "$hf_token_required" = "false" ]
  [ "$pi_auth_declared" = "true" ]
  [ "$pi_auth_required" = "false" ]
  [ "$env_pi_auth" = '${{ secrets.PI_AUTH_JSON }}' ]
  [ "$agent_hf_token" = '${{ secrets.HF_TOKEN }}' ]
  [ "$agent_anthropic" = '${{ secrets.ANTHROPIC_API_KEY }}' ]
}

@test "workflow: generated per-agent wrappers forward Hugging Face and B2 tokens" {
  scheduled_template="$SHIMMER_DIR/.github/templates/agent-scheduled.yml"
  generator="$SHIMMER_DIR/.mise/tasks/workflows/generate"

  grep -qF 'uses: ./.github/workflows/${AGENT}.yml' "$scheduled_template"
  grep -qF 'secrets: inherit' "$scheduled_template"
  grep -qF 'workflow_call:' "$generator"
  grep -qF 'HF_TOKEN: \${{ secrets.HF_TOKEN }}' "$generator"
  grep -qF 'AGENT_B2_ENDPOINT: \${{ secrets.${agent_upper}_B2_ENDPOINT }}' "$generator"
  grep -qF 'AGENT_B2_APPLICATION_KEY: \${{ secrets.${agent_upper}_B2_APPLICATION_KEY }}' "$generator"
}

@test "workflow: generated agent CI skips Matrix setup" {
  template="$SHIMMER_DIR/.github/templates/agent-run.yml"
  scheduled_template="$SHIMMER_DIR/.github/templates/agent-scheduled.yml"
  generator="$SHIMMER_DIR/.mise/tasks/workflows/generate"

  ! yq -r '.jobs.run.steps[].name' "$template" | grep -qFx 'Setup Matrix'
  ! grep -qF 'AGENT_MATRIX_PASSWORD' "$template"
  ! grep -qF '[MATRIX_PASSWORD]' "$template"
  ! grep -qF 'matrix:login ${{ inputs.agent }}' "$template"
  ! grep -qF 'AGENT_MATRIX_PASSWORD' "$scheduled_template"
  ! grep -qF 'AGENT_MATRIX_PASSWORD' "$generator"
}

@test "workflow: does not eagerly build sessions CLI" {
  template="$SHIMMER_DIR/.github/templates/agent-run.yml"

  step_names=$(yq -r '.jobs.run.steps[].name' "$template")

  ! echo "$step_names" | grep -qFx 'Build sessions CLI'
  ! grep -qF 'sessions cli:build' "$template"
}

@test "workflow: backs up sessions after repo agent run" {
  template="$SHIMMER_DIR/.github/templates/agent-run.yml"

  backup_if=$(yq -r '.jobs.run.steps[] | select(.name == "Back up sessions") | .if // ""' "$template")
  backup_run=$(yq -r '.jobs.run.steps[] | select(.name == "Back up sessions") | .run // ""' "$template")

  [ "$backup_if" = "always()" ]
  echo "$backup_run" | grep -qF 'Agent home not available; skipping session backup'
  echo "$backup_run" | grep -qF 'cd "$AGENT_HOME"'
  echo "$backup_run" | grep -qF 'shimmer sessions:backup --all'
}


# --- Identity checks ---

@test "headless: fails without GIT_AUTHOR_NAME" {
  unset GIT_AUTHOR_NAME
  mock_shimmer

  run shimmer agent --headless "do something"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No agent identity"* ]]
}

@test "headless: does not require legacy identity env" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "do something"
  [ "$status" -eq 0 ]
  grep -q "^wake mock-session-id-001 --headless --message do something --model openai-codex/gpt-5.5" "$SESSIONS_LOG"
}

# --- Headless mode ---

@test "headless: fails without message" {
  setup_agent
  mock_shimmer

  run shimmer agent --headless
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires a message"* ]]
}

@test "headless: fails without model" {
  setup_agent
  mock_shimmer

  run shimmer agent --headless "do something"
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires --model"* ]]
}

@test "headless: fails with unqualified model" {
  setup_agent
  mock_shimmer

  run shimmer agent --headless --model "gpt-5.5" "do something"
  [ "$status" -ne 0 ]
  [[ "$output" == *"provider-qualified"* ]]
}

@test "headless: fails when sessions not on PATH" {
  # Skip if sessions is installed — can't reliably hide it from mise subshell
  command -v sessions &>/dev/null && skip "sessions is installed"

  setup_agent
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "do something"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sessions not found"* ]]
}

@test "headless: checks sessions availability after runtime PATH cleanup" {
  setup_agent
  local home="$BATS_TEST_TMPDIR/path-boundary-home"
  local direct_sessions="$home/.local/share/mise/installs/shiv-sessions/0.4.1/bin"
  mkdir -p "$direct_sessions"
  cat > "$direct_sessions/sessions" <<'MOCK'
#!/usr/bin/env bash
echo "stale direct sessions should not run" >&2
exit 99
MOCK
  chmod +x "$direct_sessions/sessions"

  run env -i \
    HOME="$home" \
    PATH="$direct_sessions:/usr/bin:/bin" \
    MISE_CONFIG_ROOT="$SHIMMER_DIR" \
    GIT_AUTHOR_NAME="test-agent" \
    GIT_AUTHOR_EMAIL="test-agent@ricon.family" \
    usage_headless="true" \
    usage_model="openai-codex/gpt-5.5" \
    usage_message="review the PR" \
    bash "$SHIMMER_DIR/.mise/tasks/agent/_default" # codebase:ignore bats-test-helper — intentional direct invocation to isolate post-cleanup PATH without mise-added shims
  [ "$status" -ne 0 ]
  [[ "$output" == *"sessions not found on PATH"* ]]
  [[ "$output" != *"stale direct sessions should not run"* ]]
}

@test "headless: calls sessions new + wake" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "review the PR"
  [ "$status" -eq 0 ]

  # sessions new was called with agent name in session name
  grep -q "^new test-agent-headless-" "$SESSIONS_LOG"
  # sessions new includes agent.name metadata
  grep "^new " "$SESSIONS_LOG" | grep -q "agent.name=test-agent"
  # sessions new does not receive execution-time model selection
  ! grep "^new " "$SESSIONS_LOG" | grep -q -- "--model"
  # sessions wake was called with the session ID from new and explicit model
  grep -q "^wake mock-session-id-001 --headless --message review the PR --model openai-codex/gpt-5.5" "$SESSIONS_LOG"
}

@test "headless: uses SHIMMER_CALLER_PWD as session cwd before scrubbing" {
  setup_agent
  local caller_dir="$BATS_TEST_TMPDIR/shimmer-caller"
  mkdir -p "$caller_dir"
  unset CALLER_PWD
  export SHIMMER_CALLER_PWD="$caller_dir"
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "review the PR"
  [ "$status" -eq 0 ]

  grep "^new " "$SESSIONS_LOG" | grep -q -- "--cwd $caller_dir"
}

@test "headless: scrubs caller context before invoking sessions" {
  setup_agent
  export SHIMMER_CALLER_PWD="/stale/shimmer/caller"
  export OTHER_CALLER_PWD="/stale/other/caller"
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "review the PR"
  [ "$status" -eq 0 ]

  grep -q '^CALLER_PWD=$' "$SESSIONS_ENV_LOG"
  grep -q '^SHIMMER_CALLER_PWD=$' "$SESSIONS_ENV_LOG"
  grep -q '^OTHER_CALLER_PWD=$' "$SESSIONS_ENV_LOG"
}

@test "headless: removes mise task env and direct install PATH before invoking sessions" {
  setup_agent
  local installs="$HOME/.local/share/mise/installs"
  local stale_sessions="$installs/shiv-sessions/0.4.1/bin"
  local current_sessions="$installs/shiv-sessions/0.4.4/bin"
  export PATH="$stale_sessions:/before:$current_sessions:$PATH"
  export MISE_PROJECT_ROOT="/stale/project"
  export MISE_ORIGINAL_CWD="/stale/original"
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "review the PR"
  [ "$status" -eq 0 ]

  grep -q '^MISE_CONFIG_ROOT=$' "$SESSIONS_ENV_LOG"
  grep -q '^MISE_PROJECT_ROOT=$' "$SESSIONS_ENV_LOG"
  grep -q '^MISE_TASK_NAME=$' "$SESSIONS_ENV_LOG"
  grep -q '^usage_headless=$' "$SESSIONS_ENV_LOG"
  grep -q '^usage_model=$' "$SESSIONS_ENV_LOG"
  grep -q '^usage_message=$' "$SESSIONS_ENV_LOG"
  grep -q '^GIT_AUTHOR_NAME=test-agent$' "$SESSIONS_ENV_LOG"
  grep -q '^GIT_AUTHOR_EMAIL=test-agent@ricon.family$' "$SESSIONS_ENV_LOG"
  grep -q '^PATH=.*/before' "$SESSIONS_ENV_LOG"
  ! grep -q "^PATH=.*$stale_sessions" "$SESSIONS_ENV_LOG"
  ! grep -q "^PATH=.*$current_sessions" "$SESSIONS_ENV_LOG"
}

@test "headless: session name uses full epoch timestamp" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "test"
  [ "$status" -eq 0 ]

  # Extract the session name from the new call — should have full epoch (10+ digits)
  session_name=$(grep "^new " "$SESSIONS_LOG" | awk '{print $2}')
  # Strip prefix to get timestamp portion
  timestamp="${session_name#test-agent-headless-}"
  # Full epoch timestamp is 10 digits (until 2286)
  [ "${#timestamp}" -ge 10 ]
}

@test "headless: resumes existing session (skips sessions new)" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --session "existing-session-42" --model "openai-codex/gpt-5.5" "continue work"
  [ "$status" -eq 0 ]

  # sessions new should NOT be called
  ! grep -q "^new " "$SESSIONS_LOG"
  # sessions wake called with existing session ID
  grep -q "^wake existing-session-42 --headless --message continue work --model openai-codex/gpt-5.5" "$SESSIONS_LOG"
}

@test "headless: forwards model only to sessions wake" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --model "openai-codex/gpt-5.5" "do something"
  [ "$status" -eq 0 ]

  ! grep "^new " "$SESSIONS_LOG" | grep -q -- "--model openai-codex/gpt-5.5"
  grep "^wake " "$SESSIONS_LOG" | grep -q -- "--model openai-codex/gpt-5.5"
}

@test "headless: timeout stored as metadata (not enforced)" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --headless --timeout 300 --model "openai-codex/gpt-5.5" "do something"
  [ "$status" -eq 0 ]

  # timeout passed as metadata on wake, not as a flag
  grep "^wake " "$SESSIONS_LOG" | grep -q "timeout=300"
}

# --- Interactive mode ---

@test "interactive: requires model" {
  setup_agent
  mock_shimmer

  run shimmer agent
  [ "$status" -ne 0 ]
  [[ "$output" == *"--model"* ]]
}

@test "interactive: requires provider-qualified model" {
  setup_agent
  mock_shimmer

  run shimmer agent --model "gpt-5.5"
  [ "$status" -ne 0 ]
  [[ "$output" == *"provider-qualified"* ]]
}

@test "interactive: creates and wakes a sessions-owned runtime without a message" {
  setup_agent
  export AGENT_HARNESS="/usr/bin/false"
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --model "openai-codex/gpt-5.5"
  [ "$status" -eq 0 ]

  grep -q "^new test-agent-interactive-" "$SESSIONS_LOG"
  grep "^new " "$SESSIONS_LOG" | grep -q "agent.name=test-agent"
  grep -q "^wake mock-session-id-001 --model openai-codex/gpt-5.5$" "$SESSIONS_LOG"
}

@test "interactive: fails clearly when sessions is unavailable after runtime PATH cleanup" {
  local home="$BATS_TEST_TMPDIR/path-boundary-home"
  local direct_sessions="$home/.local/share/mise/installs/shiv-sessions/0.4.1/bin"
  mkdir -p "$direct_sessions"
  cat > "$direct_sessions/sessions" <<'MOCK'
#!/usr/bin/env bash
echo "stale direct sessions should not run" >&2
exit 99
MOCK
  chmod +x "$direct_sessions/sessions"

  run env -i \
    HOME="$home" \
    PATH="$direct_sessions:/usr/bin:/bin" \
    MISE_CONFIG_ROOT="$SHIMMER_DIR" \
    GIT_AUTHOR_NAME="test-agent" \
    GIT_AUTHOR_EMAIL="test-agent@ricon.family" \
    usage_headless="false" \
    usage_model="openai-codex/gpt-5.5" \
    usage_message="" \
    bash "$SHIMMER_DIR/.mise/tasks/agent/_default" # codebase:ignore bats-test-helper — isolates post-cleanup PATH without mise-added shims
  [ "$status" -ne 0 ]
  [[ "$output" == *"sessions not found on PATH"* ]]
  [[ "$output" != *"stale direct sessions should not run"* ]]
}

@test "interactive: ignores inherited usage env from parent task" {
  setup_agent
  export usage_headless="true"
  export usage_model="stale-provider/stale-model"
  export usage_message="stale parent message"
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --model "openai-codex/gpt-5.5"
  [ "$status" -eq 0 ]

  grep -q "^wake mock-session-id-001 --model openai-codex/gpt-5.5$" "$SESSIONS_LOG"
  ! grep -q "stale parent message" "$SESSIONS_LOG"
}

@test "interactive: uses SHIMMER_CALLER_PWD as session cwd before scrubbing" {
  setup_agent
  local caller_dir="$BATS_TEST_TMPDIR/shimmer-caller"
  mkdir -p "$caller_dir"
  unset CALLER_PWD
  export SHIMMER_CALLER_PWD="$caller_dir"
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --model "openai-codex/gpt-5.5"
  [ "$status" -eq 0 ]

  grep "^new " "$SESSIONS_LOG" | grep -q -- "--cwd $caller_dir"
}

@test "interactive: preserves identity while scrubbing caller and mise task context" {
  setup_agent
  export OTHER_CALLER_PWD="/stale/other/caller"
  export MISE_PROJECT_ROOT="/stale/project"
  export MISE_ORIGINAL_CWD="/stale/original"
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --model "openai-codex/gpt-5.5"
  [ "$status" -eq 0 ]

  grep -q '^CALLER_PWD=$' "$SESSIONS_ENV_LOG"
  grep -q '^SHIMMER_CALLER_PWD=$' "$SESSIONS_ENV_LOG"
  grep -q '^OTHER_CALLER_PWD=$' "$SESSIONS_ENV_LOG"
  grep -q '^MISE_CONFIG_ROOT=$' "$SESSIONS_ENV_LOG"
  grep -q '^MISE_PROJECT_ROOT=$' "$SESSIONS_ENV_LOG"
  grep -q '^MISE_TASK_NAME=$' "$SESSIONS_ENV_LOG"
  grep -q '^usage_headless=$' "$SESSIONS_ENV_LOG"
  grep -q '^usage_model=$' "$SESSIONS_ENV_LOG"
  grep -q '^usage_message=$' "$SESSIONS_ENV_LOG"
  grep -q '^GIT_AUTHOR_NAME=test-agent$' "$SESSIONS_ENV_LOG"
  grep -q '^GIT_AUTHOR_EMAIL=test-agent@ricon.family$' "$SESSIONS_ENV_LOG"
}

@test "interactive: resumes an existing session and forwards the initial message" {
  setup_agent
  mock_sessions_binary
  mock_shimmer

  run shimmer agent --session "existing-session-42" --model "openai-codex/gpt-5.5" "continue work"
  [ "$status" -eq 0 ]

  ! grep -q "^new " "$SESSIONS_LOG"
  grep -q "^wake existing-session-42 --model openai-codex/gpt-5.5 --message continue work$" "$SESSIONS_LOG"
}

@test "agent:dispatch requires model" {
  mock_gh 12345
  mock_shimmer

  run shimmer agent:dispatch --repo test/repo c0da "hello"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--model"* ]]
}

@test "agent:dispatch ignores inherited model and repo env" {
  export usage_model="openai-codex/gpt-5.5"
  export usage_repo="stale/repo"
  mock_gh 12345
  mock_shimmer

  run shimmer agent:dispatch c0da "hello"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--model"* ]]
  [ ! -f "$GH_LOG" ]
}

@test "agent:dispatch requires provider-qualified model" {
  mock_gh 12345
  mock_shimmer

  run shimmer agent:dispatch --repo test/repo --model gpt-5.5 c0da "hello"
  [ "$status" -ne 0 ]
  [[ "$output" == *"provider-qualified"* ]]
}

@test "agent:dispatch requires an inline message or message file" {
  mock_gh 12345
  mock_shimmer

  run shimmer agent:dispatch --repo test/repo --model openai-codex/gpt-5.5 c0da
  [ "$status" -ne 0 ]
  [[ "$output" == *"message is required"* ]]
  [ ! -f "$GH_LOG" ]
}

@test "agent:dispatch fails when inline message and message file are both supplied" {
  mock_gh 12345
  printf 'file message\n' > "$BATS_TEST_TMPDIR/message.md"
  mock_shimmer

  run shimmer agent:dispatch --repo test/repo --model openai-codex/gpt-5.5 --message-file message.md c0da "inline message"
  [ "$status" -ne 0 ]
  [[ "$output" == *"either inline <message> or --message-file, not both"* ]]
  [ ! -f "$GH_LOG" ]
}

@test "agent:dispatch fails clearly when message file cannot be read" {
  mock_gh 12345
  mock_shimmer

  run shimmer agent:dispatch --repo test/repo --model openai-codex/gpt-5.5 --message-file missing.md c0da
  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot read --message-file: missing.md"* ]]
  [ ! -f "$GH_LOG" ]
}

@test "agent:dispatch help documents message file" {
  mock_shimmer

  run mise -C "$OVERLAY" tasks info agent:dispatch
  [ "$status" -eq 0 ]
  [[ "$output" == *"flag --message-file"* ]]
  [[ "$output" == *"Read message for the agent from a file"* ]]
}

@test "agent:dispatch preserves embedded newlines in message input" {
  mock_gh 12345
  mock_shimmer

  message=$'line1\nline2'
  run shimmer agent:dispatch --repo test/repo --model openai-codex/gpt-5.5 c0da "$message"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Woke c0da (run 12345)"* ]]
  [[ "$output" == *"shimmer ci:logs 12345 --agent --repo test/repo"* ]]
  [[ "$output" != *"actions/runs"* ]]

  log=$(cat "$GH_LOG")
  [[ "$log" == *$'message=line1\nline2'* ]]
  [[ "$log" == *"model=openai-codex/gpt-5.5"* ]]
}

@test "agent:dispatch reads message from file without interpolation" {
  mock_gh 12345
  cat > "$BATS_TEST_TMPDIR/dispatch-packet.md" <<'PACKET'
Please review `KnickKnackLabs/websites#30`.

- Check `$VARS` are not interpolated.
- Preserve "quotes" and bullets.
PACKET
  mock_shimmer

  run shimmer agent:dispatch --repo test/repo --model openai-codex/gpt-5.5 --message-file "$BATS_TEST_TMPDIR/dispatch-packet.md" c0da
  [ "$status" -eq 0 ]
  [[ "$output" == *"Woke c0da (run 12345)"* ]]

  log=$(cat "$GH_LOG")
  [[ "$log" == *$'message=Please review `KnickKnackLabs/websites#30`.

- Check `$VARS` are not interpolated.
- Preserve "quotes" and bullets.
'* ]]
  [[ "$log" == *"model=openai-codex/gpt-5.5"* ]]
}

@test "agent:dispatch resolves relative message file from caller cwd" {
  mock_gh 12345
  local caller_dir="$BATS_TEST_TMPDIR/caller"
  mkdir -p "$caller_dir"
  cat > "$caller_dir/dispatch-packet.md" <<'PACKET'
Relative packet line 1
$RELATIVE_VARS stay literal
PACKET
  export SHIMMER_CALLER_PWD="$caller_dir"
  mock_shimmer

  run shimmer agent:dispatch --repo test/repo --model openai-codex/gpt-5.5 --message-file dispatch-packet.md c0da
  [ "$status" -eq 0 ]
  [[ "$output" == *"Woke c0da (run 12345)"* ]]

  log=$(cat "$GH_LOG")
  [[ "$log" == *$'message=Relative packet line 1
$RELATIVE_VARS stay literal
'* ]]
  [[ "$log" == *"model=openai-codex/gpt-5.5"* ]]
}
