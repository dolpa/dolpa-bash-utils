#!/bin/bash

#===============================================================================
# Bash Utility Library - System Detection Module
#===============================================================================
# Description: Operating system and hardware detection functions
# Author: dolpa (https://dolpa.me)
# Version: main
# License: Unlicense
# Dependencies: logging.sh (for logging), validation.sh (for command_exists)
#===============================================================================

# Prevent multiple sourcing
if [[ "${BASH_UTILS_SYSTEM_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_SYSTEM_LOADED="true"

# ------------------------------------------------------------------
# SYSTEM DETECTION FUNCTIONS
# ------------------------------------------------------------------

# Detect and return the operating system name
# Uses multiple detection methods for maximum compatibility
# Usage: os_name=$(get_os_name)
# Returns: operating system name string
get_os_name() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$NAME"
    elif command_exists lsb_release; then
        lsb_release -si
    elif [[ -f /etc/redhat-release ]]; then
        cat /etc/redhat-release
    else
        uname -s
    fi
}

# Detect and return the operating system version
# Uses multiple detection methods for maximum compatibility
# Usage: os_version=$(get_os_version)
# Returns: operating system version string
get_os_version() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$VERSION_ID"
    elif command_exists lsb_release; then
        lsb_release -sr
    else
        uname -r
    fi
}

# Auto-detect system type based on DMI information
auto_detect_system() {
    local detected_system=""
    
    log_debug "Attempting to auto-detect system type..."
    
    # Try to get system information from DMI
    if command_exists dmidecode; then
        local vendor product
        vendor=$(dmidecode -s system-manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr ' ' '-' || echo "unknown")
        product=$(dmidecode -s system-product-name 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr ' ' '-' || echo "unknown")
        
        # Construct system name from vendor and product
        if [[ "$vendor" != "unknown" && "$product" != "unknown" ]]; then
            detected_system="${vendor}-${product}"
            detected_system=$(echo "$detected_system" | sed 's/[^a-zA-Z0-9_-]//g')
            log_debug "Auto-detected system from DMI: $detected_system"
        fi
    fi
    
    # Fallback detection methods
    if [[ -z "$detected_system" && -f /sys/class/dmi/id/product_name ]]; then
        local product_name
        product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-zA-Z0-9_-]//g')
        if [[ -n "$product_name" && "$product_name" != "unknown" ]]; then
            detected_system="$product_name"
            log_debug "Auto-detected system from DMI sysfs: $detected_system"
        fi
    fi
    
    if [[ -n "$detected_system" ]]; then
        echo "$detected_system"
        return 0
    else
        log_warning "Could not auto-detect system type"
        return 1
    fi
}

# ------------------------------------------------------------------
# Sysctl profile detection
# ------------------------------------------------------------------



_sysctl_slugify() {
    # Lowercase, whitespace to '-', strip unsupported characters
    echo "$*" | tr '[:upper:]' '[:lower:]' | tr '[:space:]' '-' | sed 's/[^a-z0-9_-]//g'
}

_dmi_read() {
    local path="$1"
    [[ -f "$path" ]] || return 1
    cat "$path" 2>/dev/null
}

get_system_fingerprint() {
    # Best-effort, non-root fingerprint from sysfs DMI.
    local vendor product board
    vendor=$(_dmi_read /sys/class/dmi/id/sys_vendor || true)
    product=$(_dmi_read /sys/class/dmi/id/product_name || true)
    board=$(_dmi_read /sys/class/dmi/id/board_name || true)
    vendor=$(_sysctl_slugify "$vendor")
    product=$(_sysctl_slugify "$product")
    board=$(_sysctl_slugify "$board")
    echo "${vendor} ${product} ${board}" | tr ' ' '-'
}

list_sysctl_profiles() {
    local config_dir="$1"
    [[ -d "$config_dir" ]] || return 1

    local systems=()
    local file

    # Performance files may have a historical typo: 'performanc'.
    for file in "$config_dir"/99-*-performance.conf "$config_dir"/99-*-performanc.conf; do
        [[ -f "$file" ]] || continue

        local base
        base=$(basename "$file")
        local system_name
        system_name=$(echo "$base" | sed -E 's/^99-(.*)-(performance|performanc)\.conf$/\1/')

        local security_file="$config_dir/99-${system_name}-security.conf"
        [[ -f "$security_file" ]] || continue
        systems+=("$system_name")
    done

    # Deduplicate
    if (( ${#systems[@]} > 0 )); then
        printf '%s\n' "${systems[@]}" | awk '!seen[$0]++'
    fi
}

auto_detect_sysctl_profile() {
    # Usage: auto_detect_sysctl_profile <config_dir>
    # Honors SYSCTL_SYSTEM_NAME (or DOLPA_SYSCTL_SYSTEM_NAME) override.
    local config_dir="${1:-}"

    if [[ -n "${SYSCTL_SYSTEM_NAME:-}" ]]; then
        echo "${SYSCTL_SYSTEM_NAME}"
        return 0
    fi
    if [[ -n "${DOLPA_SYSCTL_SYSTEM_NAME:-}" ]]; then
        echo "${DOLPA_SYSCTL_SYSTEM_NAME}"
        return 0
    fi

    local fingerprint
    fingerprint=$(get_system_fingerprint | _sysctl_slugify)
    log_debug "System fingerprint: $fingerprint"

    local candidates=()
    if [[ -n "$config_dir" && -d "$config_dir" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && candidates+=("$line")
        done < <(list_sysctl_profiles "$config_dir" || true)
    fi

    # If we can’t see candidates, fall back to the generic DMI detection.
    if (( ${#candidates[@]} == 0 )); then
        auto_detect_system
        return $?
    fi

    # 1) Substring match (pick the longest matching candidate).
    local best=""
    local best_len=0
    local c
    for c in "${candidates[@]}"; do
        if [[ "$fingerprint" == *"$c"* ]]; then
            if (( ${#c} > best_len )); then
                best="$c"
                best_len=${#c}
            fi
        fi
    done
    if [[ -n "$best" ]]; then
        log_debug "Matched sysctl profile by substring: $best"
        echo "$best"
        return 0
    fi

    # 2) Heuristic mappings for common machines / your AI server.
    local fp="$fingerprint"
    if [[ "$fp" == *"dell"* && "$fp" == *"xps"* ]]; then
        if printf '%s\n' "${candidates[@]}" | grep -qx "dell-xps"; then
            echo "dell-xps"
            return 0
        fi
    fi
    if [[ "$fp" == *"thinkpad"* && "$fp" == *"x1"* ]] || [[ "$fp" == *"lenovo"* && "$fp" == *"x1"* ]]; then
        if printf '%s\n' "${candidates[@]}" | grep -qx "thinkpad-x1"; then
            echo "thinkpad-x1"
            return 0
        fi
    fi
    if [[ "$fp" == *"x88"* ]]; then
        if printf '%s\n' "${candidates[@]}" | grep -qx "ai-x88-srv"; then
            echo "ai-x88-srv"
            return 0
        fi
    fi

    log_warning "Could not map this machine to an available sysctl profile"
    log_info "Available profiles: $(printf '%s ' "${candidates[@]}")"
    return 1
}

# ------------------------------------------------------------------
# SYSTEM HARDWARE AND PERFORMANCE FUNCTIONS
# ------------------------------------------------------------------

# Get CPU information
# Usage: cpu_info=$(get_cpu_info)
# Returns: CPU information via stdout
get_cpu_info() {
    if [[ -f /proc/cpuinfo ]]; then
        # Linux
        local cpu_model cores
        cpu_model=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | sed 's/^ *//')
        cores=$(grep -c "^processor" /proc/cpuinfo)
        echo "CPU: $cpu_model"
        echo "Cores: $cores"
        
        # CPU frequency if available
        if [[ -f /proc/cpuinfo ]]; then
            local freq
            freq=$(grep "cpu MHz" /proc/cpuinfo | head -n1 | cut -d: -f2 | sed 's/^ *//')
            if [[ -n "$freq" ]]; then
                echo "Frequency: ${freq} MHz"
            fi
        fi
    elif command_exists sysctl; then
        # macOS/BSD
        local cpu_model cores freq
        cpu_model=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || sysctl -n hw.model 2>/dev/null)
        cores=$(sysctl -n hw.ncpu 2>/dev/null)
        freq=$(sysctl -n hw.cpufrequency 2>/dev/null)
        
        echo "CPU: $cpu_model"
        echo "Cores: $cores"
        if [[ -n "$freq" ]]; then
            echo "Frequency: $((freq / 1000000)) MHz"
        fi
    else
        log_warning "get_cpu_info: CPU information not available on this system"
        return 1
    fi
}

# Get memory information
# Usage: memory_info=$(get_memory_info)
# Returns: memory information via stdout
get_memory_info() {
    if [[ -f /proc/meminfo ]]; then
        # Linux
        local total_kb available_kb used_kb
        total_kb=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
        available_kb=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}')
        
        if [[ -z "$available_kb" ]]; then
            local free_kb buffers_kb cached_kb
            free_kb=$(grep "MemFree:" /proc/meminfo | awk '{print $2}')
            buffers_kb=$(grep "Buffers:" /proc/meminfo | awk '{print $2}')
            cached_kb=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
            available_kb=$((free_kb + buffers_kb + cached_kb))
        fi
        
        used_kb=$((total_kb - available_kb))
        
        echo "Total Memory: $((total_kb / 1024)) MB"
        echo "Used Memory: $((used_kb / 1024)) MB"
        echo "Available Memory: $((available_kb / 1024)) MB"
        echo "Memory Usage: $((used_kb * 100 / total_kb))%"
    elif command_exists sysctl; then
        # macOS/BSD
        local total_bytes
        total_bytes=$(sysctl -n hw.memsize 2>/dev/null)
        if [[ -n "$total_bytes" ]]; then
            echo "Total Memory: $((total_bytes / 1024 / 1024)) MB"
        fi
        
        # Try to get memory pressure info on macOS
        if command_exists vm_stat; then
            vm_stat | head -n10
        fi
    else
        log_warning "get_memory_info: memory information not available on this system"
        return 1
    fi
}

# Get disk usage information
# Usage: disk_info=$(get_disk_info)
# Returns: disk usage information via stdout
get_disk_info() {
    if command_exists df; then
        echo "Disk Usage:"
        df -h | grep -vE '^Filesystem|tmpfs|cdrom|udev'
    else
        log_warning "get_disk_info: df command not available"
        return 1
    fi
}

# Get system load averages
# Usage: load_info=$(get_load_info)
# Returns: load average information via stdout
get_load_info() {
    if [[ -f /proc/loadavg ]]; then
        # Linux
        local load1 load5 load15
        read -r load1 load5 load15 _ < /proc/loadavg
        echo "Load Average: $load1 (1min), $load5 (5min), $load15 (15min)"
    elif command_exists uptime; then
        # macOS/BSD and others
        uptime | awk -F'load average:' '{print "Load Average:" $2}'
    else
        log_warning "get_load_info: load information not available on this system"
        return 1
    fi
}

# Get system uptime
# Usage: uptime_info=$(get_uptime_info)
# Returns: uptime information via stdout
get_uptime_info() {
    if [[ -f /proc/uptime ]]; then
        # Linux
        local uptime_seconds
        uptime_seconds=$(cut -d. -f1 /proc/uptime)
        local days hours minutes
        days=$((uptime_seconds / 86400))
        hours=$(((uptime_seconds % 86400) / 3600))
        minutes=$(((uptime_seconds % 3600) / 60))
        echo "Uptime: ${days}d ${hours}h ${minutes}m"
    elif command_exists uptime; then
        # macOS/BSD and others
        uptime | awk -F'up ' '{print "Uptime: " $2}' | awk -F', [0-9]+ users' '{print $1}'
    else
        log_warning "get_uptime_info: uptime information not available"
        return 1
    fi
}

# Get running processes count
# Usage: process_count=$(get_process_count)
# Returns: number of running processes via stdout
get_process_count() {
    if command_exists ps; then
        ps aux | wc -l | awk '{print $1 - 1}'  # Subtract 1 for header
    else
        log_warning "get_process_count: ps command not available"
        return 1
    fi
}

# Get system temperature (if available)
# Usage: temp_info=$(get_temperature_info)
# Returns: temperature information via stdout
get_temperature_info() {
    local found_temp=false
    
    # Linux thermal zones
    if [[ -d /sys/class/thermal ]]; then
        local zone temp
        for zone in /sys/class/thermal/thermal_zone*/temp; do
            if [[ -r "$zone" ]]; then
                temp=$(cat "$zone")
                local zone_name
                zone_name=$(basename "$(dirname "$zone")")
                echo "$zone_name: $((temp / 1000))°C"
                found_temp=true
            fi
        done
    fi
    
    # Raspberry Pi specific
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local cpu_temp
        cpu_temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo "CPU Temperature: $((cpu_temp / 1000))°C"
        found_temp=true
    fi
    
    # Try sensors command if available
    if command_exists sensors; then
        sensors 2>/dev/null | grep -E "Core|temp" | head -10
        found_temp=true
    fi
    
    # macOS temperature (if tools available)
    if command_exists osx-cpu-temp 2>/dev/null; then
        echo "CPU Temperature: $(osx-cpu-temp)°C"
        found_temp=true
    fi
    
    if [[ "$found_temp" == false ]]; then
        log_debug "get_temperature_info: temperature sensors not available"
        return 1
    fi
}

# ------------------------------------------------------------------
# PROCESS AND SERVICE MANAGEMENT
# ------------------------------------------------------------------

# Get top processes by CPU usage
# Usage: top_cpu=$(get_top_processes_cpu 5)
# Arguments:
#   $1 - number of processes to show (default: 10)
# Returns: top CPU consuming processes via stdout
get_top_processes_cpu() {
    local count="${1:-10}"
    
    if command_exists ps; then
        echo "Top $count processes by CPU usage:"
        ps aux --sort=-pcpu | head -n $((count + 1)) | awk '{printf "%-8s %-6s %-6s %-6s %s\n", $1, $2, $3, $4, $11}'
    else
        log_warning "get_top_processes_cpu: ps command not available"
        return 1
    fi
}

# Get top processes by memory usage
# Usage: top_mem=$(get_top_processes_memory 5)
# Arguments:
#   $1 - number of processes to show (default: 10)
# Returns: top memory consuming processes via stdout
get_top_processes_memory() {
    local count="${1:-10}"
    
    if command_exists ps; then
        echo "Top $count processes by memory usage:"
        ps aux --sort=-pmem | head -n $((count + 1)) | awk '{printf "%-8s %-6s %-6s %-6s %s\n", $1, $2, $3, $4, $11}'
    else
        log_warning "get_top_processes_memory: ps command not available"
        return 1
    fi
}

# Kill processes by name
# Usage: kill_processes_by_name "firefox" "TERM"
# Arguments:
#   $1 - process name pattern
#   $2 - signal to send (default: TERM)
# Returns: number of processes killed via stdout
kill_processes_by_name() {
    local process_name="$1"
    local signal="${2:-TERM}"
    local killed_count=0
    
    if [[ -z "$process_name" ]]; then
        log_error "kill_processes_by_name: missing process name"
        return 1
    fi
    
    if command_exists pkill; then
        if pkill -"$signal" "$process_name"; then
            killed_count=$(pgrep -c "$process_name" 2>/dev/null || echo 0)
            log_success "Sent $signal signal to processes matching '$process_name'"
        else
            log_warning "No processes found matching '$process_name'"
        fi
    else
        log_error "kill_processes_by_name: pkill command not available"
        return 1
    fi
    
    echo "$killed_count"
}

# ------------------------------------------------------------------
# SYSTEM MONITORING AND HEALTH
# ------------------------------------------------------------------

# Check system health (comprehensive overview)
# Usage: system_health=$(check_system_health)
# Returns: system health report via stdout
check_system_health() {
    echo "=== SYSTEM HEALTH REPORT ==="
    echo "Generated: $(date)"
    echo
    
    # OS Information
    echo "--- Operating System ---"
    get_os_name
    get_os_version
    echo
    
    # Uptime and Load
    echo "--- System Status ---"
    get_uptime_info
    get_load_info
    echo "Processes: $(get_process_count)"
    echo
    
    # Hardware Information
    echo "--- Hardware Information ---"
    get_cpu_info
    echo
    get_memory_info
    echo
    
    # Disk Usage
    echo "--- Storage ---"
    get_disk_info
    echo
    
    # Temperature (if available)
    echo "--- Temperature ---"
    if get_temperature_info >/dev/null 2>&1; then
        get_temperature_info
    else
        echo "Temperature sensors not available"
    fi
    echo
}

# Monitor system resources in real-time
# Usage: monitor_system [interval] [count]
# Arguments:
#   $1 - update interval in seconds (default: 5, must be a non-negative integer)
#   $2 - number of iterations, 0 = infinite (default: 0)
monitor_system() {
    local interval="${1:-5}"
    local max_count="${2:-0}"
    local count=0

    if [[ ! "$interval" =~ ^[0-9]+$ ]]; then
        log_error "monitor_system: invalid interval '$interval' (must be a non-negative integer)"
        return 1
    fi
    if [[ ! "$max_count" =~ ^[0-9]+$ ]]; then
        log_error "monitor_system: invalid count '$max_count' (must be a non-negative integer)"
        return 1
    fi

    log_info "Starting system monitoring (interval: ${interval}s, press Ctrl+C to stop)"

    while true; do
        check_system_health

        if [[ $max_count -gt 0 ]]; then
            (( count++ ))
            if [[ $count -ge $max_count ]]; then
                break
            fi
        fi

        sleep "$interval"
    done
}

# Check if system needs reboot (Linux)
# Usage: if needs_reboot; then ...; fi
# Returns: 0 if reboot needed, 1 otherwise
needs_reboot() {
    # Check for reboot-required file (Ubuntu/Debian)
    if [[ -f /var/run/reboot-required ]]; then
        return 0
    fi
    
    # Check if kernel has been updated (general Linux)
    if [[ -f /proc/version ]]; then
        local running_kernel installed_kernel
        running_kernel=$(uname -r)
        
        if command_exists rpm; then
            # RPM-based systems
            installed_kernel=$(rpm -q kernel | tail -n1 | sed 's/kernel-//')
        elif command_exists dpkg; then
            # Debian-based systems
            installed_kernel=$(dpkg -l | grep 'linux-image-[0-9]' | grep '^ii' | awk '{print $2}' | tail -n1 | sed 's/linux-image-//')
        fi
        
        if [[ -n "$installed_kernel" && "$running_kernel" != "$installed_kernel"* ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Get system users currently logged in
# Usage: users=$(get_logged_users)
# Returns: list of logged in users via stdout
get_logged_users() {
    if command_exists who; then
        who | awk '{print $1}' | sort -u
    elif command_exists users; then
        users | tr ' ' '\n' | sort -u
    else
        log_warning "get_logged_users: no suitable command available"
        return 1
    fi
}

# Check available package updates (if package manager available)
# Usage: updates=$(check_package_updates)
# Returns: number of available updates via stdout
check_package_updates() {
    if command_exists apt; then
        # Debian/Ubuntu
        apt list --upgradable 2>/dev/null | grep -c upgradable || echo 0
    elif command_exists yum; then
        # Red Hat/CentOS (older)
        yum check-update -q | wc -l || echo 0
    elif command_exists dnf; then
        # Fedora/Red Hat (newer)
        dnf check-update -q | wc -l || echo 0
    elif command_exists pacman; then
        # Arch Linux
        pacman -Qu | wc -l || echo 0
    elif command_exists zypper; then
        # openSUSE
        zypper list-updates | grep -c '^v' || echo 0
    else
        log_debug "check_package_updates: no supported package manager found"
        return 1
    fi
}

# ------------------------------------------------------------------
# SYSTEM CONFIGURATION AND ENVIRONMENT
# ------------------------------------------------------------------

# Get environment overview
# Usage: env_info=$(get_environment_info)
# Returns: environment information via stdout
get_environment_info() {
    echo "=== ENVIRONMENT INFORMATION ==="
    
    echo "--- Shell ---"
    echo "Shell: $SHELL"
    echo "Bash Version: ${BASH_VERSION:-N/A}"
    
    echo
    echo "--- Paths ---"
    echo "PATH: $PATH"
    echo "HOME: $HOME"
    echo "PWD: $PWD"
    
    echo
    echo "--- Locale ---"
    echo "LANG: ${LANG:-not set}"
    echo "LC_ALL: ${LC_ALL:-not set}"
    
    echo
    echo "--- Terminal ---"
    echo "TERM: ${TERM:-not set}"
    echo "Terminal Size: $(tput cols 2>/dev/null || echo 'unknown')x$(tput lines 2>/dev/null || echo 'unknown')"
    
    if command_exists locale; then
        echo
        echo "--- Locale Settings ---"
        locale
    fi
}

# Check for virtualization type
# Usage: virt_type=$(detect_virtualization)
# Returns: one of: none vm container kvm vmware virtualbox xen docker podman
detect_virtualization() {
    # Container environments (most specific — check first)
    if [[ -f /.dockerenv ]]; then
        echo "docker"; return 0
    fi
    if [[ -n "${container:-}" ]] || grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
        echo "container"; return 0
    fi

    # Use systemd-detect-virt when available (most reliable)
    if command_exists systemd-detect-virt; then
        local virt
        virt=$(systemd-detect-virt 2>/dev/null)
        case "$virt" in
            none)                                    echo "none";       return 0 ;;
            kvm)                                     echo "kvm";        return 0 ;;
            vmware)                                  echo "vmware";     return 0 ;;
            oracle|virtualbox)                       echo "virtualbox"; return 0 ;;
            xen)                                     echo "xen";        return 0 ;;
            docker)                                  echo "docker";     return 0 ;;
            podman)                                  echo "podman";     return 0 ;;
            lxc*|lxd*|openvz*|rkt|systemd-nspawn)   echo "container";  return 0 ;;
            *) echo "vm"; return 0 ;;
        esac
    fi

    # DMI-based fallback
    if [[ -d /sys/class/dmi/id ]]; then
        local vendor product
        vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "")
        product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
        case "$vendor $product" in
            *VMware*)              echo "vmware";     return 0 ;;
            *VirtualBox*|*Oracle*VM*) echo "virtualbox"; return 0 ;;
            *QEMU*|*KVM*)          echo "kvm";        return 0 ;;
            *Xen*)                 echo "xen";        return 0 ;;
        esac
    fi

    # /proc/cpuinfo hypervisor flag
    if [[ -f /proc/cpuinfo ]] && grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
        echo "vm"; return 0
    fi

    echo "none"
}

# Get kernel information
# Usage: kernel_info=$(get_kernel_info)
# Returns: kernel information via stdout
get_kernel_info() {
    echo "Kernel: $(uname -s)"
    echo "Kernel Release: $(uname -r)"
    echo "Kernel Version: $(uname -v)"
    echo "Architecture: $(uname -m)"
    
    if [[ -f /proc/version ]]; then
        echo "Kernel Details: $(cat /proc/version)"
    fi
}

# ------------------------------------------------------------------
# SYSTEM INFO AGGREGATION
# ------------------------------------------------------------------

# Get a brief system summary
# Usage: get_system_info
get_system_info() {
    echo "OS: $(get_os_name)"
    echo "OS Version: $(get_os_version)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Hostname: $(hostname 2>/dev/null || echo 'unknown')"
}

# Get the CPU architecture string
# Usage: get_architecture
get_architecture() {
    uname -m
}

# ------------------------------------------------------------------
# PERFORMANCE MONITORING
# ------------------------------------------------------------------

# Get current CPU usage percentage
# Usage: cpu_pct=$(get_cpu_usage)
get_cpu_usage() {
    if [[ -f /proc/stat ]]; then
        local line1 line2
        line1=$(grep "^cpu " /proc/stat)
        sleep 0.2
        line2=$(grep "^cpu " /proc/stat)
        local idle1 total1 idle2 total2
        idle1=$(echo "$line1" | awk '{print $5}')
        total1=$(echo "$line1" | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')
        idle2=$(echo "$line2" | awk '{print $5}')
        total2=$(echo "$line2" | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')
        local diff_idle=$(( idle2 - idle1 ))
        local diff_total=$(( total2 - total1 ))
        if (( diff_total == 0 )); then
            echo "0"
        else
            echo "$(( 100 * (diff_total - diff_idle) / diff_total ))"
        fi
        return 0
    fi
    log_warning "get_cpu_usage: CPU usage information not available"
    return 1
}

# Get memory usage summary
# Usage: get_memory_usage
get_memory_usage() {
    if [[ -f /proc/meminfo ]]; then
        local total_kb available_kb used_kb percent
        total_kb=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
        available_kb=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}')
        if [[ -z "$available_kb" ]]; then
            local free_kb buffers_kb cached_kb
            free_kb=$(grep "MemFree:" /proc/meminfo | awk '{print $2}')
            buffers_kb=$(grep "Buffers:" /proc/meminfo | awk '{print $2}')
            cached_kb=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
            available_kb=$(( free_kb + buffers_kb + cached_kb ))
        fi
        used_kb=$(( total_kb - available_kb ))
        percent=$(( used_kb * 100 / total_kb ))
        echo "${percent}% ($(( used_kb / 1024 )) MB / $(( total_kb / 1024 )) MB)"
        return 0
    fi
    log_warning "get_memory_usage: memory information not available"
    return 1
}

# Get disk usage percentage for a path
# Usage: get_disk_usage [path]
# Arguments:
#   $1 - filesystem path to check (default: /)
# Returns: disk usage percentage via stdout
get_disk_usage() {
    local path="${1:-/}"
    if [[ ! -e "$path" ]]; then
        log_error "get_disk_usage: path not found: $path"
        return 1
    fi
    if command_exists df; then
        local percent
        percent=$(df "$path" 2>/dev/null | tail -n1 | awk '{print $5}' | tr -d '%')
        if [[ -z "$percent" ]]; then
            log_error "get_disk_usage: failed to read disk usage for $path"
            return 1
        fi
        echo "${percent}%"
        return 0
    fi
    log_error "get_disk_usage: df not available"
    return 1
}

# Get system load averages (1, 5, 15 min)
# Usage: get_system_load
get_system_load() {
    if [[ -f /proc/loadavg ]]; then
        local load1 load5 load15
        read -r load1 load5 load15 _ < /proc/loadavg
        echo "$load1 $load5 $load15"
        return 0
    elif command_exists uptime; then
        uptime | grep -oE 'load average[s]?: [0-9., ]+' | sed 's/load average[s]*: //'
        return 0
    fi
    log_warning "get_system_load: load average not available"
    return 1
}

# Get system uptime
# Usage: get_uptime
get_uptime() {
    if [[ -f /proc/uptime ]]; then
        local uptime_seconds days hours minutes
        uptime_seconds=$(cut -d. -f1 /proc/uptime)
        days=$(( uptime_seconds / 86400 ))
        hours=$(( (uptime_seconds % 86400) / 3600 ))
        minutes=$(( (uptime_seconds % 3600) / 60 ))
        echo "${days}d ${hours}h ${minutes}m"
        return 0
    elif command_exists uptime; then
        uptime
        return 0
    fi
    log_warning "get_uptime: uptime information not available"
    return 1
}

# ------------------------------------------------------------------
# PROCESS MANAGEMENT
# ------------------------------------------------------------------

# Get detailed information about a process by PID
# Usage: get_process_info <pid>
get_process_info() {
    local pid="${1:-}"
    if [[ -z "$pid" ]]; then
        log_error "get_process_info: PID argument required"
        return 1
    fi
    # Verify the process exists
    if ! kill -0 "$pid" 2>/dev/null && [[ ! -d "/proc/$pid" ]]; then
        log_error "get_process_info: process $pid not found"
        return 1
    fi
    if command_exists ps; then
        # Try Linux-style ps with format options first
        local output
        output=$(ps -p "$pid" -o pid,ppid,user,pcpu,pmem,stat,cmd 2>/dev/null)
        if [[ -n "$output" ]]; then
            echo "$output"
            return 0
        fi
        # Fallback: plain ps -p (minimal environments)
        output=$(ps -p "$pid" 2>/dev/null)
        if [[ -n "$output" ]]; then
            echo "$output"
            return 0
        fi
    fi
    # Fallback: /proc filesystem (Linux/WSL/Git Bash)
    if [[ -d "/proc/$pid" ]]; then
        echo "PID: $pid"
        if [[ -f "/proc/$pid/status" ]]; then
            grep -E "^(Name|State|Pid|PPid|VmRSS|VmSize):" "/proc/$pid/status" 2>/dev/null
        fi
        return 0
    fi
    log_error "get_process_info: ps not available"
    return 1
}

# Kill a process and all its children recursively
# Usage: kill_process_tree <pid> [signal]
kill_process_tree() {
    local pid="${1:-}"
    local signal="${2:-TERM}"
    if [[ -z "$pid" ]]; then
        log_error "kill_process_tree: PID argument required"
        return 1
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
        log_error "kill_process_tree: process $pid not found or no permission"
        return 1
    fi
    # Kill children first
    local children
    children=$(ps -o pid= --ppid "$pid" 2>/dev/null || true)
    for child in $children; do
        kill_process_tree "$child" "$signal" 2>/dev/null || true
    done
    kill -"$signal" "$pid" 2>/dev/null || {
        log_error "kill_process_tree: failed to send signal $signal to process $pid"
        return 1
    }
}

# Get top processes by CPU usage
# Usage: get_top_processes [count]
# Arguments:
#   $1 - number of processes to show (default: 10, must be a positive integer)
get_top_processes() {
    local count="${1:-10}"
    if [[ ! "$count" =~ ^[0-9]+$ ]]; then
        log_error "get_top_processes: invalid count '$count' (must be a positive integer)"
        return 1
    fi
    if command_exists ps; then
        local output
        # Try Linux-style with sort (procps-ng)
        output=$(ps aux --sort=-pcpu 2>/dev/null | head -n $(( count + 1 )))
        if [[ -n "$output" ]]; then
            echo "$output"
            return 0
        fi
        # Fallback: ps aux without sort
        output=$(ps aux 2>/dev/null | head -n $(( count + 1 )))
        if [[ -n "$output" ]]; then
            echo "$output"
            return 0
        fi
        # Fallback: plain ps (works in Git Bash / minimal envs)
        output=$(ps 2>/dev/null | head -n $(( count + 1 )))
        if [[ -n "$output" ]]; then
            echo "$output"
            return 0
        fi
    fi
    log_warning "get_top_processes: ps not available"
    return 1
}

# ------------------------------------------------------------------
# SERVICE MANAGEMENT
# ------------------------------------------------------------------

# Start a system service
# Usage: start_service <service_name>
start_service() {
    local service="${1:-}"
    if [[ -z "$service" ]]; then
        log_error "start_service: service name required"
        return 1
    fi
    if command_exists systemctl; then
        systemctl start "$service" 2>/dev/null; return $?
    elif command_exists service; then
        service "$service" start 2>/dev/null; return $?
    fi
    log_error "start_service: no service manager available"
    return 1
}

# Stop a system service
# Usage: stop_service <service_name>
stop_service() {
    local service="${1:-}"
    if [[ -z "$service" ]]; then
        log_error "stop_service: service name required"
        return 1
    fi
    if command_exists systemctl; then
        systemctl stop "$service" 2>/dev/null; return $?
    elif command_exists service; then
        service "$service" stop 2>/dev/null; return $?
    fi
    log_error "stop_service: no service manager available"
    return 1
}

# Restart a system service
# Usage: restart_service <service_name>
restart_service() {
    local service="${1:-}"
    if [[ -z "$service" ]]; then
        log_error "restart_service: service name required"
        return 1
    fi
    if command_exists systemctl; then
        systemctl restart "$service" 2>/dev/null; return $?
    elif command_exists service; then
        service "$service" restart 2>/dev/null; return $?
    fi
    log_error "restart_service: no service manager available"
    return 1
}

# Get the status of a system service
# Usage: get_service_status <service_name>
get_service_status() {
    local service="${1:-}"
    if [[ -z "$service" ]]; then
        log_error "get_service_status: service name required"
        return 1
    fi
    if command_exists systemctl; then
        systemctl status "$service" 2>/dev/null || return 1
        return 0
    elif command_exists service; then
        service "$service" status 2>/dev/null || return 1
        return 0
    fi
    log_error "get_service_status: no service manager available"
    return 1
}

# ------------------------------------------------------------------
# RESOURCE LIMITS
# ------------------------------------------------------------------

# Check system resource limits
# Usage: check_resource_limits
check_resource_limits() {
    echo "=== System Resource Limits ==="
    echo "Open files limit:    $(ulimit -n 2>/dev/null || echo 'N/A')"
    echo "Max processes limit: $(ulimit -u 2>/dev/null || echo 'N/A')"
    echo "Stack size limit:    $(ulimit -s 2>/dev/null || echo 'N/A') KB"
    echo "Max memory lock:     $(ulimit -l 2>/dev/null || echo 'N/A') KB"
    if [[ -f /proc/sys/fs/file-max ]]; then
        echo "Kernel file-max limit: $(cat /proc/sys/fs/file-max)"
    fi
    if [[ -f /proc/sys/kernel/pid_max ]]; then
        echo "Kernel PID max limit:  $(cat /proc/sys/kernel/pid_max)"
    fi
    return 0
}

# Export system detection functions
export -f get_os_name get_os_version auto_detect_system \
          _sysctl_slugify _dmi_read get_system_fingerprint list_sysctl_profiles auto_detect_sysctl_profile \
          get_cpu_info get_memory_info get_disk_info get_load_info get_uptime_info get_process_count get_temperature_info \
          get_top_processes_cpu get_top_processes_memory kill_processes_by_name \
          get_system_info get_architecture \
          get_cpu_usage get_memory_usage get_disk_usage get_system_load get_uptime \
          get_process_info kill_process_tree get_top_processes \
          start_service stop_service restart_service get_service_status \
          check_system_health monitor_system needs_reboot get_logged_users check_package_updates \
          get_environment_info detect_virtualization get_kernel_info check_resource_limits