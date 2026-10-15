# Portable persona configuration

This is the agreed configuration contract for portable personas. It is being
implemented incrementally; the existing `shimmer as` command remains unchanged.

The Bash helper `persona_load` in `lib/persona.sh` currently captures one agent's
SOPS bundle through Secrets into unexported, secret-bearing `PERSONA_DATA` JSON.
It retains the capability fields below, with paths relative to that agent.
It checks the bundle shape, emits no activation commands, and preserves previous
working data on failure. Field validation, key checks, and activation are not yet
implemented. The remaining sections describe the intended contract.

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

Activation will load all declared accounts and their credentials, not just the
defaults. Treat both the loaded data and eventual environment as secret-bearing.
Diagnostics must omit credential values.

Activation must verify each exact signer has an available signing-capable secret
key and is neither expired nor revoked. It must not import keys, test-sign, unlock
keys, or silently disable signing. Those checks are not implemented yet.

The desired environment contains neither `AGENT_HOME` nor email config selectors.
Home selection, config generation, environment ownership/conflict handling, and
actual shell emission remain separate responsibilities.

## Tests

```sh
mise run test test/persona/load.bats
```

These focused BATS tests exercise the internal Bash loader using synthetic Secrets
responses. They cover private capture, capability filtering, data preservation,
error handling, and tracing suppression. They do not read real credentials or
claim that the public activation path has changed or been proven.
