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

printf ''
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