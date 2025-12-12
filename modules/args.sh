#!/usr/bin/env bash
# =============================================================================
# Argument handling utilities for bash‑utils
# =============================================================================
# The module follows the same pattern as the other modules:
#   * it can be sourced many times without side‑effects
#   * it sets a BASH_UTILS_ARGS_LOADED flag when first loaded
# =============================================================================

# -------------------------------------------------------------------------
# Guard against multiple sourcing
# -------------------------------------------------------------------------
if [[ -n ${BASH_UTILS_ARGS_LOADED-} ]]; then
    return
fi
readonly BASH_UTILS_ARGS_LOADED=true

# -------------------------------------------------------------------------
# Internal storage
# -------------------------------------------------------------------------
# associative arrays for flags and values
declare -gA _args_flags      # e.g. _args_flags[force]=true
declare -gA _args_values    # e.g. _args_values[output]=outfile.txt
declare -ga _args_positionals   # positional arguments (no leading dashes)

# arrays that describe which options are *flags* (no value) and which expect a
# value.  The public helpers `args_set_flags` and `args_set_values` fill them.
declare -ga _args_known_flags
declare -ga _args_known_values

# usage string – set with `args_set_usage` and printed by `args_usage`
declare -g _args_usage=""

# -------------------------------------------------------------------------
# Public helpers – declaration order is not important, they are all exported
# -------------------------------------------------------------------------

# args_set_flags <flag> …
#   Register a list of options that act as simple boolean flags.
args_set_flags() {
    _args_known_flags=()
    for flag in "$@"; do
        # Normalise: strip leading dashes, replace - with _
        local name="${flag##--}"
        name="${name//-/_}"
        _args_known_flags+=("$name")
    done
}

# args_set_values <option> …
#   Register a list of options that expect a value (e.g. --output <file>).
args_set_values() {
    _args_known_values=()
    for opt in "$@"; do
        local name="${opt##--}"
        name="${name//-/_}"
        _args_known_values+=("$name")
    done
}

# args_set_usage <string>
#   Store a usage/help string that can later be displayed with `args_usage`.
args_set_usage() {
    _args_usage=$1
}

# args_usage
#   Echo the usage string that was stored with `args_set_usage`.
args_usage() {
    printf '%s\n' "$_args_usage"
}

# -------------------------------------------------------------------------
# args_parse <argv…>
#   Walk through the supplied arguments and fill the internal tables.
# -------------------------------------------------------------------------
args_parse() {
    # Reset any previous state
    _args_flags=()
    _args_values=()
    _args_positionals=()
    local i=0
    while (( i < $# )); do
        local arg="${!i}"
        # -------------------------------------------------------------
        # 1. Long option with an attached value:  --opt=val
        # -------------------------------------------------------------
        if [[ $arg == --*=* ]]; then
            local name="${arg%%=*}"
            local value="${arg#*=}"
            name="${name##--}"
            name="${name//-/_}"
            _args_values["$name"]="$value"
            ((i++))
            continue
        fi

        # -------------------------------------------------------------
        # 2. Known flag (no value)  e.g.  --force
        # -------------------------------------------------------------
        if [[ $arg == --* ]]; then
            local name="${arg##--}"
            name="${name//-/_}"
            # is it a registered flag?
            if [[ " ${_args_known_flags[*]} " == *" $name "* ]]; then
                _args_flags["$name"]=true
                ((i++))
                continue
            fi

            # is it a registered value‑option? then the next token is its value
            if [[ " ${_args_known_values[*]} " == *" $name "* ]]; then
                local next_index=$((i + 1))
                if (( next_index < $# )); then
                    local next="${!next_index}"
                    _args_values["$name"]="$next"
                    i=$((i + 2))
                    continue
                fi
            fi
        fi

        # -------------------------------------------------------------
        # 3. Anything else is a positional argument
        # -------------------------------------------------------------
        _args_positionals+=("$arg")
        ((i++))
    done
    return 0
}

# -------------------------------------------------------------------------
# Retrieval helpers
# -------------------------------------------------------------------------

# args_get_flag <flag> [fallback]
#   Return 0/1 status indicating whether the flag is set.
#   If the flag is not set, try the environment variable of the same name.
#   The optional fallback value is returned as the function’s output.
args_get_flag() {
    local flag="${1##--}"
    flag="${flag//-/_}"
    local fallback="${2-}"

    if [[ -n ${_args_flags[$flag]+_} ]]; then
        printf '%s\n' "${fallback:-true}"
        return 0
    fi

    # fall back to an environment variable with the same (upper‑cased) name
    local env_name="${flag^^}"
    if [[ -n ${!env_name-} ]]; then
        printf '%s\n' "${!env_name}"
        return 0
    fi

    return 1
}

# args_get_value <option> [default]
#   Return the value for an option if it was supplied on the command line,
#   otherwise return the caller‑supplied default (or the empty string).
args_get_value() {
    local opt="${1##--}"
    opt="${opt//-/_}"
    local default="${2-}"

    if [[ -n ${_args_values[$opt]+_} ]]; then
        printf '%s\n' "${_args_values[$opt]}"
        return 0
    fi

    # try an environment variable with the same name (upper‑cased)
    local env_name="${opt^^}"
    if [[ -n ${!env_name-} ]]; then
        printf '%s\n' "${!env_name}"
        return 0
    fi

    printf '%s\n' "$default"
    return 0
}

# args_get_positional <index>
#   Retrieve the N‑th positional argument (0‑based).  Returns 1 if out of range.
args_get_positional() {
    local idx=$1
    if (( idx < ${#_args_positionals[@]} )); then
        printf '%s\n' "${_args_positionals[$idx]}"
        return 0
    fi
    return 1
}

# -------------------------------------------------------------------------
# End of module – export the public symbols
# -------------------------------------------------------------------------
export -f args_set_flags args_set_values args_set_usage args_usage \
            args_parse args_get_flag args_get_value args_get_positional