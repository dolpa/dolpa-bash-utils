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

export -f http_get http_post http_status http_download