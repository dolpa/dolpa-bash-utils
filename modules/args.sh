#!/usr/bin/env bash
#===============================================================================
# args.sh – Light‑weight CLI argument & flag parser
#
# Provides:
#   args_parse "$@"               – parse the command line
#   args_get_flag --name          – true (0) if flag present, otherwise 1
#   args_get_value --opt [def]    – echo the value or the default
#   args_set_usage "text ..."      – set a usage string
#   args_usage                    – print the usage string
#
# Flags/values can also be supplied via environment variables.  The env name is
# derived from the long option name (e.g. --force → FORCE, --output-file → OUTPUT_FILE).
#===============================================================================

# ---------------------------------------------------------------------------
# Guard against double‑sourcing
# ---------------------------------------------------------------------------
if [[ -n "${BASH_UTILS_ARGS_LOADED:-}" ]]; then
    return
fi
readonly BASH_UTILS_ARGS_LOADED=true

# ---------------------------------------------------------------------------
# Load dependencies
# ---------------------------------------------------------------------------
source "${BASH_UTILS_ROOT:-$(dirname "${BASH_SOURCE[0]}")}/../modules/config.sh"
source "${BASH_UTILS_ROOT:-$(dirname "${BASH_SOURCE[0]}")}/../modules/logging.sh"
source "${BASH_UTILS_ROOT:-$(dirname "${BASH_SOURCE[0]}")}/../modules/env.sh"

# ---------------------------------------------------------------------------
# Global storage (associative arrays – Bash ≥4)
# ---------------------------------------------------------------------------
declare -gA ARGS_FLAGS   # flag → 1
declare -gA ARGS_VALUES  # option → value
declare -ga ARGS_POSITIONAL   # everything that is not an option

# ---------------------------------------------------------------------------
# args_set_usage  "text ..."
#   Store a usage string that can be printed later with args_usage.
# ---------------------------------------------------------------------------
args_set_usage() {
    BASH_UTILS_ARGS_USAGE="${*}"
}

# ---------------------------------------------------------------------------
# args_usage
#   Print a tiny usage message (script name + stored usage string).
# ---------------------------------------------------------------------------
args_usage() {
    local script
    script="$(basename "${0}")"
    log_header "Usage"
    printf "  %s %s\n" "$script" "${BASH_UTILS_ARGS_USAGE:-[options] [arguments]}"
    return 0
}

# ---------------------------------------------------------------------------
# args_parse "$@"
#   Populate ARGS_FLAGS, ARGS_VALUES and ARGS_POSITIONAL.
#   Supports:
#       --flag
#       --opt value   or   --opt=value
#       -abc          (short‑flag grouping)
# ---------------------------------------------------------------------------
args_parse() {
    # Reset previous data (so a script can call args_parse more than once)
    ARGS_FLAGS=()
    ARGS_VALUES=()
    ARGS_POSITIONAL=()

    while (( "$#" )); do
        case "$1" in
            --*=*)                                   # --opt=value
                local key="${1%%=*}"
                local val="${1#*=}"
                ARGS_VALUES["$key"]="$val"
                shift
                ;;

            --*)                                     # --flag   or   --opt value
                local key="$1"
                if [[ -n "$2" && "$2" != --* && "$2" != -* ]]; then
                    ARGS_VALUES["$key"]="$2"
                    shift 2
                else
                    ARGS_FLAGS["$key"]=1
                    shift
                fi
                ;;

            -?*)                                     # -a -b -c   or   -abc (grouped)
                local chars="${1:1}"
                local i
                for (( i=0; i<${#chars}; i++ )); do
                    ARGS_FLAGS["-${chars:i:1}"]=1
                done
                shift
                ;;

            *)                                       # Positional argument
                ARGS_POSITIONAL+=("$1")
                shift
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# args_get_flag  --name
#   Returns 0 if the flag is present on the command line **or** if the
#   corresponding environment variable is set (non‑empty).  Otherwise returns 1.
# ---------------------------------------------------------------------------
args_get_flag() {
    local flag="$1"

    # 1️⃣  Direct flag on the command line
    if [[ -n "${ARGS_FLAGS[$flag]}" ]]; then
        return 0
    fi

    # 2️⃣  Fallback to environment variable
    #   --force  →  FORCE
    #   --dry-run → DRY_RUN
    local env_name
    env_name="$(printf '%s' "$flag" |
                sed -e 's/^--//' -e 's/^-\{1\}//' -e 's/-/_/g' |
                tr '[:lower:]' '[:upper:]')"

    if [[ -n "${!env_name}" ]]; then
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# args_get_value  --opt [default]
#   Echoes the value of an option.  The lookup order is:
#       1️⃣  value supplied with args_parse
#       2️⃣  environment variable (same conversion as above)
#       3️⃣  optional default argument passed to the function
#   Returns 0 on success, 1 if no value could be found.
# ---------------------------------------------------------------------------
args_get_value() {
    local key="$1"
    local default="${2-}"

    if [[ -n "${ARGS_VALUES[$key]}" ]]; then
        printf '%s' "${ARGS_VALUES[$key]}"
        return 0
    fi

    # Environment fallback
    local env_name
    env_name="$(printf '%s' "$key" |
                sed -e 's/^--//' -e 's/^-\{1\}//' -e 's/-/_/g' |
                tr '[:lower:]' '[:upper:]')"

    if [[ -n "${!env_name}" ]]; then
        printf '%s' "${!env_name}"
        return 0
    fi

    # Default supplied by the caller
    if [[ -n "$default" ]]; then
        printf '%s' "$default"
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# args_get_flag  --name
#   Wrapper that returns 0/1 (no output) – useful inside conditionals.
# ---------------------------------------------------------------------------
args_get_flag() {
    local flag="$1"
    args_get_flag "$flag"
}

export -f args_parse args_get_flag args_get_value args_set_usage args_usage

