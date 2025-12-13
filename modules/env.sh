#!/usr/bin/env bash
#=====================================================================
#  env.sh – Environment variable helper utilities
#=====================================================================
#  Why?
#  ----
#  Every serious automation script deals with environment variables.
#  This module reduces boilerplate and unexplained failures by
#  providing a small set of convenience functions for reading,
#  validating, exporting and managing environment variables.
#
#  Functions provided:
#   * env_require   VAR               – abort if $VAR is unset/empty
#   * env_default   VAR VALUE         – set $VAR to VALUE when empty
#   * env_bool      VAR               – normalise boolean strings
#   * env_from_file FILE              – safely load a .env‑style file
#=====================================================================

# Guard against multiple sourcing
if [[ "${BASH_UTILS_ENV_LOADED:-}" == "true" ]]; then
    return
fi
# Mark the module as loaded – readonly to prevent accidental changes
readonly BASH_UTILS_ENV_LOADED="true"

# ----------------------------------------------------------------------
# Helper: trim leading and trailing whitespace (used internally)
# ----------------------------------------------------------------------
_env_ltrim()  { local s="${1#"${1%%[![:space:]]*}"}"; printf '%s' "$s"; }
_env_rtrim()  { local s="${1%"${1##*[![:space:]]}"}"; printf '%s' "$s"; }
_env_trim()   { _env_rtrim "$(_env_ltrim "$1")"; }

#---------------------------------------------------------------------
# env_require – abort script if a required variable is missing
#---------------------------------------------------------------------
#   $1 – name of the variable (e.g. "HOME")
#   Returns:
#     0 – variable is set and non‑empty
#     1 – variable is unset or empty (logs an error)
#---------------------------------------------------------------------
env_require() {
    local var_name=$1
    # shellcheck disable=SC2154   # we intentionally use indirect expansion
    if [[ -z "${!var_name:-}" ]]; then
        log_error "Required environment variable '$var_name' is not set"
        return 1
    fi
    return 0
}

#---------------------------------------------------------------------
# env_default – set a default value when a variable is empty or unset
#---------------------------------------------------------------------
#   $1 – variable name
#   $2 – default value to assign
#   Returns 0 always; the variable is exported if a default is applied.
#---------------------------------------------------------------------
env_default() {
    local var_name=$1
    local default_value=$2
    # shellcheck disable=SC2154
    if [[ -z "${!var_name:-}" ]]; then
        export "$var_name=$default_value"
        log_debug "Set default for '$var_name' => '$default_value'"
    fi
    return 0
}

#---------------------------------------------------------------------
# env_bool – normalise common boolean representations
#---------------------------------------------------------------------
#   $1 – variable name
#   Accepts: true/false, yes/no, 1/0 (case‑insensitive)
#   Returns:
#     0 – variable was normalised (value will be 'true' or 'false')
#     1 – value is not recognisable as a boolean (logs an error)
#---------------------------------------------------------------------
env_bool() {
    local var_name=$1
    local value="${!var_name:-}"
    local lc_value=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
    case "$lc_value" in
        true|yes|1)  
            printf 'true'
            ;;
        false|no|0)
            printf 'false'
            ;;
        *)  
            log_error "Invalid boolean value for '$var_name': '$value'"
            return 1
            ;;
    esac
    return 0
}

#---------------------------------------------------------------------
# env.sh – simple .env‑file loader
#---------------------------------------------------------------------
# The function reads a file that contains lines of the form
#   VAR=value
# Blank lines and lines that start with ‘#’ are ignored.
# If a line does not contain exactly one ‘=’ the function aborts,
# prints a helpful error message and returns 1.
# The function returns 0 on success.
#---------------------------------------------------------------------

env_from_file() {
    local env_file="$1"

    # -----------------------------------------------------------------
    # 1️⃣  file must exist and be readable
    # -----------------------------------------------------------------
    if [[ ! -f "$env_file" ]]; then
        echo "Environment file not found: $env_file" >&2
        return 1
    fi

    # -----------------------------------------------------------------
    # 2️⃣  read the file line‑by‑line
    # -----------------------------------------------------------------
    while IFS= read -r line || [[ -n $line ]]; do
        # Strip leading and trailing whitespace (spaces or tabs)
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # -----------------------------------------------------------------
        # 3️⃣  ignore blanks and comments
        # -----------------------------------------------------------------
        [[ -z $line || $line == \#* ]] && continue

        # -----------------------------------------------------------------
        # 4️⃣  verify the line has exactly one ‘=’
        # -----------------------------------------------------------------
        if [[ $line =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local var_value="${BASH_REMATCH[2]}"
            # Export the variable so that the caller (the BATS test) can see it
            export "$var_name=$var_value"
        else
            echo "Invalid line in env file: $line" >&2
            return 1
        fi
    done < "$env_file"

    return 0
}

# Export all file operation functions for use in other scripts
export -f env_require env_default env_bool env_from_file
