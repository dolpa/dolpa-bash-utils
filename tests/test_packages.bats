#!/usr/bin/env bats

#=====================================================================
# test_packages.bats – Unit tests for the packages module
#=====================================================================
# These tests validate package-manager detection and command dispatch
# using lightweight command mocks placed first in $PATH.
#=====================================================================

# ------------------------------------------------------------------
# setup() – runs before each test case.
# ------------------------------------------------------------------
setup() {
    # Force deterministic output – no colour codes.
    export NO_COLOR=1

    # Ensure no inherited manager selection affects detection.
    unset PKG_MANAGER

    # Create temporary directories for mocked binaries and a minimal toolchain.
    export ORIG_PATH="$PATH"
    export MOCK_BIN_DIR="$(mktemp -d)"
    export TOOLS_BIN_DIR="$(mktemp -d)"

    _link_tool() {
        local tool="$1"
        local tool_path
        tool_path="$(command -v "$tool" || true)"
        [[ -n "$tool_path" ]] || return 0
        ln -sf "$tool_path" "${TOOLS_BIN_DIR}/${tool}"
    }

    # Provide the core utilities used by the modules and tests, without
    # exposing the container's real package managers (e.g. apt-get).
    _link_tool bash
    _link_tool env
    _link_tool date
    _link_tool grep
    _link_tool dirname
    _link_tool cat
    _link_tool chmod
    _link_tool rm
    _link_tool mktemp
    _link_tool uname
    _link_tool tput
    _link_tool stty
    _link_tool printf
    _link_tool sed
    _link_tool awk
    _link_tool tr
    _link_tool cut
    _link_tool head
    _link_tool tail
    _link_tool sort

    # Keep the PATH deterministic: mocks first, then the toolchain.
    export PATH="${MOCK_BIN_DIR}:${TOOLS_BIN_DIR}"

    # GitHub Actions runs tests as a non-root user. The packages module
    # uses sudo when EUID != 0; provide a lightweight sudo shim that
    # preserves PATH so our mocked package managers are still used.
    cat >"${MOCK_BIN_DIR}/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
    chmod +x "${MOCK_BIN_DIR}/sudo"

    # Load the core modules in the required order.
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/validation.sh"
    source "${BATS_TEST_DIRNAME}/../modules/packages.sh"
}

# ------------------------------------------------------------------
# teardown() – runs after each test case.
# ------------------------------------------------------------------
teardown() {
    # Restore PATH first (Bats may execute helpers after teardown).
    export PATH="$ORIG_PATH"

    # Remove temporary directories.
    rm -rf "${MOCK_BIN_DIR}" "${TOOLS_BIN_DIR}"
    unset MOCK_BIN_DIR
    unset TOOLS_BIN_DIR
    unset ORIG_PATH
    unset NO_COLOR
    unset PKG_MANAGER   # ensure detection runs fresh for each test
}

# ------------------------------------------------------------------
# Helper – create a mock command that writes its arguments to a log file.
# ------------------------------------------------------------------
mock_cmd() {
    local name="$1"
    local script="${MOCK_BIN_DIR}/${name}"
    cat >"$script" <<'EOF'
#!/usr/bin/env bash
# Record invocation (package name(s) and flags) to a file for assertions.
echo "$0 $@" >> "${MOCK_LOG}"
exit "${MOCK_EXIT_CODE:-0}"
EOF
    chmod +x "$script"
}

# ------------------------------------------------------------------
# Verify the module loads correctly and the loaded flag is set.
# ------------------------------------------------------------------
@test "packages module reports that it has been loaded" {
    [ -n "${BASH_UTILS_PACKAGES_LOADED:-}" ]
}

# ------------------------------------------------------------------
# pkg_detect_manager – pick the first manager that exists.
# ------------------------------------------------------------------
@test "pkg_detect_manager finds apt when both apt and yum are present" {
    # Create two mock managers – apt‑get and yum.
    mock_cmd "apt-get"
    mock_cmd "yum"

    pkg_detect_manager
    [ "$?" -eq 0 ]
    [ "$PKG_MANAGER" = "apt" ]
}

@test "pkg_detect_manager falls back to yum when apt is missing" {
    mock_cmd "yum"

    pkg_detect_manager
    [ "$?" -eq 0 ]
    [ "$PKG_MANAGER" = "yum" ]
}

@test "pkg_detect_manager returns error when no manager is available" {
    # No mock binaries created – the detection must fail.
    run pkg_detect_manager
    [ "$status" -eq 1 ]
}

# ------------------------------------------------------------------
# pkg_installed – mock dpkg and rpm behaviours.
# ------------------------------------------------------------------
@test "pkg_installed returns 0 when the package is present (apt)" {
    mock_cmd "apt-get"
    # Provide a dummy dpkg that pretends the package exists.
    cat >"${MOCK_BIN_DIR}/dpkg" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "-s" && "$2" == "nginx" ]] && exit 0
exit 1
EOF
    chmod +x "${MOCK_BIN_DIR}/dpkg"

    run pkg_installed nginx
    [ "$status" -eq 0 ]
}

@test "pkg_installed returns 1 when the package is missing (apt)" {
    mock_cmd "apt-get"
    cat >"${MOCK_BIN_DIR}/dpkg" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "${MOCK_BIN_DIR}/dpkg"

    run pkg_installed nonexistent-pkg
    [ "$status" -eq 1 ]
}

@test "pkg_installed works with rpm based managers (yum)" {
    mock_cmd "yum"
    cat >"${MOCK_BIN_DIR}/rpm" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "-q" && "$2" == "nginx" ]] && exit 0
exit 1
EOF
    chmod +x "${MOCK_BIN_DIR}/rpm"

    run pkg_installed nginx
    [ "$status" -eq 0 ]
}

# ------------------------------------------------------------------
# pkg_install – ensure the correct underlying command is invoked.
# ------------------------------------------------------------------
@test "pkg_install uses apt-get when manager is apt" {
    mock_cmd "apt-get"
    export MOCK_LOG="${MOCK_BIN_DIR}/apt.log"
    export MOCK_EXIT_CODE=0

    run pkg_install htop
    [ "$status" -eq 0 ]

    # The mock script should have been called with the expected arguments.
    grep -q "apt-get install -y htop" "${MOCK_LOG}"
}

@test "pkg_install uses yum when manager is yum" {
    mock_cmd "yum"
    export MOCK_LOG="${MOCK_BIN_DIR}/yum.log"
    export MOCK_EXIT_CODE=0

    # Force detection to use yum (no apt‑get present)
    run pkg_install curl
    [ "$status" -eq 0 ]

    grep -q "yum install -y curl" "${MOCK_LOG}"
}

@test "pkg_install reports an error for an unknown manager" {
    # Remove all supported manager binaries from PATH.
    run pkg_install htop
    [ "$status" -eq 1 ]
}

# ------------------------------------------------------------------
# pkg_update – make sure the right update command runs.
# ------------------------------------------------------------------
@test "pkg_update triggers the correct command for pacman" {
    mock_cmd "pacman"
    export MOCK_LOG="${MOCK_BIN_DIR}/pacman.log"
    export MOCK_EXIT_CODE=0

    run pkg_update
    [ "$status" -eq 0 ]

    grep -q "pacman -Sy" "${MOCK_LOG}"
}

@test "pkg_update triggers the correct command for apk" {
    mock_cmd "apk"
    export MOCK_LOG="${MOCK_BIN_DIR}/apk.log"
    export MOCK_EXIT_CODE=0

    run pkg_update
    [ "$status" -eq 0 ]

    grep -q "apk update" "${MOCK_LOG}"
}