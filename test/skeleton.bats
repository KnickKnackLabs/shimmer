#!/usr/bin/env bats

load test_helper

@test "standard maintained-tool surfaces exist" {
  for path in \
    mise.toml \
    README.tsx \
    README.md \
    CONTRIBUTING.md \
    .mise/tasks/test \
    .mise/tasks/doctor \
    .github/workflows/test.yml \
    test/setup_suite.bash \
    test/test_helper.bash \
    lib
  do
    [ -e "$REPO_DIR/$path" ]
  done
}

@test "README.md is generated from README.tsx" {
  run bash -c 'cd "$REPO_DIR" && readme build --check'
  [ "$status" -eq 0 ]
}

@test "doctor reports optional pre-commit hook state" {
  run shimmer_task doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"pre-commit"* ]]
}
