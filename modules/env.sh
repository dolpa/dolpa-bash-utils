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
if [[ -n ${BASH_UTILS_ENV_LOADED:-} ]]; then
    return
fi

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
    local lc_value="${value,,}"   # lower‑case

    case "$lc_value" in
        true|yes|1)
            export "$var_name=true"
            ;;
        false|no|0)
            export "$var_name=false"
            ;;
        *)
            log_error "Invalid boolean value for '$var_name': '$value'"
            return 1
            ;;
    esac
    return 0
}

#---------------------------------------------------------------------
# env_from_file – safely source an env‑style file
#---------------------------------------------------------------------
#   $1 – path to a file containing lines VAR=VALUE
#   Empty lines and comments (starting with '#') are ignored.
#   Only assignments that match a safe pattern are exported.
#   Returns 0 on success, 1 on error (file missing or bad line).
#---------------------------------------------------------------------
env_from_file() {
    local env_file=$1

    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        return 1
    fi

    while IFS= read -r line || [[ -n $line ]]; do
        # Trim leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Skip blanks and comments
        [[ -z $line || $line == \#* ]] && continue

        # Accept only VAR=VALUE where VAR is a valid identifier
        if [[ $line =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            # Export using builtin to avoid eval injection
            export "$line"
        else
            log_error "Invalid line in env file '$env_file': $line"
            return 1
        fi
    done < "$env_file"

    return 0
}

# Mark the module as loaded – readonly to prevent accidental changes
readonly BASH_UTILS_ENV_LOADED="true"