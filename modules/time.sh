#!/usr/bin/env bash
#====================================================================
# 8. time.sh – Time, Timers, and Benchmarks
#
# Provides the most frequently‑needed time helpers for scripts:
#   • time_now          – current time in ISO‑8601 (UTC)
#   • time_epoch        – current POSIX epoch seconds
#   • time_benchmark    – human‑readable diff between two epoch values
#   • sleep_until       – sleep until a given epoch time is reached
#
# Why?  Perfect for logging timestamps, benchmarking commands,
#       and building reliable automations.
#
# The module follows the same conventions as the rest of the library:
#   • All public functions are declared with the `time_` prefix.
#   • The module sets a read‑only flag `BASH_UTILS_TIME_LOADED`
#     to indicate successful loading.
#   • Double‑sourcing is a no‑op.
#====================================================================

# ------------------------------------------------------------------
# Guard – return immediately if the module has already been sourced.
# ------------------------------------------------------------------
if [[ "${BASH_UTILS_TIME_LOADED:-}" == "true" ]]; then
    return 0
fi

# ------------------------------------------------------------------
# Load dependencies in the required order.
# ------------------------------------------------------------------
source "${BASH_SOURCE%/*}/config.sh"
source "${BASH_SOURCE%/*}/logging.sh"
source "${BASH_SOURCE%/*}/validation.sh"

# ------------------------------------------------------------------
# Export a read‑only flag that other code (and the test‑suite) can
# check to know the module is available.
# ------------------------------------------------------------------
readonly BASH_UTILS_TIME_LOADED="true"

# ------------------------------------------------------------------
# Private helper – convert a number of seconds into a compact
# human‑readable string (d/h/m/s).  This is deliberately lightweight
# and does **not** depend on utils.sh so the module stays self‑contained.
# ------------------------------------------------------------------
_time_seconds_to_human() {
    local secs=$1
    local out=""

    (( secs >= 86400 )) && { out+=$(( secs / 86400 ))d; secs=$(( secs % 86400 )); }
    (( secs >= 3600 ))  && { out+=$(( secs / 3600 ))h; secs=$(( secs % 3600 )); }
    (( secs >= 60 ))    && { out+=$(( secs / 60 ))m; secs=$(( secs % 60 )); }
    out+="${secs}s"
    printf "%s" "$out"
}

_time_is_gnu_date() {
    date --version >/dev/null 2>&1
}

_time_format_epoch() {
    local epoch="$1"
    local format="$2"
    local mode="${3:-utc}"

    if [[ -z "$epoch" || ! "$epoch" =~ ^-?[0-9]+$ ]]; then
        log_error "time_format_epoch: epoch must be an integer"
        return 2
    fi
    if [[ -z "$format" ]]; then
        log_error "time_format_epoch: missing format"
        return 2
    fi

    local use_utc="false"
    [[ "$mode" == "utc" ]] && use_utc="true"

    if _time_is_gnu_date; then
        if [[ "$use_utc" == "true" ]]; then
            date -u -d "@${epoch}" +"${format}"
        else
            date -d "@${epoch}" +"${format}"
        fi
        return 0
    fi

    # BSD date (macOS)
    if [[ "$use_utc" == "true" ]]; then
        date -u -r "${epoch}" +"${format}"
    else
        date -r "${epoch}" +"${format}"
    fi
}

_time_parse_iso8601_z_to_epoch() {
    local iso="$1"

    if [[ -z "$iso" ]]; then
        log_error "time_parse_iso8601: missing ISO-8601 timestamp"
        return 2
    fi
    if [[ ! "$iso" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
        log_error "time_parse_iso8601: unsupported format (expected YYYY-MM-DDTHH:MM:SSZ)"
        return 2
    fi

    if _time_is_gnu_date; then
        date -u -d "$iso" +%s
        return 0
    fi

    # BSD date (macOS)
    date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s
}

# ------------------------------------------------------------------
# time_now – ISO‑8601 timestamp (UTC) – useful for logs.
# ------------------------------------------------------------------
time_now() {
    time_now_iso8601_utc
}

# ------------------------------------------------------------------
# time_now_iso8601_utc – ISO-8601 timestamp (UTC).
# ------------------------------------------------------------------
time_now_iso8601_utc() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ------------------------------------------------------------------
# time_now_iso8601_local – ISO-like timestamp in local time.
# ------------------------------------------------------------------
time_now_iso8601_local() {
    date +"%Y-%m-%dT%H:%M:%S"
}

# ------------------------------------------------------------------
# time_epoch – current epoch seconds (POSIX time).
# ------------------------------------------------------------------
time_epoch() {
    date +%s
}

# ------------------------------------------------------------------
# time_epoch_ms – epoch time in milliseconds.
# ------------------------------------------------------------------
time_epoch_ms() {
    local ms
    ms=$(date +%s%3N 2>/dev/null || true)

    if [[ "$ms" =~ ^[0-9]{13,}$ ]]; then
        printf "%s\n" "$ms"
        return 0
    fi

    # BSD date has no millisecond formatter; fall back to seconds*1000.
    local s
    s=$(date +%s)
    printf "%s\n" "$(( s * 1000 ))"
}

# ------------------------------------------------------------------
# time_format_epoch <epoch> [format] [utc|local]
# ------------------------------------------------------------------
time_format_epoch() {
    local epoch="$1"
    local format="${2:-%Y-%m-%dT%H:%M:%SZ}"
    local mode="${3:-utc}"

    _time_format_epoch "$epoch" "$format" "$mode"
}

# ------------------------------------------------------------------
# time_epoch_to_iso8601 <epoch> [utc|local]
# ------------------------------------------------------------------
time_epoch_to_iso8601() {
    local epoch="$1"
    local mode="${2:-utc}"

    if [[ "$mode" == "utc" ]]; then
        _time_format_epoch "$epoch" "%Y-%m-%dT%H:%M:%SZ" "utc"
    else
        _time_format_epoch "$epoch" "%Y-%m-%dT%H:%M:%S" "local"
    fi
}

# ------------------------------------------------------------------
# time_parse_iso8601 <YYYY-MM-DDTHH:MM:SSZ>
# ------------------------------------------------------------------
time_parse_iso8601() {
    _time_parse_iso8601_z_to_epoch "$1"
}

# ------------------------------------------------------------------
# time_add_seconds <epoch> <delta>
# ------------------------------------------------------------------
time_add_seconds() {
    local epoch="$1"
    local delta="$2"

    if [[ -z "$epoch" || -z "$delta" || ! "$epoch" =~ ^-?[0-9]+$ || ! "$delta" =~ ^-?[0-9]+$ ]]; then
        log_error "time_add_seconds: usage: time_add_seconds <epoch> <delta_seconds>"
        return 2
    fi

    printf "%s\n" "$(( epoch + delta ))"
}

# ------------------------------------------------------------------
# time_diff_seconds <start_epoch> <end_epoch>
# ------------------------------------------------------------------
time_diff_seconds() {
    local start="$1"
    local end="$2"

    if [[ -z "$start" || -z "$end" || ! "$start" =~ ^-?[0-9]+$ || ! "$end" =~ ^-?[0-9]+$ ]]; then
        log_error "time_diff_seconds: usage: time_diff_seconds <start_epoch> <end_epoch>"
        return 2
    fi

    printf "%s\n" "$(( end - start ))"
}

# ------------------------------------------------------------------
# time_seconds_to_human <seconds>
# ------------------------------------------------------------------
time_seconds_to_human() {
    local secs="$1"
    if [[ -z "$secs" || ! "$secs" =~ ^[0-9]+$ ]]; then
        log_error "time_seconds_to_human: seconds must be a non-negative integer"
        return 2
    fi

    _time_seconds_to_human "$secs"
}

# ------------------------------------------------------------------
# time_benchmark start end
#   * $1 – start epoch (seconds)
#   * $2 – end   epoch (seconds)
#
# Returns a human‑readable duration, e.g. “1h2m3s”.
# ------------------------------------------------------------------
time_benchmark() {
    local start=$1
    local end=$2
    if [[ -z $start || -z $end ]]; then
        log_error "time_benchmark requires <start> <end> epoch values"
        return 2
    fi
    local diff
    diff=$(time_diff_seconds "$start" "$end") || return $?
    if (( diff < 0 )); then
        log_error "time_benchmark: end time is earlier than start time"
        return 2
    fi
    _time_seconds_to_human "$diff"
}

# ------------------------------------------------------------------
# sleep_until <epoch_seconds>
#   Sleep until the supplied epoch time is reached.
#   If the target time is already in the past, return immediately.
# ------------------------------------------------------------------
sleep_until() {
    local target=$1
    if [[ -z $target || ! "$target" =~ ^[0-9]+$ ]]; then
        log_error "sleep_until expects a positive integer epoch time"
        return 2
    fi
    local now
    now=$(time_epoch)
    local diff=$(( target - now ))
    if (( diff > 0 )); then
        sleep "$diff"
    fi
}

export -f time_now time_now_iso8601_utc time_now_iso8601_local
export -f time_epoch time_epoch_ms time_format_epoch time_epoch_to_iso8601 time_parse_iso8601
export -f time_add_seconds time_diff_seconds time_seconds_to_human time_benchmark sleep_until