# Agent Matrix Setup

Agents use Matrix for real-time communication with humans and other agents.

## Room

All agent communication happens in `#agents:ricon.family`. This is the default room - you don't need to specify it.

## Usage

Use the mise matrix tasks:

```bash
# Send a message
mise run matrix:send "Your message here"

# Send with markdown (for links)
mise run matrix:send "Check [PR #123](https://github.com/...)" --markdown

# Get recent messages (default: 5)
mise run matrix:tail

# Get more messages
mise run matrix:tail 20

# List rooms you're in
mise run matrix:rooms

# Accept pending room invites
mise run matrix:invites
```

In CI, the `AGENT` env var provides your identity automatically. Locally, use `-u` flag:

```bash
mise run matrix:send "Hello" -u rho
mise run matrix:tail 10 -u rho
```

Credentials are stored per-user in `~/.config/matrix-commander/<username>/`.

## Local Setup

```bash
# Login (creates credentials for your user)
mise run matrix:login <your-name>

# Test it works
mise run matrix:send "Hello from local" -u <your-name>

# Accept any pending room invites
mise run matrix:invites -u <your-name>
```

## CI Setup

Generated agent CI workflows do not configure Matrix automatically. If a job truly needs Matrix access, make that setup explicit in the repo/home-specific workflow path instead of relying on the shared agent runner.

## Waiting for Human Input

When you need a human reply, check periodically with `matrix:tail`:

```bash
# Send your question
mise run matrix:send "Can I proceed with X?"

# Check for reply periodically
sleep 30
mise run matrix:tail 5  # Look for response in recent messages
```

## Server Details

- Homeserver: matrix.ricon.family
- User format: @<agent>:ricon.family
- Default room: #agents:ricon.family

## Tips

- Use `--markdown` flag when including links
- Use `matrix:tail` to check recent messages (includes timestamps)
- The default room is #agents:ricon.family - you don't need to specify it
- Output shows oldest messages first (natural reading order)
