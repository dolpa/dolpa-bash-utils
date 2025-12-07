#!/bin/bash

#===============================================================================
# Bash Utility Library - Strings Module
#===============================================================================
# Description: String manipulation and text processing utilities including case
#              conversion, trimming, validation, and advanced text operations
# Author: dolpa (https://dolpa.me)
# Version: main
# License: Unlicense
# Dependencies: logging.sh (for error logging)
#===============================================================================

# Prevent multiple sourcing
if [[ "${BASH_UTILS_STRINGS_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_STRINGS_LOADED="true"

#===============================================================================
# STRING MANIPULATION FUNCTIONS
#===============================================================================

# Convert string to uppercase
# Usage: upper=$(str_upper "hello world")
# Arguments:
#   $1 - string to convert
# Returns: uppercase string via stdout
str_upper() {
    local string="$1"
    echo "${string}" | tr '[:lower:]' '[:upper:]'
}

# Convert string to lowercase
# Usage: lower=$(str_lower "HELLO WORLD")
# Arguments:
#   $1 - string to convert
# Returns: lowercase string via stdout
str_lower() {
    local string="$1"
    echo "${string}" | tr '[:upper:]' '[:lower:]'
}

# Convert string to title case (first letter of each word capitalized)
# Usage: title=$(str_title "hello world")
# Arguments:
#   $1 - string to convert
# Returns: title case string via stdout
str_title() {
    local string="$1"
    echo "${string}" | sed 's/\b\(.\)/\u\1/g'
}

# Get string length in characters
# Usage: length=$(str_length "hello")
# Arguments:
#   $1 - string to measure
# Returns: length as integer via stdout
str_length() {
    local string="$1"
    echo "${#string}"
}

# Trim whitespace from beginning and end of string
# Usage: trimmed=$(str_trim "   hello world   ")
# Arguments:
#   $1 - string to trim
# Returns: trimmed string via stdout
str_trim() {
    local string="$1"
    # Remove leading whitespace
    string="${string#"${string%%[![:space:]]*}"}"
    # Remove trailing whitespace
    string="${string%"${string##*[![:space:]]}"}"
    echo "${string}"
}

# Trim whitespace from beginning of string
# Usage: left_trimmed=$(str_ltrim "   hello world")
# Arguments:
#   $1 - string to left trim
# Returns: left-trimmed string via stdout
str_ltrim() {
    local string="$1"
    string="${string#"${string%%[![:space:]]*}"}"
    echo "${string}"
}

# Trim whitespace from end of string
# Usage: right_trimmed=$(str_rtrim "hello world   ")
# Arguments:
#   $1 - string to right trim
# Returns: right-trimmed string via stdout
str_rtrim() {
    local string="$1"
    string="${string%"${string##*[![:space:]]}"}"
    echo "${string}"
}

# Check if string starts with specified prefix
# Usage: if str_starts_with "hello world" "hello"; then ...; fi
# Arguments:
#   $1 - string to check
#   $2 - prefix to look for
# Returns: 0 if string starts with prefix, 1 otherwise
str_starts_with() {
    local string="$1"
    local prefix="$2"
    [[ "$string" == "$prefix"* ]]
}

# Check if string ends with specified suffix
# Usage: if str_ends_with "hello world" "world"; then ...; fi
# Arguments:
#   $1 - string to check
#   $2 - suffix to look for
# Returns: 0 if string ends with suffix, 1 otherwise
str_ends_with() {
    local string="$1"
    local suffix="$2"
    [[ "$string" == *"$suffix" ]]
}

# Check if string contains substring
# Usage: if str_contains "hello world" "llo wo"; then ...; fi
# Arguments:
#   $1 - string to search in
#   $2 - substring to find
# Returns: 0 if substring found, 1 otherwise
str_contains() {
    local string="$1"
    local substring="$2"
    [[ "$string" == *"$substring"* ]]
}

# Replace all occurrences of a substring with replacement
# Usage: replaced=$(str_replace "hello world" "world" "universe")
# Arguments:
#   $1 - original string
#   $2 - substring to replace
#   $3 - replacement string
# Returns: modified string via stdout
str_replace() {
    local string="$1"
    local search="$2"
    local replace="$3"
    echo "${string//"$search"/"$replace"}"
}

# Replace first occurrence of a substring with replacement
# Usage: replaced=$(str_replace_first "hello world world" "world" "universe")
# Arguments:
#   $1 - original string
#   $2 - substring to replace
#   $3 - replacement string
# Returns: modified string via stdout
str_replace_first() {
    local string="$1"
    local search="$2"
    local replace="$3"
    echo "${string/"$search"/"$replace"}"
}

# Split string by delimiter into array
# Usage: str_split "a,b,c" "," result_array
# Arguments:
#   $1 - string to split
#   $2 - delimiter
#   $3 - name of array variable to populate
str_split() {
    local string="$1"
    local delimiter="$2"
    local -n result_ref="$3"
    
    # Clear the result array
    result_ref=()
    
    # Handle empty string
    if [[ -z "$string" ]]; then
        return 0
    fi
    
    # Split string using delimiter
    IFS="$delimiter" read -ra result_ref <<< "$string"
}

# Join array elements with delimiter
# Usage: joined=$(str_join "," "a" "b" "c")
# Arguments:
#   $1 - delimiter
#   $2+ - strings to join
# Returns: joined string via stdout
str_join() {
    local delimiter="$1"
    shift
    local first="$1"
    shift
    printf "%s" "$first" "${@/#/$delimiter}"
}

# Repeat string n times
# Usage: repeated=$(str_repeat "abc" 3)
# Arguments:
#   $1 - string to repeat
#   $2 - number of times to repeat
# Returns: repeated string via stdout
str_repeat() {
    local string="$1"
    local count="$2"
    local result=""
    local i

    for ((i = 0; i < count; i++)); do
        result+="$string"
    done
    echo "$result"
}

# Pad string to specified length with character
# Usage: padded=$(str_pad_left "abc" 10 "0")
# Arguments:
#   $1 - string to pad
#   $2 - target length
#   $3 - padding character (default: space)
# Returns: padded string via stdout
str_pad_left() {
    local string="$1"
    local length="$2"
    local padchar="${3:- }"
    local current_length="${#string}"
    
    if [[ $current_length -ge $length ]]; then
        echo "$string"
        return
    fi
    
    local pad_length=$((length - current_length))
    local padding
    padding=$(str_repeat "$padchar" "$pad_length")
    echo "${padding}${string}"
}

# Pad string to specified length with character on the right
# Usage: padded=$(str_pad_right "abc" 10 "0")
# Arguments:
#   $1 - string to pad
#   $2 - target length
#   $3 - padding character (default: space)
# Returns: padded string via stdout
str_pad_right() {
    local string="$1"
    local length="$2"
    local padchar="${3:- }"
    local current_length="${#string}"
    
    if [[ $current_length -ge $length ]]; then
        echo "$string"
        return
    fi
    
    local pad_length=$((length - current_length))
    local padding
    padding=$(str_repeat "$padchar" "$pad_length")
    echo "${string}${padding}"
}

# Check if string is empty or contains only whitespace
# Usage: if str_is_empty "   "; then ...; fi
# Arguments:
#   $1 - string to check
# Returns: 0 if empty/whitespace only, 1 otherwise
str_is_empty() {
    local string="$1"
    local trimmed
    trimmed=$(str_trim "$string")
    [[ -z "$trimmed" ]]
}

# Extract substring by position and length
# Usage: substring=$(str_substring "hello world" 6 5)
# Arguments:
#   $1 - original string
#   $2 - start position (0-based)
#   $3 - length (optional, default: to end of string)
# Returns: substring via stdout
str_substring() {
    local string="$1"
    local start="$2"
    local length="${3:-}"
    
    if [[ -n "$length" ]]; then
        echo "${string:$start:$length}"
    else
        echo "${string:$start}"
    fi
}

# Reverse a string
# Usage: reversed=$(str_reverse "hello")
# Arguments:
#   $1 - string to reverse
# Returns: reversed string via stdout
str_reverse() {
    local string="$1"
    local reversed=""
    local i
    
    # Reverse character by character using pure bash
    for ((i=${#string}-1; i>=0; i--)); do
        reversed="${reversed}${string:$i:1}"
    done
    
    echo "$reversed"
}

export -f str_upper str_lower str_title str_length str_trim str_ltrim str_rtrim \
          str_starts_with str_ends_with str_contains str_replace str_replace_first \
          str_split str_join str_repeat str_pad_left str_pad_right str_is_empty \
          str_substring str_reverse