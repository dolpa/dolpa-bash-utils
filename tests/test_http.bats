#!/usr/bin/env bats

#=====================================================================
# test_http.bats – tests for the http.sh wrapper
#=====================================================================

# ------------------------------------------------------------------
# Global setup – run once before every test case
# ------------------------------------------------------------------
setup() {
    # Load the library modules in the correct order.
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/validation.sh"
    source "${BATS_TEST_DIRNAME}/../modules/http.sh"

    # Force deterministic output – no colour codes.
    export NO_COLOR=1

    # Use a short timeout so CI does not hang on unreachable hosts.
    export BASH_UTILS_HTTP_TIMEOUT=5
}

# ------------------------------------------------------------------
# Helper – clean up temporary files created by download tests
# ------------------------------------------------------------------
teardown() {
    rm -f "${BATS_TEST_TMPDIR}/downloaded_test_file"
}

# ------------------------------------------------------------------
# Module loading tests
# ------------------------------------------------------------------
@test "http module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/http.sh"
    [ "$status" -eq 0 ]
}

@test "http module sets BASH_UTILS_HTTP_LOADED" {
    [ "$BASH_UTILS_HTTP_LOADED" = "true" ]
}

@test "http module prevents multiple sourcing" {
    run source "${BATS_TEST_DIRNAME}/../modules/http.sh"
    [ "$status" -eq 0 ]
}

# ------------------------------------------------------------------
# http_get()
# ------------------------------------------------------------------
@test "http_get returns content for a reachable URL (example.com)" {
    run http_get "https://example.com"
    [ "$status" -eq 0 ]
    # The page contains the word "Example Domain"
    [[ "$output" == *"Example Domain"* ]]
}

# ------------------------------------------------------------------
# http_status()
# ------------------------------------------------------------------
@test "http_status returns 200 for a reachable URL" {
    run http_status "https://example.com"
    [ "$status" -eq 0 ]
    [ "$output" = "200" ]
}

@test "http_status returns non‑200 for an unreachable IP" {
    run http_status "http://10.255.255.1"
    # The exact code depends on the client, but it must not be 200.
    [ "$status" -eq 0 ]               # the wrapper itself succeeded
    [[ "$output" != "200" ]]
}

# ------------------------------------------------------------------
# http_post()
# ------------------------------------------------------------------
@test "http_post to httpbin.org/post echoes back the posted data" {
    # Small JSON payload – works with both curl and wget.
    payload='{"msg":"bats test"}'
    run http_post "https://httpbin.org/post" "$payload"
    [ "$status" -eq 0 ]
    # httpbin returns the posted JSON under the key "data"
    [[ "$output" == *'"msg": "bats test"'* ]] || \
        [[ "$output" == *'"msg":"bats test"'* ]]
}

# ------------------------------------------------------------------
# http_download()
# ------------------------------------------------------------------
@test "http_download fetches a file and writes it to the given path" {
    local dest="${BATS_TEST_TMPDIR}/downloaded_test_file"
    run http_download "https://example.com" "$dest"
    [ "$status" -eq 0 ]
    [ -f "$dest" ]
    # The file must contain the same marker we used in the GET test.
    grep -q "Example Domain" "$dest"
}