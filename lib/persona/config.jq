# Convert portable vault fields into one complete desired configuration.
# This filter only maps and validates data; it never inspects the caller's shell.

def required($path):
  .[$path]
  | if type == "string" and length > 0 and (contains("\u0000") | not)
    then .
    else error("missing or invalid field: " + $path)
    end;

def fingerprint($path):
  required($path)
  | if test("^([A-Fa-f0-9]{40}|[A-Fa-f0-9]{64})$")
    then ascii_upcase
    else error("invalid signer: " + $path)
    end;

def account_labels($kind):
  (
    .[$kind + "/accounts"] // ""
    | split(" ")
    | map(select(length > 0))
  ) as $labels
  | if all($labels[]; test("^[a-z][a-z0-9_]*$"))
      and ($labels | unique | length) == ($labels | length)
    then $labels
    else error("invalid account labels: " + $kind)
    end;

def account_fields($kind):
  if $kind == "email" then
    [
      "address", "display-name", "signing-fingerprint",
      "imap/host", "imap/port", "imap/encryption", "imap/username", "imap/password",
      "smtp/host", "smtp/port", "smtp/encryption", "smtp/username", "smtp/password"
    ]
  else
    ["provider", "bucket", "key-id", "application-key"]
  end;

def validate_email_transport($path):
  required($path + "/port") as $port
  | required($path + "/encryption") as $encryption
  | if ($port | test("^[0-9]+$"))
      and ($port | tonumber) >= 1
      and ($port | tonumber) <= 65535
      and ($encryption == "tls" or $encryption == "starttls")
    then .
    else error("invalid transport: " + $path)
    end;

def account_variables($kind; $label):
  . as $data
  | ($kind + "/" + $label + "/") as $path
  | (($kind | ascii_upcase) + "_" + ($label | ascii_upcase) + "_") as $prefix
  | if $kind == "email" then
      validate_email_transport($path + "imap")
      | validate_email_transport($path + "smtp")
    elif required($path + "provider") != "b2" then
      error("unsupported blob provider")
    else .
    end
  | reduce account_fields($kind)[] as $field ({};
      ($prefix + ($field | ascii_upcase | gsub("[-/]"; "_"))) as $name
      | (
          $data
          | if $field == "signing-fingerprint"
            then fingerprint($path + $field)
            else required($path + $field)
            end
        ) as $value
      | . + {($name): $value}
    );

def capability_variables($kind):
  . as $data
  | account_labels($kind) as $labels
  | if ($labels | length) == 0 then {}
    else
      required($kind + "/default-account") as $default
      | if ($labels | index($default)) == null then
          error("invalid default: " + $kind)
        else .
        end
      | (
          reduce $labels[] as $label ({};
            . + ($data | account_variables($kind; $label))
          )
        ) as $accounts
      | $accounts + {
          (($kind | ascii_upcase) + "_ACCOUNTS"): ($labels | join(" ")),
          (($kind | ascii_upcase) + "_DEFAULT_ACCOUNT"): $default
        }
    end;

. as $data
| required("git/name") as $git_name
| required("git/email") as $git_email
| fingerprint("git/signing-fingerprint") as $git_signer
| {
    GIT_AUTHOR_NAME: $git_name,
    GIT_COMMITTER_NAME: $git_name,
    GIT_AUTHOR_EMAIL: $git_email,
    GIT_COMMITTER_EMAIL: $git_email,
    GH_HOST: "github.com"
  }
  + (
      if ($data["github/token"] // "") == "" then {}
      else {GH_TOKEN: ($data | required("github/token"))}
      end
    )
  + ($data | capability_variables("email"))
  + ($data | capability_variables("blobs")) as $variables
| {
    variables: $variables,
    git: [
      {key: "user.name", value: $git_name},
      {key: "user.email", value: $git_email},
      {key: "user.signingkey", value: $git_signer},
      {key: "gpg.format", value: "openpgp"},
      {key: "commit.gpgsign", value: "true"},
      {key: "tag.gpgsign", value: "true"}
    ],
    signers: (
      [$git_signer] + [
        $variables | to_entries[]
        | select(.key | endswith("_SIGNING_FINGERPRINT"))
        | .value
      ]
      | unique
    )
  }
