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

export -f hash_sha256 hash_verify uuid_generate random_string