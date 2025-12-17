#!/usr/bin/env bash
#=====================================================================
# ansi.sh - ANSI Colors & Terminal Formatting for Bash‑Utils library
#
# This module provides a comprehensive set of functions for terminal
# colors and text formatting using ANSI escape sequences. It builds
# upon the color definitions in config.sh to provide easy‑to‑use
# formatting functions for enhanced CLI user experience.
#
#   • Text color functions (red, green, blue, etc.)
#   • Text style functions (bold, italic, underline, etc.)
#   • Background color functions
#   • Composite formatting functions
#   • Terminal capability detection
#   • Color‑aware output functions
#
# All functions respect NO_COLOR environment variable and terminal
# capabilities, gracefully degrading when colors are not supported.
#
# The module follows the same conventions as the rest of the library:
#   • It guards against being sourced more than once.
#   • It loads its dependencies in the correct order.
#   • All public functions are documented with descriptions and examples.
#=====================================================================

# ------------------------------------------------------------------
# Guard against multiple sourcing – this pattern is used in every
# other module of the library.
# ------------------------------------------------------------------
if [[ -n "${BASH_UTILS_ANSI_LOADED:-}" ]]; then
    # The module has already been sourced – exit silently.
    return 0
fi
readonly BASH_UTILS_ANSI_LOADED=true

# ------------------------------------------------------------------
# Load required modules – config.sh provides the base color definitions
# and terminal detection logic that this module extends.
# ------------------------------------------------------------------
source "${BASH_SOURCE[0]%/*}/config.sh"

# ------------------------------------------------------------------
# Configuration variables (can be overridden by the caller)
# ------------------------------------------------------------------
# Force color output even when not connected to a terminal
: "${BASH_UTILS_FORCE_COLOR:=false}"

# Use 256-color mode when available (experimental)
: "${BASH_UTILS_USE_256_COLOR:=false}"

# ------------------------------------------------------------------
# ANSI Color Constants (independent of config.sh color detection)
# These are always defined since ansi.sh has its own color detection
# ------------------------------------------------------------------

# Standard ANSI colors (foreground)
readonly ANSI_COLOR_RED=$'\033[0;31m'
readonly ANSI_COLOR_GREEN=$'\033[0;32m'
readonly ANSI_COLOR_YELLOW=$'\033[1;33m'
readonly ANSI_COLOR_BLUE=$'\033[0;34m'
readonly ANSI_COLOR_PURPLE=$'\033[0;35m'
readonly ANSI_COLOR_MAGENTA=$'\033[0;35m'  # Alias for purple
readonly ANSI_COLOR_CYAN=$'\033[0;36m'
readonly ANSI_COLOR_WHITE=$'\033[1;37m'
readonly ANSI_COLOR_BLACK=$'\033[0;30m'
readonly ANSI_COLOR_GRAY=$'\033[0;37m'

# Bright/bold variant colors
readonly ANSI_COLOR_BRIGHT_RED=$'\033[1;31m'
readonly ANSI_COLOR_BRIGHT_GREEN=$'\033[1;32m'
readonly ANSI_COLOR_BRIGHT_YELLOW=$'\033[1;33m'
readonly ANSI_COLOR_BRIGHT_BLUE=$'\033[1;34m'
readonly ANSI_COLOR_BRIGHT_PURPLE=$'\033[1;35m'
readonly ANSI_COLOR_BRIGHT_MAGENTA=$'\033[1;35m'
readonly ANSI_COLOR_BRIGHT_CYAN=$'\033[1;36m'
readonly ANSI_COLOR_BRIGHT_WHITE=$'\033[1;37m'
readonly ANSI_COLOR_BRIGHT_BLACK=$'\033[1;30m'

# Background colors
readonly ANSI_COLOR_BG_RED=$'\033[41m'
readonly ANSI_COLOR_BG_GREEN=$'\033[42m'
readonly ANSI_COLOR_BG_YELLOW=$'\033[43m'
readonly ANSI_COLOR_BG_BLUE=$'\033[44m'
readonly ANSI_COLOR_BG_PURPLE=$'\033[45m'
readonly ANSI_COLOR_BG_MAGENTA=$'\033[45m'
readonly ANSI_COLOR_BG_CYAN=$'\033[46m'
readonly ANSI_COLOR_BG_WHITE=$'\033[47m'
readonly ANSI_COLOR_BG_BLACK=$'\033[40m'

# Text styling
readonly ANSI_STYLE_BOLD=$'\033[1m'
readonly ANSI_STYLE_DIM=$'\033[2m'
readonly ANSI_STYLE_ITALIC=$'\033[3m'
readonly ANSI_STYLE_UNDERLINE=$'\033[4m'
readonly ANSI_STYLE_BLINK=$'\033[5m'
readonly ANSI_STYLE_REVERSE=$'\033[7m'
readonly ANSI_STYLE_STRIKETHROUGH=$'\033[9m'

# Reset and control codes
readonly ANSI_RESET=$'\033[0m'
readonly ANSI_CLEAR_LINE=$'\033[2K'
readonly ANSI_CLEAR_SCREEN=$'\033[2J\033[H'

#=====================================================================
# INTERNAL HELPER FUNCTIONS
#=====================================================================

#---------------------------------------------------------------------
# _ansi_supports_color()
#   Internal helper – checks if the current terminal supports colors.
#   Takes into account NO_COLOR, TERM settings, and stdout redirection.
#   Returns 0 if colors are supported, 1 otherwise.
#---------------------------------------------------------------------
_ansi_supports_color() {
    # Check if colors are explicitly disabled
    if [[ "${NO_COLOR:-}" == "1" ]]; then
        return 1
    fi
    
    # Check if colors are forced
    if [[ "${BASH_UTILS_FORCE_COLOR}" == "true" ]]; then
        return 0
    fi
    
    # Check if stdout is a terminal
    if [[ ! -t 1 ]]; then
        return 1
    fi
    
    # Check TERM variable
    if [[ "${TERM:-}" == "dumb" ]] || [[ -z "${TERM:-}" ]]; then
        return 1
    fi
    
    return 0
}

#---------------------------------------------------------------------
# _ansi_wrap()
#   Internal helper – wraps text with ANSI codes if colors are supported.
#   Arguments:
#       $1 - opening ANSI escape sequence
#       $2 - text to format
#       $3 - closing ANSI escape sequence (optional, defaults to reset)
#   Returns: formatted text or plain text if colors not supported
#---------------------------------------------------------------------
_ansi_wrap() {
    local open_code="$1"
    local text="$2"
    local close_code="${3:-${ANSI_RESET}}"
    
    if _ansi_supports_color; then
        printf "%s%s%s" "${open_code}" "${text}" "${close_code}"
    else
        printf "%s" "${text}"
    fi
}

#=====================================================================
# TEXT COLOR FUNCTIONS
#=====================================================================

#---------------------------------------------------------------------
# ansi_red()
#   Format text in red color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_red "Error occurred")"
#---------------------------------------------------------------------
ansi_red() {
    _ansi_wrap "${ANSI_COLOR_RED}" "$1"
}

#---------------------------------------------------------------------
# ansi_green()
#   Format text in green color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_green "Success!")"
#---------------------------------------------------------------------
ansi_green() {
    _ansi_wrap "${ANSI_COLOR_GREEN}" "$1"
}

#---------------------------------------------------------------------
# ansi_yellow()
#   Format text in yellow color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_yellow "Warning: Check configuration")"
#---------------------------------------------------------------------
ansi_yellow() {
    _ansi_wrap "${ANSI_COLOR_YELLOW}" "$1"
}

#---------------------------------------------------------------------
# ansi_blue()
#   Format text in blue color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_blue "Information")"
#---------------------------------------------------------------------
ansi_blue() {
    _ansi_wrap "${ANSI_COLOR_BLUE}" "$1"
}

#---------------------------------------------------------------------
# ansi_purple()
#   Format text in purple/magenta color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_purple "Debug mode enabled")"
#---------------------------------------------------------------------
ansi_purple() {
    _ansi_wrap "${ANSI_COLOR_PURPLE}" "$1"
}

#---------------------------------------------------------------------
# ansi_magenta()
#   Format text in magenta color (alias for purple).
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_magenta "Special message")"
#---------------------------------------------------------------------
ansi_magenta() {
    _ansi_wrap "${ANSI_COLOR_MAGENTA}" "$1"
}

#---------------------------------------------------------------------
# ansi_cyan()
#   Format text in cyan color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_cyan "Processing...")"
#---------------------------------------------------------------------
ansi_cyan() {
    _ansi_wrap "${ANSI_COLOR_CYAN}" "$1"
}

#---------------------------------------------------------------------
# ansi_white()
#   Format text in bright white color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_white "Highlighted text")"
#---------------------------------------------------------------------
ansi_white() {
    _ansi_wrap "${ANSI_COLOR_WHITE}" "$1"
}

#---------------------------------------------------------------------
# ansi_black()
#   Format text in black color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_black "Hidden text")"
#---------------------------------------------------------------------
ansi_black() {
    _ansi_wrap "${ANSI_COLOR_BLACK}" "$1"
}

#---------------------------------------------------------------------
# ansi_gray()
#   Format text in gray color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_gray "Secondary information")"
#---------------------------------------------------------------------
ansi_gray() {
    _ansi_wrap "${ANSI_COLOR_GRAY}" "$1"
}

#=====================================================================
# BRIGHT/BOLD COLOR VARIANTS
#=====================================================================

#---------------------------------------------------------------------
# ansi_bright_red()
#   Format text in bright red color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_bright_red "Critical error!")"
#---------------------------------------------------------------------
ansi_bright_red() {
    _ansi_wrap "${ANSI_COLOR_BRIGHT_RED}" "$1"
}

#---------------------------------------------------------------------
# ansi_bright_green()
#   Format text in bright green color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_bright_green "Operation completed successfully")"
#---------------------------------------------------------------------
ansi_bright_green() {
    _ansi_wrap "${ANSI_COLOR_BRIGHT_GREEN}" "$1"
}

#---------------------------------------------------------------------
# ansi_bright_yellow()
#   Format text in bright yellow color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_bright_yellow "Important notice")"
#---------------------------------------------------------------------
ansi_bright_yellow() {
    _ansi_wrap "${ANSI_COLOR_BRIGHT_YELLOW}" "$1"
}

#---------------------------------------------------------------------
# ansi_bright_blue()
#   Format text in bright blue color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_bright_blue "System information")"
#---------------------------------------------------------------------
ansi_bright_blue() {
    _ansi_wrap "${ANSI_COLOR_BRIGHT_BLUE}" "$1"
}

#---------------------------------------------------------------------
# ansi_bright_purple()
#   Format text in bright purple color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_bright_purple "Enhanced debug output")"
#---------------------------------------------------------------------
ansi_bright_purple() {
    _ansi_wrap "${ANSI_COLOR_BRIGHT_PURPLE}" "$1"
}

#---------------------------------------------------------------------
# ansi_bright_cyan()
#   Format text in bright cyan color.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_bright_cyan "Status update")"
#---------------------------------------------------------------------
ansi_bright_cyan() {
    _ansi_wrap "${ANSI_COLOR_BRIGHT_CYAN}" "$1"
}

#=====================================================================
# TEXT STYLE FUNCTIONS
#=====================================================================

#---------------------------------------------------------------------
# ansi_bold()
#   Format text in bold/bright style.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if formatting not supported)
#   Example: echo "$(ansi_bold "Important message")"
#---------------------------------------------------------------------
ansi_bold() {
    _ansi_wrap "${ANSI_STYLE_BOLD}" "$1"
}

#---------------------------------------------------------------------
# ansi_dim()
#   Format text in dim/faint style.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if formatting not supported)
#   Example: echo "$(ansi_dim "Less important details")"
#---------------------------------------------------------------------
ansi_dim() {
    _ansi_wrap "${ANSI_STYLE_DIM}" "$1"
}

#---------------------------------------------------------------------
# ansi_italic()
#   Format text in italic style.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if formatting not supported)
#   Example: echo "$(ansi_italic "Emphasized text")"
#---------------------------------------------------------------------
ansi_italic() {
    _ansi_wrap "${ANSI_STYLE_ITALIC}" "$1"
}

#---------------------------------------------------------------------
# ansi_underline()
#   Format text with underline style.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if formatting not supported)
#   Example: echo "$(ansi_underline "Section header")"
#---------------------------------------------------------------------
ansi_underline() {
    _ansi_wrap "${ANSI_STYLE_UNDERLINE}" "$1"
}

#---------------------------------------------------------------------
# ansi_blink()
#   Format text with blinking style (use sparingly).
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if formatting not supported)
#   Example: echo "$(ansi_blink "ALERT")"
#---------------------------------------------------------------------
ansi_blink() {
    _ansi_wrap "${ANSI_STYLE_BLINK}" "$1"
}

#---------------------------------------------------------------------
# ansi_reverse()
#   Format text with reverse/inverse style (swaps fg/bg colors).
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if formatting not supported)
#   Example: echo "$(ansi_reverse "Highlighted")"
#---------------------------------------------------------------------
ansi_reverse() {
    _ansi_wrap "${ANSI_STYLE_REVERSE}" "$1"
}

#---------------------------------------------------------------------
# ansi_strikethrough()
#   Format text with strikethrough style.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if formatting not supported)
#   Example: echo "$(ansi_strikethrough "Deprecated function")"
#---------------------------------------------------------------------
ansi_strikethrough() {
    _ansi_wrap "${ANSI_STYLE_STRIKETHROUGH}" "$1"
}

#=====================================================================
# BACKGROUND COLOR FUNCTIONS
#=====================================================================

#---------------------------------------------------------------------
# ansi_bg_red()
#   Format text with red background.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_bg_red "ERROR")"
#---------------------------------------------------------------------
ansi_bg_red() {
    _ansi_wrap "${ANSI_COLOR_BG_RED}" "$1"
}

#---------------------------------------------------------------------
# ansi_bg_green()
#   Format text with green background.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_bg_green "SUCCESS")"
#---------------------------------------------------------------------
ansi_bg_green() {
    _ansi_wrap "${ANSI_COLOR_BG_GREEN}" "$1"
}

#---------------------------------------------------------------------
# ansi_bg_yellow()
#   Format text with yellow background.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_bg_yellow "WARNING")"
#---------------------------------------------------------------------
ansi_bg_yellow() {
    _ansi_wrap "${ANSI_COLOR_BG_YELLOW}" "$1"
}

#---------------------------------------------------------------------
# ansi_bg_blue()
#   Format text with blue background.
#   Arguments: $1 - text to format
#   Returns: formatted text (or plain text if colors not supported)
#   Example: echo "$(ansi_bg_blue "INFO")"
#---------------------------------------------------------------------
ansi_bg_blue() {
    _ansi_wrap "${ANSI_COLOR_BG_BLUE}" "$1"
}

#=====================================================================
# COMPOSITE FORMATTING FUNCTIONS
#=====================================================================

#---------------------------------------------------------------------
# ansi_error()
#   Format text for error messages (bright red, bold).
#   Arguments: $1 - text to format
#   Returns: formatted text optimized for error display
#   Example: echo "$(ansi_error "File not found")"
#---------------------------------------------------------------------
ansi_error() {
    if _ansi_supports_color; then
        _ansi_wrap "${ANSI_COLOR_BRIGHT_RED}${ANSI_STYLE_BOLD}" "$1"
    else
        printf "ERROR: %s" "$1"
    fi
}

#---------------------------------------------------------------------
# ansi_success()
#   Format text for success messages (bright green, bold).
#   Arguments: $1 - text to format
#   Returns: formatted text optimized for success display
#   Example: echo "$(ansi_success "Operation completed")"
#---------------------------------------------------------------------
ansi_success() {
    if _ansi_supports_color; then
        _ansi_wrap "${ANSI_COLOR_BRIGHT_GREEN}${ANSI_STYLE_BOLD}" "$1"
    else
        printf "SUCCESS: %s" "$1"
    fi
}

#---------------------------------------------------------------------
# ansi_warning()
#   Format text for warning messages (bright yellow, bold).
#   Arguments: $1 - text to format
#   Returns: formatted text optimized for warning display
#   Example: echo "$(ansi_warning "Configuration may be outdated")"
#---------------------------------------------------------------------
ansi_warning() {
    if _ansi_supports_color; then
        _ansi_wrap "${ANSI_COLOR_BRIGHT_YELLOW}${ANSI_STYLE_BOLD}" "$1"
    else
        printf "WARNING: %s" "$1"
    fi
}

#---------------------------------------------------------------------
# ansi_info()
#   Format text for informational messages (bright blue).
#   Arguments: $1 - text to format
#   Returns: formatted text optimized for info display
#   Example: echo "$(ansi_info "Processing 100 files")"
#---------------------------------------------------------------------
ansi_info() {
    if _ansi_supports_color; then
        _ansi_wrap "${ANSI_COLOR_BRIGHT_BLUE}" "$1"
    else
        printf "INFO: %s" "$1"
    fi
}

#---------------------------------------------------------------------
# ansi_header()
#   Format text for section headers (bold, underlined, bright white).
#   Arguments: $1 - text to format
#   Returns: formatted text optimized for header display
#   Example: echo "$(ansi_header "Configuration Section")"
#---------------------------------------------------------------------
ansi_header() {
    if _ansi_supports_color; then
        _ansi_wrap "${ANSI_STYLE_BOLD}${ANSI_STYLE_UNDERLINE}${ANSI_COLOR_WHITE}" "$1"
    else
        printf "=== %s ===" "$1"
    fi
}

#---------------------------------------------------------------------
# ansi_code()
#   Format text for code/command display (cyan, monospace effect).
#   Arguments: $1 - text to format
#   Returns: formatted text optimized for code display
#   Example: echo "Run $(ansi_code "make install") to install"
#---------------------------------------------------------------------
ansi_code() {
    if _ansi_supports_color; then
        _ansi_wrap "${ANSI_COLOR_CYAN}" "\`$1\`"
    else
        printf "\`%s\`" "$1"
    fi
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================

#---------------------------------------------------------------------
# ansi_reset()
#   Reset all formatting to terminal defaults.
#   Arguments: none
#   Returns: ANSI reset sequence (or nothing if colors not supported)
#   Example: echo "Colored text$(ansi_reset) normal text"
#---------------------------------------------------------------------
ansi_reset() {
    if _ansi_supports_color; then
        printf "%s" "${ANSI_RESET}"
    fi
}

#---------------------------------------------------------------------
# ansi_supports_color()
#   Check if the current terminal supports colors.
#   Arguments: none
#   Returns: 0 if colors supported, 1 otherwise
#   Example: ansi_supports_color && echo "Colors available"
#---------------------------------------------------------------------
ansi_supports_color() {
    _ansi_supports_color
}

#---------------------------------------------------------------------
# ansi_strip()
#   Remove all ANSI escape sequences from text.
#   Arguments: $1 - text that may contain ANSI sequences
#   Returns: plain text with all ANSI sequences removed
#   Example: clean_text=$(ansi_strip "$formatted_text")
#---------------------------------------------------------------------
ansi_strip() {
    local text="$1"
    # Remove ANSI escape sequences using sed
    # Handle both literal \033 and actual escape sequences
    printf "%s" "${text}" | sed -e 's/\x1b\[[0-9;]*m//g' -e 's/\\033\[[0-9;]*m//g'
}

#---------------------------------------------------------------------
# ansi_length()
#   Get the visible length of text (excluding ANSI sequences).
#   Arguments: $1 - text that may contain ANSI sequences
#   Returns: visible character count
#   Example: visible_len=$(ansi_length "$formatted_text")
#---------------------------------------------------------------------
ansi_length() {
    local text="$1"
    local clean_text
    clean_text=$(ansi_strip "$text")
    printf "%d" "${#clean_text}"
}

#---------------------------------------------------------------------
# ansi_test_colors()
#   Display a test pattern showing all available colors and formatting.
#   Arguments: none
#   Side effects: prints color test pattern to stdout
#   Example: ansi_test_colors
#---------------------------------------------------------------------
ansi_test_colors() {
    echo "ANSI Color and Formatting Test"
    echo "==============================="
    echo
    
    echo "Basic Colors:"
    echo "  $(ansi_red "Red") $(ansi_green "Green") $(ansi_yellow "Yellow") $(ansi_blue "Blue")"
    echo "  $(ansi_purple "Purple") $(ansi_cyan "Cyan") $(ansi_white "White") $(ansi_gray "Gray")"
    echo
    
    echo "Bright Colors:"
    echo "  $(ansi_bright_red "Bright Red") $(ansi_bright_green "Bright Green") $(ansi_bright_yellow "Bright Yellow")"
    echo "  $(ansi_bright_blue "Bright Blue") $(ansi_bright_purple "Bright Purple") $(ansi_bright_cyan "Bright Cyan")"
    echo
    
    echo "Text Styles:"
    echo "  $(ansi_bold "Bold") $(ansi_dim "Dim") $(ansi_underline "Underline")"
    echo "  $(ansi_reverse "Reverse") $(ansi_strikethrough "Strikethrough")"
    echo
    
    echo "Background Colors:"
    echo "  $(ansi_bg_red " Red BG ") $(ansi_bg_green " Green BG ") $(ansi_bg_yellow " Yellow BG ") $(ansi_bg_blue " Blue BG ")"
    echo
    
    echo "Composite Styles:"
    echo "  $(ansi_error "Error Message")"
    echo "  $(ansi_success "Success Message")"
    echo "  $(ansi_warning "Warning Message")"
    echo "  $(ansi_info "Info Message")"
    echo "  $(ansi_header "Header Text")"
    echo "  Run $(ansi_code "command") to execute"
    echo
    
    echo "Color Support: $(ansi_supports_color && echo "$(ansi_green "Enabled")" || echo "$(ansi_red "Disabled")")"
}

# Export public functions
export -f ansi_red ansi_green ansi_yellow ansi_blue ansi_purple ansi_magenta ansi_cyan ansi_white ansi_black ansi_gray
export -f ansi_bright_red ansi_bright_green ansi_bright_yellow ansi_bright_blue ansi_bright_purple ansi_bright_cyan
export -f ansi_bold ansi_dim ansi_italic ansi_underline ansi_blink ansi_reverse ansi_strikethrough
export -f ansi_bg_red ansi_bg_green ansi_bg_yellow ansi_bg_blue
export -f ansi_error ansi_success ansi_warning ansi_info ansi_header ansi_code
export -f ansi_reset ansi_supports_color ansi_strip ansi_length ansi_test_colors

#=====================================================================
# END OF FILE
#=====================================================================