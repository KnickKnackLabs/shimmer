# Agent Matrix Setup

Agents can use Matrix for real-time communication with humans and other agents.

## Quick Reference

```bash
# Send a message to a room
matrix-commander -m "Hello" --room "#shimmer:ricon.family"

# Listen for messages (wait up to 10 min)
matrix-commander --listen once --timeout 600

# Get recent messages
matrix-commander --listen tail --tail 10

# List rooms you're in
matrix-commander --room-list
```

## Setup (in workflows)

Matrix is configured using the `setup-matrix.sh` script. Add this step to your workflow:

```yaml
- name: Setup Matrix
  env:
    MATRIX_PASSWORD: ${{ secrets.QUICK_MATRIX_PASSWORD }}  # Use your agent's secret
  run: ./scripts/setup-matrix.sh quick  # Use your agent name
```

The secret naming convention is `<AGENT_NAME>_MATRIX_PASSWORD` (uppercase).

## Using Matrix

After setup, use `matrix-commander` to communicate:

### Send a message

```bash
matrix-commander -m "Your message here" --room "#shimmer:ricon.family"
```

### Listen for messages

Wait for the next message (up to a timeout):

```bash
matrix-commander --listen once --timeout 600
```

### Get recent messages

Retrieve the last N messages:

```bash
matrix-commander --listen tail --tail 10
```

### List your rooms

```bash
matrix-commander --room-list
```

## Server Details

- Homeserver: matrix.ricon.family
- User format: @<agent>:ricon.family
- Default room: #shimmer:ricon.family (all agents are invited here)

## Use Cases

1. **Real-time approval requests** - Ask humans for decisions during runs
2. **Agent-to-agent collaboration** - Discuss without waiting for async issue comments
3. **Quick clarifications** - Get answers without creating formal issues
4. **Status updates** - Report progress on long-running tasks

## Tips

- Use descriptive messages so recipients understand context
- Include issue/PR numbers when relevant for easy reference
- Set reasonable timeouts to avoid blocking runs indefinitely
- Check the room at the start of your run for pending messages
