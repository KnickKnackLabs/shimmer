# Portable persona configuration

`shimmer as <handle>` loads a portable persona from the selected SOPS vault,
checks its configuration and secret signing keys, and emits Bash exports:

```bash
eval "$(shimmer as alice)"
```

Secrets/vault access and GnuPG keys are prerequisites, independent of any home
checkout. The handle selects vault fields; the configured Git name supplies the
commit identity. Activation makes no network requests or persistent config writes.
All loading, validation and conflict approval finish before any shell commands
are emitted. Failure leaves the caller's previous environment unchanged.

`lib/persona.sh` owns private bundle loading. `lib/persona/config.jq` maps and
validates fields; `switch.jq` plans ownership changes; `activate.sh` checks keys,
handles consent and emits the complete switch. Working JSON is unexported.

## Fields

Required Git fields:

| Vault field | Use |
| --- | --- |
| `git/name` | Author/committer name and `user.name` |
| `git/email` | Author/committer email and `user.email` |
| `git/signing_fingerprint` | Full fingerprint for `user.signingkey` |

Git's other fixed settings are `gpg.format=openpgp`, `commit.gpgsign=true`,
and `tag.gpgsign=true`. Numbered `GIT_CONFIG_*` transport and account provisioning
are separate from data loading.

`github/token` is optional and maps to `GH_TOKEN`. `GH_HOST` is `github.com`.

Email uses `email/accounts` (space-separated labels) and
`email/default_account` (one declared label). For each label, the fields are:

- `email/<label>/address` and `display_name`;
- `email/<label>/imap/{host,port,encryption,username,password}`;
- `email/<label>/smtp/{host,port,encryption,username,password}`;
- `email/<label>/signing_fingerprint` (required, not optional).

The environment uses `EMAIL_ACCOUNTS`, `EMAIL_DEFAULT_ACCOUNT`, and
`EMAIL_<UPPERCASE_LABEL>_<FIELD>`. Transport fields use `_IMAP_` and `_SMTP_`.
Encryption values are `tls` or `starttls`; ports are integers from 1 through 65535.
Incoming and outgoing credentials remain separate.

Blobs uses `blobs/accounts`, `blobs/default_account`, and for each label:
`blobs/<label>/{provider,bucket,key_id,application_key}`. The initial provider is
`b2`. Environment names use `BLOBS_ACCOUNTS`, `BLOBS_DEFAULT_ACCOUNT`, and
`BLOBS_<UPPERCASE_LABEL>_<FIELD>`. Each account selects one bucket.

Labels start with a lowercase letter and contain only lowercase letters, digits,
and underscores. Labels must be unique. Missing or empty account lists mean the
capability is unconfigured and generate no exports for it. Declared accounts must
be complete, including a default naming a declared account. Unknown fields are
ignored, allowing unrelated vault data without exporting it.

## Boundaries

Activation loads every declared account and its credentials, not just the defaults.
Treat both the loaded data and the emitted shell commands as secret-bearing.
Diagnostics and prompts contain names and actions, never credential values.

GnuPG's colon metadata must show the exact configured primary or subkey
fingerprint as a signing-capable secret key. Revoked, disabled, expired and
unavailable keys fail; subkeys also require a valid primary. Activation neither
imports nor test-signs nor unlocks keys. Passing this check does not guarantee
later access to a locked key or hardware device.

Activation does not select, discover or change the caller's home. It does not
assign email config selectors or create Himalaya configuration. Explicit email
setup must consume the environment and a caller-selected destination separately.
Account provisioning, credential migration, rotation and blob bucket creation
are outside activation.

## Switching and approval

`SHIMMER_PERSONA_STATE` is an exported ownership manifest with variable names and
SHA-256 value hashes, plus Git entry keys, hashes and ownership. It contains no
duplicate plaintext credentials. Keep it with the environment it describes.
SHA-256 uses the system `shasum` command.

A successful switch replaces the entire managed persona. Unchanged old managed
values can be removed or replaced automatically. Edited values and assignments
that would overwrite different unmanaged values require consent. Equal values
need none. Unrelated variables remain untouched; old manifest-owned mail selectors
follow the same cleanup rules as other retired names.

Prompts use the controlling terminal, never stdout. Without one, activation emits
no commands and prints a value-free conflict plan with an exact retry digest:

```bash
# Review the reported names/actions, then retry using the reported digest.
eval "$(shimmer as alice --approve DIGEST_FROM_PLAN)"
```

The digest binds approval to the requested values and inspected relevant state.
Changing either invalidates approval. Declining cancels the entire switch.
There is no blanket `--yes` or partial-preservation mode.

The shared `GIT_CONFIG_*` list retains unrelated entries in order, removes owned
entries, compacts, then appends the six persona settings. Ownership follows keys
and hashes, not permanent numeric slots. Edited owned entries and competing
identity/signing entries require consent, even when shadowed. Ambiguous ownership,
incomplete/orphaned slots, or nonempty `GIT_CONFIG_PARAMETERS` fail closed and must
be resolved before switching. Approval never guesses an uncertain owner.

This is emission atomicity, not a guarantee that arbitrary caller-side `eval`
cannot fail midway. Only exported caller state is visible to an external command.

## Tests

```sh
mise run test test/as test/persona
```

Focused BATS tests use synthetic Secrets responses and GnuPG metadata. They cover
public Mise routing, complete account mapping, key rejection, quoting, switching,
Git preservation, state-bound approval and failure emission. A compatibility smoke
executes activation under `/bin/bash` (Bash 3.2 on macOS). These tests do not retrieve
real credentials or prove vault access, key unlock, hardware access or network
identity. Verify GitHub's authenticated account before consequential operations.
