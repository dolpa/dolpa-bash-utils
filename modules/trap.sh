#!/usr/bin/env bash
#===============================================================================
# trap.sh – Signal handling & cleanup helpers
#===============================================================================
# Every serious script needs a graceful termination path.  This module provides
# a tiny set of utilities that make dealing with signals, exit‑handlers and
# temporary working directories painless and repeatable.
#
# Public functions
#   trap_on_exit   <cleanup_function>
#   trap_signals   <SIGNAL> [...]
#   with_tempdir   <command> [args …]
#
# All functions are deliberately simple – they do not depend on any external
# tools other than what the shared library already provides (config.sh,
# logging.sh, validation.sh).  They are safe to source multiple times; the
# first load sets a read‑only flag and subsequent sources return immediately.
#===============================================================================

# ---------------------------------------------------------------------------
# Guard – return if the module has already been loaded.
# ---------------------------------------------------------------------------
if [[ "${BASH_UTILS_TRAP_LOADED:-}" == "true" ]]; then
    return 0
fi

# ---------------------------------------------------------------------------
# Dependencies – load in the correct order.
# ---------------------------------------------------------------------------
_BASH_UTILS_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_BASH_UTILS_MODULE_DIR}/../modules/config.sh"
source "${_BASH_UTILS_MODULE_DIR}/../modules/logging.sh"
source "${_BASH_UTILS_MODULE_DIR}/../modules/validation.sh"

readonly BASH_UTILS_TRAP_LOADED="true"

# ---------------------------------------------------------------------------
# trap_on_exit <function_name>
# ---------------------------------------------------------------------------
# Register a function to be called when the script terminates (EXIT trap).
# The function name is stored in a global variable so that multiple calls
# replace the previous handler – this mirrors the behaviour of most
# “setup‑signal‑handlers” helpers in the library.
trap_on_exit() {
    local _func="${1:?trap_on_exit requires a function name}"
    if ! declare -F "${_func}" >/dev/null; then
        log_error "trap_on_exit: function '${_func}' not found"
        return 1
    fi
    trap "${_func}" EXIT
}

# ---------------------------------------------------------------------------
# trap_signals <SIGNAL> [...]
# ---------------------------------------------------------------------------
# Install a generic handler for each supplied signal.  The handler logs the
# receipt of the signal (if logging is enabled) and exits with status 0.
# Users can replace the handler with their own logic by redefining the
# function `__trap_signal_handler` before calling `trap_signals`.
__trap_signal_handler() {
    local _sig="${1}"
    log_warn "Received signal ${_sig} – exiting gracefully"
    # Let any EXIT‑trap run before terminating.
    exit 0
}

trap_signals() {
    if [[ $# -eq 0 ]]; then
        log_error "trap_signals: at least one signal name required"
        return 1
    fi
    local _sig
    for _sig in "$@"; do
        trap "__trap_signal_handler ${_sig}" "${_sig}"
    done
}

# ---------------------------------------------------------------------------
# with_tempdir <command> [args …]
# ---------------------------------------------------------------------------
# Run a command inside a freshly created temporary directory.  The directory
# is removed automatically when the command finishes (whether it succeeds or
# fails).  The command is executed in a subshell so that `cd` does not affect
# the caller.
with_tempdir() {
    if [[ $# -eq 0 ]]; then
        log_error "with_tempdir: a command to execute is required"
        return 1
    fi
    local _tmpdir
    _tmpdir=$(mktemp -d) || {
        log_error "with_tempdir: failed to create temporary directory"
        return 1
    }

    # Execute the supplied command in the temporary directory.
    (
        cd "${_tmpdir}" || exit 1
        "$@"
    )
    local _rc=$?
    rm -rf "${_tmpdir}"
    return "${_rc}"
}

export -f trap_on_exit trap_signals with_tempdir