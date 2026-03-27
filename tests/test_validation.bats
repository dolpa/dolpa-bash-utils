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
}

#===============================================================================
# NETWORK VALIDATION TESTS
#===============================================================================

@test "validate_ipv4 accepts valid IPv4 addresses" {
    run validate_ipv4 "192.168.1.1"
    [ "$status" -eq 0 ]
    
    run validate_ipv4 "10.0.0.1"
    [ "$status" -eq 0 ]
    
    run validate_ipv4 "255.255.255.255"
    [ "$status" -eq 0 ]
}

@test "validate_ipv4 rejects invalid IPv4 addresses" {
    run validate_ipv4 "256.1.1.1"
    [ "$status" -eq 1 ]
    
    run validate_ipv4 "192.168.1"
    [ "$status" -eq 1 ]
    
    run validate_ipv4 "192.168.1.1.1"
    [ "$status" -eq 1 ]
    
    run validate_ipv4 "not.an.ip.address"
    [ "$status" -eq 1 ]
}

@test "validate_ipv6 accepts valid IPv6 addresses" {
    run validate_ipv6 "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
    [ "$status" -eq 0 ]
    
    run validate_ipv6 "2001:db8:85a3::8a2e:370:7334"
    [ "$status" -eq 0 ]
}

@test "validate_ipv6 rejects invalid IPv6 addresses" {
    run validate_ipv6 "192.168.1.1"
    [ "$status" -eq 1 ]
    
    run validate_ipv6 "not-ipv6"
    [ "$status" -eq 1 ]
}

@test "validate_mac_address accepts valid MAC addresses" {
    run validate_mac_address "00:1B:44:11:3A:B7"
    [ "$status" -eq 0 ]
    
    run validate_mac_address "AA-BB-CC-DD-EE-FF"
    [ "$status" -eq 0 ]
}

@test "validate_mac_address rejects invalid MAC addresses" {
    run validate_mac_address "00:1B:44:11:3A"
    [ "$status" -eq 1 ]
    
    run validate_mac_address "00:1B:44:11:3A:B7:XX"
    [ "$status" -eq 1 ]
    
    run validate_mac_address "not-a-mac"
    [ "$status" -eq 1 ]
}

#===============================================================================
# DATA FORMAT VALIDATION TESTS
#===============================================================================

@test "validate_date accepts valid dates" {
    run validate_date "2023-12-25"
    [ "$status" -eq 0 ]
    
    run validate_date "2024-02-29"
    [ "$status" -eq 0 ]
}

@test "validate_date rejects invalid dates" {
    run validate_date "2023-13-25"
    [ "$status" -eq 1 ]
    
    run validate_date "2023-12-32"
    [ "$status" -eq 1 ]
    
    run validate_date "not-a-date"
    [ "$status" -eq 1 ]
    
    run validate_date "23-12-25"
    [ "$status" -eq 1 ]
}

@test "validate_phone_number accepts valid phone numbers" {
    run validate_phone_number "555-123-4567"
    [ "$status" -eq 0 ]
    
    run validate_phone_number "(555) 123-4567"
    [ "$status" -eq 0 ]
    
    run validate_phone_number "555.123.4567"
    [ "$status" -eq 0 ]
    
    run validate_phone_number "5551234567"
    [ "$status" -eq 0 ]
}

@test "validate_phone_number rejects invalid phone numbers" {
    run validate_phone_number "123"
    [ "$status" -eq 1 ]
    
    run validate_phone_number "555-123-456"
    [ "$status" -eq 1 ]
    
    run validate_phone_number "not-a-phone"
    [ "$status" -eq 1 ]
}

@test "validate_json accepts valid JSON" {
    skip "Requires jq or python for JSON validation"
}

@test "validate_json rejects invalid JSON" {
    skip "Requires jq or python for JSON validation"
}

#===============================================================================
# NUMERIC VALIDATION TESTS
#===============================================================================

@test "validate_number_range accepts numbers in range" {
    run validate_number_range "15" 1 100
    [ "$status" -eq 0 ]
    
    run validate_number_range "1" 1 100
    [ "$status" -eq 0 ]
    
    run validate_number_range "100" 1 100
    [ "$status" -eq 0 ]
}

@test "validate_number_range rejects numbers out of range" {
    run validate_number_range "0" 1 100
    [ "$status" -eq 1 ]
    
    run validate_number_range "101" 1 100
    [ "$status" -eq 1 ]
    
    run validate_number_range "abc" 1 100
    [ "$status" -eq 1 ]
}

@test "validate_positive_number accepts positive numbers" {
    run validate_positive_number "42"
    [ "$status" -eq 0 ]
    
    run validate_positive_number "3.14"
    [ "$status" -eq 0 ]
}

@test "validate_positive_number rejects non-positive numbers" {
    run validate_positive_number "0"
    [ "$status" -eq 1 ]
    
    run validate_positive_number "-5"
    [ "$status" -eq 1 ]
    
    run validate_positive_number "abc"
    [ "$status" -eq 1 ]
}

#===============================================================================
# SYSTEM VALIDATION TESTS
#===============================================================================

@test "validate_process_running checks for running processes" {
    # Test with a process that should be running
    run validate_process_running "$$"
    [ "$status" -eq 0 ]
}

@test "validate_process_running fails for non-existing processes" { 
    run validate_process_running "999999"
    [ "$status" -eq 1 ]
    
    run validate_process_running "non_existing_process_12345"
    [ "$status" -eq 1 ]
}

@test "validate_disk_space checks available disk space" {
    # Test with a small requirement for /tmp
    run validate_disk_space "/tmp" 1
    [ "$status" -eq 0 ]
}

@test "validate_disk_space fails for non-existing paths" {
    run validate_disk_space "/non/existing/path" 1
    [ "$status" -eq 1 ]
}

@test "validate_username accepts valid usernames" {
    run validate_username "john_doe"
    [ "$status" -eq 0 ]
    
    run validate_username "user123"
    [ "$status" -eq 0 ]
    
    run validate_username "test-user"
    [ "$status" -eq 0 ]
}

@test "validate_username rejects invalid usernames" {
    run validate_username "ab"
    [ "$status" -eq 1 ]
    
    run validate_username "user@name"
    [ "$status" -eq 1 ]
    
    run validate_username "very_very_very_very_long_username"
    [ "$status" -eq 1 ]
}

@test "validate_password_strength accepts strong passwords" {
    run validate_password_strength "MyP@ssw0rd123"
    [ "$status" -eq 0 ]
    
    run validate_password_strength "Str0ng!Pass"
    [ "$status" -eq 0 ]
}

@test "validate_password_strength rejects weak passwords" {
    run validate_password_strength "weak"
    [ "$status" -eq 1 ]
    
    run validate_password_strength "password123"
    [ "$status" -eq 1 ]
    
    run validate_password_strength "PASSWORD123"
    [ "$status" -eq 1 ]
    
    run validate_password_strength "Pass123"
    [ "$status" -eq 1 ]
}

@test "validate_env_var succeeds for set environment variables" {
    export TEST_VAR="test_value"
    run validate_env_var "TEST_VAR"
    [ "$status" -eq 0 ]
    unset TEST_VAR
}

@test "validate_env_var fails for unset environment variables" {
    run validate_env_var "UNSET_VARIABLE_12345"
    [ "$status" -eq 1 ]
} 