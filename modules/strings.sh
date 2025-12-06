#!/usr/bin/env bash
#=================================================================
# Bash Utility Library – Strings Module
#=================================================================
# Description : Handy helpers for working with strings and words
# Author      : <your‑name>
# Version     : main
# License     : Unlicense
# Dependencies: logging.sh (for coloured log output)
#=================================================================

# Prevent multiple sourcing – same pattern as the other modules
# (see utils.sh, logging.sh, etc.) [5] [3]
if [[ "${BASH_UTILS_STRINGS_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_STRINGS_LOADED="true"

#=================================================================
# INTERNAL HELPERS
#=================================================================

# Strip leading and trailing whitespace
# Usage: trimmed=$(str_trim "   some text   ")
str_trim() {
    local s="$1"
    # shellcheck disable=SC2001
    echo -e "${s}" | sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//'
}

#=================================================================
# PUBLIC STRING FUNCTIONS
#=================================================================

# Convert a string to upper‑case
#   upper=$(str_upper "hello")
str_upper() {
    local s="${1}"
    echo "${s}" | tr '[:lower:]' '[:upper:]'
}

# Convert a string to lower‑case
#   lower=$(str_lower "HELLO")
str_lower() {
    local s="${1}"
    echo "${s}" | tr '[:upper:]' '[:lower:]'
}

# Return the length of a string (in characters)
#   len=$(str_length "abc")
str_length() {
    local s="${1}"
    echo "${#s}"
}

# Test if a string contains a given substring
#   if str_contains "$text" "needle"; then …
str_contains() {
    local txt="$1"
    local pat="$2"

    # If the pattern is found, print the original string and succeed.
    if [[ "$txt" == *"$pat"* ]]; then
        printf '%s\n' "$txt"
        return 0
    fi

    # No match → fail (no output)
    return 1
}

# Test if a string starts with a prefix
#   if str_startswith "$text" "pre"; then …
str_startswith() {
    local txt="$1"
    local prefix="$2"

    if [[ "$txt" == "$prefix"* ]]; then
        printf '%s\n' "$txt"
        return 0
    fi
    return 1
}

# Test if a string ends with a suffix
#   if str_endswith "$text" ".txt"; then …
str_endswith() {
    local txt="$1"
    local suffix="$2"

    if [[ "$txt" == *"$suffix" ]]; then
        printf '%s\n' "$txt"
        return 0
    fi
    return 1
}

# Replace all occurrences of a pattern (plain text, not regex)
#   new=$(str_replace "foo bar foo" "foo" "baz")
str_replace() {
    local str="${1}"
    local search="${2}"
    local replace="${3}"
    echo "${str//${search}/${replace}}"
}

# Split a string into an array by a delimiter
#   IFS=' ' read -r -a words <<< "$(str_split "one two three" " ")"
str_split() {
    local s="${1}"
    local delim="${2:- }"
    # Turn the string into a newline‑separated list, then read it back
    IFS=$'\n' read -rd '' -a result <<< "$(printf '%s' "${s}" | tr "${delim}" '\n')"
    printf '%s\n' "${result[@]}"
}

# Join an array of words into a single string with a delimiter
#   joined=$(str_join "," "a" "b" "c")
str_join() {
    local delim="${1}"
    shift
    local first=true
    local out=
    for elem in "$@"; do
        if $first; then
            out="${elem}"
            first=false
        else
            out="${out}${delim}${elem}"
        fi
    done
    echo "${out}"
}

# Count words (separated by whitespace) in a string
#   n=$(str_word_count "one two three")
str_word_count() {
    local s="${1}"
    # Collapse consecutive whitespace, then count the fields
    echo "${s}" | tr -s '[:space:]' '\n' | wc -l | tr -d ' '
}

# Return a substring (offset, length)
#   sub=$(str_substring "abcdef" 2 3)   # => "cde"
str_substring() {
    local s="${1}"
    local offset="${2}"
    local length="${3:-}"
    if [[ -z "${length}" ]]; then
        echo "${s:offset}"
    else
        echo "${s:offset:length}"
    fi
}

# Repeat a string N times
#   repeated=$(str_repeat "ab" 3)   # => "ababab"
str_repeat() {
    local s="${1}"
    local n="${2}"
    local result=
    for ((i=0; i<n; i++)); do
        result+="${s}"
    done
    echo "${result}"
}

# PUBLIC WORD FUNCTIONS
# Count how many times a word appears in a string (exact word match)
#   cnt=$(str_word_occurrences "a b a c a" "a")   # => 3
str_word_occurrences() {
    local text="${1}"
    local word="${2}"
    # Pad both sides with a space to avoid partial matches
    local padded=" ${text} "
    local pattern=" ${word} "
    echo "${padded}" | grep -o "${pattern}" | wc -l | tr -d ' '
}

# Return the N‑th word (1‑based) of a string
#   third=$(str_nth_word "one two three four" 3)   # => "three"
str_nth_word() {
    local text="${1}"
    local n="${2}"
    echo "${text}" | awk -v idx="${n}" '{print $idx}'
}

# Convert a string to title‑case (first letter of each word capitalised)
#   title=$(str_title "this is a test")
str_title() {
    local s="${1}"
    echo "${s}" | awk '
        {
            for (i=1; i<=NF; i++) {
                $i = toupper(substr($i,1,1)) tolower(substr($i,2))
            }
            print
        }'
}

# EXPORT FUNCTIONS
export -f str_trim
export -f str_upper
export -f str_lower
export -f str_length
export -f str_contains
export -f str_startswith
export -f str_endswith
export -f str_replace
export -f str_split
export -f str_join
export -f str_word_count
export -f str_substring
export -f str_repeat
export -f str_nth_word
export -f str_word_occurrences
export -f str_title