#!/usr/bin/env bats

# Test strings.sh module

setup() {
    # Load required modules in dependency order
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/strings.sh"
}

teardown() {
    # Clean up any environment variables set during tests
    # Note: Cannot unset readonly variables
    unset -f str_upper str_lower str_title str_length str_trim str_ltrim str_rtrim 2>/dev/null || true
    unset -f str_starts_with str_ends_with str_contains str_replace str_replace_first 2>/dev/null || true
    unset -f str_split str_join str_repeat str_pad_left str_pad_right str_is_empty 2>/dev/null || true
    unset -f str_substring str_reverse str_shorten 2>/dev/null || true
}

@test "strings module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/strings.sh"
    [ "$status" -eq 0 ]
}

@test "strings module sets BASH_UTILS_STRINGS_LOADED" {
    [ "$BASH_UTILS_STRINGS_LOADED" = "true" ]
}

@test "strings module prevents multiple sourcing" {
    # Source again, should return immediately
    run source "${BATS_TEST_DIRNAME}/../modules/strings.sh"
    [ "$status" -eq 0 ]
}

#===============================================================================
# CASE CONVERSION TESTS
#===============================================================================

@test "str_upper converts to uppercase" {
    run str_upper "hello world"
    [ "$status" -eq 0 ]
    [ "$output" = "HELLO WORLD" ]
}

@test "str_lower converts to lowercase" {
    run str_lower "HELLO WORLD"
    [ "$status" -eq 0 ]
    [ "$output" = "hello world" ]
}

@test "str_title converts to title case" {
    run str_title "hello world test"
    [ "$status" -eq 0 ]
    [ "$output" = "Hello World Test" ]
}

#===============================================================================
# LENGTH AND TRIMMING TESTS
#===============================================================================

@test "str_length returns correct string length" {
    run str_length "hello"
    [ "$status" -eq 0 ]
    [ "$output" = "5" ]
}

@test "str_length handles empty string" {
    run str_length ""
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "str_trim removes leading and trailing whitespace" {
    run str_trim "   hello world   "
    [ "$status" -eq 0 ]
    [ "$output" = "hello world" ]
}

@test "str_ltrim removes leading whitespace only" {
    run str_ltrim "   hello world   "
    [ "$status" -eq 0 ]
    [ "$output" = "hello world   " ]
}

@test "str_rtrim removes trailing whitespace only" {
    run str_rtrim "   hello world   "
    [ "$status" -eq 0 ]
    [ "$output" = "   hello world" ]
}

#===============================================================================
# STRING TESTING TESTS
#===============================================================================

@test "str_starts_with returns true for matching prefix" {
    run str_starts_with "hello world" "hello"
    [ "$status" -eq 0 ]
}

@test "str_starts_with returns false for non-matching prefix" {
    run str_starts_with "hello world" "world"
    [ "$status" -eq 1 ]
}

@test "str_ends_with returns true for matching suffix" {
    run str_ends_with "hello world" "world"
    [ "$status" -eq 0 ]
}

@test "str_ends_with returns false for non-matching suffix" {
    run str_ends_with "hello world" "hello"
    [ "$status" -eq 1 ]
}

@test "str_contains returns true for existing substring" {
    run str_contains "hello world" "llo wo"
    [ "$status" -eq 0 ]
}

@test "str_contains returns false for non-existing substring" {
    run str_contains "hello world" "xyz"
    [ "$status" -eq 1 ]
}

#===============================================================================
# STRING REPLACEMENT TESTS
#===============================================================================

@test "str_replace replaces all occurrences" {
    run str_replace "hello world world" "world" "universe"
    [ "$status" -eq 0 ]
    [ "$output" = "hello universe universe" ]
}

@test "str_replace_first replaces only first occurrence" {
    run str_replace_first "hello world world" "world" "universe"
    [ "$status" -eq 0 ]
    [ "$output" = "hello universe world" ]
}

#===============================================================================
# STRING MANIPULATION TESTS
#===============================================================================

@test "str_join joins strings with delimiter" {
    run str_join "," "a" "b" "c"
    [ "$status" -eq 0 ]
    [ "$output" = "a,b,c" ]
}

@test "str_repeat repeats string n times" {
    run str_repeat "abc" 3
    [ "$status" -eq 0 ]
    [ "$output" = "abcabcabc" ]
}

@test "str_pad_left pads string on the left" {
    run str_pad_left "abc" 6 "0"
    [ "$status" -eq 0 ]
    [ "$output" = "000abc" ]
}

@test "str_pad_right pads string on the right" {
    run str_pad_right "abc" 6 "0"
    [ "$status" -eq 0 ]
    [ "$output" = "abc000" ]
}

@test "str_is_empty returns true for empty string" {
    run str_is_empty ""
    [ "$status" -eq 0 ]
}

@test "str_is_empty returns true for whitespace-only string" {
    run str_is_empty "   "
    [ "$status" -eq 0 ]
}

@test "str_is_empty returns false for non-empty string" {
    run str_is_empty "hello"
    [ "$status" -eq 1 ]
}

@test "str_substring extracts substring by position" {
    run str_substring "hello world" 6 5
    [ "$status" -eq 0 ]
    [ "$output" = "world" ]
}

@test "str_substring extracts substring to end" {
    run str_substring "hello world" 6
    [ "$status" -eq 0 ]
    [ "$output" = "world" ]
}

@test "str_reverse reverses a string" {
    run str_reverse "hello"
    [ "$status" -eq 0 ]
    [ "$output" = "olleh" ]
}

@test "str_shorten returns original string when within max length" {
    run str_shorten 10 "short"
    [ "$status" -eq 0 ]
    [ "$output" = "short" ]
}

@test "str_shorten truncates and appends ellipsis when max length allows" {
    run str_shorten 10 "Very long text"
    [ "$status" -eq 0 ]
    [ "$output" = "Very lo..." ]
}

@test "str_shorten truncates without ellipsis when max length is too small" {
    run str_shorten 3 "abcdef"
    [ "$status" -eq 0 ]
    [ "$output" = "abc" ]
}

@test "str_shorten uses default max length of 10" {
    run str_shorten
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

#===============================================================================
# STRING SPLIT TESTS
#===============================================================================

@test "str_split splits string into array" {
    # Test using a function since we can't test array assignment directly
    run bash -c '
        source "'${BATS_TEST_DIRNAME}'/../modules/config.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/logging.sh"
        source "'${BATS_TEST_DIRNAME}'/../modules/strings.sh"
        declare -a result
        str_split "a,b,c" "," result
        echo "${#result[@]}"
        echo "${result[0]}"
        echo "${result[1]}" 
        echo "${result[2]}"
    '
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "3" ]
    [ "${lines[1]}" = "a" ]
    [ "${lines[2]}" = "b" ]
    [ "${lines[3]}" = "c" ]
}

#===============================================================================
# STRING VALIDATION TESTS
#===============================================================================

@test "str_is_numeric returns true for numeric string" {
    run str_is_numeric "12345"
    [ "$status" -eq 0 ]
}

@test "str_is_numeric returns false for non-numeric string" {
    run str_is_numeric "123abc"
    [ "$status" -eq 1 ]
    
    run str_is_numeric "hello"
    [ "$status" -eq 1 ]
}

@test "str_is_alpha returns true for alphabetic string" {
    run str_is_alpha "hello"
    [ "$status" -eq 0 ]
    
    run str_is_alpha "HELLO"
    [ "$status" -eq 0 ]
}

@test "str_is_alpha returns false for non-alphabetic string" {
    run str_is_alpha "hello123"
    [ "$status" -eq 1 ]
    
    run str_is_alpha "hello world"
    [ "$status" -eq 1 ]
}

@test "str_is_alnum returns true for alphanumeric string" {
    run str_is_alnum "hello123"
    [ "$status" -eq 0 ]
    
    run str_is_alnum "ABC123"
    [ "$status" -eq 0 ]
}

@test "str_is_alnum returns false for non-alphanumeric string" {
    run str_is_alnum "hello 123"
    [ "$status" -eq 1 ]
    
    run str_is_alnum "hello@123"
    [ "$status" -eq 1 ]
}

@test "str_is_email returns true for valid email addresses" {
    run str_is_email "user@example.com"
    [ "$status" -eq 0 ]
    
    run str_is_email "test.email+tag@example.org"
    [ "$status" -eq 0 ]
}

@test "str_is_email returns false for invalid email addresses" {
    run str_is_email "invalid.email"
    [ "$status" -eq 1 ]
    
    run str_is_email "@example.com"
    [ "$status" -eq 1 ]
    
    run str_is_email "user@"
    [ "$status" -eq 1 ]
}

@test "str_is_url returns true for valid URLs" {
    run str_is_url "https://example.com"
    [ "$status" -eq 0 ]
    
    run str_is_url "http://example.com:8080/path"
    [ "$status" -eq 0 ]
}

@test "str_is_url returns false for invalid URLs" {
    run str_is_url "ftp://example.com"
    [ "$status" -eq 1 ]
    
    run str_is_url "not-a-url"
    [ "$status" -eq 1 ]
}

@test "str_is_ipv4 returns true for valid IPv4 addresses" {
    run str_is_ipv4 "192.168.1.1"
    [ "$status" -eq 0 ]
    
    run str_is_ipv4 "10.0.0.1"
    [ "$status" -eq 0 ]
}

@test "str_is_ipv4 returns false for invalid IPv4 addresses" {
    run str_is_ipv4 "192.168.1.256"
    [ "$status" -eq 1 ]
    
    run str_is_ipv4 "192.168.1"
    [ "$status" -eq 1 ]
    
    run str_is_ipv4 "not.an.ip.address"
    [ "$status" -eq 1 ]
}

#===============================================================================
# STRING SEARCH AND INDEX TESTS
#===============================================================================

@test "str_index returns correct index of substring" {
    run str_index "hello world" "world"
    [ "$status" -eq 0 ]
    [ "$output" = "6" ]
}

@test "str_index returns -1 for non-existing substring" {
    run str_index "hello world" "xyz"
    [ "$status" -eq 0 ]
    [ "$output" = "-1" ]
}

@test "str_rindex returns correct last index of substring" {
    run str_rindex "hello world hello" "hello"
    [ "$status" -eq 0 ]
    [ "$output" = "12" ]
}

@test "str_count returns correct count of substring occurrences" {
    run str_count "hello hello hello" "hello"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

@test "str_count returns 0 for non-existing substring" {
    run str_count "hello world" "xyz"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

#===============================================================================
# CASE CONVERSION TESTS
#===============================================================================

@test "str_to_snake converts to snake_case" {
    run str_to_snake "HelloWorld"
    [ "$status" -eq 0 ]
    [ "$output" = "hello_world" ]
    
    run str_to_snake "hello world"
    [ "$status" -eq 0 ]
    [ "$output" = "hello_world" ]
}

@test "str_to_kebab converts to kebab-case" {
    run str_to_kebab "HelloWorld"
    [ "$status" -eq 0 ]
    [ "$output" = "hello-world" ]
    
    run str_to_kebab "hello world"
    [ "$status" -eq 0 ]
    [ "$output" = "hello-world" ]
}

@test "str_to_camel converts to camelCase" {
    run str_to_camel "hello world"
    [ "$status" -eq 0 ]
    [ "$output" = "helloWorld" ]
    
    run str_to_camel "hello-world"
    [ "$status" -eq 0 ]
    [ "$output" = "helloWorld" ]
}

@test "str_to_pascal converts to PascalCase" {
    run str_to_pascal "hello world"
    [ "$status" -eq 0 ]
    [ "$output" = "HelloWorld" ]
    
    run str_to_pascal "hello-world"
    [ "$status" -eq 0 ]
    [ "$output" = "HelloWorld" ]
}

#===============================================================================
# STRING ENCODING AND ESCAPING TESTS
#===============================================================================

@test "str_url_encode encodes URL special characters" {
    run str_url_encode "hello world"
    [ "$status" -eq 0 ]
    [ "$output" = "hello%20world" ]
}

@test "str_url_decode decodes URL encoded characters" {
    run str_url_decode "hello%20world"
    [ "$status" -eq 0 ]
    [ "$output" = "hello world" ]
}

@test "str_shell_escape escapes shell special characters" {
    run str_shell_escape "rm -rf /"
    [ "$status" -eq 0 ]
    # Should contain escaped characters
    [[ "$output" == *"\\"* ]] || [[ "$output" == *"'"* ]]
}

@test "str_html_escape escapes HTML special characters" {
    run str_html_escape "<script>alert('test')</script>"  
    [ "$status" -eq 0 ]
    [ "$output" = "&lt;script&gt;alert(&#39;test&#39;)&lt;/script&gt;" ]
}

@test "str_html_unescape unescapes HTML entities" {
    run str_html_unescape "&lt;strong&gt;bold&lt;/strong&gt;"
    [ "$status" -eq 0 ]
    [ "$output" = "<strong>bold</strong>" ]
}

#===============================================================================
# STRING COMPARISON TESTS
#===============================================================================

@test "str_equals_ignore_case returns true for case-insensitive match" {
    run str_equals_ignore_case "Hello" "hello"
    [ "$status" -eq 0 ]
    
    run str_equals_ignore_case "WORLD" "world"
    [ "$status" -eq 0 ]
}

@test "str_equals_ignore_case returns false for non-matching strings" {
    run str_equals_ignore_case "hello" "world"
    [ "$status" -eq 1 ]
}

@test "str_version_compare compares version strings correctly" {
    # Test if 1.2.3 < 1.2.10
    run str_version_compare "1.2.3" "1.2.10"
    [ "$status" -eq 0 ]
    
    # Test if 2.0.0 >= 1.9.9 (should return 1)
    run str_version_compare "2.0.0" "1.9.9"
    [ "$status" -eq 1 ]
}

#===============================================================================
# STRING GENERATION TESTS
#===============================================================================

@test "str_random generates random string of correct length" {
    run str_random 8
    [ "$status" -eq 0 ]
    [ "${#output}" -eq 8 ]
}

@test "str_random generates different strings on multiple calls" {
    local first second
    first=$(str_random 10)
    second=$(str_random 10)
    [ "$first" != "$second" ]
}