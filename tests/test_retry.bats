#!/usr/bin/env bats

# ==============================================================================
# test_retry.bats – unit tests for the retry.sh reliability module
#
# The layout follows the style of the other test files in the repository:
#   • All required library modules are sourced in dependency order.
#   • Colours are disabled (NO_COLOR=1) for deterministic output.
#   • Any environment variables that the tests may touch are cleared in teardown.
#   • Each public function is exercised for both a successful and a failing
#     scenario.
# ==============================================================================

# ----------------------------------------------------------------------
# Global setup – runs once before any test case
# ----------------------------------------------------------------------
setup() {
    # Deterministic output – no colour codes.
    export NO_COLOR=1

    # Make the tests fast and deterministic: mock out wall-clock and sleeping.
    export ORIGINAL_PATH="$PATH"
    export MOCK_BIN_DIR
    MOCK_BIN_DIR="$(mktemp -d)"

    # Mock sleep: do nothing (no real waiting in unit tests).
    cat >"${MOCK_BIN_DIR}/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "${MOCK_BIN_DIR}/sleep"

    # Mock date +%s: return an incrementing counter so retry_until exits quickly.
    export DATE_COUNTER_FILE="${BATS_TEST_TMPDIR}/date_counter"
    echo 0 >"${DATE_COUNTER_FILE}"
    cat >"${MOCK_BIN_DIR}/date" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "+%s" ]]; then
  echo "mock date only supports: date +%s" >&2
  exit 2
fi

counter_file="${DATE_COUNTER_FILE:?}"
current="$(cat "$counter_file")"
echo "$current"
echo "$(( current + 1 ))" >"$counter_file"
EOF
    chmod +x "${MOCK_BIN_DIR}/date"

    export PATH="${MOCK_BIN_DIR}:${PATH}"

    # Load the module under test (it sources its own dependencies).
    source "${BATS_TEST_DIRNAME}/../modules/retry.sh"
}

# ----------------------------------------------------------------------
# Global teardown – runs after every test case
# ----------------------------------------------------------------------
teardown() {
    export PATH="$ORIGINAL_PATH"
    rm -rf "${MOCK_BIN_DIR}" || true

    unset DATE_COUNTER_FILE
    unset MOCK_BIN_DIR
    unset ORIGINAL_PATH
    unset NO_COLOR
}

# ----------------------------------------------------------------------
# Basic loading tests
# ----------------------------------------------------------------------
@test "retry module reports that it has been loaded" {
    [ "${BASH_UTILS_RETRY_LOADED:-}" = "true" ]
}

@test "retry module prevents multiple sourcing" {
    run source "${BATS_TEST_DIRNAME}/../modules/retry.sh"
    [ "$status" -eq 0 ]
}

# ----------------------------------------------------------------------
# retry – fixed number of attempts
# ----------------------------------------------------------------------
@test "retry succeeds when the command succeeds on the first try" {
    run retry_cmd 3 true
    [ "$status" -eq 0 ]
}

@test "retry fails after the configured number of attempts" {
    # `false` always returns 1 → after 3 attempts the function should still
    # return non‑zero.
    run retry_cmd 3 false
    [ "$status" -ne 0 ]
}

# ----------------------------------------------------------------------
# retry_with_backoff – exponential back‑off
# ----------------------------------------------------------------------
@test "retry_with_backoff succeeds immediately when the command works" {
    run retry_with_backoff 5 0 true
    [ "$status" -eq 0 ]
}

@test "retry_with_backoff respects the maximum number of attempts" {
    # The command always fails; we ask for 2 attempts with a 0‑second start delay.
    run retry_with_backoff 2 0 false
    [ "$status" -ne 0 ]
}

# ----------------------------------------------------------------------
# retry_until – timeout based retry
# ----------------------------------------------------------------------
@test "retry_until returns success if the command succeeds before timeout" {
    run retry_until 3 true
    [ "$status" -eq 0 ]
}

@test "retry_until gives up after the timeout expires" {
    # `false` never succeeds; the wrapper should stop after 2 seconds.
    run retry_until 2 false
    [ "$status" -ne 0 ]
}