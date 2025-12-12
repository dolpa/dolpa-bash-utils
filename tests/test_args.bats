#!/usr/bin/env bats
#===============================================================================
# test_args.bats – tests for the new args module
#===============================================================================

setup() {
    # Load the core library files that the tests rely on
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/env.sh"
    source "${BATS_TEST_DIRNAME}/../modules/args.sh"

    # Keep output tidy – the logging module respects NO_COLOR
    export NO_COLOR=1
}

teardown() {
    # Unset the globals that the parser creates so each test starts fresh
    unset ARGS_FLAGS ARGS_VALUES ARGS_POSITIONAL BASH_UTILS_ARGS_USAGE
    # unset ARGS_FLAG[@] ARGS_VALUE[@] ARGS_POSITIONAL[@]
}

# ---------------------------------------------------------------------------
# Basic loading
# ---------------------------------------------------------------------------
@test "args module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/args.sh"
    [ "$status" -eq 0 ]
}

@test "args module sets BASH_UTILS_ARGS_LOADED flag" {
    [ "${BASH_UTILS_ARGS_LOADED:-}" = "true"  ]
}

# ---------------------------------------------------------------------------
# Normal CLI parsing
# ---------------------------------------------------------------------------
@test "args_parse correctly extracts flags, values and positionals" {
    # parse the arguments
    args_parse --force --output out.txt pos1 pos2

    # --- flags ------------------------------------------------------------
    # flag that is present
    run args_get_flag --force
    [ "$status" -eq 0 ]

    # flag that is NOT present
    run args_get_flag --dry-run
    [ "$status" -eq 1 ]

    # --- values -----------------------------------------------------------
    result=$(args_get_value --output)
    [ "$result" = "out.txt" ]

    # --- positional arguments --------------------------------------------
    [ "${#ARGS_POSITIONAL[@]}" -eq 2 ]
    [ "${ARGS_POSITIONAL[0]}" = "pos1" ]
    [ "${ARGS_POSITIONAL[1]}" = "pos2" ]
}

# ---------------------------------------------------------------------------
# Short‑flag grouping (e.g. -abc)
# ---------------------------------------------------------------------------
# @test "short flag groups are recognised" {
#     args_parse -xyz
#     args_get_flag -x && args_get_flag -y && args_get_flag -z
#     [ "$?" -eq 0 ]
# }

# ---------------------------------------------------------------------------
# Fallback to environment variables
# ---------------------------------------------------------------------------
@test "args_get_flag falls back to an environment variable" {
    export FORCE=1
    args_parse            # no arguments
    run args_get_flag --force
    [ "$status" -eq 0 ]   # succeeded because $FORCE is set
}

# @test "args_get_value falls back to an environment variable" {
#     export FILE=env_file.txt
#     args_parse          # no CLI arguments
#     result=$(args_get_value --file)
#     [ "$result" = "env_file.txt" ]
# }

# ---------------------------------------------------------------------------
# Default value handling
# ---------------------------------------------------------------------------
@test "args_get_value returns a caller supplied default when nothing else is set" {
    args_parse          # nothing on CLI and nothing in env
    result=$(args_get_value --missing "default.txt")
    [ "$result" = "default.txt" ]
}

# ---------------------------------------------------------------------------
# Usage helper
# ---------------------------------------------------------------------------
@test "args_usage prints the stored usage string" {
    args_set_usage "--input <file>  Input file
                     --output <file> Output file"
    run args_usage
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--input"* ]]
    [[ "$output" == *"--output"* ]]
}