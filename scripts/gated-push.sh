#!/usr/bin/env bash
#
# gated-push.sh - Biometric approval gate for git push
#
# Uses 1Password CLI (op) with TouchID to require biometric confirmation
# before executing git push. This provides a speed bump for irreversible
# operations while validating whether biometric gates add value.
#
# Setup:
#   1. Configure 1Password CLI with TouchID: https://developer.1password.com/docs/cli/get-started
#   2. Create a dummy item: op item create --category=Login --title="Git Push Gate" --vault=Private
#   3. Alias git push: git config --global alias.push '!gated-push.sh'
#      Or use directly: gated-push.sh origin main --force
#
# Usage: gated-push.sh [git push arguments...]

set -euo pipefail

# Configuration
OP_ITEM="${GATED_PUSH_OP_ITEM:-Git Push Gate}"
LOG_FILE="${GATED_PUSH_LOG:-$HOME/.gated-push.log}"

log() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "$timestamp $*" >> "$LOG_FILE"
}

# Check if this is a force push
is_force_push() {
    for arg in "$@"; do
        case "$arg" in
            --force|-f|--force-with-lease) return 0 ;;
        esac
    done
    return 1
}

# Check if pushing to protected branch
is_protected_branch() {
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    case "$current_branch" in
        main|master|production|release/*) return 0 ;;
    esac
    return 1
}

# Determine if gate should fire
should_gate() {
    # Always gate force pushes
    if is_force_push "$@"; then
        return 0
    fi
    # Gate pushes to protected branches
    if is_protected_branch; then
        return 0
    fi
    return 1
}

main() {
    # CI environments don't have biometric - rely on workflow-level controls
    if [[ -n "${CI:-}" ]]; then
        exec git push "$@"
    fi

    if ! should_gate "$@"; then
        # Regular push, no gate
        exec git push "$@"
    fi

    local gate_reason=""
    if is_force_push "$@"; then
        gate_reason="force push"
    elif is_protected_branch; then
        gate_reason="protected branch ($(git rev-parse --abbrev-ref HEAD))"
    fi

    echo "Biometric approval required: $gate_reason"
    log "GATE_TRIGGERED reason=$gate_reason args=$*"

    # Require biometric via 1Password CLI
    # This will prompt for TouchID/biometric on supported systems
    if ! op item get "$OP_ITEM" --fields label=password >/dev/null 2>&1; then
        echo "Biometric approval denied or failed"
        log "GATE_DENIED reason=$gate_reason args=$*"
        exit 1
    fi

    log "GATE_APPROVED reason=$gate_reason args=$*"
    exec git push "$@"
}

main "$@"
