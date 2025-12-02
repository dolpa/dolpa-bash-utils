#!/bin/bash

#===============================================================================
# Bash Utility Library - Configuration Module
#===============================================================================
# Description: Configuration constants, variables, and color definitions
# Author: dolpa (https://dolpa.me)
# Version: 1.0
# License: Unlicense
#===============================================================================

# Prevent multiple sourcing
if [[ "${BASH_UTILS_CONFIG_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_CONFIG_LOADED="true"

#===============================================================================
# CONFIGURATION AND CONSTANTS
#===============================================================================

# Version information
readonly BASH_UTILS_VERSION="main"
readonly BASH_UTILS_NAME="Bash Utility Library"

# Default configuration
BASH_UTILS_VERBOSE=${BASH_UTILS_VERBOSE:-false}
BASH_UTILS_DEBUG=${BASH_UTILS_DEBUG:-false}
BASH_UTILS_TIMESTAMP_FORMAT=${BASH_UTILS_TIMESTAMP_FORMAT:-'%Y-%m-%d %H:%M:%S'}
BASH_UTILS_LOG_LEVEL=${BASH_UTILS_LOG_LEVEL:-"INFO"}

#===============================================================================
# COLOR CODES
#===============================================================================

# Color definitions (ANSI escape codes)
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    # Standard colors
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[1;33m'
    readonly COLOR_BLUE='\033[0;34m'
    readonly COLOR_PURPLE='\033[0;35m'
    readonly COLOR_CYAN='\033[0;36m'
    readonly COLOR_WHITE='\033[1;37m'
    readonly COLOR_GRAY='\033[0;37m'
    
    # Bright colors
    readonly COLOR_BRIGHT_RED='\033[1;31m'
    readonly COLOR_BRIGHT_GREEN='\033[1;32m'
    readonly COLOR_BRIGHT_YELLOW='\033[1;33m'
    readonly COLOR_BRIGHT_BLUE='\033[1;34m'
    readonly COLOR_BRIGHT_PURPLE='\033[1;35m'
    readonly COLOR_BRIGHT_CYAN='\033[1;36m'
    
    # Background colors
    readonly COLOR_BG_RED='\033[41m'
    readonly COLOR_BG_GREEN='\033[42m'
    readonly COLOR_BG_YELLOW='\033[43m'
    readonly COLOR_BG_BLUE='\033[44m'
    
    # Text formatting
    readonly COLOR_BOLD='\033[1m'
    readonly COLOR_DIM='\033[2m'
    readonly COLOR_UNDERLINE='\033[4m'
    readonly COLOR_BLINK='\033[5m'
    readonly COLOR_REVERSE='\033[7m'
    readonly COLOR_STRIKETHROUGH='\033[9m'
    
    # Reset
    readonly COLOR_RESET='\033[0m'
    readonly COLOR_NC='\033[0m'  # No Color (alias for reset)
else
    # No color support or explicitly disabled
    readonly COLOR_RED=""
    readonly COLOR_GREEN=""
    readonly COLOR_YELLOW=""
    readonly COLOR_BLUE=""
    readonly COLOR_PURPLE=""
    readonly COLOR_CYAN=""
    readonly COLOR_WHITE=""
    readonly COLOR_GRAY=""
    readonly COLOR_BRIGHT_RED=""
    readonly COLOR_BRIGHT_GREEN=""
    readonly COLOR_BRIGHT_YELLOW=""
    readonly COLOR_BRIGHT_BLUE=""
    readonly COLOR_BRIGHT_PURPLE=""
    readonly COLOR_BRIGHT_CYAN=""
    readonly COLOR_BG_RED=""
    readonly COLOR_BG_GREEN=""
    readonly COLOR_BG_YELLOW=""
    readonly COLOR_BG_BLUE=""
    readonly COLOR_BOLD=""
    readonly COLOR_DIM=""
    readonly COLOR_UNDERLINE=""
    readonly COLOR_BLINK=""
    readonly COLOR_REVERSE=""
    readonly COLOR_STRIKETHROUGH=""
    readonly COLOR_RESET=""
    readonly COLOR_NC=""
fi

# Legacy color constants for backward compatibility
readonly RED="${COLOR_RED}"
readonly GREEN="${COLOR_GREEN}"
readonly YELLOW="${COLOR_YELLOW}"
readonly BLUE="${COLOR_BLUE}"
readonly PURPLE="${COLOR_PURPLE}"
readonly CYAN="${COLOR_CYAN}"
readonly NC="${COLOR_NC}"