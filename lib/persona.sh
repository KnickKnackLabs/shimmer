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

  # Secrets owns vault access; jq only checks the bundle shape and extracts the
  # agreed capability namespaces. Unrelated agent secrets are not retained.
  if ! data=$(printf '%s' "$bundle" | jq -cse --arg prefix "$agent/" '
    if length != 1 or (.[0] | type) != "object" then
      error("expected one object")
    else
      .[0]
      | if all(to_entries[]; (.key | startswith($prefix)) and (.value | type == "string")) then
          with_entries(
            .key |= ltrimstr($prefix)
            | select(.key | test("^(git|github|email|blobs)/"))
          )
        else error("invalid bundle entries") end
    end
  ' 2>/dev/null); then
    printf 'ERROR: Secrets returned an invalid persona bundle.\n' >&2
    return 1
  fi

  PERSONA_DATA="$data"
  export -n PERSONA_DATA
}
