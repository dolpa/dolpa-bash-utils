#!/usr/bin/env bash
#=====================================================================
# Bash Utils Library Test Runner
#=====================================================================
# Description: Runs all BATS tests for the bash utilities library
# Author: dolpa (https://dolpa.me)
# Version: main
# Usage: ./run-tests.sh [options]
#=====================================================================

set -euo pipefail

# --------------------------------------------------------------------
# 1️⃣  Script & test locations
# --------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}/tests"

# --------------------------------------------------------------------
# 2️⃣  Colour handling (only if we have a real terminal)
# --------------------------------------------------------------------
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
    # shellcheck disable=SC2034
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[1;33m'
    readonly COLOR_BLUE='\033[0;34m'
    # shellcheck disable=SC2034
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

# --------------------------------------------------------------------
# 3️⃣  Default configuration
# --------------------------------------------------------------------
VERBOSE=false
QUIET=false
COVERAGE=false
PARTICULAR_TEST=""
LIST_TESTS=false
INSTALL_BATS=false

# --------------------------------------------------------------------
# 4️⃣  Helper / logging functions
# --------------------------------------------------------------------
show_usage() {
    cat <<'EOF'
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
    $0 -t "test_validation.bats" # Run a single test file
    $0 --list                    # List all available tests
EOF
}

log_info() {
    [[ "$QUIET" != "true" ]] && echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}
log_success() { echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"; }
log_error()   { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2; }

# --------------------------------------------------------------------
# 5️⃣  Argument parsing
# --------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)   VERBOSE=true; shift ;;
            -q|--quiet)     QUIET=true;   shift ;;
            -c|--coverage)  COVERAGE=true; shift ;;
            -t|--test)      PARTICULAR_TEST="$2"; shift 2 ;;
            -l|--list)      LIST_TESTS=true; shift ;;
            -i|--install-bats) INSTALL_BATS=true; shift ;;
            -h|--help)      show_usage; exit 0 ;;
            -*)
                log_error "Unknown option: $1"
                show_usage >&2
                exit 1
                ;;
            *)  PARTICULAR_TEST="$1"; shift ;;
        esac
    done
}

# --------------------------------------------------------------------
# 6️⃣  BATS detection & optional installation
# --------------------------------------------------------------------
check_bats() {
    if ! command -v bats >/dev/null 2>&1; then
        log_error "BATS testing framework not found"
        log_info "Install BATS using one of these methods:"
        cat <<'EOM'
          • Ubuntu/Debian: apt-get install bats
          • macOS: brew install bats-core
          • Manual: git clone https://github.com/bats-core/bats-core.git && cd bats-core && ./install.sh
          • Or run: $0 --install-bats
EOM
        return 1
    fi
    return 0
}

install_bats() {
    log_info "Installing BATS testing framework..."
    local bats_dir
    bats_dir="/tmp/bats-core"

    [[ -d "$bats_dir" ]] && rm -rf "$bats_dir"

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

# --------------------------------------------------------------------
# 7️⃣  Test‑related helpers
# --------------------------------------------------------------------
list_tests() {
    log_info "Available test files:"
    echo

    if [[ -d "$TEST_DIR" ]]; then
        for test_file in "$TEST_DIR"/*.bats; do
            [[ -f "$test_file" ]] || continue

            local basename_file
            basename_file=$(basename "$test_file")

            echo "  • $basename_file"

            if [[ "$VERBOSE" == "true" ]]; then
                grep '^@test' "$test_file" |
                    sed 's/@test "\(.*\)".*/    - \1/' |
                    head -5

                local test_count
                test_count=$(grep -c '^@test' "$test_file" 2>/dev/null || echo "0")
                echo "    (${test_count} tests)"
                echo
            fi
        done
    else
        log_error "Test directory not found: $TEST_DIR"
        return 1
    fi
}

run_specific_test() {
    local pattern
    pattern="$1"
    local test_files
    test_files=()

    log_info "Looking for tests matching: $pattern"

    for test_file in "$TEST_DIR"/*.bats; do
        [[ -f "$test_file" ]] || continue

        local basename_no_ext
        basename_no_ext=$(basename "$test_file" .bats)

        if [[ "$basename_no_ext" == *"$pattern"* ]] ||
           [[ "$(basename "$test_file")" == *"$pattern"* ]]; then
            test_files+=("$test_file")
        fi
    done

    if (( ${#test_files[@]} == 0 )); then
        log_error "No tests found matching pattern: $pattern"
        return 1
    fi

    log_info "Found ${#test_files[@]} test file(s) matching pattern"

    local exit_code
    exit_code=0
    for test_file in "${test_files[@]}"; do
        log_info "Running $(basename "$test_file")..."

        local bats_args
        bats_args=()
        [[ "$VERBOSE" == "true" ]] && bats_args+=("--verbose")

        if ! bats "${bats_args[@]}" "$test_file"; then
            exit_code=1
        fi
        echo
    done

    return $exit_code
}

run_all_tests() {
    log_info "Running all tests..."

    if [[ ! -d "$TEST_DIR" ]]; then
        log_error "Test directory not found: $TEST_DIR"
        return 1
    fi

    local test_files
    test_files=("$TEST_DIR"/*.bats)

    if [[ ! -f "${test_files[0]}" ]]; then
        log_error "No test files found in $TEST_DIR"
        return 1
    fi

    log_info "Found ${#test_files[@]} test file(s)"

    local bats_args
    bats_args=()
    [[ "$VERBOSE" == "true" ]] && bats_args+=("--verbose")
    [[ "$COVERAGE" == "true" ]] && log_info "Coverage reporting requested (if supported by BATS version)"

    local exit_code=0
    if [[ "$VERBOSE" == "true" ]] || (( ${#test_files[@]} <= 3 )); then
        for test_file in "${test_files[@]}"; do
            log_info "Running $(basename "$test_file")..."
            if ! bats "${bats_args[@]}" "$test_file"; then
                exit_code=1
            fi
            echo
        done
    else
        if ! bats "${bats_args[@]}" "${test_files[@]}"; then
            exit_code=1
        fi
    fi

    return $exit_code
}

print_summary() {
    local exit_code
    exit_code="$1"
    echo
    echo "================================"
    if (( exit_code == 0 )); then
        log_success "All tests passed!"
    else
        log_error "Some tests failed!"
    fi
    echo "================================"
}

# --------------------------------------------------------------------
# 8️⃣  Main entry point
# --------------------------------------------------------------------
main() {
    parse_args "$@"

    # Special actions -------------------------------------------------
    if [[ "$INSTALL_BATS" == "true" ]]; then
        install_bats
        exit $?
    fi

    if [[ "$LIST_TESTS" == "true" ]]; then
        list_tests
        exit $?
    fi

    # Prerequisite ----------------------------------------------------
    if ! check_bats; then
        exit 1
    fi

    log_info "Bash Utils Library Test Runner"
    log_info "Test directory: $TEST_DIR"
    echo

    # Run either a specific pattern or everything --------------------
    local exit_code
    exit_code=0
    if [[ -n "$PARTICULAR_TEST" ]]; then
        run_specific_test "$PARTICULAR_TEST"
        exit_code=$?
    else
        run_all_tests
        exit_code=$?
    fi

    # Summary ---------------------------------------------------------
    print_summary "$exit_code"
    exit "$exit_code"
}

# --------------------------------------------------------------------
# 9️⃣  Execute
# --------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi