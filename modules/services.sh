#!/usr/bin/env bash
# ==============================================================================
# services.sh – Systemd & Service Management
# ==============================================================================
# A tiny wrapper that gives a *single* API for dealing with services on Linux
# distributions that use systemd (most modern distros).  The functions are safe
# to source on systems that do not have systemd – they simply fall back to the
# legacy `service` command when it is available.
#
# Public API
# ----------
#   service_exists   <service>   – true if the unit exists
#   service_running  <service>   – true if the unit is active
#   service_restart  <service>   – restart the unit (returns command status)
#   service_enable   <service>   – enable the unit at boot (returns command status)
#
# Why?
# ----
# Every automation / provisioning script touches services – this module hides
# the fiddly `systemctl …` invocations behind a predictable set of helpers.
# ==============================================================================

# ----------------------------------------------------------------------
# Guard against multiple sourcing.
# ----------------------------------------------------------------------
if [[ "${BASH_UTILS_SERVICES_LOADED:-}" == "true" ]]; then
    return
fi
readonly BASH_UTILS_SERVICES_LOADED="true"

# ----------------------------------------------------------------------
# Detect which service manager is available.
# ----------------------------------------------------------------------
#  * systemd  → `systemctl`
#  * SysV    → `service`
#  * fallback → error
# ----------------------------------------------------------------------
__services_manager() {
    if command -v systemctl >/dev/null 2>&1; then
        echo "systemd"
    elif command -v service >/dev/null 2>&1; then
        echo "sysv"
    else
        echo "none"
    fi
}
readonly -f __services_manager

# ----------------------------------------------------------------------
# service_exists <name>
#   Return 0 if a unit with the given name exists, otherwise 1.
# ----------------------------------------------------------------------
service_exists() {
    local name="${1:?missing service name}"
    local manager
    manager=$(__services_manager)

    case "$manager" in
        systemd)
            # `systemctl list-unit-files foo.service` exits 0 only when the unit
            # file exists (active, disabled, static, …).  The output is suppressed.
            systemctl list-unit-files "${name}.service" >/dev/null 2>&1
            ;;
        sysv)
            # The legacy `service` command prints usage when the service is unknown.
            # We use the exit status of the help request as an existence test.
            service "${name}" status >/dev/null 2>&1
            ;;
        *)
            log_error "No service manager found on this system"
            return 1
            ;;
    esac
}
readonly -f service_exists

# ----------------------------------------------------------------------
# service_running <name>
#   Return 0 when the service is active/running, otherwise 1.
# ----------------------------------------------------------------------
service_running() {
    local name="${1:?missing service name}"
    local manager
    manager=$(__services_manager)

    case "$manager" in
        systemd)
               if systemctl is-active --quiet "$name" >/dev/null 2>&1; then
                   return 0
               fi
               return 1
            ;;
        sysv)
            # Many SysV init scripts honour “status” and return 0 when running.
            service "$name" status >/dev/null 2>&1
            ;;
        *)
            log_error "No service manager found on this system"
            return 1
            ;;
    esac
}
readonly -f service_running

# ----------------------------------------------------------------------
# service_restart <name>
#   Restart the service.  Returns the exit status of the underlying command.
# ----------------------------------------------------------------------
service_restart() {
    local name="${1:?missing service name}"
    local manager
    manager=$(__services_manager)

    case "$manager" in
        systemd)
            systemctl restart "$name"
            ;;
        sysv)
            service "$name" restart
            ;;
        *)
            log_error "No service manager found on this system"
            return 1
            ;;
    esac
}
readonly -f service_restart

# ----------------------------------------------------------------------
# service_enable <name>
#   Enable the service to start on boot.  Returns the exit status of the
#   underlying command.
# ----------------------------------------------------------------------
service_enable() {
    local name="${1:?missing service name}"
    local manager
    manager=$(__services_manager)

    case "$manager" in
        systemd)
            systemctl enable "$name"
            ;;
        sysv)
            # SysV init does not have a universal “enable” command.  Try
            # chkconfig if it exists; otherwise warn the user.
            if command -v chkconfig >/dev/null 2>&1; then
                chkconfig "$name" on
                return $?
            else
                log_warn "Enable not supported on SysV without chkconfig"
                return 1
            fi
            ;;
        *)
            log_error "No service manager found on this system"
            return 1
            ;;
    esac
}

export -f service_exists service_running service_restart service_enable