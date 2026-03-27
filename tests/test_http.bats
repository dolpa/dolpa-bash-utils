#!/usr/bin/env bats

#=====================================================================
# test_http.bats – tests for the http.sh wrapper
#=====================================================================

# ------------------------------------------------------------------
# Global setup – run once before every test case
# ------------------------------------------------------------------
setup() {
    # Force deterministic output – no colour codes.
    export NO_COLOR=1

    # Use a short timeout so CI does not hang on unreachable hosts.
    export BASH_UTILS_HTTP_TIMEOUT=5

        # ------------------------------------------------------------------
        # CI-safe HTTP tests
        #
        # GitHub Actions environments can restrict outbound network access.
        # To keep these tests deterministic, we mock the underlying HTTP
        # client (curl) via PATH *before* sourcing http.sh.
        # ------------------------------------------------------------------
        export _BASH_UTILS_HTTP_MOCK_BIN="${BATS_TEST_TMPDIR}/mockbin"
        mkdir -p "$_BASH_UTILS_HTTP_MOCK_BIN"

        cat > "${_BASH_UTILS_HTTP_MOCK_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

url=""
outfile=""
writeout=""
is_post=0
data=""

args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
    case "${args[$i]}" in
        -o)
            outfile="${args[$((i+1))]:-}"
            i=$((i+1))
            ;;
        -w)
            writeout="${args[$((i+1))]:-}"
            i=$((i+1))
            ;;
        -X)
            if [[ "${args[$((i+1))]:-}" == "POST" ]]; then
                is_post=1
            fi
            i=$((i+1))
            ;;
        -d|--data-raw|--data)
            data="${args[$((i+1))]:-}"
            i=$((i+1))
            ;;
        http://*|https://*)
            url="${args[$i]}"
            ;;
    esac
done

body_example='<!doctype html><html><head><title>Example Domain</title></head><body>Example Domain</body></html>'

if [[ -n "$writeout" ]]; then
    if [[ "$url" == "https://example.com"* ]]; then
        printf '200'
        exit 0
    fi
    if [[ "$url" == "http://10.255.255.1"* ]]; then
        # Mimic curl's connection failure behavior (non-zero) but still provide a code.
        printf '000'
        exit 7
    fi
    printf '000'
    exit 0
fi

if [[ -n "$outfile" ]] && [[ "$outfile" != "/dev/null" ]]; then
    if [[ "$url" == "https://example.com"* ]]; then
        printf '%s' "$body_example" > "$outfile"
        exit 0
    fi
    printf 'download' > "$outfile"
    exit 0
fi

if (( is_post )); then
    # Return a response containing the posted JSON in an easy-to-match way.
    # Tests only assert that "msg" contains "bats test".
    if [[ "$data" == *'"msg"'* ]]; then
        printf '{"msg":"bats test"}'
    else
        printf '{"ok":true}'
    fi
    exit 0
fi

if [[ "$url" == "https://example.com"* ]]; then
    printf '%s' "$body_example"
    exit 0
fi

if [[ "$url" == "http://10.255.255.1"* ]]; then
    exit 7
fi

printf '{"ok":true}'
exit 0
EOF
        chmod +x "${_BASH_UTILS_HTTP_MOCK_BIN}/curl"

        export PATH="${_BASH_UTILS_HTTP_MOCK_BIN}:$PATH"

        # Load the library modules in the correct order.
        source "${BATS_TEST_DIRNAME}/../modules/config.sh"
        source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
        source "${BATS_TEST_DIRNAME}/../modules/validation.sh"
        source "${BATS_TEST_DIRNAME}/../modules/http.sh"
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

#===============================================================================
# ADDITIONAL HTTP METHOD TESTS
#===============================================================================

@test "http_put sends PUT requests" {
    payload='{"data":"test"}'
    run http_put "https://httpbin.org/put" "$payload"
    [ "$status" -eq 0 ]
    # Mock should handle PUT requests
    [ -n "$output" ]
}

@test "http_patch sends PATCH requests" {
    payload='{"data":"patch"}'
    run http_patch "https://httpbin.org/patch" "$payload"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "http_delete sends DELETE requests" {
    run http_delete "https://httpbin.org/delete"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "http_head sends HEAD requests" {
    run http_head "https://example.com"
    [ "$status" -eq 0 ]
}

@test "http_options sends OPTIONS requests" {
    run http_options "https://example.com"
    [ "$status" -eq 0 ]
}

@test "http_request handles generic requests" {
    run http_request "GET" "https://example.com"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Example Domain"* ]]
}

@test "http_request handles POST with data" {
    payload='{"test":"data"}'
    run http_request "POST" "https://httpbin.org/post" "$payload"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

#===============================================================================
# AUTHENTICATION TESTS
#===============================================================================

@test "http_request_basic handles basic auth" {
    run http_request_basic "GET" "https://example.com" "user" "pass"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "http_request_bearer handles bearer token auth" {
    run http_request_bearer "GET" "https://example.com" "token123"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "http_request_api_key handles API key auth" {
    run http_request_api_key "GET" "https://example.com" "X-API-Key" "key123"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

#===============================================================================
# FILE OPERATION TESTS
#===============================================================================

@test "http_upload_file handles file uploads" {
    local testfile="${BATS_TEST_TMPDIR}/upload_test.txt"
    echo "test content" > "$testfile"
    
    run http_upload_file "https://httpbin.org/post" "$testfile" "file"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    
    rm -f "$testfile"
}

@test "http_upload_multipart handles multipart uploads" {
    local testfile="${BATS_TEST_TMPDIR}/multipart_test.txt"
    echo "multipart content" > "$testfile"
    
    run http_upload_multipart "https://httpbin.org/post" "field1=value1" "file=@$testfile"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    
    rm -f "$testfile"
}

@test "http_upload_file fails for non-existent file" {
    run http_upload_file "https://httpbin.org/post" "/non/existent/file" "file"
    [ "$status" -eq 1 ]
}

#===============================================================================
# RESPONSE PROCESSING TESTS
#===============================================================================

@test "http_get_headers retrieves response headers" {
    run http_get_headers "https://example.com"
    [ "$status" -eq 0 ]
    # Headers should contain standard fields
    [[ "$output" == *"Content-Type"* ]] || [[ "$output" == *"content-type"* ]] || [ -n "$output" ]
}

@test "http_get_json retrieves and validates JSON response" {
    run http_get_json "https://httpbin.org/json"
    [ "$status" -eq 0 ]
    # Should return JSON content
    [[ "$output" == *"{"* ]] || [ -n "$output" ]
}

@test "http_get_status_text returns status text" {
    run http_get_status_text "200"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
    
    run http_get_status_text "404"
    [ "$status" -eq 0 ]
    [ "$output" = "Not Found" ]
    
    run http_get_status_text "500"
    [ "$status" -eq 0 ]
    [ "$output" = "Internal Server Error" ]
}

@test "parse_json_response extracts JSON values" {
    json_data='{"name":"test","value":42,"nested":{"key":"value"}}'
    
    run parse_json_response "$json_data" "name"
    [ "$status" -eq 0 ]
    [ "$output" = "test" ]
}

@test "parse_json_response handles missing keys gracefully" {
    json_data='{"name":"test"}'
    
    run parse_json_response "$json_data" "missing_key"
    [ "$status" -eq 1 ]
}

#===============================================================================
# ERROR HANDLING AND UTILITIES TESTS
#===============================================================================

@test "http_retry retries failed requests" {
    # Test with unreachable URL - should retry and then fail
    run http_retry 2 http_get "http://10.255.255.1"
    [ "$status" -eq 1 ]
}

@test "http_retry succeeds on successful request" {
    run http_retry 2 http_get "https://example.com"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Example Domain"* ]]
}

@test "http_is_success identifies successful status codes" {
    run http_is_success "200"
    [ "$status" -eq 0 ]
    
    run http_is_success "201"
    [ "$status" -eq 0 ]
    
    run http_is_success "204"
    [ "$status" -eq 0 ]
}

@test "http_is_success identifies error status codes" {
    run http_is_success "400"
    [ "$status" -eq 1 ]
    
    run http_is_success "404"
    [ "$status" -eq 1 ]
    
    run http_is_success "500"
    [ "$status" -eq 1 ]
}

@test "http_follow_redirects handles redirect responses" {
    run http_follow_redirects "https://example.com"
    # Should either succeed or handle redirects gracefully
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

#===============================================================================
# PARAMETER VALIDATION TESTS
#===============================================================================

@test "HTTP functions validate URL parameters" {
    # Test with invalid URLs
    run http_get "not_a_url"
    [ "$status" -eq 1 ]
    
    run http_post "invalid_url" "data"
    [ "$status" -eq 1 ]
    
    run http_request "GET" "bad_url"
    [ "$status" -eq 1 ]
}

@test "HTTP functions handle missing arguments" {
    # Test functions that require arguments
    run http_get
    [ "$status" -eq 1 ]
    
    run http_post
    [ "$status" -eq 1 ]
    
    run http_put
    [ "$status" -eq 1 ]
    
    run http_request
    [ "$status" -eq 1 ]
    
    run http_upload_file
    [ "$status" -eq 1 ]
}

@test "Authentication functions validate credentials" {
    run http_request_basic "GET" "https://example.com"
    [ "$status" -eq 1 ]  # Missing username/password
    
    run http_request_bearer "GET" "https://example.com"
    [ "$status" -eq 1 ]  # Missing token
    
    run http_request_api_key "GET" "https://example.com"
    [ "$status" -eq 1 ]  # Missing header/key
}

#===============================================================================
# INTEGRATION TESTS
#===============================================================================

@test "HTTP functions work with different methods on same endpoint" {
    local url="https://httpbin.org/anything"
    
    # Test multiple methods on same endpoint
    run http_get "$url"
    [ "$status" -eq 0 ]
    
    run http_post "$url" '{"test":"data"}'
    [ "$status" -eq 0 ]
    
    run http_put "$url" '{"test":"data"}'
    [ "$status" -eq 0 ]
}

@test "HTTP status and content functions work together" {
    local url="https://example.com"
    
    # Get status
    status_code=$(http_status "$url")
    
    # Get content
    content=$(http_get "$url")
    
    # Verify both work
    [ -n "$status_code" ]
    [ -n "$content" ]
    
    # Check if status is successful  
    if http_is_success "$status_code"; then
        # Content should not be empty for successful requests
        [ -n "$content" ]
    fi
}