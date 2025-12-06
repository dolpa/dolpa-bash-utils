#!/usr/bin/env bats

# Load the library modules that strings.sh depends on
# load ../modules/logging.sh      # brings in the colour constants & log functions
# load ../modules/config.sh       # defines the colour variables used by logging

# Source the module under test
setup() {
    # Load required modules
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/strings.sh"
}

# --------------------------------------------------------------------
# Helper: capture output of a function
capture() {
    "$@" 2>/dev/null
}

# --------------------------------------------------------------------
# 1. Normalisation helpers
@test "str_trim removes leading and trailing whitespace" {
    run capture str_trim "   foo bar   "
    [ "$status" -eq 0 ]
    [ "$output" = "foo bar" ]
}

@test "str_upper converts to upper case" {
    run capture str_upper "Hello World"
    [ "$status" -eq 0 ]
    [ "$output" = "HELLO WORLD" ]
}

@test "str_lower converts to lower case" {
    run capture str_lower "Hello WORLD"
    [ "$status" -eq 0 ]
    [ "$output" = "hello world" ]
}

@test "str_title capitalises each word" {
    run capture str_title "hello world from bats"
    [ "$status" -eq 0 ]
    [ "$output" = "Hello World From Bats" ]
}

# --------------------------------------------------------------------
# 2. Query / test helpers
@test "str_contains returns the original string when pattern is present" {
    run capture str_contains "foobar" "foo"
    [ "$status" -eq 0 ]
    [ "$output" = "foobar" ]
}

@test "str_startswith detects a matching prefix" {
    run capture str_startswith "foobar" "foo"
    [ "$status" -eq 0 ]
    [ "$output" = "foobar" ]
}

@test "str_endswith detects a matching suffix" {
    run capture str_endswith "foobar" "bar"
    [ "$status" -eq 0 ]
    [ "$output" = "foobar" ]
}

@test "str_word_count returns correct count" {
    run capture str_word_count "one two three"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

@test "str_word_occurrences counts occurrences of a word" {
    run capture str_word_occurrences "one two one three one" "one"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

# --------------------------------------------------------------------
# 3. Transformation helpers
@test "str_replace substitutes a substring" {
    run capture str_replace "hello world" "world" "BATS"
    [ "$status" -eq 0 ]
    [ "$output" = "hello BATS" ]
}

@test "str_substring extracts a slice" {
    run capture str_substring "abcdef" 2 3
    [ "$status" -eq 0 ]
    [ "$output" = "cde" ]
}

@test "str_repeat repeats a string N times" {
    run capture str_repeat "x" 5
    [ "$status" -eq 0 ]
    [ "$output" = "xxxxx" ]
}

# --------------------------------------------------------------------
# 4. Splitting / joining helpers
@test "str_split splits on whitespace" {
    output=$(str_split "a b c d")
    readarray -t parts <<<"$output"
    [ "${#parts[@]}" -eq 4 ]
    [ "${parts[0]}" = "a" ]
    [ "${parts[1]}" = "b" ]
    [ "${parts[2]}" = "c" ]
    [ "${parts[3]}" = "d" ]
}

@test "str_join concatenates an array with a delimiter" {
    # Build an array in the test script
    my_array=("one" "two" "three")
    run capture str_join "," "${my_array[@]}"
    [ "$status" -eq 0 ]
    [ "$output" = "one,two,three" ]
}

# --------------------------------------------------------------------
# 5. Misc utilities
@test "str_nth_word returns the correct word" {
    run capture str_nth_word "the quick brown fox" 3
    [ "$status" -eq 0 ]
    [ "$output" = "brown" ]
}

@test "str_length returns the length of the string" {
    run capture str_length "abcd"
    [ "$status" -eq 0 ]
    [ "$output" = "4" ]
}