#!/usr/bin/env bats

# Test validation.sh module

setup() {
    # Load required modules
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/validation.sh"
    
    # Disable colors for consistent testing
    export NO_COLOR=1
}

teardown() {
    # Note: Cannot unset readonly variables
    true
}

@test "validation module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/validation.sh"
    [ "$status" -eq 0 ]
}

@test "validation module sets BASH_UTILS_VALIDATION_LOADED" {
    [ "$BASH_UTILS_VALIDATION_LOADED" = "true" ]
}

@test "command_exists returns 0 for existing command" {
    run command_exists "echo"
    [ "$status" -eq 0 ]
}

@test "command_exists returns 1 for non-existing command" {
    run command_exists "non_existing_command_12345"
    [ "$status" -eq 1 ]
}

@test "validate_file returns 0 for existing file" {
    # Create a temporary file
    temp_file="$(mktemp)"
    echo "test" > "$temp_file"
    
    run validate_file "$temp_file"
    [ "$status" -eq 0 ]
    
    # Clean up
    rm -f "$temp_file"
}

@test "validate_file returns 1 for non-existing file" {
    run validate_file "/non/existing/file.txt"
    [ "$status" -eq 1 ]
}

@test "validate_directory returns 0 for existing directory" {
    run validate_directory "$BATS_TEST_DIRNAME"
    [ "$status" -eq 0 ]
}

@test "validate_directory returns 1 for non-existing directory" {
    run validate_directory "/non/existing/directory"
    [ "$status" -eq 1 ]
}

@test "validate_not_empty returns 0 for non-empty string" {
    run validate_not_empty "test string"
    [ "$status" -eq 0 ]
}

@test "validate_not_empty returns 1 for empty string" {
    run validate_not_empty ""
    [ "$status" -eq 1 ]
}

@test "validate_system_name accepts valid names" {
    run validate_system_name "valid-system-name"
    [ "$status" -eq 0 ]
    
    run validate_system_name "valid_system_name"
    [ "$status" -eq 0 ]
    
    run validate_system_name "valid123"
    [ "$status" -eq 0 ]
}

@test "validate_system_name rejects invalid names" {
    run validate_system_name "-invalid"
    [ "$status" -eq 1 ]
    
    run validate_system_name "invalid-"
    [ "$status" -eq 1 ]
    
    run validate_system_name "invalid@name"
    [ "$status" -eq 1 ]
}

@test "validate_email accepts valid email addresses" {
    run validate_email "test@example.com"
    [ "$status" -eq 0 ]
    
    run validate_email "user.name+tag@example.co.uk"
    [ "$status" -eq 0 ]
}

@test "validate_email rejects invalid email addresses" {
    run validate_email "invalid-email"
    [ "$status" -eq 1 ]
    
    run validate_email "@example.com"
    [ "$status" -eq 1 ]
    
    run validate_email "test@"
    [ "$status" -eq 1 ]
}

@test "validate_url accepts valid URLs" {
    run validate_url "https://example.com"
    [ "$status" -eq 0 ]
    
    run validate_url "http://example.com/path"
    [ "$status" -eq 0 ]
}

@test "validate_url rejects invalid URLs" {
    run validate_url "not-a-url"
    [ "$status" -eq 1 ]
    
    run validate_url "ftp://example.com"
    [ "$status" -eq 1 ]
}

@test "validate_port accepts valid port numbers" {
    run validate_port "80"
    [ "$status" -eq 0 ]
    
    run validate_port "8080"
    [ "$status" -eq 0 ]
    
    run validate_port "65535"
    [ "$status" -eq 0 ]
}

@test "validate_port rejects invalid port numbers" {
    run validate_port "0"
    [ "$status" -eq 1 ]
    
    run validate_port "65536"
    [ "$status" -eq 1 ]
    
    run validate_port "abc"
    [ "$status" -eq 1 ]
    
    run validate_port "-1"
    [ "$status" -eq 1 ]
}