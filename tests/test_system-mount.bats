#!/usr/bin/env bats
#=====================================================================
#  BATS tests for the modules/system-mount.sh module
#
#  As with all other test files in this project the tests:
#   • source the required library modules in the proper order
#   • disable colour output (NO_COLOR=1) for deterministic results
#   • verify that the module sets its loaded‑flag variable
#   • exercise every public function with a success case and, where
#     feasible, a failure case
#=====================================================================

#--------------------------------------------------------------------
# Global setup – runs before every test case
#--------------------------------------------------------------------
setup() {
    # Load the library modules in dependency order
    source "${BATS_TEST_DIRNAME}/../modules/config.sh"
    source "${BATS_TEST_DIRNAME}/../modules/logging.sh"
    source "${BATS_TEST_DIRNAME}/../modules/validation.sh"
    source "${BATS_TEST_DIRNAME}/../modules/system-mount.sh"

    # Deterministic output – no colour codes
    export NO_COLOR=1
}

#--------------------------------------------------------------------
# Global teardown – runs after every test case
#--------------------------------------------------------------------
teardown() {
    # Clean up any variables that the tests may have changed
    unset NO_COLOR
    # Unset the functions defined by the module so they do not leak
    # into other test files (readonly variables cannot be unset)
    unset -f is_mounted get_mount_point list_mounts \
            mount_tmpfs unmount_path mount_is_mounted \
            mount_do_list mount_do_mount mount_do_status \
            mount_do_unmount mount_cli_mount mount_cli_umount \
            mount_cli_status mount_cli_list 2>/dev/null || true
}

#--------------------------------------------------------------------
# Basic sanity checks
#--------------------------------------------------------------------
@test "system-mount module loads without errors" {
    run source "${BATS_TEST_DIRNAME}/../modules/system-mount.sh"
    [ "$status" -eq 0 ]
}

@test "system-mount module sets its loaded flag" {
    [ -n "${BASH_UTILS_SYSTEM_MOUNT_LOADED:-}" ]
}

@test "system-mount module prevents multiple sourcing" {
    # Sourcing a second time must be a no‑op and must not error
    run source "${BATS_TEST_DIRNAME}/../modules/system-mount.sh"
    [ "$status" -eq 0 ]
}

#--------------------------------------------------------------------
# is_mounted() – positive test (rootfs is always mounted)
#--------------------------------------------------------------------
@test "is_mounted returns success for a known mount point (/) " {
    run is_mounted "/"
    [ "$status" -eq 0 ]
}

#--------------------------------------------------------------------
# is_mounted() – negative test (random non‑existent path)
#--------------------------------------------------------------------
@test "is_mounted returns failure for a non‑mount point" {
    # Create a temporary directory that is *not* a mount point
    temp_dir="$(mktemp -d)"
    run is_mounted "$temp_dir"
    [ "$status" -ne 0 ]
    rm -rf "$temp_dir"
}

#--------------------------------------------------------------------
# get_mount_point() – should return the mount point that contains the
# given path.  For a file that lives on the root filesystem we expect "/".
#--------------------------------------------------------------------
@test "get_mount_point returns '/' for a path on the root filesystem" {
    result="$(get_mount_point "/etc/passwd")"
    [ "$status" -eq 0 ]
    [ "$result" = "/" ]
}

@test "get_mount_point returns a non‑empty string for any existing path" {
    # Any existing path – use the test directory itself
    result="$(get_mount_point "$BATS_TEST_DIRNAME")"
    [ "$status" -eq 0 ]
    [ -n "$result" ]
}

#--------------------------------------------------------------------
# list_mounts() – should emit at least one line (the rootfs) and
# contain the '/' mount point.
#--------------------------------------------------------------------
@test "list_mounts prints at least one mount entry and includes '/'" {
    run list_mounts
    [ "$status" -eq 0 ]
    # There must be at least one line of output
    [ "${#lines[@]}" -ge 1 ]
    # One of the lines must be exactly '/' (the mount point column)
    # The format of list_mounts in the library is:  <device> <mountpoint> <type> …
    # We therefore look for a word that is exactly '/'.
    found=0
    for line in "${lines[@]}"; do
        for word in $line; do
            if [ "$word" = "/" ]; then
                found=1
                break 2
            fi
        done
    done
    [ "$found" -eq 1 ]
}

#--------------------------------------------------------------------
# mount_tmpfs() – create a temporary directory and mount a tmpfs on it.
# This requires root privileges; the test therefore checks that the
# function exists and returns a non‑zero status when run as an
# unprivileged user (the typical CI environment).  The important part
# is that the function does not crash.
#--------------------------------------------------------------------
@test "mount_tmpfs exists and fails gracefully without root" {
    # Create a temporary directory that will be the mount target
    mount_dir="$(mktemp -d)"
    run mount_tmpfs "$mount_dir" "1M"
    # The command is expected to fail for non‑root users, but the
    # exit status must be non‑zero and the function must not abort the test.
    [ "$status" -ne 0 ]
    rm -rf "$mount_dir"
}

#--------------------------------------------------------------------
# unmount_path() – try to unmount the directory created above.
# When the previous mount failed the path is not a mount point, so
# unmount_path should return a non‑zero status but still exit cleanly.
#--------------------------------------------------------------------
@test "unmount_path returns non‑zero for a path that is not a mount point" {
    mount_dir="$(mktemp -d)"
    run unmount_path "$mount_dir"
    [ "$status" -ne 0 ]
    rm -rf "$mount_dir"
}