#!/bin/bash

#===============================================================================
# Bash Utility Library - Prompts Module
#===============================================================================
# Description: User input and interaction functions for prompts, confirmations,
#              password input, and simple menu selections
# Author: dolpa (https://dolpa.me)
# Version: main
# License: Unlicense
# Dependencies: logging.sh (for error logging and colored output)
#===============================================================================

# Prevent multiple sourcing
if [[ "${BASH_UTILS_PROMPTS_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_PROMPTS_LOADED="true"

#===============================================================================
# USER INPUT AND PROMPT FUNCTIONS
#===============================================================================

# Prompt user for text input with optional default value
# Displays prompt on stderr to avoid interfering with output capture
# Usage: result=$(prompt_input "Enter name: " "default_name")
# Arguments:
#   $1 - prompt message to display
#   $2 - optional default value (used when user just hits Enter)
# Returns: user input or default value via stdout
prompt_input() {
    local msg="$1"
    local default="$2"
    local answer

    # Display prompt on stderr so it doesn't interfere with output capture
    printf "%s " "$msg" >&2

    # Read user input
    IFS= read -r answer

    # Trim whitespace from both input and default
    answer="$(echo -n "$answer" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    default="$(echo -n "$default" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    if [[ -z "$answer" && -n "$default" ]]; then
        printf "%s\n" "$default"
    else
        printf "%s\n" "$answer"
    fi
}

# Prompt user for password input (no echo)
# Handles both interactive and non-interactive input
# Usage: password=$(prompt_password "Enter password: ")
# Arguments:
#   $1 - prompt message to display
# Returns: password via stdout
prompt_password() {
    local msg="$1"
    local pwd

    # If input is from a terminal, disable echo
    if [[ -t 0 ]]; then
        printf "%s " "$msg" >&2
        IFS= read -s -r pwd
        printf "\n" >&2
    else
        # Non-interactive input (like in tests) - just read normally
        IFS= read -r pwd
    fi

    # Always print password to stdout
    printf "%s\n" "$pwd"
}

# Yes/No confirmation prompt
# Displays prompt and waits for y/n response
# Usage: if prompt_confirm "Are you sure?"; then ...; fi
# Arguments:
#   $1 - confirmation message to display
# Returns: 0 for yes, 1 for no
prompt_confirm() {
    local msg="$1"
    local response

    while true; do
        printf "%s [y/N]: " "$msg" >&2
        IFS= read -r response
        
        case "${response,,}" in
            y|yes) return 0 ;;
            n|no|"") return 1 ;;
            *) printf "Please answer yes or no.\n" >&2 ;;
        esac
    done
}

# Yes/No confirmation with default to Yes
# Similar to prompt_confirm but defaults to yes
# Usage: if prompt_confirm_yes "Continue?"; then ...; fi
# Arguments:
#   $1 - confirmation message to display
# Returns: 0 for yes (default), 1 for no
prompt_confirm_yes() {
    local msg="$1"
    local response

    while true; do
        printf "%s [Y/n]: " "$msg" >&2
        IFS= read -r response
        
        case "${response,,}" in
            y|yes|"") return 0 ;;
            n|no) return 1 ;;
            *) printf "Please answer yes or no.\n" >&2 ;;
        esac
    done
}

# Display a simple numbered menu and get user selection
# Usage: choice=$(prompt_menu "Select option:" "Option 1" "Option 2" "Option 3")
# Arguments:
#   $1 - menu title/prompt
#   $2+ - menu options
# Returns: selected option text via stdout, or empty string if cancelled
prompt_menu() {
    local title="$1"
    shift
    local options=("$@")
    local choice
    local i

    if [[ ${#options[@]} -eq 0 ]]; then
        echo "Error: No menu options provided" >&2
        return 1
    fi

    while true; do
        printf "\n%s\n" "$title" >&2
        for i in "${!options[@]}"; do
            printf "%2d) %s\n" $((i + 1)) "${options[i]}" >&2
        done
        printf "%2s) %s\n" "q" "Quit" >&2
        printf "\nSelect option [1-%d,q]: " ${#options[@]} >&2

        IFS= read -r choice

        case "$choice" in
            q|Q)
                return 1
                ;;
            [1-9]|[1-9][0-9])
                if [[ $choice -ge 1 && $choice -le ${#options[@]} ]]; then
                    printf "%s\n" "${options[$((choice - 1))]}"
                    return 0
                else
                    printf "Invalid selection. Please choose 1-%d or q.\n" ${#options[@]} >&2
                fi
                ;;
            *)
                printf "Invalid input. Please enter a number 1-%d or q.\n" ${#options[@]} >&2
                ;;
        esac
    done
}

# Wait for user to press Enter to continue
# Usage: prompt_pause "Press Enter to continue..."
# Arguments:
#   $1 - optional message to display (default: "Press Enter to continue...")
prompt_pause() {
    local msg="${1:-Press Enter to continue...}"
    printf "%s" "$msg" >&2
    IFS= read -r
}

# Prompt for numeric input with validation
# Usage: number=$(prompt_number "Enter age: " 1 100)
# Arguments:
#   $1 - prompt message
#   $2 - minimum value (optional)
#   $3 - maximum value (optional)
# Returns: validated number via stdout
prompt_number() {
    local msg="$1"
    local min="${2:-}"
    local max="${3:-}"
    local input
    local number

    while true; do
        printf "%s" "$msg" >&2
        IFS= read -r input

        # Check if input is a valid number
        if [[ "$input" =~ ^-?[0-9]+$ ]]; then
            number="$input"
            
            # Check minimum value
            if [[ -n "$min" && $number -lt $min ]]; then
                printf "Number must be at least %d.\n" "$min" >&2
                continue
            fi
            
            # Check maximum value
            if [[ -n "$max" && $number -gt $max ]]; then
                printf "Number must be at most %d.\n" "$max" >&2
                continue
            fi
            
            printf "%d\n" "$number"
            return 0
        else
            printf "Please enter a valid number.\n" >&2
        fi
    done
}

export -f prompt_input prompt_password prompt_confirm prompt_confirm_yes prompt_menu prompt_pause prompt_number