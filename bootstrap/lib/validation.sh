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

    # Try HTTP/HTTPS first (works in Docker containers)
    local test_urls=("https://1.1.1.1" "https://www.google.com" "https://github.com")

    for url in "${test_urls[@]}"; do
        if command -v curl &>/dev/null; then
            if curl -s --connect-timeout 3 --max-time 5 "$url" &>/dev/null; then
                log_debug "Internet connectivity confirmed via $url (HTTP)"
                return 0
            fi
        elif command -v wget &>/dev/null; then
            if wget -q --timeout=5 --tries=1 --spider "$url" &>/dev/null; then
                log_debug "Internet connectivity confirmed via $url (HTTP)"
                return 0
            fi
        fi
    done

    # Fallback to ping if curl/wget not available
    local test_hosts=("1.1.1.1" "8.8.8.8")
    for host in "${test_hosts[@]}"; do
        if command -v ping &>/dev/null; then
            if ping -c 1 -W 2 "$host" &>/dev/null; then
                log_debug "Internet connectivity confirmed via $host (ping)"
                return 0
            fi
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

# Validate module name
# Usage: validate_module_name module_name [available_modules_array]
validate_module_name() {
    local module="$1"
    shift
    local -a available_modules=("$@")

    # Check if module name contains only allowed characters
    if [[ ! "$module" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid module name: $module (only alphanumeric, hyphens, and underscores allowed)"
        return 1
    fi

    # Check length (reasonable module name length)
    if [[ ${#module} -gt 50 ]]; then
        log_error "Module name too long: $module (max 50 characters)"
        return 1
    fi

    # If available modules list provided, check if module exists
    if [[ ${#available_modules[@]} -gt 0 ]]; then
        local found=false
        for available_module in "${available_modules[@]}"; do
            if [[ "$module" == "$available_module" ]]; then
                found=true
                break
            fi
        done

        if [[ "$found" != "true" ]]; then
            log_error "Module not found: $module"
            log_info "Available modules: ${available_modules[*]}"
            return 1
        fi
    fi

    log_debug "Module name validated: $module"
    return 0
}

# Validate URL
# Usage: validate_url url
validate_url() {
    local url="$1"

    # Check if URL is empty
    if [[ -z "$url" ]]; then
        log_error "URL cannot be empty"
        return 1
    fi

    # Only allow HTTPS URLs for security
    if [[ ! "$url" =~ ^https:// ]]; then
        log_error "URL must use HTTPS protocol: $url"
        log_info "HTTP and other protocols are not allowed for security reasons"
        return 1
    fi

    # Basic URL format validation
    # Pattern: https://domain.tld/path (domain must have at least one dot)
    if [[ ! "$url" =~ ^https://[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+(/[a-zA-Z0-9._~:/?#\[\]@!$&\'()*+,;=-]*)?$ ]]; then
        log_error "Invalid URL format: $url"
        return 1
    fi

    # Check URL length (prevent extremely long URLs)
    if [[ ${#url} -gt 2048 ]]; then
        log_error "URL too long: ${#url} characters (max 2048)"
        return 1
    fi

    # Check for suspicious patterns
    # Prevent URLs with @ (could be used for credential injection)
    if [[ "$url" =~ @ ]] && [[ ! "$url" =~ ^https://[^@]+$ ]]; then
        log_error "Suspicious URL pattern detected (contains @ in authority)"
        return 1
    fi

    # Prevent URLs with unusual port numbers that might indicate attacks
    if [[ "$url" =~ :([0-9]+)/ ]]; then
        local port="${BASH_REMATCH[1]}"
        # Only allow common HTTPS ports
        if [[ "$port" != "443" && "$port" != "8443" ]]; then
            log_warn "Non-standard HTTPS port detected: $port"
            # Don't fail, just warn - some legitimate services use non-standard ports
        fi
    fi

    log_debug "URL validated: $url"
    return 0
}

# Validate file path (prevent directory traversal)
# Usage: validate_path path
validate_path() {
    local path="$1"

    # Check if path is empty
    if [[ -z "$path" ]]; then
        log_error "Path cannot be empty"
        return 1
    fi

    # Prevent directory traversal attempts
    if [[ "$path" =~ \.\. ]]; then
        log_error "Invalid path: directory traversal detected (..) in: $path"
        return 1
    fi

    # Prevent absolute paths to sensitive directories
    local -a sensitive_dirs=(
        "/etc/shadow"
        "/etc/passwd"
        "/root"
        "/var/log/auth.log"
        "/proc"
        "/sys"
    )

    for sensitive_dir in "${sensitive_dirs[@]}"; do
        if [[ "$path" == "$sensitive_dir"* ]]; then
            log_error "Access to sensitive path denied: $path"
            return 1
        fi
    done

    log_debug "Path validated: $path"
    return 0
}

# Validate environment variable name
# Usage: validate_env_var_name name
validate_env_var_name() {
    local name="$1"

    # Environment variable names must start with letter or underscore
    # and contain only letters, numbers, and underscores
    if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        log_error "Invalid environment variable name: $name"
        return 1
    fi

    # Prevent overwriting critical system variables
    local -a protected_vars=(
        "PATH"
        "HOME"
        "USER"
        "SHELL"
        "LOGNAME"
        "LD_PRELOAD"
        "LD_LIBRARY_PATH"
    )

    for protected_var in "${protected_vars[@]}"; do
        if [[ "$name" == "$protected_var" ]]; then
            log_error "Cannot modify protected environment variable: $name"
            return 1
        fi
    done

    log_debug "Environment variable name validated: $name"
    return 0
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
export -f validate_module_name
export -f validate_url
export -f validate_path
export -f validate_env_var_name
