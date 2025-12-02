#!/usr/bin/env bats

# Test utils.sh module

setup() {
    # Load required modules
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/utils.sh"
    
    # Disable colors for consistent testing
    export NO_COLOR=1
}

teardown() {
    # Note: Cannot unset readonly variables
    true
}

@test "utils module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/utils.sh"
    [ "$status" -eq 0 ]
}

@test "utils module sets BASH_UTILS_UTILITIES_LOADED" {
    [ "$BASH_UTILS_UTILITIES_LOADED" = "true" ]
}

@test "seconds_to_human formats seconds correctly" {
    result=$(seconds_to_human 0)
    [ "$result" = "0s" ]
    
    result=$(seconds_to_human 65)
    [ "$result" = "1m5s" ]
    
    result=$(seconds_to_human 3661)
    [ "$result" = "1h1m1s" ]
    
    result=$(seconds_to_human 90061)
    [ "$result" = "1d1h1m1s" ]
}

@test "bytes_to_human formats bytes correctly" {
    result=$(bytes_to_human 512)
    [ "$result" = "512B" ]
    
    result=$(bytes_to_human 1024)
    [ "$result" = "1KB" ]
    
    result=$(bytes_to_human 1048576)
    [ "$result" = "1MB" ]
}

@test "generate_random_string generates string of correct length" {
    result=$(generate_random_string 10)
    [ ${#result} -eq 10 ]
    
    result=$(generate_random_string 20)
    [ ${#result} -eq 20 ]
}

@test "generate_random_string uses default length" {
    result=$(generate_random_string)
    [ ${#result} -eq 16 ]
}

@test "is_semver validates semantic versions correctly" {
    run is_semver "1.0.0"
    [ "$status" -eq 0 ]
    
    run is_semver "1.2.3-alpha"
    [ "$status" -eq 0 ]
    
    run is_semver "1.2.3+build.1"
    [ "$status" -eq 0 ]
    
    run is_semver "1.0"
    [ "$status" -eq 1 ]
    
    run is_semver "invalid"
    [ "$status" -eq 1 ]
}

@test "compare_versions compares versions correctly" {
    result=$(compare_versions "1.0.0" "1.0.0")
    [ "$result" = "0" ]
    
    result=$(compare_versions "1.0.1" "1.0.0")
    [ "$result" = "1" ]
    
    result=$(compare_versions "1.0.0" "1.0.1")
    [ "$result" = "-1" ]
    
    result=$(compare_versions "2.0.0" "1.9.9")
    [ "$result" = "1" ]
}

@test "retry function attempts command multiple times" {
    # Test with a command that always fails
    run retry 2 1 1 false
    [ "$status" -eq 1 ]
}

@test "retry function succeeds on first attempt" {
    run retry 3 1 1 true
    [ "$status" -eq 0 ]
}

@test "setup_signal_handlers sets up trap" {
    # This is difficult to test directly, just ensure it doesn't error
    run setup_signal_handlers
    [ "$status" -eq 0 ]
}

@test "cleanup_on_exit function exists" {
    # Test that the function exists and can be called
    run cleanup_on_exit
    [ "$status" -eq 0 ]
}

# Note: show_spinner and confirm functions are difficult to test
# in an automated environment as they involve interactive elements
# or background processes. They would require more complex test setups.