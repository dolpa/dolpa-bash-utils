#!/usr/bin/env bash
#====================================================================
# Bash Utility Library – Prompt & Input Module
#====================================================================
# Description: Helper functions for reading user input, passwords,
#              yes/no confirmations, and simple menus.
# Author:      dolpa (https://dolpa.me)
# Version:     main
# License:     Unlicense
# Dependencies: logging.sh (for coloured log output)
#====================================================================

# -----------------------------------------------------------------
#  Guard against double‑sourcing
# ----------------------------------------------------------------------
if [[ "${BASH_UTILS_PROMPTS_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_PROMPTS_LOADED="true"


# ----------------------------------------------------------------------
#  Basic text prompt
# ----------------------------------------------------------------------
# Prompt the user for a free‑form value.
#   $1 – prompt message
#   $2 – optional default value (used when the user just hits <Enter>)
# Writes only the answer to STDOUT; the prompt itself goes to STDERR.
# ----------------------------------------------------------------------
prompt_input() {
    local msg=$1
    local default=$2
    local answer

    # Prompt on STDERR so BATS doesn’t capture it.
    printf "%s " "$msg" >&2

    # Read a line from STDIN (the test feeds the line via a pipe).
    IFS= read -r answer

    # Trim leading/trailing whitespace (including newlines)
    answer="$(echo -n "$answer" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    default="$(echo -n "$default" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    if [[ -z $answer && -n $default ]]; then
        printf "%s\n" "$default"
    else
        printf "%s\n" "$answer"
    fi
}

# ----------------------------------------------------------------------
#  Password (silent) prompt
# ----------------------------------------------------------------------
# Prompt the user for a password (no echo).
#   $1 – prompt message
# Writes only the password to STDOUT; the prompt goes to STDERR.
# ----------------------------------------------------------------------
prompt_password() {
    local msg=$1
    local pwd

    # If input is from a terminal, disable echo
    if [ -t 0 ]; then
        printf "%s " "$msg" >&2
        IFS= read -s -r pwd
        printf "\n"
    else
        # Non-interactive input (like in tests) - just read normally
        IFS= read -r -p "$msg " pwd
    fi

    # Always print password to stdout
    printf "%s\n" "$pwd"
}


# ----------------------------------------------------------------------
#  Yes/No confirmation (wrapper around utils.sh `confirm`)
# ----------------------------------------------------------------------
# Prompt the user for a yes/no confirmation.
#   $1 – prompt message
#   $2 – optional default value (e.g. “y” or “n”)
# Returns 0 (true) for “yes”, 1 (false) for “no”.
# The prompt itself is sent to STDERR.
# ----------------------------------------------------------------------
prompt_confirm() {
    local msg=$1
    local default=$2
    local answer

    if [[ -n $default ]]; then
        printf "%s [%s]: " "$msg" "$default" >&2
    else
        printf "%s: " "$msg" >&2
    fi

    IFS= read -r answer

    # If the user just presses <Enter>, fall back to the default (if any).
    if [[ -z $answer && -n $default ]]; then
        answer=$default
    fi

    case "${answer,,}" in
        y|yes|true|1)  return 0 ;;
        n|no|false|0)  return 1 ;;
        *)             return 1 ;;   # Anything else is treated as “no”.
    esac
}

# ----------------------------------------------------------------------
#  Simple numbered menu
# ----------------------------------------------------------------------
# Show a simple numbered menu and return the selected option.
#   $1 – prompt text (optional, defaults to "Select an option")
#   $2… – list of options
# Returns:
#   * selected option on stdout, exit status 0
#   * empty string on EOF, exit status 1
# Re‑asks automatically when the user enters an invalid number.
prompt_menu() {
    local prompt="${1:-Select an option}"
    shift
    local options=("$@")
    local count=${#options[@]}

    # Guard against calling without any options
    if (( count == 0 )); then
        log_error "prompt_menu: no options supplied"
        return 1
    fi

    while true; do
        #  ----- show the menu (to stderr) ---------------------------------
        printf "%s:\n" "$prompt" >&2
        for i in "${!options[@]}"; do
            printf "  %d) %s\n" $((i + 1)) "${options[i]}" >&2
        done

        # ----- read the choice --------------------------------------------
        local choice
        if ! read -r -p "Enter choice [1-${count}]: " choice; then
            # EOF (Ctrl‑D) or read error → signal failure, no output
            return 1
        fi

        # ----- trim whitespace ---------------------------------------------
        choice="${choice#"${choice%%[![:space:]]*}"}"
        choice="${choice%"${choice##*[![:space:]]}"}"

        # ----- validate ----------------------------------------------------
        if [[ $choice =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
            # valid → print the *selected option* on stdout
            printf "%s" "${options[choice-1]}"
            return 0
        fi

        # ----- invalid ------------------------------------------------------
        log_warning "Invalid selection – please try again."
    done
}

# -----------------------------------------------------------------
#  Export the public API
# -----------------------------------------------------------------
export -f prompt_input prompt_password prompt_confirm prompt_menu