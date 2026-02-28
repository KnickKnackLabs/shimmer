# Biometric Gate Validation Protocol

This document describes a one-week experiment to validate whether biometric approval gates provide value for sensitive git operations.

Related: [Issue #105 - TouchID/biometric approval gate for agent operations](https://github.com/ricon-family/shimmer/issues/105)

## Hypothesis

Requiring biometric confirmation (TouchID) before destructive operations provides a useful safety net that catches mistakes without creating excessive friction.

## Setup

### Prerequisites

- macOS with TouchID or compatible biometric hardware
- [1Password CLI](https://developer.1password.com/docs/cli/get-started) configured with biometric unlock

### Installation

1. Create a dummy 1Password item for the gate to read:
   ```bash
   op item create --category=Login --title="Git Push Gate" --vault=Private
   ```

2. Test biometric works:
   ```bash
   op item get "Git Push Gate" --fields label=password
   # Should prompt for TouchID
   ```

3. Configure git to use the gated push script:
   ```bash
   # Option A: Global alias
   git config --global alias.gpush '!/path/to/shimmer/scripts/gated-push.sh'

   # Option B: Replace git push entirely (more intrusive)
   git config --global alias.push '!/path/to/shimmer/scripts/gated-push.sh'
   ```

## Experiment Protocol

### Duration

One week of normal development activity.

### What Gets Gated

The script gates:
- All force pushes (`--force`, `-f`, `--force-with-lease`)
- Pushes to protected branches (`main`, `master`, `production`, `release/*`)

### Logging

All gate events are logged to `~/.gated-push.log`:
- `GATE_TRIGGERED` - Gate fired, waiting for biometric
- `GATE_APPROVED` - Biometric succeeded, push proceeded
- `GATE_DENIED` - Biometric failed or was cancelled

### Questions to Answer

After one week, review the log and answer:

1. **Frequency**: How many times did the gate fire?
2. **Friction**: Was the biometric prompt annoying or reassuring?
3. **Catches**: Did the gate catch any mistakes (operations you cancelled after seeing the prompt)?
4. **Bypasses**: Did you work around the gate (e.g., using regular `git push` directly)?
5. **False positives**: Were there operations the gate blocked that it shouldn't have?

## Expected Outcomes

### Gate is valuable if:
- At least one operation was caught/cancelled after the prompt made you reconsider
- The friction felt proportionate to the risk of the operations

### Gate is not valuable if:
- Every gated operation was approved immediately with no hesitation
- You bypassed the gate more than you used it
- The delay became annoying enough to affect workflow

## Extending the Experiment

If the initial experiment is valuable, consider:
- Gating additional operations (secret access via `op read`)
- Extending to more branches or repos
- Building infrastructure for opt-in agent escalation

## Results Template

After completing the experiment, document results here:

```markdown
## Experiment Results

**Period**: [start date] to [end date]
**Participant**: [name]

### Metrics
- Total gate triggers: X
- Approved: X
- Denied/cancelled: X
- Bypassed: X

### Observations
[Free-form notes about the experience]

### Conclusion
[Was it valuable? Should we expand it?]
```
