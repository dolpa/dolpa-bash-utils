#!/bin/bash

#===============================================================================
# Bash Utils Library Test Runner
#===============================================================================
# Description: Runs all BATS tests for the bash utilities library
# Author: dolpa (https://dolpa.me)
# Version: main
# Usage: ./run-tests.sh [options]
#===============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}/tests"

# Colors for output (if supported)
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[1;33m'
    readonly COLOR_BLUE='\033[0;34m'
    readonly COLOR_BOLD='\033[1m'
    readonly COLOR_RESET='\033[0m'
else
    readonly COLOR_RED=''
    readonly COLOR_GREEN=''
    readonly COLOR_YELLOW=''
    readonly COLOR_BLUE=''
    readonly COLOR_BOLD=''
    readonly COLOR_RESET=''
fi

# Configuration
VERBOSE=false
QUIET=false
COVERAGE=false
PARTICULAR_TEST=""
LIST_TESTS=false
INSTALL_BATS=false

# Usage information
show_usage() {
    cat << EOF
${COLOR_BOLD}Bash Utils Library Test Runner${COLOR_RESET}

Usage: $0 [OPTIONS] [TEST_PATTERN]

OPTIONS:
    -v, --verbose       Enable verbose output
    -q, --quiet         Suppress output except for failures
    -c, --coverage      Run with coverage reporting (if available)
    -t, --test TEST     Run specific test file or pattern
    -l, --list          List available test files
    -i, --install-bats  Install BATS testing framework
    -h, --help          Show this help message

EXAMPLES:
    $0                           # Run all tests
    $0 -v                        # Run all tests with verbose output
    $0 -t config                 # Run only config tests
    $0 -t "test_validation.bats" # Run specific test file
    $0 --list                    # List all available tests

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -c|--coverage)
                COVERAGE=true
                shift
                ;;
            -t|--test)
                PARTICULAR_TEST="$2"
                shift 2
                ;;
            -l|--list)
                LIST_TESTS=true
                shift
                ;;
            -i|--install-bats)
                INSTALL_BATS=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                echo -e "${COLOR_RED}Error: Unknown option $1${COLOR_RESET}" >&2
                show_usage >&2
                exit 1
                ;;
            *)
                PARTICULAR_TEST="$1"
                shift
                ;;
        esac
    done
}

# Logging functions
log_info() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
    fi
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

# Check if BATS is installed
check_bats() {
    if ! command -v bats >/dev/null 2>&1; then
        log_error "BATS testing framework not found"
        log_info "Install BATS using one of these methods:"
        echo "  • Ubuntu/Debian: apt-get install bats"
        echo "  • macOS: brew install bats-core"
        echo "  • Manual: git clone https://github.com/bats-core/bats-core.git && cd bats-core && ./install.sh"
        echo "  • Or run: $0 --install-bats"
        return 1
    fi
    return 0
}

# Install BATS if requested
install_bats() {
    log_info "Installing BATS testing framework..."
    
    local bats_dir="/tmp/bats-core"
    
    if [[ -d "$bats_dir" ]]; then
        rm -rf "$bats_dir"
    fi
    
    if git clone https://github.com/bats-core/bats-core.git "$bats_dir"; then
        cd "$bats_dir"
        if sudo ./install.sh /usr/local; then
            log_success "BATS installed successfully"
            cd "$SCRIPT_DIR"
            rm -rf "$bats_dir"
            return 0
        else
            log_error "Failed to install BATS"
            return 1
        fi
    else
        log_error "Failed to clone BATS repository"
        return 1
    fi
}

# List available tests
list_tests() {
    log_info "Available test files:"
    echo
    
    if [[ -d "$TEST_DIR" ]]; then
        for test_file in "$TEST_DIR"/*.bats; do
            if [[ -f "$test_file" ]]; then
                local basename_file=$(basename "$test_file")
                echo "  • $basename_file"
                
                if [[ "$VERBOSE" == "true" ]]; then
                    # Show test descriptions
                    grep "^@test" "$test_file" | sed 's/@test "\(.*\)".*/    - \1/' | head -5
                    local test_count=$(grep -c "^@test" "$test_file" 2>/dev/null || echo "0")
                    echo "    (${test_count} tests)"
                    echo
                fi
            fi
        done
    else
        log_error "Test directory not found: $TEST_DIR"
        return 1
    fi
}

# Run specific test or pattern
run_specific_test() {
    local pattern="$1"
    local test_files=()
    
    log_info "Looking for tests matching: $pattern"
    
    # Find matching test files
    for test_file in "$TEST_DIR"/*.bats; do
        if [[ -f "$test_file" ]]; then
            local basename_file=$(basename "$test_file" .bats)
            if [[ "$basename_file" == *"$pattern"* ]] || [[ "$(basename "$test_file")" == *"$pattern"* ]]; then
                test_files+=("$test_file")
            fi
        fi
    done
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_error "No tests found matching pattern: $pattern"
        return 1
    fi
    
    log_info "Found ${#test_files[@]} test file(s) matching pattern"
    
    # Run the matching tests
    local exit_code=0
    for test_file in "${test_files[@]}"; do
        log_info "Running $(basename "$test_file")..."
        
        local bats_args=()
        if [[ "$VERBOSE" == "true" ]]; then
            bats_args+=("--verbose")
        fi
        
        if ! bats "${bats_args[@]}" "$test_file"; then
            exit_code=1
        fi
        echo
    done
    
    return $exit_code
}

# Run all tests
run_all_tests() {
    log_info "Running all tests..."
    
    if [[ ! -d "$TEST_DIR" ]]; then
        log_error "Test directory not found: $TEST_DIR"
        return 1
    fi
    
    local test_files=("$TEST_DIR"/*.bats)
    
    if [[ ! -f "${test_files[0]}" ]]; then
        log_error "No test files found in $TEST_DIR"
        return 1
    fi
    
    log_info "Found ${#test_files[@]} test file(s)"
    
    local bats_args=()
    if [[ "$VERBOSE" == "true" ]]; then
        bats_args+=("--verbose")
    fi
    if [[ "$COVERAGE" == "true" ]]; then
        log_info "Coverage reporting requested (if supported by BATS version)"
    fi
    
    # Run tests
    local exit_code=0
    if [[ "$VERBOSE" == "true" ]] || [[ ${#test_files[@]} -le 3 ]]; then
        # Run tests individually for better output
        for test_file in "${test_files[@]}"; do
            log_info "Running $(basename "$test_file")..."
            if ! bats "${bats_args[@]}" "$test_file"; then
                exit_code=1
            fi
            echo
        done
    else
        # Run all tests together
        if ! bats "${bats_args[@]}" "${test_files[@]}"; then
            exit_code=1
        fi
    fi
    
    return $exit_code
}

# Print test summary
print_summary() {
    local exit_code="$1"
    echo
    echo "======================================"
    if [[ $exit_code -eq 0 ]]; then
        log_success "All tests passed!"
    else
        log_error "Some tests failed!"
    fi
    echo "======================================"
}

# Main function
main() {
    parse_args "$@"
    
    # Handle special options
    if [[ "$INSTALL_BATS" == "true" ]]; then
        install_bats
        exit $?
    fi
    
    if [[ "$LIST_TESTS" == "true" ]]; then
        list_tests
        exit $?
    fi
    
    # Check prerequisites
    if ! check_bats; then
        exit 1
    fi
    
    log_info "Bash Utils Library Test Runner"
    log_info "Test directory: $TEST_DIR"
    echo
    
    # Run tests
    local exit_code=0
    if [[ -n "$PARTICULAR_TEST" ]]; then
        run_specific_test "$PARTICULAR_TEST"
        exit_code=$?
    else
        run_all_tests
        exit_code=$?
    fi
    
    # Print summary
    print_summary $exit_code
    
    exit $exit_code
}

# Run main function
main "$@"