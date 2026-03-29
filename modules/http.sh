#!/usr/bin/env bash
#=====================================================================
# http.sh – Lightweight HTTP client wrapper (curl / wget)
#
# Provides tiny helpers for GET, POST, status‑checking and file‑download.
#=====================================================================

# ------------------------------------------------------------------
# Guard – make the file idempotent when sourced multiple times
# ------------------------------------------------------------------
if [[ "${BASH_UTILS_HTTP_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_HTTP_LOADED="true"

# ------------------------------------------------------------------
# Dependencies – load in the same order as the rest of the library
# ------------------------------------------------------------------
# The module is deliberately *light*: only config, logging and
# validation are required.
source "${BASH_SOURCE%/*}/../modules/config.sh"
source "${BASH_SOURCE%/*}/../modules/logging.sh"
source "${BASH_SOURCE%/*}/../modules/validation.sh"

# ------------------------------------------------------------------
# Configuration defaults (can be overridden by the caller / tests)
# ------------------------------------------------------------------
: "${BASH_UTILS_HTTP_TIMEOUT:=10}"   # seconds for all network calls

# ------------------------------------------------------------------
# Detect which client we can use – curl is preferred, otherwise wget.
# If neither exists we abort early with a clear log message.
# ------------------------------------------------------------------
if command -v curl >/dev/null 2>&1; then
    _HTTP_CLIENT="curl"
elif command -v wget >/dev/null 2>&1; then
    _HTTP_CLIENT="wget"
else
    log_error "http.sh – Neither 'curl' nor 'wget' is installed"
    return 1
fi

# ------------------------------------------------------------------
# Internal helper – run a command with the configured timeout.
# ------------------------------------------------------------------
_http_run() {
    # Arguments are passed as an array to preserve quoting.
    local cmd=("$@")
    if [[ -n "${BASH_UTILS_HTTP_TIMEOUT}" ]]; then
        timeout "${BASH_UTILS_HTTP_TIMEOUT}" "${cmd[@]}"
    else
        "${cmd[@]}"
    fi
}

#=====================================================================
# Public API
#=====================================================================

# ------------------------------------------------------------------
# http_get URL
#   Perform a GET request and write the response body to stdout.
#   Returns the exit‑status of the underlying client.
# ------------------------------------------------------------------
http_get() {
    local url="${1:?Missing URL}"
    validate_url "$url" || { log_error "http_get – invalid URL: $url"; return 1; }

    if [[ "$_HTTP_CLIENT" == "curl" ]]; then
        _http_run curl -fsSL --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url"
    else
        _http_run wget -qO - "$url"
    fi
}

# ------------------------------------------------------------------
# http_post URL DATA
#   POST DATA to URL and write the response body to stdout.
# ------------------------------------------------------------------
http_post() {
    local url="${1:?Missing URL}"
    local data="${2:-}"
    validate_url "$url" || { log_error "http_post – invalid URL: $url"; return 1; }

    if [[ "$_HTTP_CLIENT" == "curl" ]]; then
        # If the payload looks like JSON, send it as JSON so services like httpbin
        # parse it and echo it back in a predictable structure.
        if [[ -n "$data" ]] && [[ "$data" =~ ^[[:space:]]*[\{\[] ]]; then
            _http_run curl -fsSL -X POST \
                -H "Content-Type: application/json" \
                --data-raw "$data" \
                --max-time "$BASH_UTILS_HTTP_TIMEOUT" \
                "$url"
        else
            _http_run curl -fsSL -X POST -d "$data" --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url"
        fi
    else
        # wget's --post-data expects a string; we use the same interface.
        if [[ -n "$data" ]] && [[ "$data" =~ ^[[:space:]]*[\{\[] ]]; then
            _http_run wget --header="Content-Type: application/json" --post-data="$data" -qO - "$url"
        else
            _http_run wget --post-data="$data" -qO - "$url"
        fi
    fi
}

# ------------------------------------------------------------------
# http_status URL
#   Return only the HTTP status code (as printed to stdout).
# ------------------------------------------------------------------
http_status() {
    local url="${1:?Missing URL}"
    validate_url "$url" || { log_error "http_status – invalid URL: $url"; return 1; }

    if [[ "$_HTTP_CLIENT" == "curl" ]]; then
        # Always return 0 and print a status code.
        # On network/connection errors curl exits non-zero; we still want a code.
        local code
        code="$(_http_run curl -s -o /dev/null -w "%{http_code}" --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url" 2>/dev/null || true)"
        [[ -n "$code" ]] || code="000"
        printf '%s' "$code"
        return 0
    else
        # wget –spider prints headers to stderr; we capture them.
        local headers
        headers="$(_http_run wget --spider -S "$url" 2>&1 || true)"
        local code
        code="$(awk '/^  HTTP\/[0-9\.]+/ {code=$2} END {print code}' <<<"$headers")"
        [[ -n "$code" ]] || code="000"
        printf '%s' "$code"
        return 0
    fi
}

# ------------------------------------------------------------------
# http_download URL FILE
#   Download a remote file into the supplied local path.
#   Returns 0 on success, non‑zero otherwise.
# ------------------------------------------------------------------
http_download() {
    local url="${1:?Missing URL}"
    local dest="${2:?Missing destination file}"
    validate_url "$url" || { log_error "http_download – invalid URL: $url"; return 1; }

    if [[ "$_HTTP_CLIENT" == "curl" ]]; then
        _http_run curl -fSL --max-time "$BASH_UTILS_HTTP_TIMEOUT" -o "$dest" "$url"
    else
        _http_run wget -q -O "$dest" "$url"
    fi
}

#===============================================================================
# ADDITIONAL HTTP METHODS
#===============================================================================

# HTTP PUT request
# Usage: response=$(http_put "https://api.example.com/data" '{"key":"value"}' "application/json")
# Arguments:
#   $1 - URL to request
#   $2 - request body (optional)
#   $3 - content type (default: application/json)
# Returns: response body via stdout, HTTP status via return code
http_put() {
    local url="$1"
    local body="$2"
    local content_type="${3:-application/json}"
    
    if [[ -z "$url" ]]; then
        log_error "http_put: missing URL argument"
        return 1
    fi
    
    validate_url "$url" || { log_error "http_put – invalid URL: $url"; return 1; }
    
    if [[ "$_HTTP_CLIENT" == "curl" ]]; then
        if [[ -n "$body" ]]; then
            _http_run curl -fsSL -X PUT -H "Content-Type: $content_type" -d "$body" --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url"
        else
            _http_run curl -fsSL -X PUT --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url"
        fi
    else
        if [[ -n "$body" ]]; then
            echo "$body" | _http_run wget --method=PUT --header="Content-Type: $content_type" --body-data=- -qO- "$url"
        else
            _http_run wget --method=PUT -qO- "$url"
        fi
    fi
}

# HTTP DELETE request
# Usage: response=$(http_delete "https://api.example.com/data/123")
# Arguments:
#   $1 - URL to request
# Returns: response body via stdout
http_delete() {
    local url="$1"
    
    if [[ -z "$url" ]]; then
        log_error "http_delete: missing URL argument"
        return 1
    fi
    
    validate_url "$url" || { log_error "http_delete – invalid URL: $url"; return 1; }
    
    if [[ "$_HTTP_CLIENT" == "curl" ]]; then
        _http_run curl -fsSL -X DELETE --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url"
    else
        _http_run wget --method=DELETE -qO- "$url"
    fi
}

# HTTP PATCH request
# Usage: response=$(http_patch "https://api.example.com/data/123" '{"key":"value"}')
# Arguments:
#   $1 - URL to request
#   $2 - request body (optional)
#   $3 - content type (default: application/json)
# Returns: response body via stdout
http_patch() {
    local url="$1"
    local body="$2"
    local content_type="${3:-application/json}"
    
    if [[ -z "$url" ]]; then
        log_error "http_patch: missing URL argument"
        return 1
    fi
    
    validate_url "$url" || { log_error "http_patch – invalid URL: $url"; return 1; }
    
    if [[ "$_HTTP_CLIENT" == "curl" ]]; then
        if [[ -n "$body" ]]; then
            _http_run curl -fsSL -X PATCH -H "Content-Type: $content_type" -d "$body" --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url"
        else
            _http_run curl -fsSL -X PATCH --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url"
        fi
    else
        if [[ -n "$body" ]]; then
            echo "$body" | _http_run wget --method=PATCH --header="Content-Type: $content_type" --body-data=- -qO- "$url"
        else
            _http_run wget --method=PATCH -qO- "$url"
        fi
    fi
}

# HTTP HEAD request (get headers only)
# Usage: headers=$(http_head "https://example.com")
# Arguments:
#   $1 - URL to request
# Returns: response headers via stdout
http_head() {
    local url="$1"
    
    if [[ -z "$url" ]]; then
        log_error "http_head: missing URL argument"
        return 1
    fi
    
    if command_exists curl; then
        curl -s -I "$url"
    elif command_exists wget; then
        wget --server-response --spider "$url" 2>&1 | grep -E "^\s*HTTP|^\s*[A-Za-z-]+:"
    else
        log_error "http_head: neither curl nor wget available"
        return 1
    fi
}

#===============================================================================
# HTTP REQUEST WITH CUSTOM HEADERS AND OPTIONS
#===============================================================================

# HTTP request with custom headers
# Usage: response=$(http_request "GET" "https://api.example.com" "" "Authorization: Bearer token" "Accept: application/json")
# Arguments:
#   $1 - HTTP method (GET, POST, PUT, DELETE, etc.)
#   $2 - URL to request
#   $3 - request body (optional)
#   $4+ - custom headers (optional)
# Returns: response body via stdout
http_request() {
    local method="$1"
    local url="$2"
    local body="$3"
    shift 3
    local headers=("$@")
    
    if [[ -z "$method" || -z "$url" ]]; then
        log_error "http_request: usage: http_request <method> <url> [body] [header1] [header2] ..."
        return 1
    fi

    validate_url "$url" || { log_error "http_request – invalid URL: $url"; return 1; }
    
    if command_exists curl; then
        local curl_args=("-s" "-X" "$method")
        
        # Add headers
        local header
        for header in "${headers[@]}"; do
            curl_args+=("-H" "$header")
        done
        
        # Add body if provided
        if [[ -n "$body" ]]; then
            curl_args+=("-d" "$body")
        fi
        
        # Add URL
        curl_args+=("$url")
        
        curl "${curl_args[@]}"
    else
        log_error "http_request: curl required for custom headers"
        return 1
    fi
}

# HTTP request with authentication
# Usage: response=$(http_request_auth "GET" "https://api.example.com" "username" "password")
# Arguments:
#   $1 - HTTP method
#   $2 - URL to request
#   $3 - username
#   $4 - password
#   $5 - request body (optional)
# Returns: response body via stdout
http_request_auth() {
    local method="$1"
    local url="$2"
    local username="$3"
    local password="$4"
    local body="$5"
    
    if [[ -z "$method" || -z "$url" || -z "$username" || -z "$password" ]]; then
        log_error "http_request_auth: usage: http_request_auth <method> <url> <username> <password> [body]"
        return 1
    fi
    
    if command_exists curl; then
        local curl_args=("-s" "-X" "$method" "-u" "$username:$password")
        
        if [[ -n "$body" ]]; then
            curl_args+=("-d" "$body")
        fi
        
        curl_args+=("$url")
        curl "${curl_args[@]}"
    else
        log_error "http_request_auth: curl required for authentication"
        return 1
    fi
}

# HTTP request with Bearer token
# Usage: response=$(http_request_bearer "GET" "https://api.example.com" "your-token")
# Arguments:
#   $1 - HTTP method
#   $2 - URL to request
#   $3 - Bearer token
#   $4 - request body (optional)
# Returns: response body via stdout
http_request_bearer() {
    local method="$1"
    local url="$2"  
    local token="$3"
    local body="$4"
    
    if [[ -z "$method" || -z "$url" || -z "$token" ]]; then
        log_error "http_request_bearer: usage: http_request_bearer <method> <url> <token> [body]"
        return 1
    fi
    
    local auth_header="Authorization: Bearer $token"
    
    if [[ -n "$body" ]]; then
        http_request "$method" "$url" "$body" "$auth_header"
    else
        http_request "$method" "$url" "" "$auth_header"
    fi
}

#===============================================================================
# FILE UPLOAD AND FORM DATA
#===============================================================================

# Upload file via HTTP POST
# Usage: response=$(http_upload_file "https://api.example.com/upload" "/path/to/file" "file")
# Arguments:
#   $1 - URL to upload to
#   $2 - file path to upload
#   $3 - form field name (default: file)
# Returns: response body via stdout
http_upload_file() {
    local url="$1"
    local file_path="$2"
    local field_name="${3:-file}"
    
    if [[ -z "$url" || -z "$file_path" ]]; then
        log_error "http_upload_file: usage: http_upload_file <url> <file_path> [field_name]"
        return 1
    fi
    
    if [[ ! -f "$file_path" ]]; then
        log_error "http_upload_file: file not found: $file_path"
        return 1
    fi
    
    validate_url "$url" || { log_error "http_upload_file – invalid URL: $url"; return 1; }
    
    if [[ "$_HTTP_CLIENT" == "curl" ]]; then
        _http_run curl -fsSL -F "$field_name=@$file_path" --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url"
    else
        log_error "http_upload_file: curl required for file uploads"
        return 1
    fi
}

# Send form data via HTTP POST
# Usage: response=$(http_post_form "https://example.com/submit" "name=John" "email=john@example.com")
# Arguments:
#   $1 - URL to post to
#   $2+ - form data fields (key=value format)
# Returns: response body via stdout
http_post_form() {
    local url="$1"
    shift
    local form_data=("$@")
    
    if [[ -z "$url" || ${#form_data[@]} -eq 0 ]]; then
        log_error "http_post_form: usage: http_post_form <url> <field1=value1> [field2=value2] ..."
        return 1
    fi
    
    if command_exists curl; then
        local curl_args=("-s" "-X" "POST")
        
        local field
        for field in "${form_data[@]}"; do
            curl_args+=("-d" "$field")
        done
        
        curl_args+=("$url")
        curl "${curl_args[@]}"
    else
        log_error "http_post_form: curl required for form data"
        return 1
    fi
}

#===============================================================================
# HTTP RESPONSE ANALYSIS
#===============================================================================

# Get HTTP status code and headers
# Usage: status_and_headers=$(http_get_full_response "https://example.com")
# Arguments:
#   $1 - URL to request
#   $2 - HTTP method (default: GET)
# Returns: status code and headers via stdout
http_get_full_response() {
    local url="$1"
    local method="${2:-GET}"
    
    if [[ -z "$url" ]]; then
        log_error "http_get_full_response: missing URL argument"
        return 1
    fi
    
    if command_exists curl; then
        curl -s -i -X "$method" "$url"
    elif command_exists wget; then
        wget --server-response -qO- "$url" 2>&1
    else
        log_error "http_get_full_response: neither curl nor wget available"
        return 1
    fi
}

# Get specific HTTP header value
# Usage: content_type=$(http_get_header "https://example.com" "content-type")
# Arguments:
#   $1 - URL to request
#   $2 - header name to extract
# Returns: header value via stdout
http_get_header() {
    local url="$1"
    local header_name="$2"
    
    if [[ -z "$url" || -z "$header_name" ]]; then
        log_error "http_get_header: usage: http_get_header <url> <header_name>"
        return 1
    fi
    
    if command_exists curl; then
        curl -s -I "$url" | grep -i "^$header_name:" | cut -d: -f2- | sed 's/^ *//' | tr -d '\r'
    else
        log_error "http_get_header: curl required for header extraction"
        return 1
    fi
}

# Check if URL is accessible (returns true/false)
# Usage: if http_is_accessible "https://example.com"; then ...; fi
# Arguments:
#   $1 - URL to check
#   $2 - timeout in seconds (default: 10)
# Returns: 0 if accessible, 1 if not
http_is_accessible() {
    local url="$1"
    local timeout="${2:-10}"
    
    if [[ -z "$url" ]]; then
        log_error "http_is_accessible: missing URL argument"
        return 1
    fi
    
    if command_exists curl; then
        curl -s --connect-timeout "$timeout" --max-time "$timeout" -o /dev/null -w "%{http_code}" "$url" | grep -q "^[23]"
    elif command_exists wget; then
        wget --timeout="$timeout" --tries=1 -q --spider "$url"
    else
        log_error "http_is_accessible: neither curl nor wget available"
        return 1
    fi
}

# Measure HTTP response time
# Usage: response_time=$(http_measure_time "https://example.com")
# Arguments:
#   $1 - URL to measure
# Returns: response time in seconds via stdout
http_measure_time() {
    local url="$1"
    
    if [[ -z "$url" ]]; then
        log_error "http_measure_time: missing URL argument"
        return 1
    fi
    
    if command_exists curl; then
        curl -s -o /dev/null -w "%{time_total}" "$url"
    else
        # Fallback timing method
        local start_time end_time
        start_time=$(date +%s)
        
        if http_is_accessible "$url" >/dev/null 2>&1; then
            end_time=$(date +%s)
            echo $((end_time - start_time))
        else
            return 1
        fi
    fi
}

#===============================================================================
# JSON API HELPERS
#===============================================================================

# GET JSON data and parse with jq (if available)
# Usage: data=$(http_get_json "https://api.example.com/data")
# Arguments:
#   $1 - URL to request
#   $2 - jq filter (optional)
# Returns: JSON response (optionally filtered) via stdout
http_get_json() {
    local url="$1"
    local jq_filter="$2"
    
    if [[ -z "$url" ]]; then
        log_error "http_get_json: missing URL argument"
        return 1
    fi
    
    local response
    response=$(http_get "$url")
    
    if [[ -n "$jq_filter" ]] && command_exists jq; then
        echo "$response" | jq "$jq_filter"
    else
        echo "$response"
    fi
}

# POST JSON data
# Usage: response=$(http_post_json "https://api.example.com/data" '{"key":"value"}')
# Arguments:
#   $1 - URL to post to
#   $2 - JSON data to send
# Returns: response body via stdout
http_post_json() {
    local url="$1"
    local json_data="$2"
    
    if [[ -z "$url" || -z "$json_data" ]]; then
        log_error "http_post_json: usage: http_post_json <url> <json_data>"
        return 1
    fi
    
    http_request "POST" "$url" "$json_data" "Content-Type: application/json"
}

# PUT JSON data
# Usage: response=$(http_put_json "https://api.example.com/data" '{"key":"value"}')
# Arguments:
#   $1 - URL to put to
#   $2 - JSON data to send
# Returns: response body via stdout
http_put_json() {
    local url="$1"
    local json_data="$2"
    
    if [[ -z "$url" || -z "$json_data" ]]; then
        log_error "http_put_json: usage: http_put_json <url> <json_data>"
        return 1
    fi
    
    http_request "PUT" "$url" "$json_data" "Content-Type: application/json"
}

#===============================================================================
# HTTP UTILITIES AND TESTING
#===============================================================================

# Download and save file with progress
# Usage: http_download_with_progress "https://example.com/file.zip" "/tmp/file.zip"
# Arguments:
#   $1 - URL to download from
#   $2 - local file path to save to  
# Returns: 0 on success, 1 on error
http_download_with_progress() {
    local url="$1"
    local output_file="$2"
    
    if [[ -z "$url" || -z "$output_file" ]]; then
        log_error "http_download_with_progress: usage: http_download_with_progress <url> <output_file>"
        return 1
    fi
    
    if command_exists curl; then
        curl -o "$output_file" --progress-bar -L "$url"
    elif command_exists wget; then
        wget --progress=bar -O "$output_file" "$url"
    else
        log_error "http_download_with_progress: neither curl nor wget available"
        return 1
    fi
}

# Test multiple URLs for accessibility
# Usage: http_test_urls "https://google.com" "https://github.com" "https://stackoverflow.com"
# Arguments: list of URLs to test
# Returns: 0 if all accessible, 1 if any fail
http_test_urls() {
    local urls=("$@")
    local failures=0
    
    if [[ ${#urls[@]} -eq 0 ]]; then
        log_error "http_test_urls: no URLs provided"
        return 1
    fi
    
    echo "Testing URL accessibility..."
    
    local url
    for url in "${urls[@]}"; do
        if http_is_accessible "$url" >/dev/null 2>&1; then
            log_success "✓ $url"
        else
            log_error "✗ $url"
            ((failures++))
        fi
    done
    
    if [[ $failures -eq 0 ]]; then
        log_success "All URLs are accessible"
        return 0
    else
        log_error "$failures URL(s) failed accessibility test"
        return 1
    fi
}

# Extract all links from a web page
# Usage: links=$(http_extract_links "https://example.com")
# Arguments:
#   $1 - URL to extract links from
# Returns: list of links, one per line
http_extract_links() {
    local url="$1"
    
    if [[ -z "$url" ]]; then
        log_error "http_extract_links: missing URL argument"
        return 1
    fi
    
    local content
    content=$(http_get "$url")
    
    if [[ -n "$content" ]]; then
        echo "$content" | grep -oiE 'href="[^"]+' | sed 's/href="//i' | sort -u
    else
        log_error "http_extract_links: failed to retrieve content from $url"
        return 1
    fi
}

#===============================================================================
# ADDITIONAL HTTP FUNCTIONS
#===============================================================================

# HTTP OPTIONS request
# Usage: response=$(http_options "https://api.example.com")
# Arguments:
#   $1 - URL to request
# Returns: response body via stdout
http_options() {
    local url="$1"
    
    if [[ -z "$url" ]]; then
        log_error "http_options: missing URL argument"
        return 1
    fi
    
    if command_exists curl; then
        _http_run curl -fsSL -X OPTIONS --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url"
    elif command_exists wget; then
        _http_run wget --method=OPTIONS -qO- "$url"
    else
        log_error "http_options: neither curl nor wget available"
        return 1
    fi
}

# HTTP request with basic authentication
# Usage: response=$(http_request_basic GET "https://api.example.com" "username" "password")
# Arguments:
#   $1 - HTTP method
#   $2 - URL to request
#   $3 - username
#   $4 - password
# Returns: response body via stdout
http_request_basic() {
    local method="$1"
    local url="$2"
    local username="$3"
    local password="$4"
    
    if [[ -z "$method" || -z "$url" ]]; then
        log_error "http_request_basic: usage: http_request_basic <method> <url> [username] [password]"
        return 1
    fi
    
    if [[ -z "$username" || -z "$password" ]]; then
        log_error "http_request_basic: both username and password are required for basic auth"
        return 1
    fi
    
    if command_exists curl; then
        _http_run curl -fsSL -X "$method" -u "$username:$password" --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url"
    elif command_exists wget; then
        _http_run wget --method="$method" --user="$username" --password="$password" -qO- "$url"
    else
        log_error "http_request_basic: neither curl nor wget available"
        return 1
    fi
}

# HTTP request with API key header
# Usage: response=$(http_request_api_key GET "https://api.example.com" "X-API-Key" "key123")
# Arguments:
#   $1 - HTTP method
#   $2 - URL to request
#   $3 - header name
#   $4 - API key value
# Returns: response body via stdout
http_request_api_key() {
    local method="$1"
    local url="$2"
    local header_name="$3"
    local api_key="$4"
    
    if [[ -z "$method" || -z "$url" || -z "$header_name" || -z "$api_key" ]]; then
        log_error "http_request_api_key: usage: http_request_api_key <method> <url> <header_name> <api_key>"
        return 1
    fi
    
    if command_exists curl; then
        _http_run curl -fsSL -X "$method" -H "$header_name: $api_key" --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url"
    elif command_exists wget; then
        _http_run wget --method="$method" --header="$header_name: $api_key" -qO- "$url"
    else
        log_error "http_request_api_key: neither curl nor wget available"
        return 1
    fi
}

# Upload multipart form data
# Usage: response=$(http_upload_multipart "https://httpbin.org/post" "field1=value1" "file=@/path/to/file.txt")
# Arguments:
#   $1 - URL to upload to
#   $@ - form fields and files
# Returns: response body via stdout
http_upload_multipart() {
    local url="$1"
    shift
    local form_data=("$@")
    
    if [[ -z "$url" || ${#form_data[@]} -eq 0 ]]; then
        log_error "http_upload_multipart: usage: http_upload_multipart <url> <field=value>..."
        return 1
    fi
    
    validate_url "$url" || { log_error "http_upload_multipart – invalid URL: $url"; return 1; }
    
    if [[ "$_HTTP_CLIENT" == "curl" ]]; then
        local curl_args=()
        for field in "${form_data[@]}"; do
            curl_args+=("-F" "$field")
        done
        _http_run curl -fsSL "${curl_args[@]}" --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url"
    else
        log_error "http_upload_multipart: curl is required for multipart uploads"
        return 1
    fi
}

# Get HTTP response headers
# Usage: headers=$(http_get_headers "https://example.com")
# Arguments:
#   $1 - URL to request
# Returns: response headers via stdout
http_get_headers() {
    local url="$1"
    
    if [[ -z "$url" ]]; then
        log_error "http_get_headers: missing URL argument"
        return 1
    fi
    
    if command_exists curl; then
        _http_run curl -fsSL -I --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url"
    elif command_exists wget; then
        _http_run wget -S -O /dev/null "$url" 2>&1 | grep -E "^[[:space:]]*[A-Za-z-]+:"
    else
        log_error "http_get_headers: neither curl nor wget available"
        return 1
    fi
}

# Get status text for HTTP status codes
# Usage: text=$(http_get_status_text 200)
# Arguments:
#   $1 - HTTP status code
# Returns: status text via stdout
http_get_status_text() {
    local status_code="$1"
    
    if [[ -z "$status_code" ]]; then
        log_error "http_get_status_text: missing status code argument"
        return 1
    fi
    
    case "$status_code" in
        200) echo "OK" ;;
        201) echo "Created" ;;
        204) echo "No Content" ;;
        301) echo "Moved Permanently" ;;
        302) echo "Found" ;;
        304) echo "Not Modified" ;;
        400) echo "Bad Request" ;;
        401) echo "Unauthorized" ;;
        403) echo "Forbidden" ;;
        404) echo "Not Found" ;;
        405) echo "Method Not Allowed" ;;
        409) echo "Conflict" ;;
        422) echo "Unprocessable Entity" ;;
        429) echo "Too Many Requests" ;;
        500) echo "Internal Server Error" ;;
        502) echo "Bad Gateway" ;;
        503) echo "Service Unavailable" ;;
        504) echo "Gateway Timeout" ;;
        *) echo "Unknown" ;;
    esac
}

# Parse JSON response (simple key extraction)
# Usage: value=$(parse_json_response '{"name":"test","value":42}' "name")
# Arguments:
#   $1 - JSON response
#   $2 - key to extract
# Returns: value via stdout
parse_json_response() {
    local json_response="$1"
    local key="$2"
    
    if [[ -z "$json_response" || -z "$key" ]]; then
        log_error "parse_json_response: usage: parse_json_response <json> <key>"
        return 1
    fi
    
    if command_exists jq; then
        local result
        result=$(echo "$json_response" | jq -r ".$key // empty" 2>/dev/null)
        if [[ -n "$result" && "$result" != "null" ]]; then
            echo "$result"
            return 0
        else
            return 1
        fi
    else
        # Simple regex-based extraction for basic cases
        local result
        result=$(echo "$json_response" | grep -oP "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*"[^"]*"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        else
            return 1
        fi
    fi
}

# Retry HTTP requests
# Usage: response=$(http_retry 3 http_get "https://example.com")
# Arguments:
#   $1 - max retry count
#   $@ - command to retry
# Returns: response from successful attempt
http_retry() {
    local max_retries="$1"
    shift
    local cmd=("$@")
    local attempt=1
    
    if [[ -z "$max_retries" || ${#cmd[@]} -eq 0 ]]; then
        log_error "http_retry: usage: http_retry <max_retries> <command> [args...]"
        return 1
    fi
    
    while [[ $attempt -le $max_retries ]]; do
        if "${cmd[@]}"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_retries ]]; then
            sleep 1
        fi
        ((attempt++))
    done
    
    log_error "http_retry: failed after $max_retries attempts"
    return 1
}

# Check if HTTP status code indicates success (2xx)
# Usage: if http_is_success 200; then echo "success"; fi
# Arguments:
#   $1 - HTTP status code
# Returns: 0 if success, 1 otherwise
http_is_success() {
    local status_code="$1"
    
    if [[ -z "$status_code" ]]; then
        log_error "http_is_success: missing status code argument"
        return 1
    fi
    
    if [[ "$status_code" =~ ^2[0-9][0-9]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Follow HTTP redirects
# Usage: final_url=$(http_follow_redirects "https://example.com")
# Arguments:
#   $1 - URL to follow
# Returns: final URL after redirects via stdout
http_follow_redirects() {
    local url="$1"
    
    if [[ -z "$url" ]]; then
        log_error "http_follow_redirects: missing URL argument"
        return 1
    fi
    
    if command_exists curl; then
        _http_run curl -fsSL -I -w "%{redirect_url}" --max-time "$BASH_UTILS_HTTP_TIMEOUT" "$url" | tail -n1
    elif command_exists wget; then
        _http_run wget -S -O /dev/null "$url" 2>&1 | grep "Location:" | tail -n1 | sed 's/.*Location: //'
    else
        log_error "http_follow_redirects: neither curl nor wget available"
        return 1
    fi
}

export -f http_get http_post http_status http_download \
          http_put http_delete http_patch http_head http_options \
          http_request http_request_auth http_request_bearer http_request_basic http_request_api_key \
          http_upload_file http_post_form http_upload_multipart \
          http_get_full_response http_get_header http_get_headers http_is_accessible http_measure_time \
          http_get_json http_post_json http_put_json \
          http_download_with_progress http_test_urls http_extract_links \
          http_get_status_text parse_json_response http_retry http_is_success http_follow_redirects