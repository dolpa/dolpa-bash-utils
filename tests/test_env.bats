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
        export BOOL_VAR=$v
        run env_bool BOOL_VAR
        [ "$status" -eq 0 ]
        [ "$output" = "true" ]
    done
}

@test "env_bool normalises false‑like values to 'false'" {
    for v in false FALSE No NO 0; do
        export BOOL_VAR=$v
        run env_bool BOOL_VAR
        [ "$status" -eq 0 ]
        [ "$output" = "false" ]
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
# --------------------------------------------------------------------
#  1.  Loading a well‑formed file
# --------------------------------------------------------------------
@test "env_from_file loads a well‑formed env file" {
    tmpfile="$(mktemp)"
    cat <<'EOF' >"$tmpfile"
FOO=bar
BAZ=qux
EOF

    # Call the function *directly* – we want its side‑effects to stay in this shell
    env_from_file "$tmpfile"

    [ "$FOO" = "bar" ]
    [ "$BAZ" = "qux" ]

    rm -f "$tmpfile"
}

# --------------------------------------------------------------------
#  2.  Ignoring comments and blank lines
# --------------------------------------------------------------------
@test "env_from_file skips comments and blank lines" {
    tmpfile="$(mktemp)"
    cat <<'EOF' >"$tmpfile"
# this is a comment

VAR1=one

# another comment
VAR2=two

EOF

    env_from_file "$tmpfile"

    [ "$VAR1" = "one" ]
    [ "$VAR2" = "two" ]

    rm -f "$tmpfile"
}

# --------------------------------------------------------------------
#  3.  Malformed lines produce an error
# --------------------------------------------------------------------
@test "env_from_file fails on malformed lines" {
    tmpfile="$(mktemp)"
    cat <<'EOF' >"$tmpfile"
GOOD=ok
MALFORMED LINE
EOF

    # We *do* want to run it in a sub‑shell so we can capture the error message
    run bash -c '
        source "'"${BATS_TEST_DIRNAME}"'/../modules/config.sh"
        source "'"${BATS_TEST_DIRNAME}"'/../modules/logging.sh"
        source "'"${BATS_TEST_DIRNAME}"'/../modules/env.sh"
        env_from_file "'"${tmpfile}"'"
    '

    # The function should exit with a non‑zero status
    [ "$status" -ne 0 ]

    # The error text is printed to stderr by log_error
    [[ "$output" == *"Invalid line in env file"* ]]

    rm -f "$tmpfile"
}

# --------------------------------------------------------------------
#  4.  Missing file reports an error
# --------------------------------------------------------------------
@test "env_from_file reports missing file" {
    missing_file="/non/existing/env.file"

    run bash -c '
        source "'"${BATS_TEST_DIRNAME}"'/../modules/config.sh"
        source "'"${BATS_TEST_DIRNAME}"'/../modules/logging.sh"
        source "'"${BATS_TEST_DIRNAME}"'/../modules/env.sh"
        env_from_file "'"${missing_file}"'"
    '
    
    # The function should exit with a non‑zero status
    [ "$status" -ne 0 ]

    # Again, log_error writes to stderr
    [[ "$output" == *"Environment file not found"* ]]
}