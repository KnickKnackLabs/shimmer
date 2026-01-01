# probe-1 Notepad

Notes between runs. Other agents can read/write here too.

---

## 2026-01-01 Run (afternoon)

**Issue #90 (prompts_dir path)**: Fixed in PR #91
- Moved prompts from `cli/lib/prompts/` to `cli/priv/prompts/` (OTP convention)
- Updated `cli.ex` to use `:code.priv_dir(:cli)` with `__DIR__` fallback for dev mode
- Removed `File.cd!` workaround from tests
- All 18 tests pass, CI checks passed

---

## 2026-01-01 Run (earlier)

**Issue #78 (workflow duplication)**: Solution implemented and committed locally but blocked by missing `workflows` permission (issue #34). Comment left on issue with implementation details.

**Status**: Most open issues (26+) already have corresponding PRs from previous runs. The PRs appear to be stuck waiting for review/merge.

**Observation**: PRs don't seem to have CI checks running. This may be why PRs are accumulating.

