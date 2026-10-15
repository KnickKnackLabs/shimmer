# Pure switch policy. Bash supplies five private JSON documents in this order:
# desired configuration, previous ownership, current environment, desired hashes,
# and current hashes. Only the final plan may be rendered as shell commands.

def variable_name:
  test("^[A-Za-z_][A-Za-z0-9_]*$");

def sha256:
  type == "string" and test("^[a-f0-9]{64}$");

def managed_variable:
  (.key | variable_name)
  and .key != "AGENT_HOME"
  and .key != "SHIMMER_PERSONA_STATE"
  and (.key | startswith("GIT_CONFIG_") | not)
  and (.value | sha256);

def validate_ownership:
  if .version != 1
    or (.variables | type) != "object"
    or (.git | type) != "array"
    or (all(.variables | to_entries[]; managed_variable) | not)
    or (all(.git[];
          (.key | type) == "string"
          and (.hash | sha256)
          and (.owned | type) == "boolean"
        ) | not)
  then error("invalid ownership manifest")
  else .
  end;

def conflict($name; $action):
  {name: $name, action: $action};

def git_slot_name:
  "GIT_CONFIG_KEY_" + .index + "/GIT_CONFIG_VALUE_" + .index;

def identity_setting:
  ascii_downcase
  | IN(
      "user.name", "user.email",
      "author.name", "author.email",
      "committer.name", "committer.email",
      "user.signingkey", "gpg.format", "commit.gpgsign", "tag.gpgsign"
    );

# Git's environment transport is one contiguous list shared with other tools.
def read_git_entries($current; $hashes):
  if ($current.GIT_CONFIG_PARAMETERS // "") != "" then
    error("GIT_CONFIG_PARAMETERS must be resolved before activation")
  else .
  end
  | ($current.GIT_CONFIG_COUNT // "0") as $count
  | if ($count | test("^(0|[1-9][0-9]{0,4})$")) and ($count | tonumber) <= 10000
    then .
    else error("invalid Git config count")
    end
  | if any($current | keys[];
        test("^GIT_CONFIG_(KEY|VALUE)_[0-9]+$")
        and (
          capture("_(?<index>[0-9]+)$").index as $index
          | ($index | tonumber) >= ($count | tonumber)
            or ($index | tonumber | tostring) != $index
        )
      )
    then error("orphaned Git config variables")
    else .
    end
  | [
      range(0; ($count | tonumber))
      | tostring as $index
      | ("GIT_CONFIG_KEY_" + $index) as $key_name
      | ("GIT_CONFIG_VALUE_" + $index) as $value_name
      | if ($current | has($key_name) and has($value_name)) then
          {
            key: $current[$key_name],
            value: $current[$value_name],
            hash: $hashes[$value_name],
            index: $index
          }
        else error("incomplete Git config list")
        end
    ];

# Indexes are not identities. Find a moved entry by its key and value hash.
# An edited value is identifiable only if that key was and still is unique.
def locate_owned_entry($entry; $previous; $current):
  [$current[] | select(.key == $entry.key and .hash == $entry.hash)] as $exact
  | [$current[] | select(.key == $entry.key)] as $same_key
  | [$previous[] | select(.key == $entry.key)] as $previous_same_key
  | if ($exact | length) == 1 then $exact[0]
    elif ($exact | length) == 0
      and ($same_key | length) == 1
      and ($previous_same_key | length) == 1
    then $same_key[0]
    else error("Git ownership is ambiguous; restore or resolve the shared list")
    end;

def reconcile_git_ownership($previous; $current):
  reduce ($previous[] | select(.owned)) as $entry (
    {indexes: [], conflicts: []};
    locate_owned_entry($entry; $previous; $current) as $match
    | if (.indexes | index($match.index)) != null then
        error("duplicate Git ownership")
      else . end
    | .indexes += [$match.index]
    | if $match.hash != $entry.hash then
        .conflicts += [conflict($match | git_slot_name; "replace edited owned entry")]
      else . end
  );

def git_assignments:
  length as $count
  | reduce to_entries[] as $slot ({};
      ($slot.key | tostring) as $index
      | . + {
          ("GIT_CONFIG_KEY_" + $index): $slot.value.key,
          ("GIT_CONFIG_VALUE_" + $index): $slot.value.value
        }
    ) + {GIT_CONFIG_COUNT: ($count | tostring)};

def variable_conflicts($desired; $previous; $current; $desired_hashes; $current_hashes):
  [($desired | keys[]) as $name
    | select($current | has($name))
    | select($current_hashes[$name] != $desired_hashes[$name])
    | select(($previous | has($name) | not)
             or $current_hashes[$name] != $previous[$name])
    | conflict($name; "replace")];

def removal_conflicts($removed; $previous; $current; $hashes):
  [$removed[] as $name
    | select($current | has($name))
    | select($hashes[$name] != $previous[$name])
    | conflict($name; "remove")];

def switch_plan($desired; $previous; $current; $desired_hashes; $current_hashes):
  $previous | validate_ownership
  | read_git_entries($current; $current_hashes) as $git
  | reconcile_git_ownership($previous.git; $git) as $ownership
  | [
      $git[]
      | select(.index as $index | $ownership.indexes | index($index) | not)
    ] as $preserved
  | [$desired.git[] | . + {hash: $desired_hashes["git:" + .key]}] as $requested
  | ($preserved + $requested) as $replacement
  | [($previous.variables | keys[]) as $name
      | select($desired.variables | has($name) | not)
      | $name] as $removed
  | (
      variable_conflicts(
        $desired.variables; $previous.variables; $current;
        $desired_hashes; $current_hashes
      )
      + removal_conflicts($removed; $previous.variables; $current; $current_hashes)
      + $ownership.conflicts
      + [
          $preserved[]
          | select(.key | identity_setting)
          | conflict(git_slot_name; "retain competing Git setting")
        ]
    ) as $conflicts
  | {
      set: ($desired.variables + ($replacement | git_assignments)),
      unset: (
        $removed + [
          $current | keys[]
          | select(test("^GIT_CONFIG_(KEY|VALUE)_[0-9]+$"))
        ]
        | unique
      ),
      conflicts: $conflicts,
      state: {
        version: 1,
        variables: (
          $desired_hashes
          | with_entries(select(.key | startswith("git:") | not))
        ),
        git: [$replacement[] | {key, hash, owned: (.index == null)}]
      },
      # Retry consent covers relevant presence, hashes, ownership, Git order and
      # conflicts. Unrelated environment changes do not invalidate approval.
      binding: {
        old: $previous,
        current: $current_hashes,
        desired: $desired_hashes,
        git: [$git[] | {key, hash, index}],
        count: ($current.GIT_CONFIG_COUNT // "0"),
        conflicts: $conflicts
      }
    };

# jq type errors can include input values. Only fixed diagnostics may escape.
def safe_error:
  if IN(
      "invalid ownership manifest",
      "GIT_CONFIG_PARAMETERS must be resolved before activation",
      "invalid Git config count",
      "orphaned Git config variables",
      "incomplete Git config list",
      "Git ownership is ambiguous; restore or resolve the shared list",
      "duplicate Git ownership"
    )
  then .
  else "invalid ownership or shared Git config structure"
  end;

try switch_plan(.[0]; .[1]; .[2]; .[3]; .[4])
catch {error: safe_error}
