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

# ----------------------------------------------------------------------
# Pad string to specified length with character
# Usage: padded=$(str_pad_left "abc" 10 "0")
# Arguments:
#   $1 - string to pad
#   $2 - target length
#   $3 - padding character (default: space)
# Returns: padded string via stdout
# ----------------------------------------------------------------------
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

# ----------------------------------------------------------------------
# Pad string to specified length with character on the right
# Usage: padded=$(str_pad_right "abc" 10 "0")
# Arguments:
#   $1 - string to pad
#   $2 - target length
#   $3 - padding character (default: space)
# Returns: padded string via stdout
# ----------------------------------------------------------------------
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

# ----------------------------------------------------------------------
# Check if string is empty or contains only whitespace
# Usage: if str_is_empty "   "; then ...; fi
# Arguments:
#   $1 - string to check
# Returns: 0 if empty/whitespace only, 1 otherwise
# ----------------------------------------------------------------------
str_is_empty() {
    local string="$1"
    local trimmed
    trimmed=$(str_trim "$string")
    [[ -z "$trimmed" ]]
}

# ----------------------------------------------------------------------
# Extract substring by position and length
# Usage: substring=$(str_substring "hello world" 6 5)
# Arguments:
#   $1 - original string
#   $2 - start position (0-based)
#   $3 - length (optional, default: to end of string)
# Returns: substring via stdout
# ----------------------------------------------------------------------
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

# ----------------------------------------------------------------------
# Reverse a string
# Usage: reversed=$(str_reverse "hello")
# Arguments:
#   $1 - string to reverse
# Returns: reversed string via stdout
# ----------------------------------------------------------------------
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

# ----------------------------------------------------------------------
# str_shorten LENGTH STRING
#   Shortens STRING to LENGTH characters.
#   Appends "..." when truncated.
#   $1 - string to shorten
#   $2 - maximum length (default: 10)
#   Returns: shortened string via stdout
#   Usage:
#     str_shorten 10 "Very long text"
# ----------------------------------------------------------------------
str_shorten() {
    local max_length
    local string
    local ellipsis

    max_length="${1:-10}"
    shift || true
    string="$*"
    ellipsis="..."

    # If string fits, print as is
    if (( ${#string} <= max_length )); then
        printf '%s\n' "$string"
        return 0
    fi

    # Ensure ellipsis fits
    if (( max_length > ${#ellipsis} )); then
        printf '%s%s\n' \
            "${string:0:max_length-${#ellipsis}}" \
            "$ellipsis"
    else
        printf '%s\n' "${string:0:max_length}"
    fi
}

# ----------------------------------------------------------------------
# STRING VALIDATION FUNCTIONS
# ----------------------------------------------------------------------

# Check if string contains only numeric characters
# Usage: if str_is_numeric "123"; then ...; fi
# Arguments:
#   $1 - string to check
# Returns: 0 if numeric, 1 otherwise
str_is_numeric() {
    local string="$1"
    [[ "$string" =~ ^[0-9]+$ ]]
}

# Check if string contains only alphabetic characters
# Usage: if str_is_alpha "hello"; then ...; fi
# Arguments:
#   $1 - string to check
# Returns: 0 if alphabetic, 1 otherwise
str_is_alpha() {
    local string="$1"
    [[ "$string" =~ ^[a-zA-Z]+$ ]]
}

# Check if string contains only alphanumeric characters
# Usage: if str_is_alnum "hello123"; then ...; fi
# Arguments:
#   $1 - string to check
# Returns: 0 if alphanumeric, 1 otherwise
str_is_alnum() {
    local string="$1"
    [[ "$string" =~ ^[a-zA-Z0-9]+$ ]]
}

# Check if string is a valid email address (basic validation)
# Usage: if str_is_email "user@example.com"; then ...; fi
# Arguments:
#   $1 - string to check
# Returns: 0 if valid email format, 1 otherwise
str_is_email() {
    local string="$1"
    [[ "$string" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

# Check if string is a valid URL (basic validation)
# Usage: if str_is_url "https://example.com"; then ...; fi
# Arguments:
#   $1 - string to check
# Returns: 0 if valid URL format, 1 otherwise
str_is_url() {
    local string="$1"
    [[ "$string" =~ ^https?://[a-zA-Z0-9.-]+(\.[a-zA-Z]{2,})?(:[0-9]+)?(/.*)?$ ]]
}

# Check if string is a valid IPv4 address
# Usage: if str_is_ipv4 "192.168.1.1"; then ...; fi
# Arguments:
#   $1 - string to check
# Returns: 0 if valid IPv4, 1 otherwise
str_is_ipv4() {
    local string="$1"
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    if [[ "$string" =~ $regex ]]; then
        local IFS='.'
        local -a parts=($string)
        local part
        for part in "${parts[@]}"; do
            if [[ $part -gt 255 ]] || [[ ${part#0} != $part && $part != 0 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# ----------------------------------------------------------------------
# STRING SEARCH AND INDEX FUNCTIONS
# ----------------------------------------------------------------------

# Find the index of first occurrence of substring
# Usage: index=$(str_index "hello world" "world")
# Arguments:
#   $1 - string to search in
#   $2 - substring to find
# Returns: index (0-based) via stdout, or -1 if not found
str_index() {
    local string="$1"
    local substring="$2"
    local index="${string%%$substring*}"
    
    if [[ ${#index} -eq ${#string} ]]; then
        echo -1
    else
        echo ${#index}
    fi
}

# Find the index of last occurrence of substring
# Usage: index=$(str_rindex "hello world hello" "hello")
# Arguments:
#   $1 - string to search in
#   $2 - substring to find
# Returns: index (0-based) via stdout, or -1 if not found
str_rindex() {
    local string="$1"
    local substring="$2"
    local index="${string%$substring*}"
    
    if [[ ${#index} -eq ${#string} ]]; then
        echo -1
    else
        echo ${#index}
    fi
}

# Count occurrences of substring in string
# Usage: count=$(str_count "hello hello hello" "hello")
# Arguments:
#   $1 - string to search in
#   $2 - substring to count
# Returns: count via stdout
str_count() {
    local string="$1"
    local substring="$2"

    if [[ -z "$substring" ]]; then
        echo "0"
        return 0
    fi

    local count=0
    local temp="$string"
    local rest
    while [[ "$temp" == *"$substring"* ]]; do
        rest="${temp#*"$substring"}"
        (( count++ ))
        temp="$rest"
    done
    echo "$count"
}

# ----------------------------------------------------------------------
# CASE CONVERSION FUNCTIONS
# ----------------------------------------------------------------------

# Convert string to snake_case
# Usage: snake=$(str_to_snake "HelloWorld")
# Arguments:
#   $1 - string to convert
# Returns: snake_case string via stdout
str_to_snake() {
    local string="$1"
    echo "$string" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1_\2/g' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_\|_$//g'
}

# Convert string to kebab-case
# Usage: kebab=$(str_to_kebab "HelloWorld")
# Arguments:
#   $1 - string to convert
# Returns: kebab-case string via stdout
str_to_kebab() {
    local string="$1"
    echo "$string" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1-\2/g' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

# Convert string to camelCase
# Usage: camel=$(str_to_camel "hello world")
# Arguments:
#   $1 - string to convert
# Returns: camelCase string via stdout
str_to_camel() {
    local string="$1"
    local words result first_word
    
    # Split into words and process
    IFS=' _-' read -ra words <<< "$string"
    first_word=$(echo "${words[0]}" | tr '[:upper:]' '[:lower:]')
    result="$first_word"
    
    local i
    for ((i=1; i<${#words[@]}; i++)); do
        local word="${words[i]}"
        local first_char="${word:0:1}"
        local rest="${word:1}"
        result+="$(echo "$first_char" | tr '[:lower:]' '[:upper:]')$(echo "$rest" | tr '[:upper:]' '[:lower:]')"
    done
    
    echo "$result"
}

# Convert string to PascalCase
# Usage: pascal=$(str_to_pascal "hello world")
# Arguments:
#   $1 - string to convert
# Returns: PascalCase string via stdout
str_to_pascal() {
    local string="$1"
    local words result
    
    # Split into words and process
    IFS=' _-' read -ra words <<< "$string"
    
    local word
    for word in "${words[@]}"; do
        local first_char="${word:0:1}"
        local rest="${word:1}"
        result+="$(echo "$first_char" | tr '[:lower:]' '[:upper:]')$(echo "$rest" | tr '[:upper:]' '[:lower:]')"
    done
    
    echo "$result"
}

# ----------------------------------------------------------------------
# STRING ENCODING AND ESCAPING FUNCTIONS
# ----------------------------------------------------------------------

# URL encode a string
# Usage: encoded=$(str_url_encode "hello world")
# Arguments:
#   $1 - string to encode
# Returns: URL encoded string via stdout
str_url_encode() {
    local string="$1"
    local length="${#string}"
    local encoded="" c
    
    local i
    for ((i=0; i<length; i++)); do
        c="${string:i:1}"
        case "$c" in
            [a-zA-Z0-9.~_-]) 
                encoded+="$c" ;;
            *) 
                encoded+=$(printf '%%%02X' "'$c") ;;
        esac
    done
    
    echo "$encoded"
}

# URL decode a string
# Usage: decoded=$(str_url_decode "hello%20world")
# Arguments:
#   $1 - string to decode
# Returns: URL decoded string via stdout
str_url_decode() {
    local string="$1"
    echo -e "${string//\%/\\x}"
}

# Escape shell special characters
# Usage: escaped=$(str_shell_escape "rm -rf /")
# Arguments:
#   $1 - string to escape
# Returns: shell-escaped string via stdout
str_shell_escape() {
    local string="$1"
    printf '%q' "$string"
}

# Escape HTML special characters
# Usage: escaped=$(str_html_escape "<script>alert('hi')</script>")
# Arguments:
#   $1 - string to escape
# Returns: HTML-escaped string via stdout
str_html_escape() {
    local string="$1"
    string="${string//&/\&amp;}"
    string="${string//</\&lt;}"
    string="${string//>/\&gt;}"
    string="${string//\"/\&quot;}"
    string="${string//$'\''/\&#39;}"
    echo "$string"
}

# Unescape HTML special characters
# Usage: unescaped=$(str_html_unescape "&lt;strong&gt;bold&lt;/strong&gt;")
# Arguments:
#   $1 - string to unescape
# Returns: HTML-unescaped string via stdout
str_html_unescape() {
    local string="$1"
    string="${string//&amp;/\&}"
    string="${string//&lt;/<}"
    string="${string//&gt;/>}"
    string="${string//&quot;/\"}"
    string="${string//&#39;/\'}"
    echo "$string"
}

# ----------------------------------------------------------------------
# STRING COMPARISON FUNCTIONS
# ----------------------------------------------------------------------

# Case-insensitive string comparison
# Usage: if str_equals_ignore_case "Hello" "hello"; then ...; fi
# Arguments:
#   $1 - first string
#   $2 - second string
# Returns: 0 if strings are equal (ignoring case), 1 otherwise
str_equals_ignore_case() {
    local str1="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    local str2="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
    [[ "$str1" == "$str2" ]]
}

# Compare strings naturally (version-like comparison)
# Usage: if str_version_compare "1.2.3" "1.2.10"; then echo "1.2.3 < 1.2.10"; fi
# Arguments:
#   $1 - first version string
#   $2 - second version string
# Returns: 0 if first < second, 1 if first >= second
str_version_compare() {
    local ver1="$1"
    local ver2="$2"
    
    if [[ "$ver1" == "$ver2" ]]; then
        return 1
    fi
    
    local sorted_first
    sorted_first=$(printf '%s\n%s\n' "$ver1" "$ver2" | sort -V | head -n1)
    [[ "$sorted_first" == "$ver1" ]]
}

# Generate a random string of specified length
# Usage: random=$(str_random 10)
# Arguments:
#   $1 - length of random string (default: 8)
#   $2 - character set (default: alphanumeric)
# Returns: random string via stdout
str_random() {
    local length="${1:-8}"
    local charset="${2:-a-zA-Z0-9}"
    local result

    if command -v shuf >/dev/null 2>&1; then
        result=$(tr -dc "$charset" < /dev/urandom | head -c "$length")
    elif command -v openssl >/dev/null 2>&1; then
        result=$(openssl rand -base64 $((length * 2)) | tr -dc "$charset" | head -c "$length")
    else
        # Fallback using bash RANDOM
        local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        local i
        for ((i=0; i<length; i++)); do
            result+="${chars:RANDOM%${#chars}:1}"
        done
    fi
    printf '%s\n' "$result"
}

export -f str_upper str_lower str_title str_length str_trim str_ltrim str_rtrim \
          str_starts_with str_ends_with str_contains str_replace str_replace_first \
          str_split str_join str_repeat str_pad_left str_pad_right str_is_empty \
          str_substring str_reverse str_shorten \
          str_is_numeric str_is_alpha str_is_alnum str_is_email str_is_url str_is_ipv4 \
          str_index str_rindex str_count \
          str_to_snake str_to_kebab str_to_camel str_to_pascal \
          str_url_encode str_url_decode str_shell_escape str_html_escape str_html_unescape \
          str_equals_ignore_case str_version_compare str_random