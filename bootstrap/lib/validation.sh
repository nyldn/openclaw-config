#!/usr/bin/env bash

# Validation utilities for OpenClaw bootstrap system
# Provides functions to verify installation prerequisites and component status

# Source logger if not already loaded
if ! declare -f log_info &>/dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=logger.sh
    source "$SCRIPT_DIR/logger.sh"
fi

# Validate OS is Debian-based
# Usage: validate_os
validate_os() {
    log_debug "Validating operating system"

    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS: /etc/os-release not found"
        return 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release

    if [[ "$ID" != "debian" ]] && [[ "$ID_LIKE" != *"debian"* ]]; then
        log_error "Unsupported OS: $ID. This script requires Debian or Debian-based distributions."
        return 1
    fi

    log_debug "OS validated: $PRETTY_NAME"
    return 0
}

# Validate internet connectivity
# Usage: validate_internet
validate_internet() {
    log_debug "Checking internet connectivity"

    local test_hosts=("1.1.1.1" "8.8.8.8" "github.com")

    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 2 "$host" &>/dev/null; then
            log_debug "Internet connectivity confirmed via $host"
            return 0
        fi
    done

    log_error "No internet connectivity detected. Please check network connection."
    return 1
}

# Validate available disk space
# Usage: validate_disk_space [required_mb]
validate_disk_space() {
    local required_mb="${1:-1024}"  # Default 1GB
    local available_mb

    available_mb=$(df -m "$HOME" | awk 'NR==2 {print $4}')

    log_debug "Available disk space: ${available_mb}MB (required: ${required_mb}MB)"

    if [[ "$available_mb" -lt "$required_mb" ]]; then
        log_error "Insufficient disk space: ${available_mb}MB available, ${required_mb}MB required"
        return 1
    fi

    return 0
}

# Validate user has sudo privileges
# Usage: validate_sudo
validate_sudo() {
    log_debug "Checking sudo privileges"

    if ! sudo -n true 2>/dev/null; then
        log_warn "User does not have passwordless sudo. You may be prompted for password."
        if ! sudo true; then
            log_error "Cannot obtain sudo privileges"
            return 1
        fi
    fi

    log_debug "Sudo privileges confirmed"
    return 0
}

# Validate command exists
# Usage: validate_command command_name
validate_command() {
    local cmd="$1"

    if command -v "$cmd" &>/dev/null; then
        log_debug "Command '$cmd' found: $(command -v "$cmd")"
        return 0
    else
        log_debug "Command '$cmd' not found"
        return 1
    fi
}

# Validate package is installed (apt)
# Usage: validate_package package_name
validate_package() {
    local package="$1"

    if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
        log_debug "Package '$package' is installed"
        return 0
    else
        log_debug "Package '$package' is not installed"
        return 1
    fi
}

# Validate Python package is installed
# Usage: validate_python_package package_name
validate_python_package() {
    local package="$1"
    local python_cmd="${2:-python3}"

    if "$python_cmd" -c "import $package" 2>/dev/null; then
        local version
        version=$("$python_cmd" -c "import $package; print(getattr($package, '__version__', 'unknown'))" 2>/dev/null)
        log_debug "Python package '$package' is installed (version: $version)"
        return 0
    else
        log_debug "Python package '$package' is not installed"
        return 1
    fi
}

# Validate Node package is installed globally
# Usage: validate_node_package package_name
validate_node_package() {
    local package="$1"

    if npm list -g "$package" &>/dev/null; then
        local version
        version=$(npm list -g "$package" --depth=0 2>/dev/null | grep "$package" | awk -F@ '{print $NF}')
        log_debug "Node package '$package' is installed globally (version: $version)"
        return 0
    else
        log_debug "Node package '$package' is not installed globally"
        return 1
    fi
}

# Validate directory exists
# Usage: validate_directory path
validate_directory() {
    local dir="$1"

    if [[ -d "$dir" ]]; then
        log_debug "Directory exists: $dir"
        return 0
    else
        log_debug "Directory does not exist: $dir"
        return 1
    fi
}

# Validate file exists
# Usage: validate_file path
validate_file() {
    local file="$1"

    if [[ -f "$file" ]]; then
        log_debug "File exists: $file"
        return 0
    else
        log_debug "File does not exist: $file"
        return 1
    fi
}

# Validate version meets minimum requirement
# Usage: validate_version actual_version required_version
validate_version() {
    local actual="$1"
    local required="$2"

    if [[ "$(printf '%s\n' "$required" "$actual" | sort -V | head -n1)" == "$required" ]]; then
        log_debug "Version $actual meets requirement >= $required"
        return 0
    else
        log_debug "Version $actual does not meet requirement >= $required"
        return 1
    fi
}

# Comprehensive system validation
# Usage: validate_system
validate_system() {
    local all_valid=true

    log_section "System Validation"

    # OS check
    if validate_os; then
        log_success "Operating system: Debian-based"
    else
        log_error "Operating system validation failed"
        all_valid=false
    fi

    # Internet connectivity
    if validate_internet; then
        log_success "Internet connectivity: OK"
    else
        log_error "Internet connectivity check failed"
        all_valid=false
    fi

    # Disk space
    if validate_disk_space 2048; then
        log_success "Disk space: Sufficient (>2GB available)"
    else
        log_error "Disk space check failed"
        all_valid=false
    fi

    # Sudo privileges
    if validate_sudo; then
        log_success "Sudo privileges: OK"
    else
        log_error "Sudo privileges check failed"
        all_valid=false
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "All system checks passed"
        return 0
    else
        log_error "Some system checks failed"
        return 1
    fi
}

# Export functions
export -f validate_os
export -f validate_internet
export -f validate_disk_space
export -f validate_sudo
export -f validate_command
export -f validate_package
export -f validate_python_package
export -f validate_node_package
export -f validate_directory
export -f validate_file
export -f validate_version
export -f validate_system
