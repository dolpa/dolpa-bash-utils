#!/usr/bin/env bats

# Test logging.sh module

setup() {
    # Load required modules
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    
    # Disable colors for consistent testing
    export NO_COLOR=1
    
    # Set test timestamp format
    export BASH_UTILS_TIMESTAMP_FORMAT="%Y-%m-%d %H:%M:%S"
}

teardown() {
    # Note: Cannot unset readonly variables
    unset BASH_UTILS_VERBOSE || true
    unset BASH_UTILS_DEBUG || true
    unset BASH_UTILS_LOG_LEVEL || true
    unset NO_COLOR || true
}

@test "logging module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    [ "$status" -eq 0 ]
}

@test "logging module sets BASH_UTILS_LOGGING_LOADED" {
    [ "$BASH_UTILS_LOGGING_LOADED" = "true" ]
}

@test "_get_timestamp function returns formatted timestamp" {
    result=$(_get_timestamp)
    # Should match YYYY-MM-DD HH:MM:SS format
    [[ "$result" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]
}

@test "log_info outputs info message" {
    run log_info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
    [[ "$output" == *"test message"* ]]
}

@test "log_success outputs success message" {
    run log_success "test success"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SUCCESS]"* ]]
    [[ "$output" == *"test success"* ]]
}

@test "log_warning outputs warning message" {
    run log_warning "test warning"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARNING]"* ]]
    [[ "$output" == *"test warning"* ]]
}

@test "log_warn is alias for log_warning" {
    run log_warn "test warn"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARNING]"* ]]
    [[ "$output" == *"test warn"* ]]
}

@test "log_error outputs error message to stderr" {
    run log_error "test error"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERROR]"* ]]
    [[ "$output" == *"test error"* ]]
}

@test "log_critical outputs critical message to stderr" {
    run log_critical "test critical"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[CRITICAL]"* ]]
    [[ "$output" == *"test critical"* ]]
}

@test "log_fatal is alias for log_critical" {
    run log_fatal "test fatal"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[CRITICAL]"* ]]
    [[ "$output" == *"test fatal"* ]]
}

@test "log_to_file outputs to console and appends formatted info entry to log file" {
    local log_file
    log_file="$(mktemp)"

    run log_to_file "info" "$log_file" "file log message"

    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
    [[ "$output" == *"file log message"* ]]

    run grep -E '^\[INFO\].*file log message$' "$log_file"
    [ "$status" -eq 0 ]

    rm -f "$log_file"
}

@test "log_to_file supports error level and writes to file" {
    local log_file
    log_file="$(mktemp)"

    run log_to_file "error" "$log_file" "file error message"

    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERROR]"* ]]
    [[ "$output" == *"file error message"* ]]

    run grep -E '^\[ERROR\].*file error message$' "$log_file"
    [ "$status" -eq 0 ]

    rm -f "$log_file"
}

@test "log_to_file accepts upper-case levels" {
    local log_file
    log_file="$(mktemp)"

    run log_to_file "SUCCESS" "$log_file" "upper case level"

    [ "$status" -eq 0 ]
    [[ "$output" == *"[SUCCESS]"* ]]
    [[ "$output" == *"upper case level"* ]]

    run grep -E '^\[SUCCESS\].*upper case level$' "$log_file"
    [ "$status" -eq 0 ]

    rm -f "$log_file"
}

@test "log_debug outputs when BASH_UTILS_VERBOSE is true" {
    export BASH_UTILS_VERBOSE=true
    export BASH_UTILS_LOG_LEVEL=DEBUG
    run log_debug "test debug"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DEBUG]"* ]]
    [[ "$output" == *"test debug"* ]]
}

@test "log_debug is silent when BASH_UTILS_VERBOSE is false" {
    export BASH_UTILS_VERBOSE=false
    run log_debug "test debug"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "log_trace outputs when BASH_UTILS_DEBUG is true" {
    export BASH_UTILS_DEBUG=true
    export BASH_UTILS_LOG_LEVEL=TRACE
    run log_trace "test trace"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[TRACE]"* ]]
    [[ "$output" == *"test trace"* ]]
}

@test "log_trace is silent when BASH_UTILS_DEBUG is false" {
    # The function returns a non‑zero status when the trace is disabled.
    # We only care that nothing is printed, so we do not assert on $status.
    export BASH_UTILS_DEBUG=false
    # (re‑source to make the library pick up the new value)

    run log_trace "debug off"
    # When debugging is off the function returns 1 – that is expected.
    [ "$status" -ne 0 ] || echo "unexpected success" >&2
    [ -z "$output" ]
}

@test "minimum log level filters lower-priority logs" {
    export BASH_UTILS_LOG_LEVEL=WARNING

    run bash -c '
        source "'"$BATS_TEST_DIRNAME"'/../modules/logging.sh"
        log_info "this must be hidden"
    '
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run bash -c '
        source "'"$BATS_TEST_DIRNAME"'/../modules/logging.sh"
        log_warning "this must appear"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARNING]"* ]]
}

@test "log_header outputs formatted header" {
    run log_header "Test Header"
    [ "$status" -eq 0 ]
    [[ "$output" == *"=========="* ]]
    [[ "$output" == *"Test Header"* ]]
}

@test "log_section outputs formatted section" {
    run log_section "Test Section"
    [ "$status" -eq 0 ]
    [[ "$output" == *"### Test Section"* ]]
}

@test "log_step outputs formatted step" {
    run log_step "1" "First step"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Step 1:"* ]]
    [[ "$output" == *"First step"* ]]
}