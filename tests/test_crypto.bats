#!/usr/bin/env bats
#====================================================================
# test_crypto.bats – tests for modules/crypto.sh
#====================================================================

# --------------------------------------------------------------------
# Global setup – run once before any test case
# --------------------------------------------------------------------
setup() {
    export NO_COLOR=1

    # Load the library modules in the order they depend on each other.
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/validation.sh"
    source "${BATS_TEST_DIRNAME}/../modules/crypto.sh"
}

_test_sha256() {
    local file="$1"

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
        return 0
    fi

    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
        return 0
    fi

    if command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file" | awk '{print $2}'
        return 0
    fi

    return 1
}

# --------------------------------------------------------------------
# Global teardown – run after each test case
# --------------------------------------------------------------------
teardown() {
    # Nothing special to clean up; keeping the function for symmetry.
    true
}

# --------------------------------------------------------------------
# Basic sanity checks
# --------------------------------------------------------------------
@test "crypto module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/crypto.sh"
    [ "$status" -eq 0 ]
}

@test "crypto module sets BASH_UTILS_CRYPTO_LOADED flag" {
    [ -n "${BASH_UTILS_CRYPTO_LOADED:-}" ]
}

@test "all crypto functions are defined" {
    declare -f hash_sha256    >/dev/null
    declare -f hash_verify    >/dev/null
    declare -f uuid_generate  >/dev/null
    declare -f random_string  >/dev/null
}

# --------------------------------------------------------------------
# SHA‑256 hash handling
# --------------------------------------------------------------------
@test "hash_sha256 returns the correct checksum for a known file" {
    local tmp
    tmp="$(mktemp)"
    echo -n "testdata" >"$tmp"

    if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1 && ! command -v openssl >/dev/null 2>&1; then
        skip "No SHA-256 tool available for test verification"
    fi

    local expected
    expected="$(_test_sha256 "$tmp")"
    run hash_sha256 "$tmp"

    [ "$status" -eq 0 ]
    [ "$output" = "$expected" ]

    rm -f "$tmp"
}

@test "hash_verify succeeds when checksum matches" {
    local tmp
    tmp="$(mktemp)"
    echo -n "foobar" >"$tmp"

    if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1 && ! command -v openssl >/dev/null 2>&1; then
        rm -f "$tmp"
        skip "No SHA-256 tool available for test verification"
    fi

    local checksum
    checksum="$(_test_sha256 "$tmp")"

    run hash_verify "$tmp" "$checksum"
    [ "$status" -eq 0 ]

    rm -f "$tmp"
}

@test "hash_verify fails when checksum does NOT match" {
    local tmp
    tmp="$(mktemp)"
    echo -n "different" >"$tmp"
    wrong="deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"

    run hash_verify "$tmp" "$wrong"
    [ "$status" -eq 1 ]

    rm -f "$tmp"
}

# --------------------------------------------------------------------
# UUID generation
# --------------------------------------------------------------------
@test "uuid_generate returns a syntactically valid UUID v4" {
    run uuid_generate
    [ "$status" -eq 0 ]

    # UUID v4 format: 8‑4‑4‑4‑12 hex digits, version field must be 4,
    # variant field must be 8,9,a or b.
    [[ "$output" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]]
}

# --------------------------------------------------------------------
# Random string generation
# --------------------------------------------------------------------
@test "random_string returns a string of the requested length" {
    run random_string 12
    [ "$status" -eq 0 ]
    [ "${#output}" -eq 12 ]
}

@test "random_string falls back to the default length (16) when no argument is given" {
    run random_string
    [ "$status" -eq 0 ]
    [ "${#output}" -eq 16 ]
}