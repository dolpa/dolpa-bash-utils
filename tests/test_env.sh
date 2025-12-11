#!/usr/bin/env bats

#=====================================================================
#  test_env.bats – tests for the env.sh module
#=====================================================================
#  The style mirrors the existing test suite: load dependencies in
#  the correct order, use the same comment density and verify both
#  loading and functional behaviour.
#=====================================================================

setup() {
    # Load the core modules that env.sh depends on
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/validation.sh"
    source "${BATS_TEST_DIRNAME}/../modules/env.sh"

    # Disable coloured output for deterministic tests
    export NO_COLOR=1
}

teardown() {
    # Unset any functions we defined during the test runs
    # (readonly flags stay – they are harmless)
    unset -f env_require env_default env_bool env_from_file 2>/dev/null || true
}

#---------------------------------------------------------------------
#  MODULE LOADING
#---------------------------------------------------------------------

@test "env module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/env.sh"
    [ "$status" -eq 0 ]
}

@test "env module sets BASH_UTILS_ENV_LOADED" {
    [ "$BASH_UTILS_ENV_LOADED" = "true" ]
}

@test "env module prevents multiple sourcing" {
    run source "${BATS_TEST_DIRNAME}/../modules/env.sh"
    [ "$status" -eq 0 ]
}

#---------------------------------------------------------------------
#  FUNCTION EXISTENCE
#---------------------------------------------------------------------

@test "all env helper functions are defined" {
    type env_require &>/dev/null
    type env_default &>/dev/null
    type env_bool &>/dev/null
    type env_from_file &>/dev/null
}

#---------------------------------------------------------------------
#  env_require
#---------------------------------------------------------------------

@test "env_require succeeds when variable is set" {
    export TEST_VAR="present"
    run env_require TEST_VAR
    [ "$status" -eq 0 ]
    unset TEST_VAR
}

@test "env_require fails when variable is missing" {
    unset TEST_VAR
    run env_require TEST_VAR
    [ "$status" -eq 1 ]
    [[ "$output" == *"Required environment variable 'TEST_VAR' is not set"* ]]
}

#---------------------------------------------------------------------
#  env_default
#---------------------------------------------------------------------

@test "env_default sets a default when variable is empty" {
    unset DEFAULT_VAR
    env_default DEFAULT_VAR "fallback"
    [ "${DEFAULT_VAR}" = "fallback" ]
}

@test "env_default does NOT overwrite an existing value" {
    export OVERRIDE_VAR="keep"
    env_default OVERRIDE_VAR "new"
    [ "${OVERRIDE_VAR}" = "keep" ]
    unset OVERRIDE_VAR
}

#---------------------------------------------------------------------
#  env_bool
#---------------------------------------------------------------------

@test "env_bool normalises true‑like values to 'true'" {
    for v in true TRUE Yes YES 1; do
        export BOOL_VAR="$v"
        run env_bool BOOL_VAR
        [ "$status" -eq 0 ]
        [ "${BOOL_VAR}" = "true" ]
    done
}

@test "env_bool normalises false‑like values to 'false'" {
    for v in false FALSE No NO 0; do
        export BOOL_VAR="$v"
        run env_bool BOOL_VAR
        [ "$status" -eq 0 ]
        [ "${BOOL_VAR}" = "false" ]
    done
}

@test "env_bool reports an error for unrecognised values" {
    export BOOL_VAR="maybe"
    run env_bool BOOL_VAR
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid boolean value for 'BOOL_VAR'"* ]]
    unset BOOL_VAR
}

#---------------------------------------------------------------------
#  env_from_file
#---------------------------------------------------------------------

@test "env_from_file loads a well‑formed env file" {
    env_file="$(mktemp)"
    cat >"$env_file" <<'EOF'
# comment line
FOO=bar
BAZ=qux
EMPTY=
EOF
    run env_from_file "$env_file"
    [ "$status" -eq 0 ]
    [ "${FOO}" = "bar" ]
    [ "${BAZ}" = "qux" ]
    [ -z "${EMPTY}" ]   # empty value is allowed
    rm -f "$env_file"
}

@test "env_from_file skips comments and blank lines" {
    env_file="$(mktemp)"
    cat >"$env_file" <<'EOF'

# just a comment

VAR1=one

# another comment
VAR2=two
EOF
    run env_from_file "$env_file"
    [ "$status" -eq 0 ]
    [ "${VAR1}" = "one" ]
    [ "${VAR2}" = "two" ]
    rm -f "$env_file"
}

@test "env_from_file fails on malformed lines" {
    env_file="$(mktemp)"
    cat >"$env_file" <<'EOF'
GOOD=ok
BAD line without equals
EOF
    run env_from_file "$env_file"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid line in env file"* ]]
    # Ensure the good variable was still exported before the error
    [ "${GOOD}" = "ok" ]
    rm -f "$env_file"
}

@test "env_from_file reports missing file" {
    run env_from_file "/non/existent/file.env"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Environment file not found"* ]]
}