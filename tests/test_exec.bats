#!/usr/bin/env bats
#===============================================================================
# test_exec.bats – BATS test suite for modules/exec.sh
#===============================================================================

# ---------------------------------------------------------------------------
# Load the *library* modules that exec.sh depends on.
# They are all sourced from the test directory (the same layout as the
# existing test files in the repository).
# ---------------------------------------------------------------------------
setup() {
    # The directory that contains the test file:
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/strings.sh"
    source "${BATS_TEST_DIRNAME}/../modules/exec.sh"
}

# ---------------------------------------------------------------------------
# 1️⃣  Basic sanity checks
# ---------------------------------------------------------------------------
@test "exec.sh loads sets flag" {
    # source module and check the flag
    run source "${BATS_TEST_DIRNAME}/../modules/exec.sh"
    [ "$BASH_UTILS_EXEC_LOADED" = "true" ]
    [ "$status" -eq 0 ]
}

@test "exec.sh module prevents multiple sourcing" {
    # Source module again, should return immediately
    run source "${BATS_TEST_DIRNAME}/../modules/exec.sh"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 2️⃣ exec_run – foreground execution
# ---------------------------------------------------------------------------
@test "exec_run succeeds on a command that exits 0" {
    run source "${BATS_TEST_DIRNAME}/../modules/exec.sh"

    exec_run true
    [ "$status" -eq 0 ]
}

@test "exec_run returns non‑zero on failure" {
    run exec_run false
    [ "$status" -ne 0 ]            # we *expect* a failure here
}

# --------------------------------------------------------------------
#  exec_run_capture – captures both stdout and stderr
# --------------------------------------------------------------------
@test "exec_run_capture captures stdout and stderr correctly" {
    # a tiny script that prints to both streams
    script='{
        echo "STDOUT‑LINE"
        echo "STDERR‑LINE" >&2
        exit 42
    }'

    run exec_run_capture out err "$script"

    # the wrapper should return the command’s exit status
    [ "$status" -eq 42 ]

    # and the two variables must contain the right data
    [ "$out" = "STDOUT‑LINE" ]
    [ "$err" = "STDERR‑LINE" ]
}

# --------------------------------------------------------------------
#  exec_background – fire‑and‑forget a command and get its PID
# --------------------------------------------------------------------
@test "exec_background launches a job and returns a running PID" {
    pid=$(exec_background sleep 5)
    # a PID > 0 must be returned
    [ "$pid" -gt 0 ]
    # and the process must be alive right now
    exec_is_running "$pid"
}

@test "exec_is_running reports dead PID correctly" {
    # 999999 is almost certainly not a live process on any test host
    ! exec_is_running 999999
}

@test "exec_kill terminates a long‑running background job" {
    pid=$(exec_background sleep 30)

    # give the job a moment to really start
    sleep 0.2

    # now kill it and make sure it’s gone
    exec_kill "$pid"
    ! exec_is_running "$pid"
}

# --------------------------------------------------------------------
#  exec_wait – wait for a PID to finish, with optional timeout
# --------------------------------------------------------------------
@test "exec_wait returns 0 when process finishes before timeout" {
    pid=$(exec_background sleep 0.5)
    exec_wait "$pid" 2               # 2‑second timeout – should succeed
    [ "$?" -eq 0 ]
}

@test "exec_wait returns 1 on timeout" {
    pid=$(exec_background sleep 5)
    exec_wait "$pid" 1               # 1‑second timeout – should *fail*
    [ "$?" -ne 0 ]
}

# --------------------------------------------------------------------
#  exec_run_with_timeout – run a command but abort it after N seconds
# --------------------------------------------------------------------
@test "exec_run_with_timeout aborts a command that exceeds the timeout" {
    # ‘timeout’ exits with 124 when it kills the child
    run exec_run_with_timeout 1 sleep 3
    [ "$status" -eq 124 ]
}