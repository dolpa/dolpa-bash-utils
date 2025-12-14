#!/usr/bin/env bats

#====================================================================
# Test suite for the time.sh module
#
# The layout mirrors the existing test files – load dependencies,
# disable colours, and clean up any environment variables that the
# tests may change.
#====================================================================

# ------------------------------------------------------------------
# Global setup – runs once before *any* test case.
# ------------------------------------------------------------------
setup() {
    export NO_COLOR=1

    # Load the library modules in the correct order.
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/time.sh"
}

# ------------------------------------------------------------------
# Global teardown – runs after each test case.
# ------------------------------------------------------------------
teardown() {
    unset NO_COLOR
}

# ------------------------------------------------------------------
# Verify the module loads and the loaded flag is set.
# ------------------------------------------------------------------
@test "time module reports that it has been loaded" {
    [ -n "${BASH_UTILS_TIME_LOADED:-}" ]
}

# ------------------------------------------------------------------
# time_now – ISO‑8601 timestamp.
# ------------------------------------------------------------------
@test "time_now returns a valid ISO‑8601 string (UTC)" {
    run time_now
    [ "$status" -eq 0 ]

    # Expected pattern: 2023-09-14T12:34:56Z
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

# ------------------------------------------------------------------
# time_epoch – seconds since the epoch.
# ------------------------------------------------------------------
@test "time_epoch returns a non‑negative integer" {
    run time_epoch
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
    (( output >= 0 ))
}

@test "time_epoch_ms returns a millisecond epoch integer" {
    run time_epoch_ms
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]{13,}$ ]]
}

# ------------------------------------------------------------------
# time_benchmark – human readable diff between two epoch values.
# ------------------------------------------------------------------
@test "time_benchmark formats a short interval correctly" {
    run time_benchmark 100 102
    [ "$status" -eq 0 ]
    [ "$output" = "2s" ]
}

@test "time_benchmark rejects invalid arguments" {
    run time_benchmark "" ""
    [ "$status" -ne 0 ]
}

@test "time_epoch_to_iso8601 formats a known epoch (UTC)" {
    run time_epoch_to_iso8601 0 utc
    [ "$status" -eq 0 ]
    [ "$output" = "1970-01-01T00:00:00Z" ]
}

@test "time_parse_iso8601 parses a known ISO-8601 Z timestamp" {
    run time_parse_iso8601 "1970-01-01T00:00:00Z"
    [ "$status" -eq 0 ]
    [ "$output" -eq 0 ]
}

@test "time_add_seconds adds seconds correctly" {
    run time_add_seconds 10 5
    [ "$status" -eq 0 ]
    [ "$output" -eq 15 ]
}

@test "time_diff_seconds computes signed deltas" {
    run time_diff_seconds 15 10
    [ "$status" -eq 0 ]
    [ "$output" -eq -5 ]
}

@test "time_seconds_to_human formats a duration" {
    run time_seconds_to_human 3661
    [ "$status" -eq 0 ]
    [ "$output" = "1h1m1s" ]
}

# ------------------------------------------------------------------
# sleep_until – sleep until a given epoch time.
# ------------------------------------------------------------------
@test "sleep_until sleeps for the requested amount of time" {
    local target

    # Avoid real sleeps in CI: sleeping until a time in the past should be a no-op.
    target=$(( $(time_epoch) - 1 ))
    run sleep_until "$target"
    [ "$status" -eq 0 ]
}

# ------------------------------------------------------------------
# Ensure the module prevents double‑sourcing.
# ------------------------------------------------------------------
@test "time module prevents multiple sourcing" {
    run source "${BATS_TEST_DIRNAME}/../modules/time.sh"
    [ "$status" -eq 0 ]
}