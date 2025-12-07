#!/usr/bin/env bash
#=====================================================================
# FILESYSTEM MODULE
#=====================================================================
# Provides a collection of helper functions for dealing with files
# and directories.  The module follows the same conventions as the
# other BASH‑UTILS modules (guard against multiple sourcing, use the
# logging facilities and return non‑zero on error).

#---------------------------------------------------------------------
# Prevent multiple sourcing
#---------------------------------------------------------------------
if [[ "${BASH_UTILS_FILESYSTEM_LOADED:-}" == "true" ]]; then
    return 0
fi
readonly BASH_UTILS_FILESYSTEM_LOADED="true"

# ----------------------------------------------------------------------
# Load required dependencies (config, logging and the generic file helpers)
# ----------------------------------------------------------------------
# The path of this script (e.g. /opt/bash-utils/modules/filesystem.sh)
_BASH_UTILS_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# config must be loaded first – it defines colour handling, readonly flags,
# etc.  All other modules already source it, but we keep the explicit load
# here for clarity and in case this file is sourced directly.
source "${_BASH_UTILS_MODULE_DIR}/../modules/config.sh"

# logging provides `log_debug`, `log_error`, … – used by many helpers.
source "${_BASH_UTILS_MODULE_DIR}/../modules/logging.sh"

# The generic file helpers contain `ensure_directory`, `ensure_file`,
# `readlink_path`, `get_canonical_path`, `is_path_symlink`, etc.
source "${_BASH_UTILS_MODULE_DIR}/../modules/files.sh"


#=====================================================================
# Dependency order
#=====================================================================
#   1) config.sh      – global configuration & guard variables
#   2) logging.sh     – log_error, log_info, …
#   3) validation.sh  – optional validation helpers
#   (The main script must source the modules in the above order.)

#=====================================================================
# Temporary paths
#=====================================================================

# create_temp_file ----------------------------------------------------
# Creates a temporary file using mktemp and prints the filename.
# Returns 0 on success, 1 on failure.
create_temp_file() {
    local tmpfile
    tmpfile=$(mktemp 2>/dev/null) || {
        log_error "Failed to create temporary file"
        return 1
    }
    printf '%s\n' "$tmpfile"
}

# create_temp_dir -----------------------------------------------------
# Creates a temporary directory using mktemp -d and prints the path.
# Returns 0 on success, 1 on failure.
create_temp_dir() {
    local tmpdir
    tmpdir=$(mktemp -d 2>/dev/null) || {
        log_error "Failed to create temporary directory"
        return 1
    }
    printf '%s\n' "$tmpdir"
}

#=====================================================================
# File attribute helpers
#=====================================================================

# _stat ---------------------------------------------------------------
# Wrapper around GNU/BSD stat – picks the right format string.
# Arguments: <format> <path>
_stat() {
    local fmt=$1 path=$2
    if stat --version >/dev/null 2>&1; then          # GNU coreutils
        stat -c "$fmt" "$path"
    else                                            # macOS / BSD
        case "$fmt" in
            %s) stat -f%z "$path" ;;
            %Y) stat -f%Sm -t %s "$path" ;;
            %a) stat -f%Op "$path" ;;
            %U) stat -f%Su "$path" ;;
            %G) stat -f%Sg "$path" ;;
            *) return 1 ;;
        esac
    fi
}

# get_file_size --------------------------------------------------------
# Prints the size (in bytes) of the given file.
# Returns 0 on success, 1 on failure.
get_file_size() {
    local size
    size=$(_stat %s "$1") || {
        log_error "Unable to obtain size for '$1'"
        return 1
    }
    printf '%s\n' "$size"
}

# get_file_mod_time ----------------------------------------------------
# Prints the last modification time (epoch) of the given file.
get_file_mod_time() {
    local mtime
    mtime=$(_stat %Y "$1") || {
        log_error "Unable to obtain modification time for '$1'"
        return 1
    }
    printf '%s\n' "$mtime"
}

# get_file_perm --------------------------------------------------------
# Prints the numeric permission bits of the given file (e.g. 644).
get_file_perm() {
    local perm
    perm=$(_stat %a "$1") || {
        log_error "Unable to obtain permission for '$1'"
        return 1
    }
    printf '%s\n' "$perm"
}

# get_file_owner -------------------------------------------------------
# Prints the owner name of the given file.
get_file_owner() {
    local owner
    owner=$(_stat %U "$1") || {
        log_error "Unable to obtain owner for '$1'"
        return 1
    }
    printf '%s\n' "$owner"
}

# get_file_group -------------------------------------------------------
# Prints the group name of the given file.
get_file_group() {
    local group
    group=$(_stat %G "$1") || {
        log_error "Unable to obtain group for '$1'"
        return 1
    }
    printf '%s\n' "$group"
}

#=====================================================================
# File / directory manipulation
#=====================================================================

# copy_file ------------------------------------------------------------
# Copies source to destination preserving attributes.
copy_file() {
    cp -a "$1" "$2"
}

# move_file ------------------------------------------------------------
# Moves (renames) source to destination.
move_file() {
    mv "$1" "$2"
}

# delete_file ----------------------------------------------------------
# Removes a regular file (ignores non‑existent files).
delete_file() {
    rm -f "$1"
}

# delete_directory -----------------------------------------------------
# Recursively removes a directory tree.
delete_directory() {
    rm -rf "$1"
}

# touch_file -----------------------------------------------------------
# Updates the timestamps of a file, creating it if necessary.
touch_file() {
    touch "$1"
}

# write_file -----------------------------------------------------------
# Overwrites a file with the supplied content.
write_file() {
    printf '%s' "$2" > "$1"
}

# append_to_file -------------------------------------------------------
# Appends the supplied content to a file.
append_to_file() {
    printf '%s' "$2" >> "$1"
}

# truncate_file --------------------------------------------------------
# Truncates a file to zero length (creates it if missing).
truncate_file() {
    : > "$1"
}

# chmod_file -----------------------------------------------------------
# Changes the permission bits of a path.
chmod_file() {
    chmod "$2" "$1"
}

# chown_file -----------------------------------------------------------
# Changes the owner of a path.
chown_file() {
    chown "$2" "$1"
}

# chgrp_file -----------------------------------------------------------
# Changes the group of a path.
chgrp_file() {
    chgrp "$2" "$1"
}

# symlink_file ---------------------------------------------------------
# symlink_file <source> <link>
#   Creates (or replaces) a symbolic link $link -> $source.
#   * If $link already exists (file, dir or symlink) it is removed first.
#   * The parent directory of $link is created automatically.
#   * Errors are reported via the logging subsystem (log_error) and the
#     function returns a non‑zero status on failure.
symlink_file() {
    local src=$1
    local link=$2

    # Defensive programming – make sure we got both arguments
    if [[ -z $src || -z $link ]]; then
        log_error "symlink_file: missing arguments"
        return 1
    fi

    # Ensure the directory that will contain the link exists
    ensure_directory "$(dirname "$link")"

    # If something is already at $link (file, dir, or symlink) remove it.
    # `rm -f` works for regular files and symlinks, `rm -rf` also handles
    # the unlikely case where a directory with that name exists.
    if [[ -e $link || -L $link ]]; then
        rm -rf "$link"
    fi

    # Create the symbolic link.  Use `ln -s` directly – if it still fails we
    # let the caller see the error message.
    ln -s "$src" "$link"
}

# hardlink_file --------------------------------------------------------
# Creates a hard link pointing to TARGET.
hardlink_file() {
    ln "$1" "$2"
}

# readlink_path --------------------------------------------------------
# readlink_path <path>
#   Returns the target of a symbolic link, or an empty string if $path is not a
#   symlink.  Uses `readlink` when available; otherwise falls back to `realpath`
#   with `--relative-to` (available on most recent GNU coreutils).
readlink_path() {
    local path=$1
    if ! is_path_symlink "$path"; then
        echo ""
        return 1
    fi

    # GNU readlink works fine; on macOS the BSD version also supports `-f` for
    # canonicalisation, but we only need the raw link target here.
    readlink "$path"
}

#=====================================================================
# Path analysis helpers
#=====================================================================

# get_file_extension ---------------------------------------------------
# Returns the extension of a filename (empty if none).
get_file_extension() {
    local base=$(basename "$1")
    [[ "$base" == *.* ]] && printf '%s\n' "${base##*.}" || printf '\n'
}

# get_filename_without_extension ---------------------------------------
# Returns the filename without its final extension.
get_filename_without_extension() {
    local base=$(basename "$1")
    [[ "$base" == *.* ]] && printf '%s\n' "${base%.*}" || printf '%s\n' "$base"
}

# get_basename ---------------------------------------------------------
# Wrapper around basename.
get_basename() {
    basename "$1"
}

# get_dirname ----------------------------------------------------------
# Wrapper around dirname.
get_dirname() {
    dirname "$1"
}

# get_absolute_path ----------------------------------------------------
# Returns an absolute path (no symlinks resolved).
get_absolute_path() {
    [[ "$1" = /* ]] && printf '%s\n' "$1" || printf '%s\n' "$PWD/$1"
}

# get_canonical_path ---------------------------------------------------
# Returns a fully resolved (canonical) path.
# get_canonical_path <path>
#   Returns the absolute, symlink‑resolved (canonical) path.
#   Portable fallback when `readlink -f` is not available (e.g. macOS).
get_canonical_path() {
    local path=$1

    # Prefer GNU readlink -f when it works
    if readlink -f "$path" >/dev/null 2>&1; then
        readlink -f "$path"
        return
    fi

    # Portable implementation: cd to the directory and use `pwd -P`
    # which prints the physical directory (i.e. with symlinks resolved).
    local dir file
    dir=$(dirname "$path")
    file=$(basename "$path")

    # `cd -P` changes to the physical directory, then we prepend the file name.
    (cd -P "$dir" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$file")
}

#=====================================================================
# Path‑type predicates
#=====================================================================

is_path_writable()   { [[ -w $1 ]]; }
is_path_readable()   { [[ -r $1 ]]; }
is_path_executable() { [[ -x $1 ]]; }
is_path_hidden() {
    [[ "$(basename "$1")" == .* ]]
}
# is_path_symlink <path>
#   Returns 0 (true) if the given path is a symbolic link, 1 otherwise.
is_path_symlink() {
    local path=$1
    [[ -L $path ]]
}
is_path_directory()  { [[ -d $1 ]]; }
is_path_file()       { [[ -f $1 ]]; }
is_path_fifo()       { [[ -p $1 ]]; }
is_path_socket()     { [[ -S $1 ]]; }
is_path_block()      { [[ -b $1 ]]; }
is_path_char()       { [[ -c $1 ]]; }

# is_path_empty  – true if a regular file exists and has zero size
is_path_empty() {
    [[ -f $1 && ! -s $1 ]]
}
# is_path_nonempty – true if a regular file exists and size > 0
is_path_nonempty() {
    [[ -s $1 ]]
}

#=====================================================================
# Directory traversal helpers
#=====================================================================

# list_directory -------------------------------------------------------
# Lists the contents of a directory (excluding . and ..).
list_directory() {
    ls -A "$1"
}

# list_files_recursive ------------------------------------------------
# Recursively lists all regular files under a directory.
list_files_recursive() {
    find "$1" -type f
}

# find_files_by_name --------------------------------------------------
# Finds files with an exact name under a directory tree.
find_files_by_name() {
    find "$1" -type f -name "$2"
}

# find_files_by_pattern -----------------------------------------------
# Finds files matching a shell pattern (e.g. *.txt) under a directory tree.
find_files_by_pattern() {
    find "$1" -type f -name "$2"
}

#=====================================================================
# Content helpers
#=====================================================================

# read_file ------------------------------------------------------------
# Prints the content of a file.
read_file() {
    cat "$1"
}

#=====================================================================
# Miscellaneous helpers
#=====================================================================

# get_path_type --------------------------------------------------------
# Returns a human‑readable description of the path type.
# Uses stat %F (GNU) or falls back to a set of tests.
get_path_type() {
    if [[ -L $1 ]]; then
        printf 'symbolic link\n'
    elif [[ -d $1 ]]; then
        printf 'directory\n'
    elif [[ -f $1 ]]; then
        printf 'regular file\n'
    elif [[ -p $1 ]]; then
        printf 'fifo\n'
    elif [[ -S $1 ]]; then
        printf 'socket\n'
    elif [[ -b $1 ]]; then
        printf 'block device\n'
    elif [[ -c $1 ]]; then
        printf 'character device\n'
    else
        printf 'unknown\n'
    fi
}

export -f create_temp_file create_temp_dir
export -f get_file_size get_file_mod_time get_file_perm get_file_owner get_file_group
export -f copy_file move_file delete_file delete_directory touch_file write_file append_to_file
export -f truncate_file chmod_file chown_file chgrp_file symlink_file hardlink_file readlink_path
export -f get_file_extension get_filename_without_extension get_basename get_dirname
export -f get_absolute_path get_canonical_path
export -f is_path_writable is_path_readable is_path_executable is_path_hidden
export -f is_path_symlink is_path_directory is_path_file is_path_fifo is_path_socket is_path_block is_path_char
export -f is_path_empty is_path_nonempty
export -f list_directory list_files_recursive find_files_by_name find_files_by_pattern
export -f read_file
export -f get_path_type