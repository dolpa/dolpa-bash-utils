#!/usr/bin/env bats
# ==============================================================================
# Test suite for the services.sh module
#
# The tests use a *mock* `systemctl` binary placed at the front of $PATH.
# This allows us to verify the logic without requiring real system services.
# ==============================================================================

setup() {
    # Load library modules in dependency order.
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/services.sh"

    # ------------------------------------------------------------------
    # Create a temporary directory that will contain our mock binaries.
    # ------------------------------------------------------------------
    TMP_BIN="$(mktemp -d)"
    export PATH="${TMP_BIN}:$PATH"

    # ------------------------------------------------------------------
    # Mock `systemctl`.  It understands a tiny subset of commands that the
    # services module uses.
    # ------------------------------------------------------------------
    cat > "${TMP_BIN}/systemctl" <<'EOF'
#!/usr/bin/env bash
# Simple mock for systemctl used by the BATS tests.
#   $1 = command (list-unit-files, is-active, restart, enable, etc.)
#   $2 = service name (may include .service)

cmd="$1"
shift

case "$cmd" in
    list-unit-files)
        # Return success only for "existing_service"
        if [[ "$1" == "existing_service.service" ]]; then
            exit 0
        else
            exit 1
        fi
        ;;
    is-active)
        # Support: systemctl is-active --quiet <name>
        if [[ "${1-}" == "--quiet" ]]; then
            shift
        fi
        # Return success only for "running_service"
        if [[ "${1-}" == "running_service" ]]; then
            exit 0
        else
            exit 3   # systemd uses 3 for inactive
        fi
        ;;
    restart|enable)
        # Pretend the operation always succeeds.
        exit 0
        ;;
    *)
        # Anything else – succeed.
        exit 0
        ;;
esac
EOF
    chmod +x "${TMP_BIN}/systemctl"

    # Ensure colour codes are disabled for deterministic output.
    export NO_COLOR=1
}

teardown() {
    # Remove the temporary directory containing the mock binary.
    rm -rf "${TMP_BIN}"
    # Unset functions that were sourced for safety – same pattern as other tests.
    unset -f service_exists service_running service_restart service_enable 2>/dev/null || true
    # Nothing else to clean up.
    true
}

# ----------------------------------------------------------------------
# Basic module loading tests
# ----------------------------------------------------------------------
@test "services module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/services.sh"
    [ "$status" -eq 0 ]
}

@test "services module sets BASH_UTILS_SERVICES_LOADED" {
    [ "$BASH_UTILS_SERVICES_LOADED" = "true" ]
}

# ----------------------------------------------------------------------
# service_exists()
# ----------------------------------------------------------------------
@test "service_exists returns 0 for an existing unit" {
    run service_exists existing_service
    [ "$status" -eq 0 ]
}

@test "service_exists returns 1 for a missing unit" {
    run service_exists missing_service
    [ "$status" -eq 1 ]
}

# ----------------------------------------------------------------------
# service_running()
# ----------------------------------------------------------------------
@test "service_running reports running service" {
    run service_running running_service
    [ "$status" -eq 0 ]
}

@test "service_running reports stopped service" {
    run service_running stopped_service
    [ "$status" -eq 1 ]
}

# ----------------------------------------------------------------------
# service_restart()
# ----------------------------------------------------------------------
@test "service_restart returns the status of the underlying command" {
    run service_restart any_service
    [ "$status" -eq 0 ]
}

# ----------------------------------------------------------------------
# service_enable()
# ----------------------------------------------------------------------
@test "service_enable returns the status of the underlying command" {
    run service_enable any_service
    [ "$status" -eq 0 ]
}