#!/bin/bash

#===============================================================================
# modules/system-mount.sh
#   Library that implements safe mounting/unmounting under a configurable base
#   directory.  All functions are pure Bash – they can be sourced by any script.
#
#   Dependencies (must be present on the host):
#       mount, umount, findmnt, awk
#
#   The wrapper script (scripts/system-mount.sh) sources this file and only
#   handles CLI parsing / help output.
#===============================================================================

# Prevent multiple sourcing
if [[ "${BASH_UTILS_SYSTEM_MOUNT_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_SYSTEM_MOUNT_LOADED="true"

# ---------------------------------------------------------------------------
# Configuration defaults – can be overridden by the wrapper script
# ---------------------------------------------------------------------------
MOUNT_BASE_DIR_DEFAULT="/mnt"
# The effective base directory (may be changed at runtime)
MOUNT_BASE_DIR="${MOUNT_BASE_DIR_DEFAULT}"

# ---------------------------------------------------------------------------
# Runtime flags – also set by the wrapper script
# ---------------------------------------------------------------------------
MOUNT_VERBOSE=0   # set to 1 by -v/--verbose
MOUNT_DRY_RUN=0   # set to 1 by -n/--dry-run

# ---------------------------------------------------------------------------
# Import the shared library helpers
# ---------------------------------------------------------------------------
# (the wrapper script is located in $PROJECT_ROOT/scripts, the modules in
# $PROJECT_ROOT/modules – the relative path works for both execution and testing)
source "$(dirname "${BASH_SOURCE[0]}")/../modules/logging.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../modules/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../modules/validation.sh"

# ---------------------------------------------------------------------------
# Helper: abort with a nice error message (uses the shared logging function)
# ---------------------------------------------------------------------------
mount_die() {
    log_error "$*"
    exit 1
}

# ---------------------------------------------------------------------------
# Helper: execute command with optional dry-run and verbose support
# ---------------------------------------------------------------------------
run_cmd() {
    if (( MOUNT_VERBOSE )); then
        log_info "Executing: $*"
    fi
    if (( MOUNT_DRY_RUN )); then
        log_info "DRY RUN: would execute: $*"
        return 0
    fi
    "$@"
}

# ---------------------------------------------------------------------------
# Helper: require the current UID to be 0 (sudo/root)
# ---------------------------------------------------------------------------
mount_require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        mount_die "This command requires root privileges – run with sudo or as root."
    fi
}

# ---------------------------------------------------------------------------
# Helper: ensure the configured base directory exists
# ---------------------------------------------------------------------------
mount_ensure_base_dir() {
    if [[ ! -d "${MOUNT_BASE_DIR}" ]]; then
        mount_die "Base directory does not exist: ${MOUNT_BASE_DIR}"
    fi
}

# ---------------------------------------------------------------------------
# Point‑name validation – re‑uses the generic validator from validation.sh
# ---------------------------------------------------------------------------
mount_validate_point() {
    # The generic validator only checks that a path is *relative* and does not
    # contain '.' or '..' components.  For mount points we also forbid hidden
    # directories (those starting with a dot) because they are rarely intended.
    local point="$1"
    if [[ -z "${point}" ]]; then
        mount_die "Mount point name cannot be empty."
    fi
    # Use the shared validator first
    validate_path "${point}"      # from validation.sh (fails on '/' or '..')
    # Additional rule: no leading dot
    if [[ "${point}" == .* ]]; then
        mount_die "Mount point cannot start with a dot: ${point}"
    fi
}

# ---------------------------------------------------------------------------
# Resolve a logical point (e.g. “backup”) to an absolute target path.
# ---------------------------------------------------------------------------
mount_target_path() {
    local point="$1"
    mount_validate_point "${point}"
    printf '%s/%s' "${MOUNT_BASE_DIR}" "${point}"
}

# ---------------------------------------------------------------------------
# Return true (0) if a given target directory is currently mounted.
# ---------------------------------------------------------------------------
mount_is_mounted() {
    local target="$1"
    [[ -n "${target}" && -e "${target}" ]] || return 1
    # --mountpoint checks the exact path, while --target matches parent mounts.
    findmnt -rn --mountpoint "${target}" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
#   MODE SUPPORT
# ---------------------------------------------------------------------------
# A *mode* is a named collection of mount options that can be reused across
# commands.  The default list can be extended by the user at runtime.
#
# Example:
#   --mode ro        → adds "-o ro"
#   --mode sync      → adds "-o sync"
#   --mode rw,vers=4 → adds exactly that string (same as --opts)
# ---------------------------------------------------------------------------
declare -A MOUNT_MODE_OPTS=(
    [ro]="ro"
    [rw]="rw"
    [sync]="sync"
    [async]="async"
    [default]=""
)

# Resolve a mode name to the option string; abort if the name is unknown.
mount_resolve_mode() {
    local mode_name="$1"
    local known_modes

    if [[ -z "${MOUNT_MODE_OPTS[${mode_name}]+_}" ]]; then
        known_modes="$(printf '%s ' "${!MOUNT_MODE_OPTS[@]}")"
        known_modes="${known_modes% }"
        mount_die "Unknown mount mode '${mode_name}'. Known modes: ${known_modes}"
    fi
    printf '%s' "${MOUNT_MODE_OPTS[${mode_name}]}"
}
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
#   mount command implementation
# ---------------------------------------------------------------------------
mount_do_mount() {
    local create_dir=0
    local mount_opts=""
    local mode_opt=""

    # ----- parse mount‑specific options ------------------------------------
    while (( $# )); do
        case "$1" in
            --mkdir)    create_dir=1; shift ;;
            --opts)     [[ $# -lt 2 ]] && mount_die "--opts requires a value"
                        mount_opts="$2"; shift 2 ;;
            --mode)     [[ $# -lt 2 ]] && mount_die "--mode requires a value"
                        mode_opt="$2"; shift 2 ;;
            -h|--help)  return 0 ;;            # help is printed by the wrapper
            --)         shift; break ;;
            -*)         mount_die "Unknown mount flag: $1" ;;
            *)          break ;;
        esac
    done

    [[ $# -eq 3 ]] || mount_die "mount needs: <fstype> <device> <point>"
    local fstype="$1"  device="$2" point="$3"
    local target
    target="$(mount_target_path "${point}")"

    # ----- sanity checks ----------------------------------------------------
    case "${fstype}" in
        nfs|cifs|ext4|xfs|btrfs) : ;;
        *)  log_warn "Filesystem type '${fstype}' is not in the known list – proceeding anyway."
            ;;
    esac

    if [[ ! -d "${target}" ]]; then
        if (( create_dir )); then
            run_cmd mkdir -p "${target}"
        else
            mount_die "Target directory does not exist: ${target}. Use --mkdir to create it."
        fi
    fi

    if mount_is_mounted "${target}"; then
        mount_die "Target already mounted: ${target}"
    fi

    # ----- compose final mount arguments ------------------------------------
    local -a args=(-t "${fstype}")
    # Options from --mode have lower priority than explicit --opts
    if [[ -n "${mode_opt}" ]]; then
        local mode_opts
        mode_opts="$(mount_resolve_mode "${mode_opt}")"
        # If the user also supplied --opts we merge them, otherwise we just use the mode.
        if [[ -n "${mount_opts}" ]]; then
            mount_opts="${mount_opts},${mode_opts}"
        else
            mount_opts="${mode_opts}"
        fi
    fi
    [[ -n "${mount_opts}" ]] && args+=(-o "${mount_opts}")

    # ----- execute -----------------------------------------------------------
    run_cmd mount "${args[@]}" "${device}" "${target}"
}

# ---------------------------------------------------------------------------
#   umount command implementation
# ---------------------------------------------------------------------------
mount_do_umount() {
    local lazy=0 force=0

    while (( $# )); do
        case "$1" in
            --lazy)   lazy=1; shift ;;
            --force)  force=1; shift ;;
            -h|--help) return 0 ;;
            --)        shift; break ;;
            -*)        mount_die "Unknown umount flag: $1" ;;
            *)         break ;;
        esac
    done

    [[ $# -eq 1 ]] || mount_die "umount needs: <point>"
    local point="$1"
    local target
    target="$(mount_target_path "${point}")"

    if ! mount_is_mounted "${target}"; then
        mount_die "Target is not mounted: ${target}"
    fi

    # Build the umount command according to the requested mode
    local -a cmd=(umount)
    (( lazy )) && cmd+=(--lazy)
    (( force )) && cmd+=(--force)

    run_cmd "${cmd[@]}" "${target}"
}

# ---------------------------------------------------------------------------
#   status command implementation
# ---------------------------------------------------------------------------
mount_do_status() {
    [[ $# -eq 1 ]] || mount_die "status needs a single <point>"
    local target
    target="$(mount_target_path "$1")"

    if mount_is_mounted "${target}"; then
        log_info "Mounted: ${target}"
    else
        log_info "Not mounted: ${target}"
    fi
}

# ---------------------------------------------------------------------------
#   list command implementation
# ---------------------------------------------------------------------------
mount_do_list() {
    local listed=0

    # List only the mounts that are *below* the configured base directory.
    # The output format is deliberately simple – callers can post‑process it.
    if command -v findmnt >/dev/null 2>&1; then
        findmnt -r -n -o TARGET,SOURCE,FSTYPE,OPTIONS 2>/dev/null |
            while IFS= read -r line; do
                case "$line" in
                    "${MOUNT_BASE_DIR}"*|*" ${MOUNT_BASE_DIR}"*|*" ${MOUNT_BASE_DIR}/"*)
                        log_info "${line}"
                        listed=1
                        ;;
                esac
            done
        return 0
    fi

    if [[ -r /proc/self/mounts ]]; then
        awk -v base="${MOUNT_BASE_DIR}" '
            $2 == base || index($2, base "/") == 1 {
                printf "%s %s %s %s\n", $2, $1, $3, $4
            }
        ' /proc/self/mounts | while IFS= read -r line; do
            log_info "${line}"
            listed=1
        done
        return 0
    fi

    log_error "Unable to list mounts: neither findmnt nor /proc/self/mounts is available"
    return 1
}

# ---------------------------------------------------------------------------
#   Public API – each function is deliberately prefixed with `mount_` so that
#   they do not clash with any other library symbols.
# ---------------------------------------------------------------------------
mount_set_base_dir()   { MOUNT_BASE_DIR="$1"; }
mount_get_base_dir()   { printf '%s' "${MOUNT_BASE_DIR}"; }
mount_set_verbose()    { MOUNT_VERBOSE=1; }
mount_set_dry_run()    { MOUNT_DRY_RUN=1; }

# expose the “real” actions (the wrapper script calls them)
mount_cli_mount()      { mount_do_mount "$@"; }
mount_cli_umount()     { mount_do_unmount "$@"; }   # thin alias – see below
mount_cli_status()     { mount_do_status "$@"; }
mount_cli_list()       { mount_do_list "$@"; }

# ---------------------------------------------------------------------------
# Additional convenience functions for simpler API (used by tests)
# ---------------------------------------------------------------------------
# Simple aliases without mount_ prefix for easier testing
is_mounted()           { mount_is_mounted "$@"; }
list_mounts() {
    if command -v findmnt >/dev/null 2>&1; then
        findmnt -r -n -o SOURCE,TARGET,FSTYPE,OPTIONS
        return $?
    fi

    if [[ -r /proc/self/mounts ]]; then
        awk '{ printf "%s %s %s %s\n", $1, $2, $3, $4 }' /proc/self/mounts
        return $?
    fi

    if command -v mount >/dev/null 2>&1; then
        mount
        return $?
    fi

    echo "Unable to list mounts: no supported command available" >&2
    return 1
}

# Get the mount point that contains the given path
get_mount_point() {
    local path="$1"
    local lookup_path
    local mount_point=""

    [[ -n "$path" ]] || { echo "Path required" >&2; return 1; }

    lookup_path="$path"
    while [[ ! -e "$lookup_path" ]]; do
        if [[ "$lookup_path" == "/" || "$lookup_path" == "." || -z "$lookup_path" ]]; then
            break
        fi
        lookup_path="$(dirname "$lookup_path")"
    done

    [[ -e "$lookup_path" ]] || { echo "Path does not exist: $path" >&2; return 1; }

    # Prefer findmnt when available.
    if command -v findmnt >/dev/null 2>&1; then
        mount_point="$(findmnt -rn --target "$lookup_path" --output TARGET 2>/dev/null | head -n 1)"
    fi

    # Fallback for environments where findmnt does not resolve regular files.
    if [[ -z "$mount_point" ]] && command -v df >/dev/null 2>&1; then
        mount_point="$(df -P "$lookup_path" 2>/dev/null | awk 'END { print $NF }')"
    fi

    if [[ -z "$mount_point" ]]; then
        echo "No mount point found for: $path" >&2
        return 1
    fi

    printf '%s\n' "$mount_point"
}

# Mount a tmpfs filesystem
mount_tmpfs() {
    local target="$1"
    local size="${2:-1M}"
    [[ -n "$target" ]] || { echo "Target directory required" >&2; return 1; }
    
    mount_require_root
    [[ -d "$target" ]] || { echo "Target directory does not exist: $target" >&2; return 1; }
    
    if mount_is_mounted "$target"; then
        echo "Target already mounted: $target" >&2
        return 1
    fi
    
    run_cmd mount -t tmpfs -o size="$size" tmpfs "$target"
}

# Unmount a path
unmount_path() {
    local target="$1"
    [[ -n "$target" ]] || { echo "Target path required" >&2; return 1; }
    
    mount_require_root
    
    if ! mount_is_mounted "$target"; then
        echo "Target is not mounted: $target" >&2
        return 1
    fi
    
    run_cmd umount "$target"
}

# ---------------------------------------------------------------------------
#   umount command implementation (kept separate for clarity)
# ---------------------------------------------------------------------------
mount_do_unmount() {
    local lazy=0 force=0

    while (( $# )); do
        case "$1" in
            --lazy)   lazy=1; shift ;;
            --force)  force=1; shift ;;
            -h|--help) return 0 ;;
            --)       shift; break ;;
            -*)       mount_die "Unknown umount flag: $1" ;;
            *)        break ;;
        esac
    done

    [[ $# -eq 1 ]] || mount_die "umount needs a single <point>"
    local point="$1"
    local target
    target="$(mount_target_path "${point}")"

    if ! mount_is_mounted "${target}"; then
        mount_die "Target is not mounted: ${target}"
    fi

    local -a cmd=(umount)
    (( lazy )) && cmd+=(--lazy)
    (( force )) && cmd+=(--force)

    run_cmd "${cmd[@]}" "${target}"
}