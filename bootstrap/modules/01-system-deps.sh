#!/usr/bin/env bash

# Module: System Dependencies
# Installs base Debian packages required by all other components

MODULE_NAME="system-deps"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="Base system packages and dependencies"
MODULE_DEPS=()

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    local required_packages=(
        "curl"
        "git"
        "build-essential"
        "sqlite3"
        "python3-dev"
        "libssl-dev"
        "ca-certificates"
    )

    for package in "${required_packages[@]}"; do
        if ! validate_package "$package"; then
            log_debug "Package $package not found"
            return 1
        fi
    done

    log_debug "All system dependencies are installed"
    return 0
}

# Install the module
install() {
    log_section "Installing System Dependencies"

    # Update package lists
    log_progress "Updating apt package lists"
    if ! sudo apt-get update -qq; then
        log_error "Failed to update package lists"
        return 1
    fi
    log_success "Package lists updated"

    # Install packages
    local packages=(
        curl
        git
        build-essential
        sqlite3
        python3-dev
        python3-pip
        python3-venv
        libssl-dev
        ca-certificates
        gnupg
        lsb-release
        wget
        software-properties-common
    )

    log_progress "Installing system packages: ${packages[*]}"

    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${packages[@]}"; then
        log_error "Failed to install system packages"
        return 1
    fi

    log_success "System packages installed successfully"

    # Configure locale
    log_progress "Configuring locale"
    if ! locale | grep -q "UTF-8"; then
        sudo locale-gen en_US.UTF-8 2>/dev/null || true
        sudo update-locale LANG=en_US.UTF-8 2>/dev/null || true
    fi
    log_success "Locale configured"

    return 0
}

# Validate installation
validate() {
    log_progress "Validating system dependencies installation"

    local required_packages=(
        "curl"
        "git"
        "build-essential"
        "sqlite3"
        "python3-dev"
        "libssl-dev"
        "ca-certificates"
    )

    local all_valid=true

    for package in "${required_packages[@]}"; do
        if validate_package "$package"; then
            log_success "Package installed: $package"
        else
            log_error "Package missing: $package"
            all_valid=false
        fi
    done

    # Check essential commands
    local commands=("curl" "git" "gcc" "sqlite3" "python3")

    for cmd in "${commands[@]}"; do
        if validate_command "$cmd"; then
            local version
            case "$cmd" in
                git)
                    version=$(git --version | awk '{print $3}')
                    ;;
                gcc)
                    version=$(gcc --version | head -n1 | awk '{print $NF}')
                    ;;
                python3)
                    version=$(python3 --version | awk '{print $2}')
                    ;;
                sqlite3)
                    version=$(sqlite3 --version | awk '{print $1}')
                    ;;
                *)
                    version=$(command -v "$cmd")
                    ;;
            esac
            log_success "Command available: $cmd ($version)"
        else
            log_error "Command missing: $cmd"
            all_valid=false
        fi
    done

    if [[ "$all_valid" == "true" ]]; then
        log_success "System dependencies validation passed"
        return 0
    else
        log_error "System dependencies validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rollback not implemented for system dependencies"
    log_warn "System packages are typically safe to keep installed"
    return 0
}

# Main execution when run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-install}" in
        check)
            check_installed
            ;;
        install)
            install
            ;;
        validate)
            validate
            ;;
        rollback)
            rollback
            ;;
        *)
            echo "Usage: $0 {check|install|validate|rollback}"
            exit 1
            ;;
    esac
fi
