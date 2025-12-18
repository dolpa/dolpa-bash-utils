#!/usr/bin/env bash
# ==============================================================================
# retry.sh – Retries and Back‑off Logic
# ==============================================================================
#
#   A small reliability helper for Bash scripts.  It provides three public
#   functions that can be used to repeat a command when it fails:
#
#       retry_cmd 3 command [args…]            – try *command* up to 3 times.
#       retry_with_backoff 5 2 command [args]  – try up to 5 times, waiting
#                                                an increasing delay (2 s, 4 s,
#                                                8 s …) between attempts.
#       retry_until 30 command [args]          – keep trying until the command
#                                                succeeds or *timeout* seconds
#                                                have elapsed.
#
#   All functions return the exit‑status of the last command they ran.
#
#   Why?  Many operations (network calls, package managers, API requests …)
#   are flaky.  Wrapping them in one of these helpers makes scripts more
#   robust without littering the code with loops and sleeps.
# ==============================================================================

# ----------------------------------------------------------------------
# Guard – avoid sourcing the module twice
# ----------------------------------------------------------------------
if [[ "${BASH_UTILS_RETRY_LOADED:-}" == "true" ]]; then
    return 0
fi

# ----------------------------------------------------------------------
# Load dependencies in the required order.
# ----------------------------------------------------------------------
_BASH_UTILS_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_BASH_UTILS_MODULE_DIR}/../modules/config.sh"
source "${_BASH_UTILS_MODULE_DIR}/../modules/logging.sh"
source "${_BASH_UTILS_MODULE_DIR}/../modules/validation.sh"

# ----------------------------------------------------------------------
# Export a read‑only flag that other code (and the test‑suite) can
# check to know the module is available.
# ----------------------------------------------------------------------
readonly BASH_UTILS_RETRY_LOADED="true"

# ----------------------------------------------------------------------
# retry_cmd
# ----------------------------------------------------------------------
#   retry_cmd <max-attempts> <command> [args…]
#
#   Run *command* up to <max-attempts> times.  As soon as the command
#   exits with status 0 the function returns 0.  If all attempts fail,
#   the function returns the status of the last execution.
# ----------------------------------------------------------------------
retry_cmd() {
    local attempts="${1:-}"
    shift || return 1
    local cmd=("$@")

    if [[ -z "$attempts" || ! "$attempts" =~ ^[0-9]+$ || "$attempts" -lt 1 ]]; then
        log_error "retry_cmd: <max-attempts> must be an integer >= 1"
        return 2
    fi

    local i=1
    while (( i <= attempts )); do
        "${cmd[@]}"
        local rc=$?
        if (( rc == 0 )); then
            return 0
        fi
        log_warn "retry_cmd: attempt $i/$attempts failed (rc=$rc)"
        if (( i < attempts )); then
            # a tiny pause between attempts makes most flaky commands behave better
            sleep 1
        fi
        (( i++ ))
    done
    return "$rc"
}

# ----------------------------------------------------------------------
# retry_with_backoff
# ----------------------------------------------------------------------
#   retry_with_backoff <max-attempts> <initial-delay> <command> [args…]
#
#   Same as retry, but after each failure the delay is doubled
#   (exponential back‑off).  <initial-delay> is given in seconds.
# ----------------------------------------------------------------------
retry_with_backoff() {
    local attempts="${1:-}"
    local delay="${2:-}"
    shift 2 || return 1
    local cmd=("$@")

    if [[ -z "$attempts" || ! "$attempts" =~ ^[0-9]+$ || "$attempts" -lt 1 ]]; then
        log_error "retry_with_backoff: <max-attempts> must be an integer >= 1"
        return 2
    fi
    if [[ -z "$delay" || ! "$delay" =~ ^[0-9]+$ ]]; then
        log_error "retry_with_backoff: <initial-delay> must be an integer >= 0"
        return 2
    fi

    local i=1
    local current_delay=$delay
    while (( i <= attempts )); do
        "${cmd[@]}"
        local rc=$?
        if (( rc == 0 )); then
            return 0
        fi
        log_warn "retry_with_backoff: attempt $i/$attempts failed (rc=$rc)"
        if (( i < attempts )); then
            # only sleep if we are going to try again
            sleep "$current_delay"
            # exponential back‑off for the next round
            current_delay=$(( current_delay * 2 ))
        fi
        (( i++ ))
    done
    return "$rc"
}

# ----------------------------------------------------------------------
# retry_until
# ----------------------------------------------------------------------
#   retry_until <timeout-seconds> <command> [args…]
#
#   Keep invoking *command* until it succeeds or the overall *timeout*
#   (seconds) has been reached.  The function sleeps 1 s between attempts.
# ----------------------------------------------------------------------
retry_until() {
    local timeout="${1:-}"
    shift || return 1
    local cmd=("$@")

    if [[ -z "$timeout" || ! "$timeout" =~ ^[0-9]+$ ]]; then
        log_error "retry_until: <timeout-seconds> must be an integer >= 0"
        return 2
    fi

    local start
    start=$(date +%s)

    while true; do
        "${cmd[@]}"
        local rc=$?
        if (( rc == 0 )); then
            return 0
        fi

        local now
        now=$(date +%s)
        if (( now - start >= timeout )); then
            log_error "retry_until: timeout of $timeout seconds reached"
            return "$rc"
        fi

        sleep 1
    done
}

export -f retry_cmd retry_with_backoff retry_until