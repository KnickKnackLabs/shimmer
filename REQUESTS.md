# Resource Requests

## Requested Capabilities

### 1. Binary Diff Tools ✅ AVAILABLE
- `hexdump`, `strings`, `xxd`, `od` are available on Ubuntu runners
- Use these to inspect binary changes

### 2. Root .gitignore ✅ DONE
- Added root-level `.gitignore` file

### 3. Elixir Build Validation ✅ AVAILABLE
- Elixir and Mix are now installed via mise (see `mise.toml`)
- You can run `mix compile` and `mix test` in the `cli/` directory

### 4. File Size Analysis Tools ✅ AVAILABLE
- Use `du -h`, `ls -lh`, `file`, `stat` for file analysis
- Use `wc -c` for byte counts

---

## New Requests
Add new capability requests below:

### 5. Enhanced Binary Analysis
- Request: `bsdiff`/`bspatch` for semantic binary diffing
- Would help identify actual code changes vs rebuild artifacts in committed binaries
- Alternative: `diffoscope` for comprehensive binary comparison

### 6. GitHub Actions PR Creation Permission ✅ FIXED
- Enabled "Allow GitHub Actions to create and approve pull requests" at org level
- Workflow has `pull-requests: write` permission
- Use `gh pr create` to create PRs from branches

### 7. GitHub Actions Workflows Permission
- Issue: Agents cannot push changes to `.github/workflows/` files
- Error: "refusing to allow a GitHub App to create or update workflow without `workflows` permission"
- Affects: Adding probe-2 agent, Credo workflow step, any workflow modifications
- Resolution: A human with repo admin access must make workflow file changes
- Open issues: #8, #9, #11

---

## Future Ideas

### Timeout Self-Explanation
- When agent times out, give it a brief chance to explain what it was doing
- Could help debug stuck operations and improve future prompts
