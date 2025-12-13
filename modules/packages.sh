#!/usr/bin/env bash
#=====================================================================
# packages.sh – Package manager abstraction
#=====================================================================
# A small, distro-aware wrapper around common Linux package managers.
#
# Supported managers:
#   apt (apt-get), yum, dnf, pacman, apk, zypper
#
# Quick examples:
#   pkg_update
#   pkg_install htop vim
#   pkg_installed nginx
#
# Notes:
# - This module is intended for Linux distributions that ship one of the
#   supported package managers.
# - Commands that require privileges are executed via sudo when not
#   running as root.
#=====================================================================

# ------------------------------------------------------------------
# Guard – prevent the file from being sourced more than once.
# ------------------------------------------------------------------
if [[ -n "${BASH_UTILS_PACKAGES_LOADED:-}" ]]; then
    return
fi
readonly BASH_UTILS_PACKAGES_LOADED="true"

# ------------------------------------------------------------------
# Load dependencies in the required order.
# ------------------------------------------------------------------
source "${BASH_SOURCE%/*}/config.sh"
source "${BASH_SOURCE%/*}/logging.sh"
source "${BASH_SOURCE%/*}/validation.sh"

# ------------------------------------------------------------------
# Global constants – supported package managers.
# ------------------------------------------------------------------
readonly _PKG_MANAGERS=(
    "apt"      # Debian/Ubuntu
    "yum"      # RHEL/CentOS 6
    "dnf"      # RHEL/CentOS 7+, Fedora
    "pacman"   # Arch Linux
    "apk"      # Alpine Linux
    "zypper"   # openSUSE
)

# ------------------------------------------------------------------
# Detect the package manager available on the host.
#
# Globals:
#   PKG_MANAGER – name of the detected manager
#
# Returns:
#   0  – manager found   (PKG_MANAGER is set)
#   1  – none of the supported managers are present
# ------------------------------------------------------------------
pkg_detect_manager() {
    # If a manager is already set, validate it; otherwise re-detect.
    if [[ -n "${PKG_MANAGER:-}" ]]; then
        case "$PKG_MANAGER" in
            apt)    command -v apt-get >/dev/null 2>&1 && return 0 ;;
            yum)    command -v yum >/dev/null 2>&1 && return 0 ;;
            dnf)    command -v dnf >/dev/null 2>&1 && return 0 ;;
            pacman) command -v pacman >/dev/null 2>&1 && return 0 ;;
            apk)    command -v apk >/dev/null 2>&1 && return 0 ;;
            zypper) command -v zypper >/dev/null 2>&1 && return 0 ;;
        esac
        unset PKG_MANAGER
    fi

    for mgr in "${_PKG_MANAGERS[@]}"; do
        case "$mgr" in
            apt)    command -v apt-get   >/dev/null 2>&1 && PKG_MANAGER="apt"   ;;
            yum)    command -v yum       >/dev/null 2>&1 && PKG_MANAGER="yum"   ;;
            dnf)    command -v dnf       >/dev/null 2>&1 && PKG_MANAGER="dnf"   ;;
            pacman) command -v pacman   >/dev/null 2>&1 && PKG_MANAGER="pacman";;
            apk)    command -v apk      >/dev/null 2>&1 && PKG_MANAGER="apk"   ;;
            zypper) command -v zypper   >/dev/null 2>&1 && PKG_MANAGER="zypper";;
        esac
        [[ -n "${PKG_MANAGER:-}" ]] && break
    done

    if [[ -z "${PKG_MANAGER:-}" ]]; then
        log_error "No supported package manager found on this system."
        return 1
    fi

    return 0
}

# ------------------------------------------------------------------
# Update package repositories/metadata.
#
# Returns:
#   0  – update succeeded
#   1  – update failed or unknown manager
# ------------------------------------------------------------------
pkg_update() {
    pkg_detect_manager || return 1

    local sudo_cmd=""
    [[ $EUID -ne 0 ]] && sudo_cmd="sudo"

    case "$PKG_MANAGER" in
        apt)    $sudo_cmd apt-get update ;;
        yum)    $sudo_cmd yum makecache ;;
        dnf)    $sudo_cmd dnf makecache ;;
        pacman) $sudo_cmd pacman -Sy     ;;
        apk)    $sudo_cmd apk update    ;;
        zypper) $sudo_cmd zypper refresh;;
        *)      log_error "pkg_update: unknown manager '$PKG_MANAGER'"; return 1 ;;
    esac
}

# ------------------------------------------------------------------
# Install one or more packages.
#
#   pkg_install htop vim
#
# Returns:
#   0  – all packages installed successfully
#   1  – installation failed or unknown manager
# ------------------------------------------------------------------
pkg_install() {
    [[ $# -gt 0 ]] || { log_error "pkg_install: no packages supplied"; return 1; }

    pkg_detect_manager || return 1

    local sudo_cmd=""
    [[ $EUID -ne 0 ]] && sudo_cmd="sudo"

    case "$PKG_MANAGER" in
        apt)    $sudo_cmd apt-get install -y "$@" ;;
        yum)    $sudo_cmd yum install -y "$@"   ;;
        dnf)    $sudo_cmd dnf install -y "$@"   ;;
        pacman) $sudo_cmd pacman -S --noconfirm "$@" ;;
        apk)    $sudo_cmd apk add "$@"         ;;
        zypper) $sudo_cmd zypper install -y "$@" ;;
        *)      log_error "pkg_install: unknown manager '$PKG_MANAGER'"; return 1 ;;
    esac
}

# ------------------------------------------------------------------
# Check whether a package is already installed.
#
#   pkg_installed nginx && echo "yes"
#
# Returns:
#   0  – package is installed
#   1  – package is not installed or manager unknown
# ------------------------------------------------------------------
pkg_installed() {
    [[ $# -eq 1 ]] || { log_error "pkg_installed: exactly one package name required"; return 1; }

    local pkg="$1"
    pkg_detect_manager || return 1

    case "$PKG_MANAGER" in
        apt)    dpkg -s "$pkg" >/dev/null 2>&1 ;;
        yum|dnf|zypper) rpm -q "$pkg" >/dev/null 2>&1 ;;
        pacman) pacman -Qi "$pkg" >/dev/null 2>&1 ;;
        apk)    apk info "$pkg" >/dev/null 2>&1 ;;
        *)      log_error "pkg_installed: unknown manager '$PKG_MANAGER'"; return 1 ;;
    esac
}

export -f pkg_detect_manager pkg_update pkg_install pkg_installed