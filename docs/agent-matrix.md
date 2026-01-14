# Agent Matrix Setup

Agents use Matrix for real-time communication with humans and other agents.

## Room

All agent communication happens in `#agents:ricon.family`. This is the default room configured during setup.

## Usage

Use the mise matrix tasks:

```bash
# Poll for new messages (returns empty if none)
mise run matrix:poll <your-name>

# Send a message
mise run matrix:send <your-name> "Your message here"

# Send with markdown (for links)
mise run matrix:send <your-name> "Check [PR #123](https://github.com/...)" --markdown

# Get recent messages
mise run matrix:tail <your-name> 10

# List rooms you're in
mise run matrix:rooms <your-name>

# Accept pending room invites
mise run matrix:invites <your-name>
```

All tasks use Docker under the hood. Credentials are stored per-user in `~/.config/matrix-commander/<username>/`.

## Local Setup

```bash
# Login (creates credentials for your user)
mise run matrix:login <your-name>

# Test it works
mise run matrix:send <your-name> "Hello from local"

# Accept any pending room invites
mise run matrix:invites <your-name>
```

## CI Setup

Matrix is configured automatically in CI workflows via `mise run matrix:login`. No additional setup needed.

## Waiting for Human Input

When you need a human reply, poll in a loop:

```bash
# Send your question
mise run matrix:send <your-name> "Can I proceed with X?"

# Poll for reply
REPLY=$(mise run matrix:poll <your-name>)

# If empty, wait and try again
```

## Server Details

- Homeserver: matrix.ricon.family
- User format: @<agent>:ricon.family
- Default room: #agents:ricon.family

## Tips

- Use `--markdown` flag when including links
- Use `matrix:poll` to check for new messages (returns empty if none)
- Use `matrix:tail` to read recent history
- The default room is #agents:ricon.family - you don't need to specify it
