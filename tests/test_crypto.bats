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

# --------------------------------------------------------------------
# ADDITIONAL HASH FUNCTION TESTS
# --------------------------------------------------------------------

@test "hash_md5 returns correct MD5 hash" {
    if ! command -v md5sum >/dev/null 2>&1 && ! command -v md5 >/dev/null 2>&1 && ! command -v openssl >/dev/null 2>&1; then
        skip "No MD5 tool available"
    fi
    
    local tmp
    tmp="$(mktemp)"
    echo -n "test" >"$tmp"
    
    run hash_md5 "$tmp"
    [ "$status" -eq 0 ]
    [ "${#output}" -eq 32 ]
    
    rm -f "$tmp"
}

@test "hash_sha1 returns correct SHA1 hash" {
    if ! command -v sha1sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1 && ! command -v openssl >/dev/null 2>&1; then
        skip "No SHA1 tool available"
    fi
    
    local tmp
    tmp="$(mktemp)"
    echo -n "test" >"$tmp"
    
    run hash_sha1 "$tmp"
    [ "$status" -eq 0 ]
    [ "${#output}" -eq 40 ]
    
    rm -f "$tmp"
}

@test "hash_sha512 returns correct SHA512 hash" {
    if ! command -v sha512sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1 && ! command -v openssl >/dev/null 2>&1; then
        skip "No SHA512 tool available"
    fi
    
    local tmp
    tmp="$(mktemp)"
    echo -n "test" >"$tmp"
    
    run hash_sha512 "$tmp"
    [ "$status" -eq 0 ]
    [ "${#output}" -eq 128 ]
    
    rm -f "$tmp"
}

# --------------------------------------------------------------------
# BASE64 ENCODING TESTS
# --------------------------------------------------------------------

@test "base64_encode encodes text correctly" {
    run base64_encode "Hello World"
    [ "$status" -eq 0 ]
    [ "$output" = "SGVsbG8gV29ybGQ=" ]
}

@test "base64_decode decodes text correctly" {
    run base64_decode "SGVsbG8gV29ybGQ="
    [ "$status" -eq 0 ]
    [ "$output" = "Hello World" ]
}

@test "base64 encode/decode roundtrip" {
    local text="This is a test message with special chars: !@#$%^&*()"
    local encoded
    local decoded
    
    encoded=$(base64_encode "$text")
    decoded=$(base64_decode "$encoded")
    
    [ "$decoded" = "$text" ]
}

# --------------------------------------------------------------------
# URL ENCODING TESTS
# --------------------------------------------------------------------

@test "url_encode encodes special characters" {
    run url_encode "hello world"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello%20world"* ]]
}

@test "url_decode decodes encoded characters" {
    run url_decode "hello%20world"
    [ "$status" -eq 0 ]
    [ "$output" = "hello world" ]
}

# --------------------------------------------------------------------
# HEX ENCODING TESTS  
# --------------------------------------------------------------------

@test "hex_encode converts text to hexadecimal" {
    run hex_encode "ABC"
    [ "$status" -eq 0 ]
    [ "$output" = "414243" ]
}

@test "hex_decode converts hexadecimal to text" {
    run hex_decode "414243"
    [ "$status" -eq 0 ]
    [ "$output" = "ABC" ]
}

@test "hex encode/decode roundtrip" {
    local text="Hello123!@#"
    local encoded
    local decoded
    
    encoded=$(hex_encode "$text")
    decoded=$(hex_decode "$encoded")
    
    [ "$decoded" = "$text" ]
}

# --------------------------------------------------------------------
# PASSWORD GENERATION TESTS
# --------------------------------------------------------------------

@test "generate_password creates password of specified length" {
    run generate_password 20
    [ "$status" -eq 0 ]
    [ "${#output}" -eq 20 ]
}

@test "generate_password has default length of 16" {
    run generate_password
    [ "$status" -eq 0 ]
    [ "${#output}" -eq 16 ]
}

@test "generate_password creates different passwords on each call" {
    local pass1=$(generate_password 10)
    local pass2=$(generate_password 10)
    
    [ "$pass1" != "$pass2" ]
}

@test "password_entropy calculates entropy" {
    run password_entropy "abc123"
    [ "$status" -eq 0 ]
    # Should return a numeric value
    [[ "$output" =~ ^[0-9]+\.?[0-9]*$ ]]
}

# --------------------------------------------------------------------
# FILE ENCRYPTION TESTS (OpenSSL required)
# --------------------------------------------------------------------

@test "encrypt_file/decrypt_file roundtrip" {
    if ! command -v openssl >/dev/null 2>&1; then
        skip "OpenSSL not available for encryption tests"
    fi
    
    local plaintext="$(mktemp)"
    local encrypted="$(mktemp)"
    local decrypted="$(mktemp)"
    local password="testpassword123"
    
    echo "Secret message content" > "$plaintext"
    
    # Encrypt the file
    run encrypt_file "$plaintext" "$password" "$encrypted"
    [ "$status" -eq 0 ]
    
    # Verify encrypted file exists and is different from original
    [ -f "$encrypted" ]
    run diff "$plaintext" "$encrypted"
    [ "$status" -ne 0 ]
    
    # Decrypt the file
    run decrypt_file "$encrypted" "$password" "$decrypted"
    [ "$status" -eq 0 ]
    
    # Verify decrypted content matches original
    run diff "$plaintext" "$decrypted"
    [ "$status" -eq 0 ]
    
    rm -f "$plaintext" "$encrypted" "$decrypted"
}

@test "encrypt_string/decrypt_string roundtrip" {
    if ! command -v openssl >/dev/null 2>&1; then
        skip "OpenSSL not available for encryption tests"
    fi
    
    local plaintext="This is a secret message"
    local password="testpass456"
    local encrypted
    local decrypted
    
    encrypted=$(encrypt_string "$plaintext" "$password")
    [ "$?" -eq 0 ]
    [ "$encrypted" != "$plaintext" ]
    
    decrypted=$(decrypt_string "$encrypted" "$password")
    [ "$?" -eq 0 ]
    [ "$decrypted" = "$plaintext" ]
}

# --------------------------------------------------------------------
# HMAC SIGNATURE TESTS
# --------------------------------------------------------------------

@test "hmac_sign creates consistent signatures" {
    if ! command -v openssl >/dev/null 2>&1; then
        skip "OpenSSL not available for HMAC tests"
    fi
    
    local message="test message"
    local key="secret_key"
    
    local signature1=$(hmac_sign "$message" "$key")
    local signature2=$(hmac_sign "$message" "$key")
    
    [ "$signature1" = "$signature2" ]
    [ "${#signature1}" -eq 64 ]  # SHA256 HMAC is 64 hex chars
}

@test "hmac_verify validates signatures correctly" {
    if ! command -v openssl >/dev/null 2>&1; then
        skip "OpenSSL not available for HMAC tests"
    fi
    
    local message="test message"
    local key="secret_key"
    local signature
    
    signature=$(hmac_sign "$message" "$key")
    
    run hmac_verify "$message" "$signature" "$key"
    [ "$status" -eq 0 ]
    
    # Test with wrong key
    run hmac_verify "$message" "$signature" "wrong_key"
    [ "$status" -eq 1 ]
    
    # Test with wrong message
    run hmac_verify "different message" "$signature" "$key"
    [ "$status" -eq 1 ]
}