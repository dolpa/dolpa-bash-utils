#!/usr/bin/env bash
#=====================================================================
# crypto.sh – Hashing, checksums, and random identifiers
#=====================================================================
# A small set of cryptography-adjacent helpers for scripts:
# - SHA-256 checksums for files
# - Checksum verification
# - UUID v4 generation
# - Random alphanumeric strings
#
# Notes:
# - This module uses whichever hashing/entropy tools are available on
#   the host (sha256sum, shasum, openssl, uuidgen, /proc).
# - For deterministic test output, set NO_COLOR=1 before sourcing.
#=====================================================================

# --------------------------------------------------------------------
# Guard against being sourced more than once
# --------------------------------------------------------------------
if [[ "${BASH_UTILS_CRYPTO_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_CRYPTO_LOADED="true"

# ----------------------------------------------------------------------
# Load required dependencies (config, logging and the generic file helpers)
# ----------------------------------------------------------------------
# The path of this script (e.g. /opt/bash-utils/modules/filesystem.sh)
_BASH_UTILS_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# config must be loaded first – it defines colour handling, readonly flags,
# etc.  All other modules already source it, but we keep the explicit load
# here for clarity and in case this file is sourced directly.

# shellcheck source=./modules/config.sh
source "${_BASH_UTILS_MODULE_DIR}/../modules/config.sh"
# shellcheck source=./modules/logging.sh
source "${_BASH_UTILS_MODULE_DIR}/../modules/logging.sh"
# shellcheck source=./modules/validation.sh
source "${_BASH_UTILS_MODULE_DIR}/../modules/validation.sh"

# --------------------------------------------------------------------
# Helper: compute SHA‑256 hash of a file
# --------------------------------------------------------------------
hash_sha256() {
    local file=$1

    if [[ -z $file ]]; then
        log_error "hash_sha256: missing file argument"
        return 1
    fi
    if [[ ! -f $file ]]; then
        log_error "hash_sha256: file not found – $file"
        return 1
    fi

    # Prefer the most common utilities, fall back to OpenSSL
    if command_exists sha256sum; then
        sha256sum "$file" | awk '{print $1}'
    elif command_exists shasum; then
        shasum -a 256 "$file" | awk '{print $1}'
    elif command_exists openssl; then
        openssl dgst -sha256 "$file" | awk '{print $2}'
    else
        log_error "hash_sha256: no SHA‑256 utility available on this system"
        return 1
    fi
}

# --------------------------------------------------------------------
# Helper: verify a file against an expected checksum
# --------------------------------------------------------------------
hash_verify() {
    local file=$1 expected=$2

    if [[ -z $file || -z $expected ]]; then
        log_error "hash_verify: usage: hash_verify <file> <checksum>"
        return 1
    fi

    local actual
    actual=$(hash_sha256 "$file") || return 1

    # Comparison is case‑insensitive (hex can be upper or lower)
    if [[ "${actual,,}" == "${expected,,}" ]]; then
        log_success "Checksum verified for $file"
        return 0
    else
        log_error "Checksum mismatch for $file (expected $expected, got $actual)"
        return 1
    fi
}

# --------------------------------------------------------------------
# Helper: generate a random UUID v4
# --------------------------------------------------------------------
uuid_generate() {
    # Prefer the dedicated tool if present
    if command_exists uuidgen; then
        uuidgen
        return 0
    fi

    # Linux kernel provides a ready‑made UUID
    if [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
        return 0
    fi

    # Fallback – OpenSSL + RFC4122 v4 formatting (version/variant bits).
    if command_exists openssl; then
        local raw
        raw=$(openssl rand -hex 16) || return 1  # 32 hex chars

        # Force version to 4 (high nibble of byte 6 => hex char index 12).
        raw="${raw:0:12}4${raw:13}"
        # Force variant to 10xx (high nibble of byte 8 => hex char index 16).
        raw="${raw:0:16}8${raw:17}"

        printf "%s-%s-%s-%s-%s\n" \
            "${raw:0:8}" "${raw:8:4}" "${raw:12:4}" "${raw:16:4}" "${raw:20:12}"
        return 0
    fi

    log_error "uuid_generate: cannot find a method to generate a UUID"
    return 1
}

# --------------------------------------------------------------------
# Helper: generate a random alphanumeric string
# --------------------------------------------------------------------
random_string() {
    local length=${1:-16}

    if ! [[ $length =~ ^[0-9]+$ ]] || (( length <= 0 )); then
        log_error "random_string: length must be a positive integer"
        return 1
    fi

    # Use OpenSSL if it exists (better entropy), otherwise /dev/urandom
    if command_exists openssl; then
        # OpenSSL outputs base64 – strip non‑alphanum and trim to length
        openssl rand -base64 $(( length * 3 / 4 + 4 )) |
            tr -dc 'a-zA-Z0-9' |
            head -c "$length"
    else
        tr -dc 'a-zA-Z0-9' < /dev/urandom |
            head -c "$length"
    fi
    echo
}

# --------------------------------------------------------------------
# HASH ALGORITHMS
# --------------------------------------------------------------------

# Compute MD5 hash of a file
# Usage: md5=$(hash_md5 "/path/to/file")
# Arguments:
#   $1 - file path to hash
# Returns: MD5 hash via stdout, or error code
hash_md5() {
    local file="$1"

    if [[ -z "$file" ]]; then
        log_error "hash_md5: missing file argument"
        return 1
    fi
    if [[ ! -f "$file" ]]; then
        log_error "hash_md5: file not found – $file"
        return 1
    fi

    if command_exists md5sum; then
        md5sum "$file" | awk '{print $1}'
    elif command_exists md5; then
        md5 -q "$file"
    elif command_exists openssl; then
        openssl dgst -md5 "$file" | awk '{print $2}'
    else
        log_error "hash_md5: no MD5 utility available on this system"
        return 1
    fi
}

# Compute SHA-1 hash of a file
# Usage: sha1=$(hash_sha1 "/path/to/file")
# Arguments:
#   $1 - file path to hash
# Returns: SHA-1 hash via stdout, or error code
hash_sha1() {
    local file="$1"

    if [[ -z "$file" ]]; then
        log_error "hash_sha1: missing file argument"
        return 1
    fi
    if [[ ! -f "$file" ]]; then
        log_error "hash_sha1: file not found – $file"
        return 1
    fi

    if command_exists sha1sum; then
        sha1sum "$file" | awk '{print $1}'
    elif command_exists shasum; then
        shasum -a 1 "$file" | awk '{print $1}'
    elif command_exists openssl; then
        openssl dgst -sha1 "$file" | awk '{print $2}'
    else
        log_error "hash_sha1: no SHA-1 utility available on this system"
        return 1
    fi
}

# Compute SHA-512 hash of a file
# Usage: sha512=$(hash_sha512 "/path/to/file")
# Arguments:
#   $1 - file path to hash
# Returns: SHA-512 hash via stdout, or error code
hash_sha512() {
    local file="$1"

    if [[ -z "$file" ]]; then
        log_error "hash_sha512: missing file argument"
        return 1
    fi
    if [[ ! -f "$file" ]]; then
        log_error "hash_sha512: file not found – $file"
        return 1
    fi

    if command_exists sha512sum; then
        sha512sum "$file" | awk '{print $1}'
    elif command_exists shasum; then
        shasum -a 512 "$file" | awk '{print $1}'
    elif command_exists openssl; then
        openssl dgst -sha512 "$file" | awk '{print $2}'
    else
        log_error "hash_sha512: no SHA-512 utility available on this system"
        return 1
    fi
}

# Compute hash of a string (not file)
# Usage: hash=$(hash_string "hello world" "sha256")
# Arguments:
#   $1 - string to hash
#   $2 - hash algorithm (md5, sha1, sha256, sha512)
# Returns: hash via stdout, or error code
hash_string() {
    local string="$1"
    local algorithm="${2:-sha256}"

    if [[ -z "$string" ]]; then
        log_error "hash_string: missing string argument"
        return 1
    fi

    if command_exists openssl; then
        echo -n "$string" | openssl dgst -"$algorithm" | awk '{print $2}'
    else
        case "$algorithm" in
            md5)
                if command_exists md5sum; then
                    echo -n "$string" | md5sum | awk '{print $1}'
                elif command_exists md5; then
                    echo -n "$string" | md5
                else
                    log_error "hash_string: no MD5 utility available"
                    return 1
                fi
                ;;
            sha1)
                if command_exists sha1sum; then
                    echo -n "$string" | sha1sum | awk '{print $1}'
                elif command_exists shasum; then
                    echo -n "$string" | shasum -a 1 | awk '{print $1}'
                else
                    log_error "hash_string: no SHA-1 utility available"
                    return 1
                fi
                ;;
            sha256)
                if command_exists sha256sum; then
                    echo -n "$string" | sha256sum | awk '{print $1}'
                elif command_exists shasum; then
                    echo -n "$string" | shasum -a 256 | awk '{print $1}'
                else
                    log_error "hash_string: no SHA-256 utility available"
                    return 1
                fi
                ;;
            sha512)
                if command_exists sha512sum; then
                    echo -n "$string" | sha512sum | awk '{print $1}'
                elif command_exists shasum; then
                    echo -n "$string" | shasum -a 512 | awk '{print $1}'
                else
                    log_error "hash_string: no SHA-512 utility available"
                    return 1
                fi
                ;;
            *)
                log_error "hash_string: unsupported algorithm '$algorithm'"
                return 1
                ;;
        esac
    fi
}

# --------------------------------------------------------------------
# ENCODING/DECODING FUNCTIONS
# --------------------------------------------------------------------

# Base64 encode a string
# Usage: encoded=$(base64_encode "hello world")
# Arguments:
#   $1 - string to encode
# Returns: base64 encoded string via stdout
base64_encode() {
    local string="$1"

    if [[ -z "$string" ]]; then
        log_error "base64_encode: missing string argument"
        return 1
    fi

    if command_exists base64; then
        echo -n "$string" | base64 | tr -d '\n'
    elif command_exists openssl; then
        echo -n "$string" | openssl base64 | tr -d '\n'
    else
        log_error "base64_encode: no base64 utility available"
        return 1
    fi
}

# Base64 decode a string
# Usage: decoded=$(base64_decode "aGVsbG8gd29ybGQ=")
# Arguments:
#   $1 - base64 string to decode
# Returns: decoded string via stdout
base64_decode() {
    local encoded="$1"

    if [[ -z "$encoded" ]]; then
        log_error "base64_decode: missing encoded string argument"
        return 1
    fi

    if command_exists base64; then
        echo -n "$encoded" | base64 -d 2>/dev/null
    elif command_exists openssl; then
        echo -n "$encoded" | openssl base64 -d 2>/dev/null
    else
        log_error "base64_decode: no base64 utility available"
        return 1
    fi
}

# Hexadecimal encode a string
# Usage: hex=$(hex_encode "hello")
# Arguments:
#   $1 - string to encode
# Returns: hex encoded string via stdout
hex_encode() {
    local string="$1"

    if [[ -z "$string" ]]; then
        log_error "hex_encode: missing string argument"
        return 1
    fi

    if command_exists hexdump; then
        echo -n "$string" | hexdump -v -e '/1 "%02x"'
    elif command_exists od; then
        echo -n "$string" | od -A n -t x1 | tr -d ' \n'
    elif command_exists xxd; then
        echo -n "$string" | xxd -p | tr -d '\n'
    else
        log_error "hex_encode: no hex encoding utility available"
        return 1
    fi
}

# Hexadecimal decode a string
# Usage: decoded=$(hex_decode "68656c6c6f")
# Arguments:
#   $1 - hex string to decode
# Returns: decoded string via stdout
hex_decode() {
    local hex="$1"

    if [[ -z "$hex" ]]; then
        log_error "hex_decode: missing hex string argument"
        return 1
    fi

    # Remove any spaces or colons from hex string
    hex=$(echo "$hex" | tr -d ' :')

    if command_exists xxd; then
        echo -n "$hex" | xxd -r -p
    elif command_exists perl; then
        echo -n "$hex" | perl -pe 's/([0-9a-f]{2})/chr(hex($1))/gie'
    else
        log_error "hex_decode: no hex decoding utility available"
        return 1
    fi
}

# --------------------------------------------------------------------
# PASSWORD AND KEY GENERATION
# --------------------------------------------------------------------

# Generate a secure random password
# Usage: password=$(generate_password 16)
# Arguments:
#   $1 - password length (default: 12)
#   $2 - character set: 'alnum', 'alpha', 'complex' (default: 'complex')
# Returns: random password via stdout
generate_password() {
    local length="${1:-16}"
    local charset="${2:-complex}"
    local chars

    case "$charset" in
        alnum)
            chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            ;;
        alpha)
            chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
            ;;
        complex)
            chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>?"
            ;;
        *)
            log_error "generate_password: invalid charset '$charset'. Use: alnum, alpha, complex"
            return 1
            ;;
    esac

    if command_exists openssl; then
        openssl rand -base64 $((length * 2)) | tr -dc "$chars" | head -c "$length"
    elif [[ -r /dev/urandom ]]; then
        tr -dc "$chars" < /dev/urandom | head -c "$length"
    else
        # Fallback using bash RANDOM
        local result="" i
        for ((i=0; i<length; i++)); do
            result+="${chars:RANDOM%${#chars}:1}"
        done
        echo "$result"
    fi
}

# Hash a password using a salt (basic implementation)
# Usage: hashed=$(hash_password "mypassword" "salt123")
# Arguments:
#   $1 - password to hash
#   $2 - salt (optional, will generate if not provided)
# Returns: salted hash via stdout
hash_password() {
    local password="$1"
    local salt="${2:-$(random_string 16)}"

    if [[ -z "$password" ]]; then
        log_error "hash_password: missing password argument"
        return 1
    fi

    local combined="${salt}${password}"
    local hashed
    hashed=$(hash_string "$combined" "sha256")
    echo "${salt}:${hashed}"
}

# Verify a password against a salted hash
# Usage: if verify_password "mypassword" "salt123:hash..."; then ...; fi
# Arguments:
#   $1 - password to verify
#   $2 - salted hash (format: salt:hash)
# Returns: 0 if password matches, 1 otherwise
verify_password() {
    local password="$1"
    local salted_hash="$2"

    if [[ -z "$password" || -z "$salted_hash" ]]; then
        log_error "verify_password: missing password or hash argument"
        return 1
    fi

    local salt="${salted_hash%:*}"
    local expected_hash="${salted_hash#*:}"
    
    local test_hash
    test_hash=$(hash_password "$password" "$salt")
    local actual_hash="${test_hash#*:}"

    if [[ "$actual_hash" == "$expected_hash" ]]; then
        return 0
    else
        return 1
    fi
}

# --------------------------------------------------------------------
# PASSWORD ENTROPY CALCULATION
# --------------------------------------------------------------------

# Function: password_entropy
# Description: Calculate password entropy (bits)
# Parameters:
#   $1 - Password to analyze
# Returns: 0 on success, 1 on error
# Example: password_entropy "mypassword123"
password_entropy() {
    local password="$1"
    local length=${#password}
    local unique_chars
    local charset_size=0
    
    [[ -z "$password" ]] && {
        echo "0"
        return 1
    }
    
    # Get unique characters
    unique_chars=$(echo "$password" | grep -o . | sort -u | wc -l)
    
    # Determine character set size based on character types used
    if [[ "$password" =~ [a-z] ]]; then
        charset_size=$((charset_size + 26))  # lowercase letters
    fi
    if [[ "$password" =~ [A-Z] ]]; then
        charset_size=$((charset_size + 26))  # uppercase letters
    fi
    if [[ "$password" =~ [0-9] ]]; then
        charset_size=$((charset_size + 10))  # digits
    fi
    if [[ "$password" =~ [^a-zA-Z0-9] ]]; then
        charset_size=$((charset_size + 32))  # special characters (estimated)
    fi
    
    # If no character types detected, assume basic ASCII
    [[ $charset_size -eq 0 ]] && charset_size=95
    
    # Calculate entropy: length * log2(charset_size)
    # Using bc for floating point calculation if available
    if command_exists bc; then
        echo "$length * l($charset_size) / l(2)" | bc -l 2>/dev/null | cut -d. -f1
    else
        # Simplified calculation without bc
        local entropy=$((length * 6))  # Rough approximation
        echo "$entropy"
    fi
}

# --------------------------------------------------------------------
# SIMPLE ENCRYPTION/DECRYPTION (requires OpenSSL)
# --------------------------------------------------------------------

# Encrypt a file using AES-256-CBC
# Usage: encrypt_file "/path/to/file" "password" "/path/to/encrypted"
# Arguments:
#   $1 - input file path
#   $2 - encryption password
#   $3 - output file path
# Returns: 0 on success, 1 on error
encrypt_file() {
    local input_file="$1"
    local password="$2"
    local output_file="$3"

    if [[ -z "$input_file" || -z "$password" || -z "$output_file" ]]; then
        log_error "encrypt_file: usage: encrypt_file <input> <password> <output>"
        return 1
    fi

    if [[ ! -f "$input_file" ]]; then
        log_error "encrypt_file: input file not found: $input_file"
        return 1
    fi

    if ! command_exists openssl; then
        log_error "encrypt_file: OpenSSL is required for encryption"
        return 1
    fi

    if openssl enc -aes-256-cbc -in "$input_file" -out "$output_file" -pass pass:"$password" 2>/dev/null; then
        log_success "File encrypted: $output_file"
        return 0
    else
        log_error "encrypt_file: encryption failed"
        return 1
    fi
}

# Decrypt a file using AES-256-CBC
# Usage: decrypt_file "/path/to/encrypted" "password" "/path/to/decrypted"
# Arguments:
#   $1 - encrypted file path
#   $2 - decryption password
#   $3 - output file path
# Returns: 0 on success, 1 on error
decrypt_file() {
    local encrypted_file="$1"
    local password="$2"
    local output_file="$3"

    if [[ -z "$encrypted_file" || -z "$password" || -z "$output_file" ]]; then
        log_error "decrypt_file: usage: decrypt_file <encrypted> <password> <output>"
        return 1
    fi

    if [[ ! -f "$encrypted_file" ]]; then
        log_error "decrypt_file: encrypted file not found: $encrypted_file"
        return 1
    fi

    if ! command_exists openssl; then
        log_error "decrypt_file: OpenSSL is required for decryption"
        return 1
    fi

    if openssl enc -aes-256-cbc -d -in "$encrypted_file" -out "$output_file" -pass pass:"$password" 2>/dev/null; then
        log_success "File decrypted: $output_file"
        return 0
    else
        log_error "decrypt_file: decryption failed"
        return 1
    fi
}

# Encrypt a string and return base64 encoded result
# Usage: encrypted=$(encrypt_string "hello world" "mypassword")
# Arguments:
#   $1 - string to encrypt
#   $2 - encryption password
# Returns: base64 encoded encrypted string via stdout
encrypt_string() {
    local string="$1"
    local password="$2"

    if [[ -z "$string" || -z "$password" ]]; then
        log_error "encrypt_string: usage: encrypt_string <string> <password>"
        return 1
    fi

    if ! command_exists openssl; then
        log_error "encrypt_string: OpenSSL is required for encryption"
        return 1
    fi

    local result
    result=$(printf '%s' "$string" | openssl enc -aes-256-cbc -a -pass pass:"$password" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 && -n "$result" ]]; then
        echo "$result"
        return 0
    else
        log_error "encrypt_string: encryption failed"
        return 1
    fi
}

# Decrypt a base64 encoded encrypted string
# Usage: decrypted=$(decrypt_string "U2FsdGVkX1..." "mypassword")
# Arguments:
#   $1 - base64 encoded encrypted string
#   $2 - decryption password
# Returns: decrypted string via stdout
decrypt_string() {
    local encrypted="$1"
    local password="$2"

    if [[ -z "$encrypted" || -z "$password" ]]; then
        log_error "decrypt_string: usage: decrypt_string <encrypted> <password>"
        return 1
    fi

    if ! command_exists openssl; then
        log_error "decrypt_string: OpenSSL is required for decryption"
        return 1
    fi

    local result
    result=$(printf '%s' "$encrypted" | openssl enc -aes-256-cbc -d -a -pass pass:"$password" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo -n "$result"
        return 0
    else
        log_error "decrypt_string: decryption failed"
        return 1
    fi
}

# --------------------------------------------------------------------
# HMAC FUNCTIONS
# --------------------------------------------------------------------

# Generate HMAC signature for a string
# Usage: signature=$(hmac_sign "message" "secret_key" "sha256")
# Arguments:
#   $1 - message to sign
#   $2 - secret key
#   $3 - hash algorithm (default: sha256)
# Returns: HMAC signature via stdout
hmac_sign() {
    local message="$1"
    local key="$2"
    local algorithm="${3:-sha256}"

    if [[ -z "$message" || -z "$key" ]]; then
        log_error "hmac_sign: usage: hmac_sign <message> <key> [algorithm]"
        return 1
    fi

    if ! command_exists openssl; then
        log_error "hmac_sign: OpenSSL is required for HMAC"
        return 1
    fi

    echo -n "$message" | openssl dgst -"$algorithm" -hmac "$key" | awk '{print $2}'
}

# Verify HMAC signature
# Usage: if hmac_verify "message" "signature" "key" "sha256"; then ...; fi
# Arguments:
#   $1 - original message
#   $2 - signature to verify
#   $3 - secret key
#   $4 - hash algorithm (default: sha256)
# Returns: 0 if signature valid, 1 otherwise
hmac_verify() {
    local message="$1"
    local signature="$2"
    local key="$3"
    local algorithm="${4:-sha256}"

    if [[ -z "$message" || -z "$key" || -z "$signature" ]]; then
        log_error "hmac_verify: usage: hmac_verify <message> <signature> <key> [algorithm]"
        return 1
    fi

    local computed_signature
    computed_signature=$(hmac_sign "$message" "$key" "$algorithm")

    if [[ "${computed_signature,,}" == "${signature,,}" ]]; then
        return 0
    else
        return 1
    fi
}

# --------------------------------------------------------------------
# URL ENCODING FUNCTIONS
# --------------------------------------------------------------------

# Function: url_encode
# Description: URL-encode (percent-encode) a string
# Parameters:
#   $1 - String to encode
# Returns: 0 on success, 1 on error
# Example: url_encode "hello world"
url_encode() {
    local string="$1"
    local length="${#string}"
    local result=""
    local char
    
    [[ -z "$string" ]] && {
        echo ""
        return 0
    }
    
    for (( pos = 0; pos < length; pos++ )); do
        char="${string:$pos:1}"
        case "$char" in
            [a-zA-Z0-9.~_-]) 
                result+="$char" ;;
            *) 
                printf -v encoded "%%%02X" "'$char"
                result+="$encoded" ;;
        esac
    done
    
    echo "$result"
}

# Function: url_decode
# Description: URL-decode (percent-decode) a string
# Parameters:
#   $1 - String to decode
# Returns: 0 on success, 1 on error
# Example: url_decode "hello%20world"
url_decode() {
    local string="$1"
    local result=""
    
    [[ -z "$string" ]] && {
        echo ""
        return 0
    }
    
    # Use printf to decode percent-encoded characters
    printf -v result '%b' "${string//%/\\x}"
    echo "$result"
}

export -f hash_sha256 hash_verify uuid_generate random_string \
          hash_md5 hash_sha1 hash_sha512 hash_string \
          base64_encode base64_decode hex_encode hex_decode \
          generate_password hash_password verify_password \
          encrypt_file decrypt_file encrypt_string decrypt_string \
          hmac_sign hmac_verify url_encode url_decode password_entropy