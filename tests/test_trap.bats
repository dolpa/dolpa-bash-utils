#!/usr/bin/env bats

# ==============================================================================
# test_trap.bats – unit tests for the trap.sh module
#
# Conventions:
#   - Set NO_COLOR=1 before sourcing modules (deterministic output)
#   - Avoid real sleeps and brittle temp-script relative paths
#   - Prefer single-process tests where output is captured by `run`
# ==============================================================================

setup() {
    export NO_COLOR=1
    export BASH_UTILS_TIMESTAMP=false

    # Module under test (loads its own dependencies).
    source "${BATS_TEST_DIRNAME}/../modules/trap.sh"
}

teardown() {
    unset BASH_UTILS_TIMESTAMP
    unset NO_COLOR
}

@test "trap module reports that it has been loaded" {
    [ "${BASH_UTILS_TRAP_LOADED:-}" = "true" ]
}

@test "trap module prevents multiple sourcing" {
    run source "${BATS_TEST_DIRNAME}/../modules/trap.sh"
    [ "$status" -eq 0 ]
}

@test "trap_on_exit runs the supplied cleanup function" {
    run bash -c '
        export NO_COLOR=1
        export BASH_UTILS_TIMESTAMP=false
        source "'"${BATS_TEST_DIRNAME}"'/../modules/trap.sh"

        cleanup() { echo "CLEANED"; }
        trap_on_exit cleanup
        exit 0
    '

    [ "$status" -eq 0 ]
    [[ "$output" == *"CLEANED"* ]]
}

@test "trap_signals exits gracefully and runs EXIT trap" {
    run bash -c '
        export NO_COLOR=1
        export BASH_UTILS_TIMESTAMP=false
        source "'"${BATS_TEST_DIRNAME}"'/../modules/trap.sh"

        cleanup() { echo "cleaned_on_exit"; }
        trap_on_exit cleanup
        trap_signals TERM

        kill -TERM $$
        echo "unreachable"
    '

    [ "$status" -eq 0 ]
    [[ "$output" == *"Received signal TERM"* ]]
        [[ "$output" == *"cleaned_on_exit"* ]]
}

@test "with_tempdir runs command in a temp dir and removes it" {
    run bash -c '
        export NO_COLOR=1
        export BASH_UTILS_TIMESTAMP=false
        source "'"${BATS_TEST_DIRNAME}"'/../modules/trap.sh"

        with_tempdir bash -c "touch testfile && pwd"
    '

    [ "$status" -eq 0 ]

    tmpdir="${lines[0]}"
    [ -n "$tmpdir" ]
    [ ! -d "$tmpdir" ]
}
