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

@test "log_debug outputs when BASH_UTILS_VERBOSE is true" {
    export BASH_UTILS_VERBOSE=true
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
    run log_trace "test trace"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[TRACE]"* ]]
    [[ "$output" == *"test trace"* ]]
}

@test "log_trace is silent when BASH_UTILS_DEBUG is false" {
    export BASH_UTILS_DEBUG=false
    run log_trace "test trace"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
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