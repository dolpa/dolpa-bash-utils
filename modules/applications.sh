#!/usr/bin/env bash
#=====================================================================
# applications.sh - Application management utilities for Bash‑Utils library
#
# This module provides utilities for installing, removing, and managing
# applications on various Linux distributions. Currently supports:
#
#   • Docker Engine installation and configuration
#   • Application presence detection
#   • Package manager integration
#   • Service management
#
# All functions use the library's logging, validation, and system detection
# capabilities to provide consistent, robust application management.
#
# The module follows the same conventions as the rest of the library:
#   • It guards against being sourced more than once.
#   • It loads its dependencies in the correct order.
#   • All public functions are documented with a short description,
#     a list of arguments and the expected return value.
#=====================================================================

# ------------------------------------------------------------------
# Guard against multiple sourcing – this pattern is used in every
# other module of the library.
# ------------------------------------------------------------------
if [[ "${BASH_UTILS_APPLICATIONS_LOADED:-}" == "true" ]]; then
    # The module has already been sourced – exit silently.
    return 0
fi
readonly BASH_UTILS_APPLICATIONS_LOADED="true"

# ------------------------------------------------------------------
# Load required modules – config.sh must be first, then logging,
# validation, system, utils, and exec for various operations.
# ------------------------------------------------------------------
# shellcheck source=./modules/config.sh
source "${_BASH_UTILS_MODULE_DIR}/../modules/config.sh"
# shellcheck source=./modules/logging.sh
source "${_BASH_UTILS_MODULE_DIR}/../modules/logging.sh"
# shellcheck source=./modules/validation.sh
source "${_BASH_UTILS_MODULE_DIR}/../modules/validation.sh"
# shellcheck source=./modules/system.sh
source "${_BASH_UTILS_MODULE_DIR}/../modules/system.sh"
# shellcheck source=./modules/utils.sh
source "${_BASH_UTILS_MODULE_DIR}/../modules/utils.sh"
# shellcheck source=./modules/filesystem.sh
source "${_BASH_UTILS_MODULE_DIR}/../modules/filesystem.sh"
# shellcheck source=./modules/exec.sh
source "${_BASH_UTILS_MODULE_DIR}/../modules/exec.sh"
# shellcheck source=./modules/network.sh
source "${_BASH_UTILS_MODULE_DIR}/../modules/network.sh"

#=====================================================================
# INTERNAL HELPER FUNCTIONS
#=====================================================================

#---------------------------------------------------------------------
# _apps_require_root()
#   Internal helper – checks if running as root for system operations.
#   Most application installations require root privileges.
#---------------------------------------------------------------------
_apps_require_root() {
    if ! is_root; then
        log_error "This operation requires root privileges. Please run with sudo."
        return 1
    fi
    return 0
}

#---------------------------------------------------------------------
# _apps_detect_package_manager()
#   Internal helper – detects the available package manager.
#   Returns the package manager command name.
#---------------------------------------------------------------------
_apps_detect_package_manager() {
    local pm=""
    if command_exists "apt-get"; then
        pm="apt"
    elif command_exists "dnf"; then
        pm="dnf"
    elif command_exists "yum"; then
        pm="yum"
    elif command_exists "pacman"; then
        pm="pacman"
    elif command_exists "zypper"; then
        pm="zypper"
    else
        log_error "No supported package manager found (apt, dnf, yum, pacman, zypper)."
        return 1
    fi
    printf "%s" "${pm}"
    return 0
}

#---------------------------------------------------------------------
# _apps_remove_packages()
#   Internal helper – removes packages using detected package manager.
#   Arguments:
#       $@  – package names to remove
#---------------------------------------------------------------------
_apps_remove_packages() {
    local packages=("$@")
    local pm
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_debug "No packages specified for removal."
        return 0
    fi
    
    pm=$(_apps_detect_package_manager) || return 1
    
    log_info "Removing conflicting packages: ${packages[*]}"
    
    local cmd_args=()
    case "${pm}" in
        "apt")
            cmd_args=("apt-get" "-y" "remove")
            ;;
        "dnf"|"yum")
            cmd_args=("${pm}" "-y" "remove")
            ;;
        "pacman")
            cmd_args=("pacman" "-R" "--noconfirm")
            ;;
        "zypper")
            cmd_args=("zypper" "remove" "-y")
            ;;
        *)
            log_error "Unsupported package manager: ${pm}"
            return 1
            ;;
    esac
    
    for package in "${packages[@]}"; do
        log_debug "Attempting to remove package: ${package}"
        if exec_run "${cmd_args[@]}" "${package}"; then
            log_info "Successfully removed: ${package}"
        else
            log_warning "Package ${package} was not installed or removal failed."
        fi
    done
    
    return 0
}

#---------------------------------------------------------------------
# _apps_install_packages()
#   Internal helper – installs packages using detected package manager.
#   Arguments:
#       $@  – package names to install
#---------------------------------------------------------------------
_apps_install_packages() {
    local packages=("$@")
    local pm
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_error "No packages specified for installation."
        return 1
    fi
    
    pm=$(_apps_detect_package_manager) || return 1
    
    log_info "Installing packages: ${packages[*]}"
    
    local cmd_args=()
    case "${pm}" in
        "apt")
            # Update package index first for apt
            log_info "Updating package index..."
            exec_run "apt-get" "update" || {
                log_error "Failed to update package index"
                return 1
            }
            cmd_args=("apt-get" "-y" "install")
            ;;
        "dnf"|"yum")
            cmd_args=("${pm}" "-y" "install")
            ;;
        "pacman")
            cmd_args=("pacman" "-S" "--noconfirm")
            ;;
        "zypper")
            cmd_args=("zypper" "install" "-y")
            ;;
        *)
            log_error "Unsupported package manager: ${pm}"
            return 1
            ;;
    esac
    
    if exec_run "${cmd_args[@]}" "${packages[@]}"; then
        log_success "Successfully installed packages: ${packages[*]}"
        return 0
    else
        log_error "Failed to install packages: ${packages[*]}"
        return 1
    fi
}

#=====================================================================
# PUBLIC FUNCTIONS
#=====================================================================

#---------------------------------------------------------------------
# app_is_installed()
#   Check if an application is installed and available.
#
#   Arguments:
#       $1  – application name or command to check
#
#   Returns:
#       0  – application is installed and available
#       1  – application is not installed
#
#   Side effects:
#       Logs debug information about the check result.
#---------------------------------------------------------------------
app_is_installed() {
    local app="${1:-}"
    
    if [[ -z "${app}" ]]; then
        log_error "app_is_installed: missing required argument <app>."
        return 1
    fi
    
    if command_exists "${app}"; then
        log_debug "Application '${app}' is installed and available."
        return 0
    else
        log_debug "Application '${app}' is not installed."
        return 1
    fi
}

#---------------------------------------------------------------------
# app_install_docker()
#   Install Docker Engine on supported Linux distributions.
#   This function handles the complete Docker installation process including
#   repository setup, conflicting package removal, and service configuration.
#
#   Arguments:   none
#
#   Returns:
#       0  – Docker installation succeeded
#       1  – Docker installation failed
#
#   Side effects:
#       - Requires root privileges
#       - Modifies system packages and repositories
#       - Configures and starts Docker service
#       - Adds current user to docker group
#       - Logs all installation steps
#---------------------------------------------------------------------
app_install_docker() {
    # Check prerequisites
    _apps_require_root || return 1
    
    log_info "Starting Docker installation process..."
    
    # Get OS information
    local os_name
    os_name=$(get_os_name) || {
        log_error "Could not determine operating system."
        return 1
    }
    
    log_info "Detected OS: ${os_name}"
    
    # Check if Docker is already installed
    if app_is_installed "docker"; then
        log_warning "Docker is already installed. Use app_remove_docker() to reinstall."
        return 0
    fi
    
    # Step 1: Remove conflicting packages
    log_info "Step 1: Removing conflicting packages..."
    local conflicting_packages=(
        "docker.io" "docker-doc" "docker-compose" "docker-compose-v2" 
        "podman-docker" "containerd" "runc"
    )
    _apps_remove_packages "${conflicting_packages[@]}"
    
    # Step 2: Setup Docker repository
    log_info "Step 2: Setting up Docker repository..."
    local pm
    pm=$(_apps_detect_package_manager) || return 1
    
    case "${pm}" in
        "apt")
            _apps_setup_docker_repo_apt || return 1
            ;;
        "dnf"|"yum")
            _apps_setup_docker_repo_rhel || return 1
            ;;
        *)
            log_error "Docker installation not yet supported for package manager: ${pm}"
            return 1
            ;;
    esac
    
    # Step 3: Install Docker packages
    log_info "Step 3: Installing Docker packages..."
    local docker_packages=(
        "docker-ce" "docker-ce-cli" "containerd.io" 
        "docker-buildx-plugin" "docker-compose-plugin"
    )
    _apps_install_packages "${docker_packages[@]}" || return 1
    
    # Step 4: Enable and start Docker service
    log_info "Step 4: Configuring Docker service..."
    if ! _apps_configure_docker_service; then
        log_error "Failed to configure Docker service."
        return 1
    fi
    
    # Step 5: Add user to docker group
    log_info "Step 5: Adding user to docker group..."
    local current_user="${SUDO_USER:-${USER}}"
    if [[ -n "${current_user}" && "${current_user}" != "root" ]]; then
        if exec_run "usermod" "-aG" "docker" "${current_user}"; then
            log_success "User '${current_user}' added to docker group."
            log_warning "User needs to log out and log back in for group changes to take effect."
        else
            log_warning "Failed to add user '${current_user}' to docker group."
        fi
    fi
    
    # Step 6: Verify installation
    log_info "Step 6: Verifying Docker installation..."
    if app_is_installed "docker" && exec_run "systemctl" "is-active" "--quiet" "docker"; then
        log_success "Docker installation completed successfully!"
        log_info "Docker version: $(docker --version 2>/dev/null || echo 'Version check failed')"
        return 0
    else
        log_error "Docker installation verification failed."
        return 1
    fi
}

#---------------------------------------------------------------------
# app_remove_docker()
#   Remove Docker Engine and related components from the system.
#
#   Arguments:   none
#
#   Returns:
#       0  – Docker removal succeeded
#       1  – Docker removal failed
#
#   Side effects:
#       - Requires root privileges
#       - Stops and disables Docker service
#       - Removes Docker packages
#       - Logs all removal steps
#---------------------------------------------------------------------
app_remove_docker() {
    _apps_require_root || return 1
    
    log_info "Starting Docker removal process..."
    
    # Check if Docker is installed
    if ! app_is_installed "docker"; then
        log_info "Docker is not installed."
        return 0
    fi
    
    # Stop and disable Docker service
    log_info "Stopping Docker service..."
    exec_run "systemctl" "stop" "docker" || log_warning "Failed to stop Docker service."
    exec_run "systemctl" "disable" "docker" || log_warning "Failed to disable Docker service."
    
    # Remove Docker packages
    log_info "Removing Docker packages..."
    local docker_packages=(
        "docker-ce" "docker-ce-cli" "containerd.io" 
        "docker-buildx-plugin" "docker-compose-plugin"
    )
    _apps_remove_packages "${docker_packages[@]}"
    
    log_success "Docker removal completed."
    return 0
}

#=====================================================================
# INTERNAL DOCKER SETUP FUNCTIONS
#=====================================================================

#---------------------------------------------------------------------
# _apps_setup_docker_repo_apt()
#   Internal helper – setup Docker repository for Debian/Ubuntu systems.
#---------------------------------------------------------------------
_apps_setup_docker_repo_apt() {
    log_debug "Setting up Docker repository for APT..."
    
    # Install prerequisites
    _apps_install_packages "ca-certificates" "curl" "gnupg" || return 1
    
    # Create keyrings directory
    if ! exec_run "install" "-m" "0755" "-d" "/etc/apt/keyrings"; then
        log_error "Failed to create keyrings directory."
        return 1
    fi
    
    # Get OS ID for repository URL
    local os_id=""
    if [[ -f /etc/os-release ]]; then
        os_id=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
    fi
    
    if [[ -z "${os_id}" ]]; then
        log_error "Could not determine OS ID for repository setup."
        return 1
    fi
    
    # Download and add Docker GPG key
    log_debug "Adding Docker GPG key..."
    if ! download_file "https://download.docker.com/linux/${os_id}/gpg" "/etc/apt/keyrings/docker.asc"; then
        log_error "Failed to download Docker GPG key."
        return 1
    fi
    
    # Set proper permissions on GPG key
    exec_run "chmod" "a+r" "/etc/apt/keyrings/docker.asc" || {
        log_error "Failed to set GPG key permissions."
        return 1
    }
    
    # Add Docker repository
    log_debug "Adding Docker repository..."
    local arch
    arch=$(exec_run_capture stdout stderr "dpkg" "--print-architecture") || {
        log_error "Failed to determine system architecture."
        return 1
    }
    
    local version_codename=""
    if [[ -f /etc/os-release ]]; then
        version_codename=$(grep "VERSION_CODENAME=" /etc/os-release | cut -d= -f2 | tr -d '"')
    fi
    
    if [[ -z "${version_codename}" ]]; then
        log_error "Could not determine version codename for repository setup."
        return 1
    fi
    
    local repo_line="deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${os_id} ${version_codename} stable"
    
    if printf "%s\n" "${repo_line}" > /etc/apt/sources.list.d/docker.list; then
        log_debug "Docker repository added successfully."
    else
        log_error "Failed to add Docker repository."
        return 1
    fi
    
    # Update package index
    log_debug "Updating package index..."
    exec_run "apt-get" "update" || {
        log_error "Failed to update package index after adding Docker repository."
        return 1
    }
    
    return 0
}

#---------------------------------------------------------------------
# _apps_setup_docker_repo_rhel()
#   Internal helper – setup Docker repository for RHEL/CentOS/Fedora systems.
#---------------------------------------------------------------------
_apps_setup_docker_repo_rhel() {
    log_debug "Setting up Docker repository for RHEL-based systems..."
    
    # Install prerequisites
    _apps_install_packages "yum-utils" || return 1
    
    # Add Docker repository
    log_debug "Adding Docker repository..."
    if exec_run "yum-config-manager" "--add-repo" "https://download.docker.com/linux/centos/docker-ce.repo"; then
        log_debug "Docker repository added successfully."
        return 0
    else
        log_error "Failed to add Docker repository."
        return 1
    fi
}

#---------------------------------------------------------------------
# _apps_configure_docker_service()
#   Internal helper – configure and start Docker service.
#---------------------------------------------------------------------
_apps_configure_docker_service() {
    log_debug "Configuring Docker service..."
    
    # Enable Docker service
    if ! exec_run "systemctl" "enable" "docker"; then
        log_error "Failed to enable Docker service."
        return 1
    fi
    
    # Start Docker service
    if ! exec_run "systemctl" "start" "docker"; then
        log_error "Failed to start Docker service."
        return 1
    fi
    
    # Configure Docker daemon for remote access (optional)
    log_debug "Configuring Docker daemon..."
    if ! [[ -d "/etc/docker" ]]; then
        exec_run "mkdir" "-p" "/etc/docker" || {
            log_warning "Failed to create Docker configuration directory."
        }
    fi
    
    # Create daemon configuration
    local daemon_config='{
  "hosts": ["unix:///var/run/docker.sock", "tcp://127.0.0.1:2375"]
}'
    
    if printf "%s\n" "${daemon_config}" > /etc/docker/daemon.json; then
        log_debug "Docker daemon configuration created."
    else
        log_warning "Failed to create Docker daemon configuration."
    fi
    
    # Modify systemd service file to remove conflicting -H flag
    if [[ -f "/lib/systemd/system/docker.service" ]]; then
        log_debug "Updating Docker systemd service configuration..."
        if exec_run "cp" "/lib/systemd/system/docker.service" "/etc/systemd/system/"; then
            exec_run "sed" "-i" "s/ -H fd:\\/\\/\\///g" "/etc/systemd/system/docker.service" || {
                log_warning "Failed to update Docker service configuration."
            }
            exec_run "systemctl" "daemon-reload" || {
                log_warning "Failed to reload systemd daemon."
            }
            exec_run "systemctl" "restart" "docker" || {
                log_warning "Failed to restart Docker service after configuration."
            }
        fi
    fi
    
    return 0
}

# Export public functions
export -f app_is_installed app_install_docker app_remove_docker

#=====================================================================
# END OF FILE
#=====================================================================