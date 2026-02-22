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
# shellcheck source=../lib/package-manager.sh
source "$LIB_DIR/package-manager.sh"

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

    # Update package lists (cached)
    if ! cached_apt_update; then
        return 1
    fi

    # Preconfigure debconf to suppress interactive prompts from dependencies
    # Postfix (pulled in by some packages) asks for a mail config type — default to "No configuration"
    if command -v debconf-set-selections &>/dev/null; then
        echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections
        log_debug "Preconfigured Postfix debconf to skip interactive prompt"
    fi

    # Detect system Python version for matching -venv package
    # Debian 12 has python3.11, Ubuntu 24.04 has python3.12, etc.
    local python_minor
    python_minor=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "")

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

    # Add version-specific venv package if available (e.g. python3.11-venv, python3.12-venv)
    if [[ -n "$python_minor" ]]; then
        local versioned_venv="python${python_minor}-venv"
        if apt-cache show "$versioned_venv" &>/dev/null; then
            packages+=("$versioned_venv")
            log_debug "Adding version-specific venv package: $versioned_venv"
        else
            log_debug "Version-specific venv package $versioned_venv not found, using python3-venv"
        fi
    fi

    if ! install_packages "${packages[@]}"; then
        return 1
    fi

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
