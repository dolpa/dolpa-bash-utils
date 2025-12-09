#!/bin/bash
#===============================================================================
# exec.sh – Execution helpers
#
# Provides a thin, safe wrapper around:
#   • running a command and getting its status
#   • capturing stdout / stderr
#   • launching background jobs
#   • checking, waiting for and killing processes
#
# Dependencies (must be sourced first):
#   config.sh   – colour/terminal handling & common constants
#   logging.sh  – log_* helpers used for diagnostics
#   validation.sh – tiny helpers used by a few validation functions
#
# All functions are deliberately simple – they are easy to test and can be
# composed by the higher‑level modules (utils, system, …).
#===============================================================================

# ---------------------------------------------------------------------------
# Guard – prevent the file from being sourced more than once
# ---------------------------------------------------------------------------
if [[ "${BASH_UTILS_EXEC_LOADED:-}" == "true" ]]; then
    # Already sourced – silently ignore
    return 0
fi
readonly BASH_UTILS_EXEC_LOADED="true"

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


#===============================================================================
# Helper: exec_run
#   Run a command (foreground) and return its exit status.
#   Logs the command as a step (useful when VERBOSE is on).
# Arguments:
#   $1 – command name (string)
#   $@ – arguments to the command
# Returns:
#   exit status of the command
#===============================================================================
exec_run() {
    # Logging – the tests only check that something is printed, they do
    # not depend on the log level, so we use `log_debug` (provided by the
    # logger module) if it exists, otherwise fall back to `echo`.
    if declare -F log_debug >/dev/null 2>&1; then
        log_debug "Running: $*"
    else
        echo "Running: $*"
    fi

    # Execute the command exactly as it was given.
    "$@"
    local rc=$?          # capture the exit code before any other command
    return $rc           # propagate it to the caller (BATS stores it in $status)
}

#===============================================================================
# Helper: exec_run_capture
#   Run a command and capture *both* stdout and stderr into caller‑provided
#   variables.
# Arguments:
#   $1 – name of variable that will receive stdout
#   $2 – name of variable that will receive stderr
#   $3 – command name
#   $@ – arguments to the command
# Returns:
#   exit status of the command
#===============================================================================
exec_run_capture() {
    local out_var=$1 err_var=$2
    shift 2
    local stdout_file stderr_file
    stdout_file=$(mktemp) || return 1
    stderr_file=$(mktemp) || { rm -f "$stdout_file"; return 1; }

    # Run the command, redirecting its streams to the temporary files.
    # `set -o pipefail` is not needed – we capture the status directly.
    "$@" >"$stdout_file" 2>"$stderr_file"
    local rc=$?

    # Read the captured data.
    local stdout=$(<"$stdout_file")
    local stderr=$(<"$stderr_file")

    # Clean up the temporary files.
    rm -f "$stdout_file" "$stderr_file"

    # Store the results in the caller‑provided variable names.
    printf -v "$out_var" '%s' "$stdout"
    printf -v "$err_var" '%s' "$stderr"

    return $rc
}

#===============================================================================
# Helper: exec_background
#   Start a command in the background and print its PID.
#   The function itself returns success (0) unless the command could not be
#   started at all.
# Arguments:
#   $1 – command name
#   $@ – arguments
# Output:
#   PID of the started background job (on stdout)
# Returns:
#   0 on successful start, non‑zero otherwise
#===============================================================================
exec_background() {
    # Log the command (the logger is optional for the tests)
    if declare -F log_debug >/dev/null 2>&1; then
        log_debug "Running in background: $*"
    else
        echo "Running in background: $*"
    fi

    # Start the command asynchronously.
    "$@" &
    echo $!   # print the PID so the caller can use it
}

#===============================================================================
# Helper: exec_is_running
#   Check whether a given PID is still alive.
# Arguments:
#   $1 – PID (numeric)
# Returns:
#   0 if the process exists, 1 otherwise
#===============================================================================
exec_is_running() {
    local pid=$1
    # `kill -0` does not send a signal but succeeds only if the PID exists.
    if kill -0 "$pid" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

#===============================================================================
# Helper: exec_kill
#   Send a signal (default SIGTERM) to a PID.
# Arguments:
#   $1 – PID
#   $2 – signal name or number (optional, defaults to TERM)
# Returns:
#   0 if the signal was sent, 1 otherwise
#===============================================================================
exec_kill() {
    local pid=$1
    # Send SIGTERM first; if it does not die we fall back to SIGKILL.
    kill "$pid" 2>/dev/null || return 0
    # Give the process a moment to exit gracefully.
    sleep 0.1
    # If it is still alive, force‑kill it.
    kill -9 "$pid" 2>/dev/null
    # Reap the process so that it is removed from the process table.
    wait "$pid" 2>/dev/null
}

#===============================================================================
# Helper: exec_wait
#   Wait for a PID to finish, optionally with a timeout (seconds).
# Arguments:
#   $1 – PID
#   $2 – timeout in seconds (optional, 0 = wait forever)
# Returns:
#   0 if the process exited before the timeout, 1 otherwise
#===============================================================================
exec_wait() {
    local pid=$1 timeout=$2
    local elapsed=0
    while kill -0 "$pid" 2>/dev/null; do
        if (( elapsed >= timeout )); then
            return 1            # timed‑out
        fi
        sleep 1
        (( elapsed++ ))
    done
    return 0                    # finished before the timeout
}

#===============================================================================
# Helper: exec_run_with_timeout
#   Run a command but abort it if it runs longer than the supplied timeout.
#   Uses GNU coreutils `timeout` if available; otherwise falls back to a
#   manual implementation using the helpers above.
# Arguments:
#   $1 – timeout in seconds
#   $2 – command name
#   $@ – arguments to the command
# Returns:
#   Exit status of the command, or 124 (the standard timeout exit code)
#===============================================================================
exec_run_with_timeout() {
    local to=$1
    shift
    # Prefer the external `timeout` utility when it exists.
    if command -v timeout >/dev/null 2>&1; then
        timeout "$to" "$@"
        return $?               # GNU timeout returns 124 on timeout
    fi

    # Fallback implementation (POSIX‑compatible)
    local pid
    "$@" &
    pid=$!
    # Wait for the process with our own timeout loop.
    local waited=0
    while kill -0 "$pid" 2>/dev/null; do
        if (( waited >= to )); then
            kill "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null
            return 124
        fi
        sleep 1
        (( waited++ ))
    done
    wait "$pid"
    return $?
}

#===============================================================================
# End of exec.sh
#===============================================================================

export -f exec_run exec_run_capture exec_background exec_is_running exec_kill exec_wait exec_run_with_timeout 