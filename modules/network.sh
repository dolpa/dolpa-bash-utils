#!/usr/bin/env bash
#=====================================================================
# network.sh - Network utilities for Bash‑Utils library
#
# This module provides a small collection of helper functions that
# make working with network resources easier inside Bash scripts.
#
#   • Ping a host
#   • Resolve a hostname to an IP address
#   • Test whether a TCP port is open
#   • Download a file (curl ↔ wget fallback)
#   • Verify that a URL is reachable (HEAD request)
#   • Retrieve the public IP address of the current host
#
# All functions are deliberately small, pure‑bash where possible
# and return an exit‑status compatible with the rest of the library:
#   0 – success, 1 – failure (and write an error message to stderr).
#
# The module follows the same conventions as the rest of the library:
#   • It guards against being sourced more than once.
#   • It loads its dependencies in the correct order.
#   • All public functions are documented with a short description,
#     a list of arguments and the expected return value.
#=====================================================================

# ------------------------------------------------------------------
# Guard against multiple sourcing – this pattern is used in every
# other module of the library.
# ------------------------------------------------------------------
if [[ -n "${BASH_UTILS_NETWORK_LOADED:-}" ]]; then
    # The module has already been sourced – exit silently.
    return 0
fi
readonly BASH_UTILS_NETWORK_LOADED=true

# ------------------------------------------------------------------
# Load required modules – config.sh must be first (defines colour
# handling and timestamp format), logging.sh provides the logging
# helpers, and validation.sh is used for argument validation.
# ------------------------------------------------------------------
source "${BASH_SOURCE[0]%/*}/config.sh"
source "${BASH_SOURCE[0]%/*}/logging.sh"
source "${BASH_SOURCE[0]%/*}/validation.sh"

# ------------------------------------------------------------------
# Public configuration variables (can be overridden by the caller)
# ------------------------------------------------------------------
# Timeout (in seconds) used for most network operations.
# A value of 0 disables the timeout (not recommended).
: "${BASH_UTILS_NETWORK_TIMEOUT:=5}"

# ------------------------------------------------------------------
# _network_cmd_exists()
#   Internal helper – checks that a required external command exists.
#   If the command is missing an error is logged and the function
#   returns 1.
# ------------------------------------------------------------------
_network_cmd_exists() {
    local cmd="${1}"
    if ! command_exists "${cmd}"; then
        log_error "Required command '${cmd}' not found in PATH."
        return 1
    fi
    return 0
}

#=====================================================================
# PUBLIC FUNCTIONS
#=====================================================================

#---------------------------------------------------------------------
# ping_host()
#   Ping a remote host using the system `ping` binary.
#
#   Arguments:
#       $1  – hostname or IP address to ping
#       $2  – (optional) number of ping packets to send (default: 1)
#
#   Returns:
#       0  – host replied to at least one ping packet
#       1  – host did not reply or ping is unavailable
#
#   Side effects:
#       Writes a short log entry (INFO) on success, an error log on
#       failure.
#---------------------------------------------------------------------
ping_host() {
  local host="${1:-}"
  # -----------------------------------------------------------------
  # 1️⃣  Basic validation
  # -----------------------------------------------------------------
  if [[ -z "$host" ]]; then
    log_error "ping_host: no host supplied"
    return 1
  fi

  # -----------------------------------------------------------------
  # 2️⃣  Loop‑back shortcut – always succeeds
  # -----------------------------------------------------------------
  case "$host" in
    localhost|127.0.0.1|::1) return 0 ;;
  esac

  # -----------------------------------------------------------------
  # 3️⃣  Find the ping executable
  # -----------------------------------------------------------------
  if ! command -v ping >/dev/null 2>&1; then
    # If ping is missing we cannot perform a real test – assume failure
    log_error "ping_host: ping command not found"
    return 1
  fi

  # -----------------------------------------------------------------
  # 4️⃣  Try Linux‑style ping first (-W seconds timeout)
  # -----------------------------------------------------------------
  if ping -c 1 -W 1 "$host" >/dev/null 2>&1; then
    return 0
  fi

  # -----------------------------------------------------------------
  # 5️⃣  macOS / BSD style ping uses -t (TTL) as a timeout flag
  # -----------------------------------------------------------------
  if ping -c 1 -t 1 "$host" >/dev/null 2>&1; then
    return 0
  fi

  # -----------------------------------------------------------------
  # 6️⃣  All attempts failed – report error
  # -----------------------------------------------------------------
  log_error "ping_host: unable to reach $host"
  return 1
}

#---------------------------------------------------------------------
# resolve_ip()
#   Resolve a hostname to an IP address.
#
#   Arguments:
#       $1  – hostname to resolve
#
#   Prints:
#       The first IP address found on stdout (no trailing newline).
#
#   Returns:
#       0  – resolution succeeded
#       1  – resolution failed
#
#   Side effects:
#       Writes an error log on failure.
#---------------------------------------------------------------------
resolve_ip() {
    local host="${1}"

    if [[ -z "${host}" ]]; then
        log_error "resolve_ip: missing required argument <host>."
        return 1
    fi

    # Prefer getent (works with both /etc/hosts and DNS). Fallback to
    # `dig` if getent is not available.
    if command_exists "getent"; then
        local result
        result=$(getent hosts "${host}" | awk '{print $1}' | head -n1)
        if [[ -n "${result}" ]]; then
            printf "%s" "${result}"
            return 0
        fi
    fi

    if command_exists "dig"; then
        local result
        result=$(dig +short "${host}" | head -n1)
        if [[ -n "${result}" ]]; then
            printf "%s" "${result}"
            return 0
        fi
    fi

    log_error "Unable to resolve hostname '${host}'."
    return 1
}

#---------------------------------------------------------------------
# is_port_open()
#   Test whether a TCP port on a given host is open using netcat.
#
#   Arguments:
#       $1  – hostname or IP address
#       $2  – TCP port number (1‑65535)
#
#   Returns:
#       0  – port is open (nc succeeded)
#       1  – port is closed or nc not available
#
#   Side effects:
#       Logs a debug message when BASH_UTILS_VERBOSE is true.
#---------------------------------------------------------------------
is_port_open() {
    local host="${1}"
    local port="${2}"

    if [[ -z "${host}" || -z "${port}" ]]; then
        log_error "is_port_open: missing required arguments <host> <port>."
        return 1
    fi
    if ! [[ "${port}" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        log_error "is_port_open: <port> must be in the range 1‑65535."
        return 1
    fi

    # Ensure nc (netcat) exists.
    _network_cmd_exists "nc" || return 1

    if nc -z -w "${BASH_UTILS_NETWORK_TIMEOUT}" "${host}" "${port}" &>/dev/null; then
        log_debug "Port ${port} on ${host} is open."
        return 0
    else
        log_debug "Port ${port} on ${host} is closed or filtered."
        return 1
    fi
}

#---------------------------------------------------------------------
# download_file()
#   Download a remote file to a local destination.
#
#   The function prefers `curl` (more portable) and falls back to
#   `wget` when curl is not installed. The download is performed
#   quietly (no progress bar) but errors are printed to stderr.
#
#   Arguments:
#       $1  – URL to download
#       $2  – Destination file path (must be writable)
#
#   Returns:
#       0  – download succeeded
#       1  – download failed (or missing required commands)
#
#   Side effects:
#       Logs an INFO entry on success, an ERROR entry on failure.
#---------------------------------------------------------------------
download_file() {
    local url="${1}"
    local dest="${2}"

    if [[ -z "${url}" || -z "${dest}" ]]; then
        log_error "download_file: missing required arguments <url> <dest>."
        return 1
    fi

    # Validate URL format first.
    validate_url "${url}" || return 1

    # Ensure the destination directory exists.
    local dest_dir
    dest_dir=$(dirname "${dest}")
    if [[ ! -d "${dest_dir}" ]]; then
        log_error "download_file: destination directory '${dest_dir}' does not exist."
        return 1
    fi

    # Prefer curl ---------------------------------------------------------
    if command_exists "curl"; then
        if curl -fsSL --max-time "${BASH_UTILS_NETWORK_TIMEOUT}" -o "${dest}" "${url}"; then
            log_info "File downloaded successfully to '${dest}'."
            return 0
        else
            log_error "Failed to download '${url}' with curl."
            return 1
        fi
    fi

    # Fallback to wget ----------------------------------------------------
    if command_exists "wget"; then
        if wget -q -T "${BASH_UTILS_NETWORK_TIMEOUT}" -O "${dest}" "${url}"; then
            log_info "File downloaded successfully to '${dest}'."
            return 0
        else
            log_error "Failed to download '${url}' with wget."
            return 1
        fi
    fi

    log_error "Neither 'curl' nor 'wget' is installed – cannot download files."
    return 1
}

#---------------------------------------------------------------------
# check_url()
#   Perform a lightweight HEAD request to verify that a URL is
#   reachable and returns a HTTP 2xx status code.
#
#   Arguments:
#       $1  – URL to check
#
#   Returns:
#       0  – URL reachable (2xx response)
#       1  – URL not reachable or does not return 2xx
#
#   Side effects:
#       Logs an error message when the check fails.
#---------------------------------------------------------------------
check_url() {
    local url="${1}"

    if [[ -z "${url}" ]]; then
        log_error "check_url: missing required argument <url>."
        return 1
    fi

    # Validate format first.
    validate_url "${url}" || return 1

    # Use curl if available, otherwise wget.
    if command_exists "curl"; then
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "${BASH_UTILS_NETWORK_TIMEOUT}" -I "${url}") || http_code=0
        if [[ "${http_code}" =~ ^2 ]]; then
            return 0
        else
            log_error "URL '${url}' returned HTTP status ${http_code}."
            return 1
        fi
    elif command_exists "wget"; then
        if wget --spider --timeout="${BASH_UTILS_NETWORK_TIMEOUT}" "${url}" &>/dev/null; then
            return 0
        else
            log_error "URL '${url}' is not reachable (wget spider failed)."
            return 1
        fi
    else
        log_error "Neither 'curl' nor 'wget' is installed – cannot check URL."
        return 1
    fi
}

#---------------------------------------------------------------------
# get_public_ip()
#   Retrieve the public IP address of the current machine using a
#   third‑party service (https://api.ipify.org). The service returns the
#   IP address as plain text.
#
#   Arguments:   none
#
#   Prints:      The public IP address on stdout (no newline)
#
#   Returns:
#       0  – request succeeded and a syntactically valid IP was returned
#       1  – request failed or response did not look like an IP
#
#   Side effects:
#       Logs an error on failure.
#---------------------------------------------------------------------
get_public_ip() {
    local service="https://api.ipify.org"

    # Prefer curl.
    if command_exists "curl"; then
        local ip
        ip=$(curl -fsSL --max-time "${BASH_UTILS_NETWORK_TIMEOUT}" "${service}") || ip=""
        if [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            printf "%s" "${ip}"
            return 0
        fi
    elif command_exists "wget"; then
        local ip
        ip=$(wget -q -T "${BASH_UTILS_NETWORK_TIMEOUT}" -O - "${service}") || ip=""
        if [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            printf "%s" "${ip}"
            return 0
        fi
    else
        log_error "Neither 'curl' nor 'wget' is installed – cannot obtain public IP."
        return 1
    fi

    log_error "Failed to retrieve a valid public IP address."
    return 1
}

export -f ping_host resolve_ip is_port_open download_file check_url get_public_ip

#=====================================================================
# END OF FILE
#=====================================================================