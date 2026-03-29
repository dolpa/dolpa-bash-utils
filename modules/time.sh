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

# ------------------------------------------------------------------
# TIMEZONE AND LOCALE TIME FUNCTIONS
# ------------------------------------------------------------------

# Convert time between timezones
# Usage: converted=$(time_convert_timezone "2023-12-25 10:00:00" "UTC" "America/New_York")
# Arguments:
#   $1 - datetime string (YYYY-MM-DD HH:MM:SS format)
#   $2 - source timezone (default: local)
#   $3 - target timezone (default: UTC)
# Returns: converted datetime string via stdout
time_convert_timezone() {
    local datetime="$1"
    local source_tz="${2:-local}"
    local target_tz="${3:-UTC}"
    
    if [[ -z "$datetime" ]]; then
        log_error "time_convert_timezone: missing datetime argument"
        return 1
    fi
    
    if command_exists date; then
        # Set source timezone and convert
        if [[ "$source_tz" == "local" ]]; then
            TZ="$target_tz" date -d "$datetime" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || \
            TZ="$target_tz" date -j -f "%Y-%m-%d %H:%M:%S" "$datetime" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null
        else
            TZ="$target_tz" date -d "TZ=\"$source_tz\" $datetime" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || \
            log_error "time_convert_timezone: timezone conversion failed"
        fi
    else
        log_error "time_convert_timezone: date command not available"
        return 1
    fi
}

# Get current time in different timezones
# Usage: world_time=$(time_get_world_clock)
# Returns: current time in major timezones via stdout
time_get_world_clock() {
    local timezones=(
        "UTC:UTC"
        "EST:America/New_York"
        "PST:America/Los_Angeles" 
        "GMT:Europe/London"
        "CET:Europe/Paris"
        "JST:Asia/Tokyo"
        "AEST:Australia/Sydney"
    )
    
    echo "=== WORLD CLOCK ==="
    
    local tz_pair tz_name tz_ID
    for tz_pair in "${timezones[@]}"; do
        tz_name="${tz_pair%:*}"
        tz_ID="${tz_pair#*:}"
        
        if command_exists date; then
            local current_time
            current_time=$(TZ="$tz_ID" date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null)
            if [[ -n "$current_time" ]]; then
                printf "%-4s: %s\n" "$tz_name" "$current_time"
            fi
        fi
    done
}

# List available timezones (if available)
# Usage: timezones=$(time_list_timezones)
# Returns: available timezone identifiers via stdout
time_list_timezones() {
    if [[ -d /usr/share/zoneinfo ]]; then
        find /usr/share/zoneinfo -type f | grep -E '/[A-Z]' | sed 's|/usr/share/zoneinfo/||' | head -20
    elif command_exists timedatectl; then
        timedatectl list-timezones | head -20
    else
        log_warning "time_list_timezones: timezone information not available"
        return 1
    fi
}

# ------------------------------------------------------------------
# DATE ARITHMETIC AND MANIPULATION
# ------------------------------------------------------------------

# Add/subtract days to/from an epoch timestamp
# Usage: new_epoch=$(time_add_days 1672531200 5)
# Arguments:
#   $1 - epoch timestamp
#   $2 - number of days to add (negative to subtract)
# Returns: new epoch timestamp via stdout
time_add_days() {
    local epoch="$1"
    local days="$2"

    if [[ -z "$epoch" || -z "$days" ]]; then
        log_error "time_add_days: usage: time_add_days <epoch> <days>"
        return 1
    fi

    if [[ ! "$epoch" =~ ^-?[0-9]+$ || ! "$days" =~ ^-?[0-9]+$ ]]; then
        log_error "time_add_days: epoch and days must be integers"
        return 1
    fi

    printf "%s\n" "$(( epoch + days * 86400 ))"
}

# Add/subtract hours to/from an epoch timestamp
# Usage: new_epoch=$(time_add_hours 1672531200 3)
# Arguments:
#   $1 - epoch timestamp
#   $2 - number of hours to add (negative to subtract)
# Returns: new epoch timestamp via stdout
time_add_hours() {
    local epoch="$1"
    local hours="$2"

    if [[ -z "$epoch" || -z "$hours" ]]; then
        log_error "time_add_hours: usage: time_add_hours <epoch> <hours>"
        return 1
    fi

    if [[ ! "$epoch" =~ ^-?[0-9]+$ || ! "$hours" =~ ^-?[0-9]+$ ]]; then
        log_error "time_add_hours: epoch and hours must be integers"
        return 1
    fi

    printf "%s\n" "$(( epoch + hours * 3600 ))"
}

# Add/subtract minutes to/from an epoch timestamp
# Usage: new_epoch=$(time_add_minutes 1672531200 30)
# Arguments:
#   $1 - epoch timestamp
#   $2 - number of minutes to add (negative to subtract)
# Returns: new epoch timestamp via stdout
time_add_minutes() {
    local epoch="$1"
    local minutes="$2"

    if [[ -z "$epoch" || -z "$minutes" ]]; then
        log_error "time_add_minutes: usage: time_add_minutes <epoch> <minutes>"
        return 1
    fi

    if [[ ! "$epoch" =~ ^-?[0-9]+$ || ! "$minutes" =~ ^-?[0-9]+$ ]]; then
        log_error "time_add_minutes: epoch and minutes must be integers"
        return 1
    fi

    printf "%s\n" "$(( epoch + minutes * 60 ))"
}

# Add/subtract weeks to/from an epoch timestamp
# Usage: new_epoch=$(time_add_weeks 1672531200 2)
# Arguments:
#   $1 - epoch timestamp
#   $2 - number of weeks to add (negative to subtract)
# Returns: new epoch timestamp via stdout
time_add_weeks() {
    local epoch="$1"
    local weeks="$2"

    if [[ -z "$epoch" || -z "$weeks" ]]; then
        log_error "time_add_weeks: usage: time_add_weeks <epoch> <weeks>"
        return 1
    fi

    time_add_days "$epoch" $(( weeks * 7 ))
}

# Add/subtract months to/from a date
# Usage: new_date=$(time_add_months "2023-12-25" 3)
# Arguments:
#   $1 - date string (YYYY-MM-DD format)
#   $2 - number of months to add (negative to subtract)  
# Returns: new date string via stdout
time_add_months() {
    local date_str="$1"
    local months="$2"
    
    if [[ -z "$date_str" || -z "$months" ]]; then
        log_error "time_add_months: usage: time_add_months <date> <months>"
        return 1
    fi
    
    if command_exists date; then
        # Try different date command variants
        if date -d "$date_str + $months months" '+%Y-%m-%d' 2>/dev/null; then
            return 0
        elif date -j -v+"${months}m" -f "%Y-%m-%d" "$date_str" '+%Y-%m-%d' 2>/dev/null; then
            return 0
        else
            log_error "time_add_months: date arithmetic failed"
            return 1
        fi
    else
        log_error "time_add_months: date command not available"
        return 1
    fi
}

# Get day of week for a date
# Usage: dow=$(time_get_day_of_week "2023-12-25")
# Arguments:
#   $1 - date string (YYYY-MM-DD format)
# Returns: day of week (Monday, Tuesday, etc.) via stdout
time_get_day_of_week() {
    local date_str="$1"
    
    if [[ -z "$date_str" ]]; then
        log_error "time_get_day_of_week: missing date argument"
        return 1
    fi
    
    if command_exists date; then
        date -d "$date_str" '+%A' 2>/dev/null || \
        date -j -f "%Y-%m-%d" "$date_str" '+%A' 2>/dev/null || \
        log_error "time_get_day_of_week: failed to parse date"
    else
        log_error "time_get_day_of_week: date command not available"
        return 1
    fi
}

# Get week number for a date
# Usage: week=$(time_get_week_number "2023-12-25")
# Arguments:
#   $1 - date string (YYYY-MM-DD format)
# Returns: ISO week number via stdout
time_get_week_number() {
    local date_str="$1"
    
    if [[ -z "$date_str" ]]; then
        log_error "time_get_week_number: missing date argument"
        return 1
    fi
    
    if command_exists date; then
        date -d "$date_str" '+%V' 2>/dev/null || \
        date -j -f "%Y-%m-%d" "$date_str" '+%V' 2>/dev/null || \
        log_error "time_get_week_number: failed to parse date"
    else
        log_error "time_get_week_number: date command not available"
        return 1
    fi
}

# Calculate difference between two dates in days
# Usage: diff_days=$(time_diff_days "2023-12-25" "2023-12-31")
# Arguments:
#   $1 - start date (YYYY-MM-DD format)
#   $2 - end date (YYYY-MM-DD format)
# Returns: difference in days via stdout
time_diff_days() {
    local start_date="$1"
    local end_date="$2"
    
    if [[ -z "$start_date" || -z "$end_date" ]]; then
        log_error "time_diff_days: usage: time_diff_days <start_date> <end_date>"
        return 1
    fi
    
    local start_epoch end_epoch
    start_epoch=$(time_parse_iso8601 "${start_date}T00:00:00Z")
    end_epoch=$(time_parse_iso8601 "${end_date}T00:00:00Z")
    
    if [[ -n "$start_epoch" && -n "$end_epoch" ]]; then
        echo $(((end_epoch - start_epoch) / 86400))
    else
        log_error "time_diff_days: failed to parse dates"
        return 1
    fi
}

# ----------------------------------------------------------------------
# SCHEDULING AND CRON UTILITIES
# ----------------------------------------------------------------------

# Check if a time matches a cron expression
# Usage: if time_matches_cron "0 9 * * 1-5" [epoch]; then ...; fi
# Arguments:
#   $1 - cron expression (minute hour day month weekday)
#   $2 - epoch timestamp to test against (default: current time)
# Returns: 0 if the time matches, 1 otherwise
time_matches_cron() {
    local cron_expr="$1"
    local check_epoch="${2:-}"

    if [[ -z "$cron_expr" ]]; then
        log_error "time_matches_cron: missing cron expression"
        return 1
    fi

    local -a fields
    IFS=' ' read -ra fields <<< "$cron_expr"

    if [[ ${#fields[@]} -ne 5 ]]; then
        log_error "time_matches_cron: invalid cron expression format"
        return 1
    fi

    # Single date call to extract all 5 fields efficiently
    local time_str
    if [[ -n "$check_epoch" ]]; then
        if _time_is_gnu_date; then
            time_str=$(date -u -d "@${check_epoch}" '+%M %H %d %m %u')
        else
            time_str=$(date -u -r "${check_epoch}" '+%M %H %d %m %u')
        fi
    else
        time_str=$(date -u '+%M %H %d %m %u')
    fi

    local -a tparts
    read -ra tparts <<< "$time_str"

    local current_minute=$(( 10#${tparts[0]} ))
    local current_hour=$(( 10#${tparts[1]} ))
    local current_day=$(( 10#${tparts[2]} ))
    local current_month=$(( 10#${tparts[3]} ))
    local current_weekday="${tparts[4]}"

    local minute="${fields[0]}" hour="${fields[1]}" day="${fields[2]}"
    local month="${fields[3]}" weekday="${fields[4]}"

    [[ "$minute"  == "*" ]] || [[ "$minute"  == "$current_minute"  ]] || return 1
    [[ "$hour"    == "*" ]] || [[ "$hour"    == "$current_hour"    ]] || return 1
    [[ "$day"     == "*" ]] || [[ "$day"     == "$current_day"     ]] || return 1
    [[ "$month"   == "*" ]] || [[ "$month"   == "$current_month"   ]] || return 1
    [[ "$weekday" == "*" ]] || [[ "$weekday" == "$current_weekday" ]] || return 1

    return 0
}

# Wait until specific time of day
# Usage: time_wait_until "14:30:00"
# Arguments:
#   $1 - time to wait until (HH:MM:SS format)
# Returns: 0 when target time reached, 1 on error
time_wait_until() {
    local target_time="$1"
    
    if [[ -z "$target_time" ]]; then
        log_error "time_wait_until: missing target time"
        return 1
    fi
    
    # Get target time in seconds since midnight
    local target_hour target_minute target_second
    IFS=':' read -r target_hour target_minute target_second <<< "$target_time"
    
    local target_seconds=$((target_hour * 3600 + target_minute * 60 + target_second))
    
    while true; do
        local current_hour current_minute current_second
        current_hour=$(date '+%H' | sed 's/^0//')
        current_minute=$(date '+%M' | sed 's/^0//')
        current_second=$(date '+%S' | sed 's/^0//')
        
        local current_seconds=$((current_hour * 3600 + current_minute * 60 + current_second))
        
        # If target time has passed, wait until tomorrow
        if [[ $target_seconds -le $current_seconds ]]; then
            target_seconds=$((target_seconds + 86400))  # Add 24 hours
        fi
        
        local wait_seconds=$((target_seconds - current_seconds))
        
        if [[ $wait_seconds -le 0 ]]; then
            log_success "Target time $target_time reached"
            return 0
        fi
        
        log_info "Waiting $(time_seconds_to_human $wait_seconds) until $target_time"
        sleep "$wait_seconds"
        return 0
    done
}

# ----------------------------------------------------------------------
# TIME FORMATTING AND PARSING
# ----------------------------------------------------------------------

# Format epoch time with custom format
# Usage: formatted=$(time_format_custom 1640419200 "%B %d, %Y at %I:%M %p")
# Arguments:
#   $1 - epoch timestamp
#   $2 - format string (same as date command)
# Returns: formatted time string via stdout
time_format_custom() {
    local epoch="$1"
    local format="$2"
    
    if [[ -z "$epoch" || -z "$format" ]]; then
        log_error "time_format_custom: usage: time_format_custom <epoch> <format>"
        return 1
    fi
    
    if command_exists date; then
        date -d "@$epoch" "$format" 2>/dev/null || \
        date -j -f "%s" "$epoch" "$format" 2>/dev/null || \
        log_error "time_format_custom: failed to format timestamp"
    else
        log_error "time_format_custom: date command not available"
        return 1
    fi
}

# Parse various date formats to epoch
# Usage: epoch=$(time_parse_flexible "Dec 25, 2023 3:30 PM")
# Arguments:
#   $1 - date string in various formats
# Returns: epoch timestamp via stdout
time_parse_flexible() {
    local date_str="$1"
    
    if [[ -z "$date_str" ]]; then
        log_error "time_parse_flexible: missing date string"
        return 1
    fi
    
    if command_exists date; then
        # Try to parse with date command
        date -d "$date_str" '+%s' 2>/dev/null || \
        date -j -f "%b %d, %Y %I:%M %p" "$date_str" '+%s' 2>/dev/null || \
        date -j "$date_str" '+%s' 2>/dev/null || \
        log_error "time_parse_flexible: failed to parse date string"
    else
        log_error "time_parse_flexible: date command not available"
        return 1
    fi
}

# Get relative time description ("2 hours ago", "in 3 days")
# Usage: relative=$(time_get_relative 1640419200)
# Arguments:
#   $1 - epoch timestamp to compare to current time
# Returns: relative time description via stdout
time_get_relative() {
    local target_epoch="$1"
    
    if [[ -z "$target_epoch" ]]; then
        log_error "time_get_relative: missing epoch timestamp"
        return 1
    fi
    
    local current_epoch
    current_epoch=$(time_epoch)
    local diff=$((target_epoch - current_epoch))
    local abs_diff=$((diff < 0 ? -diff : diff))
    
    local time_ago=""
    if [[ $diff -lt 0 ]]; then
        time_ago=" ago"
    elif [[ $diff -gt 0 ]]; then
        time_ago="in "
    else
        echo "now"
        return 0
    fi
    
    if [[ $abs_diff -lt 60 ]]; then
        echo "${time_ago}${abs_diff} second$([ $abs_diff -ne 1 ] && echo s)"
    elif [[ $abs_diff -lt 3600 ]]; then
        local minutes=$((abs_diff / 60))
        echo "${time_ago}${minutes} minute$([ $minutes -ne 1 ] && echo s)"
    elif [[ $abs_diff -lt 86400 ]]; then
        local hours=$((abs_diff / 3600))
        echo "${time_ago}${hours} hour$([ $hours -ne 1 ] && echo s)"
    elif [[ $abs_diff -lt 2592000 ]]; then  # 30 days
        local days=$((abs_diff / 86400))
        echo "${time_ago}${days} day$([ $days -ne 1 ] && echo s)"
    elif [[ $abs_diff -lt 31536000 ]]; then  # 365 days
        local months=$((abs_diff / 2592000))
        echo "${time_ago}${months} month$([ $months -ne 1 ] && echo s)"
    else
        local years=$((abs_diff / 31536000))
        echo "${time_ago}${years} year$([ $years -ne 1 ] && echo s)"
    fi
    
    # Fix output format
    if [[ $diff -gt 0 ]]; then
        echo "$time_ago$(echo "$time_ago" | sed 's/^in //')"
    fi
}

# Validate date string format
# Usage: if time_validate_date "2023-12-25"; then ...; fi  
# Arguments:
#   $1 - date string to validate
#   $2 - expected format (default: YYYY-MM-DD)
# Returns: 0 if valid, 1 if invalid
time_validate_date() {
    local date_str="$1"
    local format="${2:-YYYY-MM-DD}"
    
    if [[ -z "$date_str" ]]; then
        return 1
    fi
    
    case "$format" in
        "YYYY-MM-DD")
            [[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
            ;;
        "DD/MM/YYYY")
            [[ "$date_str" =~ ^[0-9]{2}/[0-9]{2}/[0-9]{4}$ ]]
            ;;
        "MM/DD/YYYY")
            [[ "$date_str" =~ ^[0-9]{2}/[0-9]{2}/[0-9]{4}$ ]]
            ;;
        *)
            log_error "time_validate_date: unsupported format '$format'"
            return 1
            ;;
    esac
}

# ----------------------------------------------------------------------
# TIMEZONE MANAGEMENT
# ----------------------------------------------------------------------

# Get the current system timezone identifier
# Usage: tz=$(time_get_timezone)
# Returns: timezone string via stdout
time_get_timezone() {
    if command_exists timedatectl; then
        local tz
        tz=$(timedatectl show --property=Timezone --value 2>/dev/null)
        if [[ -n "$tz" ]]; then echo "$tz"; return 0; fi
    fi
    if [[ -f /etc/timezone ]]; then
        cat /etc/timezone; return 0
    fi
    if [[ -L /etc/localtime ]]; then
        readlink /etc/localtime | sed 's|.*/zoneinfo/||'; return 0
    fi
    date +%Z
}

# Set the system timezone (requires root, validates against zoneinfo)
# Usage: time_set_timezone "America/New_York"
# Arguments:
#   $1 - timezone identifier
# Returns: 0 on success, 1 on failure
time_set_timezone() {
    local tz="$1"
    if [[ -z "$tz" ]]; then
        log_error "time_set_timezone: missing timezone argument"
        return 1
    fi
    if [[ ! -f "/usr/share/zoneinfo/$tz" ]]; then
        log_error "time_set_timezone: invalid timezone '$tz'"
        return 1
    fi
    if [[ $EUID -ne 0 ]]; then
        log_error "time_set_timezone: root privileges required"
        return 1
    fi
    if command_exists timedatectl; then
        timedatectl set-timezone "$tz"
    else
        ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime
    fi
}

# ------------------------------------------------------------------
# DURATION FORMATTING AND PARSING
# ------------------------------------------------------------------

# Format a number of seconds as a compact human-readable duration
# Usage: text=$(time_format_duration 3661)  # → "1h1m1s"
# Arguments:
#   $1 - duration in seconds (non-negative integer)
# Returns: human-readable string via stdout
time_format_duration() {
    local secs="$1"
    if [[ -z "$secs" || ! "$secs" =~ ^[0-9]+$ ]]; then
        log_error "time_format_duration: seconds must be a non-negative integer"
        return 1
    fi
    _time_seconds_to_human "$secs"
}

# Parse a human-readable duration string to total seconds
# Usage: secs=$(time_parse_duration "1h30m")  # → 5400
# Arguments:
#   $1 - duration string using d/h/m/s units (e.g. "1d2h30m", "90m", "2h")
# Returns: total seconds via stdout
time_parse_duration() {
    local duration="$1"
    if [[ -z "$duration" ]]; then
        log_error "time_parse_duration: missing duration string"
        return 1
    fi
    if [[ ! "$duration" =~ ^([0-9]+[dhms])+$ ]]; then
        log_error "time_parse_duration: invalid duration format '$duration'"
        return 1
    fi
    local total=0
    [[ "$duration" =~ ([0-9]+)d ]] && total=$(( total + ${BASH_REMATCH[1]} * 86400 ))
    [[ "$duration" =~ ([0-9]+)h ]] && total=$(( total + ${BASH_REMATCH[1]} * 3600 ))
    [[ "$duration" =~ ([0-9]+)m ]] && total=$(( total + ${BASH_REMATCH[1]} * 60 ))
    [[ "$duration" =~ ([0-9]+)s ]] && total=$(( total + ${BASH_REMATCH[1]} ))
    echo "$total"
}

# ------------------------------------------------------------------
# DATE VALIDATION AND EPOCH FORMATTING
# ------------------------------------------------------------------

# Validate that a YYYY-MM-DD date string is a real calendar date
# Usage: if time_is_valid_date "2024-02-29"; then ...; fi
# Returns: 0 if valid, 1 if invalid or non-existent date
time_is_valid_date() {
    local date_str="$1"
    if [[ -z "$date_str" || ! "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        return 1
    fi
    if _time_is_gnu_date; then
        date -d "$date_str" '+%Y-%m-%d' >/dev/null 2>&1
    else
        date -j -f "%Y-%m-%d" "$date_str" '+%Y-%m-%d' >/dev/null 2>&1
    fi
}

# Format an epoch timestamp using a strftime format string (UTC)
# Usage: date_str=$(time_format_date 1672531200 "%Y-%m-%d")
# Arguments:
#   $1 - epoch timestamp (integer)
#   $2 - strftime format string
# Returns: formatted date string via stdout
time_format_date() {
    local epoch="$1"
    local format="$2"
    if [[ -z "$epoch" || -z "$format" ]]; then
        log_error "time_format_date: usage: time_format_date <epoch> <format>"
        return 1
    fi
    if [[ ! "$epoch" =~ ^-?[0-9]+$ ]]; then
        log_error "time_format_date: epoch must be an integer"
        return 1
    fi
    _time_format_epoch "$epoch" "$format" "utc"
}

# ------------------------------------------------------------------
# WEEKDAY / WEEKEND HELPERS
# ------------------------------------------------------------------

# Return 0 if an epoch timestamp falls on a weekday (Mon-Fri)
# Usage: if time_is_weekday 1672617600; then ...; fi
# Arguments:
#   $1 - epoch timestamp (default: current time)
# Returns: 0 if weekday, 1 if weekend
time_is_weekday() {
    local epoch="${1:-}"
    local dow
    if [[ -n "$epoch" ]]; then
        if _time_is_gnu_date; then
            dow=$(date -u -d "@${epoch}" '+%u')
        else
            dow=$(date -u -r "${epoch}" '+%u')
        fi
    else
        dow=$(date '+%u')
    fi
    [[ "$dow" -ge 1 && "$dow" -le 5 ]]
}

# Return 0 if an epoch timestamp falls on a weekend (Sat-Sun)
# Usage: if time_is_weekend 1672531200; then ...; fi
# Arguments:
#   $1 - epoch timestamp (default: current time)
# Returns: 0 if weekend, 1 if weekday
time_is_weekend() {
    local epoch="${1:-}"
    local dow
    if [[ -n "$epoch" ]]; then
        if _time_is_gnu_date; then
            dow=$(date -u -d "@${epoch}" '+%u')
        else
            dow=$(date -u -r "${epoch}" '+%u')
        fi
    else
        dow=$(date '+%u')
    fi
    [[ "$dow" -ge 6 ]]
}

# ------------------------------------------------------------------
# NEXT CRON RUN
# ------------------------------------------------------------------

# Calculate the next epoch at which a cron expression will match
# Usage: next=$(time_next_cron_run "0 0 * * *")
# Arguments:
#   $1 - cron expression (5 fields: min hour day month weekday)
# Returns: future epoch timestamp via stdout
time_next_cron_run() {
    local cron_expr="$1"
    if [[ -z "$cron_expr" ]]; then
        log_error "time_next_cron_run: missing cron expression"
        return 1
    fi
    local -a fields
    IFS=' ' read -ra fields <<< "$cron_expr"
    if [[ ${#fields[@]} -ne 5 ]]; then
        log_error "time_next_cron_run: invalid cron expression"
        return 1
    fi
    local current_epoch
    current_epoch=$(time_epoch)
    local next=$(( (current_epoch / 60 + 1) * 60 ))
    local i
    for ((i=0; i<1440; i++)); do
        if time_matches_cron "$cron_expr" "$next"; then
            echo "$next"
            return 0
        fi
        next=$(( next + 60 ))
    done
    log_error "time_next_cron_run: no match found within 24 hours"
    return 1
}

export -f time_now time_now_iso8601_utc time_now_iso8601_local \
        time_epoch time_epoch_ms time_format_epoch time_epoch_to_iso8601 time_parse_iso8601 \
        time_add_seconds time_diff_seconds time_seconds_to_human time_benchmark sleep_until \
        time_epoch time_epoch_ms time_format_epoch time_epoch_to_iso8601 time_parse_iso8601 \
        time_add_seconds time_diff_seconds time_seconds_to_human time_benchmark sleep_until \
        time_convert_timezone time_get_world_clock time_list_timezones \
        time_add_days time_add_hours time_add_minutes time_add_weeks time_add_months \
        time_get_day_of_week time_get_week_number time_diff_days \
        time_matches_cron time_next_cron_run time_wait_until \
        time_format_custom time_parse_flexible time_get_relative time_validate_date \
        time_get_timezone time_set_timezone \
        time_format_duration time_parse_duration \
        time_is_valid_date time_format_date \
        time_is_weekday time_is_weekend