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
if [[ "${BASH_UTILS_NETWORK_LOADED:-}" == "true" ]]; then
    # The module has already been sourced – exit silently.
    return 0
fi
readonly BASH_UTILS_NETWORK_LOADED=true

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
    local result=""

    if command_exists "getent"; then
        result=$(getent hosts "${host}" | awk '{print $1}' | head -n1)
        if [[ -n "${result}" ]]; then
            printf "%s" "${result}"
            return 0
        fi
    fi

    if command_exists "dig"; then
        result=$(dig +short "${host}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
        if [[ -n "${result}" ]]; then
            printf "%s" "${result}"
            return 0
        fi
    fi

    if command_exists "nslookup"; then
        # Only accept the IP that comes after a "Name:" line (the actual answer),
        # not the server info that appears at the top of nslookup output.
        result=$(nslookup "${host}" 2>/dev/null \
            | awk '/^Name:/{found=1; next} found && /Address:/{print $NF; found=0}' \
            | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | head -n1)
        if [[ -n "${result}" ]]; then
            printf "%s" "${result}"
            return 0
        fi
    fi

    if command_exists "host"; then
        result=$(host "${host}" 2>/dev/null | grep 'has address' | awk '{print $NF}' | head -n1)
        if [[ -n "${result}" ]]; then
            printf "%s" "${result}"
            return 0
        fi
    fi

    # Last resort: parse /etc/hosts directly
    result=$(grep -w "${host}" /etc/hosts 2>/dev/null | grep -v '^#' | awk '{print $1}' | head -n1)
    if [[ -n "${result}" ]]; then
        printf "%s" "${result}"
        return 0
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
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time "${BASH_UTILS_NETWORK_TIMEOUT}" "${url}") || http_code=0
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

# Get public IP address from external service
# Usage: public_ip=$(get_public_ip)
# Returns: public IP address via stdout, or error
get_public_ip() {
    local services=(
        "https://ipinfo.io/ip"
        "https://icanhazip.com"
        "https://api.ipify.org"
        "https://checkip.amazonaws.com"
    )
    
    local ip service
    for service in "${services[@]}"; do
        if command_exists curl; then
            ip=$(curl -s --connect-timeout 5 "$service" 2>/dev/null)
        elif command_exists wget; then
            ip=$(wget -qO- --timeout=5 "$service" 2>/dev/null)
        else
            log_error "get_public_ip: neither curl nor wget available"
            return 1
        fi
        
        if [[ -n "$ip" && "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$ip" | tr -d '\n\r'
            return 0
        fi
    done
    
    log_error "get_public_ip: could not determine public IP"
    return 1
}

# ------------------------------------------------------------------
# NETWORK INTERFACE FUNCTIONS
# ------------------------------------------------------------------

# Get local IP addresses
# Usage: local_ips=$(get_local_ips)
# Returns: list of local IP addresses, one per line
get_local_ips() {
    if command_exists ip; then
        ip addr show | grep -oP 'inet \K[\d.]+' | grep -v "127.0.0.1"
    elif command_exists ifconfig; then
        ifconfig | grep -oE 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -oE '([0-9]*\.){3}[0-9]*' | grep -v "127.0.0.1"
    elif command_exists hostname; then
        hostname -I 2>/dev/null | tr ' ' '\n' | grep -v "^$"
    else
        log_error "get_local_ips: no suitable network utility available"
        return 1
    fi
}

# Get default gateway
# Usage: gateway=$(get_default_gateway)
# Returns: default gateway IP address via stdout
get_default_gateway() {
    if command_exists ip; then
        ip route show | grep default | awk '{print $3}' | head -n1
    elif command_exists route; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            route get default | grep gateway | awk '{print $2}'
        else
            route -n | grep '^0\.0\.0\.0' | awk '{print $2}' | head -n1
        fi
    elif command_exists netstat; then
        netstat -rn | grep '^0\.0\.0\.0' | awk '{print $2}' | head -n1
    else
        log_error "get_default_gateway: no suitable routing utility available"
        return 1
    fi
}

# List network interfaces
# Usage: interfaces=$(list_network_interfaces)
# Returns: list of network interface names, one per line
list_network_interfaces() {
    if command_exists ip; then
        ip link show | grep -oE '^[0-9]+: [^:]+' | cut -d' ' -f2
    elif command_exists ifconfig; then
        ifconfig -a | grep -oE '^[a-zA-Z0-9]+:' | tr -d ':'
    elif [[ -d /sys/class/net ]]; then
        ls /sys/class/net/
    else
        log_error "list_network_interfaces: no suitable network utility available"
        return 1
    fi
}

# Get MAC address of an interface
# Usage: mac=$(get_mac_address "eth0")
# Arguments:
#   $1 - interface name (optional, defaults to first active interface)
# Returns: MAC address via stdout
get_mac_address() {
    local interface="$1"
    
    if [[ -z "$interface" ]]; then
        # Get first active interface
        interface=$(list_network_interfaces | head -n1)
    fi
    
    if [[ -z "$interface" ]]; then
        log_error "get_mac_address: no network interface specified or found"
        return 1
    fi
    
    if command_exists ip; then
        ip link show "$interface" | grep -oE 'link/ether [a-fA-F0-9:]{17}' | awk '{print $2}'
    elif command_exists ifconfig; then
        ifconfig "$interface" | grep -oE '([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}'
    elif [[ -r "/sys/class/net/$interface/address" ]]; then
        cat "/sys/class/net/$interface/address"
    else
        log_error "get_mac_address: could not determine MAC address for $interface"
        return 1
    fi
}

#===============================================================================
# PORT SCANNING AND MONITORING
#===============================================================================

# Scan a range of ports on a host
# Usage: scan_ports "192.168.1.1" 80 85
# Arguments:
#   $1 - hostname or IP address
#   $2 - start port
#   $3 - end port
# Returns: list of open ports, one per line
scan_ports() {
    local host="$1"
    local start_port="$2"
    local end_port="$3"
    local timeout="${4:-2}"
    
    if [[ -z "$host" || -z "$start_port" || -z "$end_port" ]]; then
        log_error "scan_ports: usage: scan_ports <host> <start_port> <end_port> [timeout]"
        return 1
    fi
    
    local port open_ports=()
    
    for ((port=start_port; port<=end_port; port++)); do
        if timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            open_ports+=("$port")
            echo "$port"
        fi
    done
    
    if [[ ${#open_ports[@]} -eq 0 ]]; then
        log_debug "scan_ports: no open ports found in range $start_port-$end_port on $host"
        return 1
    fi
}

# Get listening ports on local machine
# Usage: ports=$(get_listening_ports)
# Returns: list of listening ports with process info
get_listening_ports() {
    if command_exists netstat; then
        netstat -tulpn 2>/dev/null | grep LISTEN | awk '{print $1,$4,$7}' | column -t
    elif command_exists ss; then
        ss -tulpn | grep LISTEN | awk '{print $1,$5,$7}' | column -t
    else
        log_error "get_listening_ports: no suitable network utility available (netstat/ss)"
        return 1
    fi
}

# Check if a port is available (not in use)
# Usage: if is_port_available 8080; then ...; fi
# Arguments:
#   $1 - port number to check
# Returns: 0 if port is available, 1 if in use
is_port_available() {
    local port="$1"
    
    if [[ -z "$port" ]]; then
        log_error "is_port_available: missing port argument"
        return 1
    fi
    
    if command_exists netstat; then
        ! netstat -tuln 2>/dev/null | grep -q ":$port "
    elif command_exists ss; then
        ! ss -tuln 2>/dev/null | grep -q ":$port "
    else
        # Fallback: try to bind to the port
        if timeout 1 bash -c "exec 3<>/dev/tcp/127.0.0.1/$port" 2>/dev/null; then
            exec 3>&-
            return 1  # Port is in use
        else
            return 0  # Port is available
        fi
    fi
}

#===============================================================================
# DNS AND LOOKUP FUNCTIONS
#===============================================================================

# Perform DNS lookup for different record types
# Usage: records=$(dns_lookup "example.com" "A")
# Arguments:
#   $1 - domain name
#   $2 - record type (A, AAAA, MX, TXT, NS, CNAME) - default: A
# Returns: DNS records via stdout
dns_lookup() {
    local domain="$1"
    local record_type="${2:-A}"
    
    if [[ -z "$domain" ]]; then
        log_error "dns_lookup: missing domain argument"
        return 1
    fi
    
    local result=""

    # Check /etc/hosts first (covers localhost and other static entries,
    # which dig does not consult).
    if [[ "$record_type" == "A" || "$record_type" == "AAAA" ]]; then
        local hosts_result
        hosts_result=$(grep -w "$domain" /etc/hosts 2>/dev/null \
            | grep -v '^#' | awk '{print $1}' | head -n1)
        if [[ -n "$hosts_result" ]]; then
            echo "$hosts_result"
            return 0
        fi
    fi

    if command_exists dig; then
        result=$(dig +short "$domain" "$record_type" 2>/dev/null \
            | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$|^[0-9a-fA-F:]+$' | head -n1)
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    fi

    if command_exists nslookup; then
        # Only accept the IP that follows a "Name:" line (actual answer, not server info).
        result=$(nslookup -type="$record_type" "$domain" 2>/dev/null \
            | awk '/^Name:/{found=1; next} found && /Address:/{print $NF; found=0}' \
            | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | head -n1)
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    fi

    if command_exists host; then
        # Only take lines that contain 'has address' or 'has IPv6 address'.
        result=$(host -t "$record_type" "$domain" 2>/dev/null \
            | grep 'has address\|has IPv6 address\|mail is handled\|descriptive text' \
            | awk '{print $NF}' | head -n1)
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    fi

    log_error "dns_lookup: could not resolve '$domain' for record type '$record_type'"
    return 1
}

# Reverse DNS lookup (IP to hostname) – canonical name
# Usage: hostname=$(dns_reverse_lookup "8.8.8.8")
# Arguments:
#   $1 - IP address
# Returns: hostname via stdout
dns_reverse_lookup() {
    reverse_dns_lookup "$@"
}

# Reverse DNS lookup (IP to hostname)
# Usage: hostname=$(reverse_dns_lookup "8.8.8.8")
# Arguments:
#   $1 - IP address
# Returns: hostname via stdout
reverse_dns_lookup() {
    local ip="$1"
    
    if [[ -z "$ip" ]]; then
        log_error "reverse_dns_lookup: missing IP address argument"
        return 1
    fi
    
    if command_exists dig; then
        dig +short -x "$ip"
    elif command_exists nslookup; then
        nslookup "$ip" | grep 'name =' | awk '{print $4}' | sed 's/\.$//'
    elif command_exists host; then
        host "$ip" | grep 'domain name pointer' | awk '{print $5}' | sed 's/\.$//'
    else
        log_error "reverse_dns_lookup: no DNS lookup utility available"
        return 1
    fi
}

#===============================================================================
# NETWORK TESTING AND MONITORING
#===============================================================================

# Test network connectivity to multiple hosts
# Usage: test_connectivity "8.8.8.8" "1.1.1.1" "google.com"
# Arguments: list of hosts to test
# Returns: 0 if all hosts reachable, 1 if any fail
test_connectivity() {
    local hosts=("$@")
    local failures=0
    local host
    
    if [[ ${#hosts[@]} -eq 0 ]]; then
        log_error "test_connectivity: no hosts specified"
        return 1
    fi
    
    for host in "${hosts[@]}"; do
        if ping_host "$host" 1 >/dev/null 2>&1; then
            log_success "Connectivity OK: $host"
        else
            log_error "Connectivity FAILED: $host"
            ((failures++))
        fi
    done
    
    if [[ $failures -eq 0 ]]; then
        log_success "All connectivity tests passed"
        return 0
    else
        log_error "$failures connectivity test(s) failed"
        return 1
    fi
}

# Measure network latency to a host
# Usage: latency=$(measure_latency "google.com" 5)
# Arguments:
#   $1 - hostname or IP address
#   $2 - number of pings (default: 3)
# Returns: average latency in milliseconds via stdout
measure_latency() {
    local host="$1"
    local count="${2:-3}"
    
    if [[ -z "$host" ]]; then
        log_error "measure_latency: missing host argument"
        return 1
    fi
    
    if command_exists ping; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            ping -c "$count" "$host" | grep 'round-trip' | awk -F'/' '{print $5}'
        else
            ping -c "$count" "$host" | grep 'rtt\|round-trip' | awk -F'/' '{print $5}'
        fi
    else
        log_error "measure_latency: ping command not available"
        return 1
    fi
}

# Simple network speed test (download)
# Usage: speed=$(network_speed_test)
# Returns: download speed information via stdout
network_speed_test() {
    local test_url="http://speedtest.wdc01.softlayer.com/downloads/test10.zip"
    local test_file="/tmp/speedtest_$$"
    
    if command_exists curl; then
        log_info "Running network speed test..."
        if curl -o "$test_file" -w "Downloaded %{size_download} bytes in %{time_total} seconds\nAverage speed: %{speed_download} bytes/sec\n" -L "$test_url" 2>/dev/null; then
            rm -f "$test_file"
        else
            log_error "network_speed_test: speed test failed"
            rm -f "$test_file"
            return 1
        fi
    elif command_exists wget; then
        log_info "Running network speed test..."
        if wget -O "$test_file" "$test_url" 2>&1 | grep -E '([0-9.]+[KMG]B/s)'; then
            rm -f "$test_file"
        else
            log_error "network_speed_test: speed test failed"
            rm -f "$test_file"
            return 1
        fi
    else
        log_error "network_speed_test: neither curl nor wget available"
        return 1
    fi
}

#===============================================================================
# SSL/TLS AND CERTIFICATE FUNCTIONS
#===============================================================================

# Check SSL certificate information
# Usage: cert_info=$(check_ssl_cert "google.com" 443)
# Arguments:
#   $1 - hostname
#   $2 - port (default: 443)
# Returns: certificate information via stdout
check_ssl_cert() {
    local hostname="$1"
    local port="${2:-443}"
    
    if [[ -z "$hostname" ]]; then
        log_error "check_ssl_cert: missing hostname argument"
        return 1
    fi
    
    if ! command_exists openssl; then
        log_error "check_ssl_cert: openssl is required"
        return 1
    fi
    
    echo | openssl s_client -servername "$hostname" -connect "$hostname:$port" 2>/dev/null | openssl x509 -noout -dates -subject -issuer
}

# Check SSL certificate expiration
# Usage: days=$(ssl_cert_days_until_expiry "google.com")
# Arguments:
#   $1 - hostname
#   $2 - port (default: 443)
# Returns: number of days until expiration via stdout
ssl_cert_days_until_expiry() {
    local hostname="$1"
    local port="${2:-443}"
    
    if [[ -z "$hostname" ]]; then
        log_error "ssl_cert_days_until_expiry: missing hostname argument"
        return 1
    fi
    
    if ! command_exists openssl; then
        log_error "ssl_cert_days_until_expiry: openssl is required"
        return 1
    fi
    
    local expiry_date
    expiry_date=$(echo | openssl s_client -servername "$hostname" -connect "$hostname:$port" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
    
    if [[ -n "$expiry_date" ]]; then
        if command_exists date; then
            local expiry_epoch current_epoch days
            expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s 2>/dev/null)
            current_epoch=$(date +%s)
            days=$(( (expiry_epoch - current_epoch) / 86400 ))
            echo "$days"
        else
            log_error "ssl_cert_days_until_expiry: date command not available"
            return 1
        fi
    else
        log_error "ssl_cert_days_until_expiry: could not retrieve certificate expiry date"
        return 1
    fi
}

#===============================================================================
# NETWORK CONFIGURATION AND ROUTING
#===============================================================================

#===============================================================================
# ADDITIONAL MISSING FUNCTIONS
#===============================================================================

# Get information about a network interface
# Usage: get_interface_info "eth0"
# Arguments:
#   $1 - interface name
# Returns: interface info via stdout, 1 if not found
get_interface_info() {
    local interface="$1"
    if [[ -z "$interface" ]]; then
        log_error "get_interface_info: missing interface argument"
        return 1
    fi
    if command_exists ip; then
        ip link show "$interface" 2>/dev/null || { log_error "get_interface_info: interface '$interface' not found"; return 1; }
    elif command_exists ifconfig; then
        ifconfig "$interface" 2>/dev/null || { log_error "get_interface_info: interface '$interface' not found"; return 1; }
    else
        log_error "get_interface_info: no suitable network utility available"
        return 1
    fi
}

# Get statistics for a network interface
# Usage: get_interface_stats "eth0"
# Arguments:
#   $1 - interface name
# Returns: stats via stdout, 1 if not found
get_interface_stats() {
    local interface="$1"
    if [[ -z "$interface" ]]; then
        log_error "get_interface_stats: missing interface argument"
        return 1
    fi
    if [[ ! -d "/sys/class/net/$interface" ]]; then
        log_error "get_interface_stats: interface '$interface' not found"
        return 1
    fi
    if [[ -r "/sys/class/net/$interface/statistics/rx_bytes" ]]; then
        echo "RX bytes: $(cat /sys/class/net/$interface/statistics/rx_bytes)"
        echo "TX bytes: $(cat /sys/class/net/$interface/statistics/tx_bytes)"
    else
        log_error "get_interface_stats: statistics not available for '$interface'"
        return 1
    fi
}

# Wait until a port is open (poll with timeout)
# Usage: wait_for_port "127.0.0.1" 8080 30
# Arguments:
#   $1 - host
#   $2 - port
#   $3 - timeout in seconds (default: 30)
# Returns: 0 when port opens, 1 if timeout expires
wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout_secs="${3:-30}"

    if [[ -z "$host" || -z "$port" ]]; then
        log_error "wait_for_port: usage: wait_for_port <host> <port> [timeout_secs]"
        return 1
    fi

    local deadline=$(( SECONDS + timeout_secs ))
    while (( SECONDS < deadline )); do
        if command_exists nc; then
            nc -z -w 1 "$host" "$port" 2>/dev/null && return 0
        elif timeout 1 bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null; then
            return 0
        fi
        sleep 1
    done

    log_error "wait_for_port: timed out waiting for port $port on $host"
    return 1
}

# Check whether internet connectivity is available
# Usage: if check_internet_connection; then ...; fi
# Returns: 0 if internet is reachable, 1 otherwise
check_internet_connection() {
    local test_hosts=("8.8.8.8" "1.1.1.1" "8.8.4.4")
    local host
    for host in "${test_hosts[@]}"; do
        if ping_host "$host" >/dev/null 2>&1; then
            return 0
        fi
    done
    if command_exists curl; then
        curl -s --connect-timeout 3 --max-time 5 -o /dev/null \
            "https://www.google.com" 2>/dev/null && return 0
    fi
    return 1
}

# Get detailed SSL certificate information for a host
# Usage: get_ssl_cert_info "google.com" 443
# Arguments:
#   $1 - hostname
#   $2 - port (default: 443)
# Returns: certificate text via stdout
get_ssl_cert_info() {
    local hostname="$1"
    local port="${2:-443}"
    if [[ -z "$hostname" ]]; then
        log_error "get_ssl_cert_info: missing hostname argument"
        return 1
    fi
    if ! command_exists openssl; then
        log_error "get_ssl_cert_info: openssl is required"
        return 1
    fi
    echo | openssl s_client -servername "$hostname" -connect "$hostname:$port" 2>/dev/null \
        | openssl x509 -noout -text 2>/dev/null
}

# Flush the local DNS resolver cache
# Usage: flush_dns_cache
# Returns: 0 on success, 1 if no supported tool found
flush_dns_cache() {
    if command_exists resolvectl; then
        resolvectl flush-caches 2>/dev/null && return 0
    fi
    if systemctl -q is-active systemd-resolved 2>/dev/null; then
        systemd-resolve --flush-caches 2>/dev/null && return 0
    fi
    if command_exists nscd; then
        nscd -i hosts 2>/dev/null && return 0
    fi
    if [[ "$OSTYPE" == "darwin"* ]] && command_exists dscacheutil; then
        dscacheutil -flushcache 2>/dev/null && return 0
    fi
    log_error "flush_dns_cache: no supported DNS cache flush tool found"
    return 1
}

# Measure download throughput to/from a host
# Usage: test_bandwidth "8.8.8.8"
# Arguments:
#   $1 - hostname or IP
# Returns: 0 on success, 1 if host unreachable
test_bandwidth() {
    local host="$1"
    if [[ -z "$host" ]]; then
        log_error "test_bandwidth: missing host argument"
        return 1
    fi
    if ! ping_host "$host" >/dev/null 2>&1; then
        log_error "test_bandwidth: host '$host' is not reachable"
        return 1
    fi
    if command_exists curl; then
        curl -o /dev/null -w "Speed: %{speed_download} bytes/sec\n" \
            -s --max-time 10 "http://$host" 2>/dev/null
        return 0
    fi
    log_error "test_bandwidth: curl required for bandwidth testing"
    return 1
}

# Monitor a network interface continuously (runs until killed)
# Usage: monitor_connection "eth0" 5
# Arguments:
#   $1 - interface name
#   $2 - polling interval in seconds (default: 5)
# Returns: 1 if interface not found, otherwise loops until killed
monitor_connection() {
    local interface="$1"
    local interval="${2:-5}"
    if [[ -z "$interface" ]]; then
        log_error "monitor_connection: missing interface argument"
        return 1
    fi
    if [[ ! -d "/sys/class/net/$interface" ]]; then
        log_error "monitor_connection: interface '$interface' not found"
        return 1
    fi
    while true; do
        if [[ -r "/sys/class/net/$interface/statistics/rx_bytes" ]]; then
            echo "RX: $(cat /sys/class/net/$interface/statistics/rx_bytes) TX: $(cat /sys/class/net/$interface/statistics/tx_bytes)"
        fi
        sleep "$interval"
    done
}

# Get RX/TX byte counters for a network interface
# Usage: get_network_usage "eth0"
# Arguments:
#   $1 - interface name
# Returns: usage stats via stdout, 1 if interface not found
get_network_usage() {
    local interface="$1"
    if [[ -z "$interface" ]]; then
        log_error "get_network_usage: missing interface argument"
        return 1
    fi
    if [[ ! -d "/sys/class/net/$interface" ]]; then
        log_error "get_network_usage: interface '$interface' not found"
        return 1
    fi
    if [[ -r "/sys/class/net/$interface/statistics/rx_bytes" ]]; then
        echo "RX bytes: $(cat /sys/class/net/$interface/statistics/rx_bytes)"
        echo "TX bytes: $(cat /sys/class/net/$interface/statistics/tx_bytes)"
    else
        log_error "get_network_usage: statistics not available for '$interface'"
        return 1
    fi
}

# Show routing table
# Usage: route_table=$(show_routing_table)
# Returns: routing table information via stdout
show_routing_table() {
    if command_exists ip; then
        ip route show
    elif command_exists route; then
        route -n
    elif command_exists netstat; then
        netstat -rn
    else
        log_error "show_routing_table: no routing utility available"
        return 1
    fi
}

# Add a static route (requires root)
# Usage: add_route "192.168.2.0/24" "192.168.1.1"
# Arguments:
#   $1 - destination network (CIDR notation)
#   $2 - gateway IP address
# Returns: 0 on success, 1 on error
add_route() {
    local destination="$1"
    local gateway="$2"
    
    if [[ -z "$destination" || -z "$gateway" ]]; then
        log_error "add_route: usage: add_route <destination> <gateway>"
        return 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        log_error "add_route: root privileges required"
        return 1
    fi
    
    if command_exists ip; then
        ip route add "$destination" via "$gateway"
    elif command_exists route; then
        route add -net "$destination" gw "$gateway"
    else
        log_error "add_route: no routing utility available"
        return 1
    fi
}

# Delete a static route (requires root)
# Usage: delete_route "192.168.2.0/24"
# Arguments:
#   $1 - destination network (CIDR notation)
# Returns: 0 on success, 1 on error
delete_route() {
    local destination="$1"
    
    if [[ -z "$destination" ]]; then
        log_error "delete_route: usage: delete_route <destination>"
        return 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        log_error "delete_route: root privileges required"
        return 1
    fi
    
    if command_exists ip; then
        ip route del "$destination"
    elif command_exists route; then
        route del -net "$destination"
    else
        log_error "delete_route: no routing utility available"
        return 1
    fi
}

export -f ping_host resolve_ip is_port_open download_file check_url get_public_ip \
          get_local_ips get_default_gateway list_network_interfaces get_mac_address \
          scan_ports get_listening_ports is_port_available \
          dns_lookup reverse_dns_lookup dns_reverse_lookup \
          test_connectivity measure_latency network_speed_test \
          check_ssl_cert ssl_cert_days_until_expiry get_ssl_cert_info \
          show_routing_table add_route delete_route \
          get_interface_info get_interface_stats \
          wait_for_port check_internet_connection \
          flush_dns_cache test_bandwidth monitor_connection get_network_usage

#=====================================================================
# END OF FILE
#=====================================================================