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
    unset -f str_substring str_reverse 2>/dev/null || true
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