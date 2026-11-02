#!/usr/bin/env bash
# Private data loading for persona activation. Sourcing this file has no effects.

# Load one agent's portable configuration into PERSONA_DATA as JSON, with paths
# relative to that agent. This is secret-bearing working state, never shell code.
# No exports are emitted, and failure preserves any previous PERSONA_DATA.
# Schema validation and activation are separate steps; this only reads data.
persona_load() {
  # Provider output and shell tracing may contain credentials. Do not restore
  # tracing while the caller is still handling the loaded data.
  set +x
  set +v

  # Do not inherit export attributes from same-named caller variables.
  local +x agent="${1:-}" bundle data
  case "$agent" in
    ''|*/*)
      printf 'ERROR: persona loading requires one agent handle.\n' >&2
      return 1
      ;;
  esac

  if ! bundle=$(secrets export --prefix "$agent/" 2>/dev/null); then
    printf 'ERROR: could not load persona from the selected Secrets provider.\n' >&2
    return 1
  fi

  # Remove the agent prefix from the Secrts export
  if ! data=$(
    printf '%s' "${bundle}" |
      jq -ce --arg prefix "${agent}/" \
        'with_entries(.key |= ltrimstr($prefix))' 2>/dev/null
  ); then
      printf 'ERROR: Could not parse persona JSON.\n' >&2
      return 1
  fi

  PERSONA_DATA="$data"
  export -n PERSONA_DATA
}
