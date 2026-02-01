#!/usr/bin/env bash

# Module: Python Environment
# Sets up Python 3.9+ runtime and package management

MODULE_NAME="python"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="Python 3.9+ runtime and package management"
MODULE_DEPS=("system-deps")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

VENV_DIR="$HOME/.local/venv/openclaw"
MIN_PYTHON_VERSION="3.9"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    # Check Python version
    if ! validate_command "python3"; then
        return 1
    fi

    local python_version
    python_version=$(python3 --version 2>&1 | awk '{print $2}')

    if ! validate_version "$python_version" "$MIN_PYTHON_VERSION"; then
        log_debug "Python version $python_version < $MIN_PYTHON_VERSION"
        return 1
    fi

    # Check if venv exists
    if [[ ! -d "$VENV_DIR" ]]; then
        log_debug "Virtual environment not found"
        return 1
    fi

    log_debug "Python environment is installed"
    return 0
}

# Install the module
install() {
    log_section "Installing Python Environment"

    # Check current Python version
    local current_version
    current_version=$(python3 --version 2>&1 | awk '{print $2}')

    log_info "Current Python version: $current_version"

    # Check if we need to install a newer Python
    if ! validate_version "$current_version" "$MIN_PYTHON_VERSION"; then
        log_warn "Python $current_version < $MIN_PYTHON_VERSION, attempting to install Python 3.9+"

        # Add deadsnakes PPA for newer Python versions
        log_progress "Adding deadsnakes PPA"
        if ! sudo add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null; then
            log_error "Failed to add deadsnakes PPA"
            return 1
        fi

        sudo apt-get update -qq

        log_progress "Installing Python 3.9"
        if ! sudo apt-get install -y -qq python3.9 python3.9-venv python3.9-dev; then
            log_error "Failed to install Python 3.9"
            return 1
        fi

        # Update alternatives to use Python 3.9
        sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1
        log_success "Python 3.9 installed"
    else
        log_success "Python version meets requirements"
    fi

    # Install pip if not available
    if ! validate_command "pip3"; then
        log_progress "Installing pip"
        if ! sudo apt-get install -y -qq python3-pip; then
            log_error "Failed to install pip"
            return 1
        fi
        log_success "pip installed"
    fi

    # Create virtual environment
    log_progress "Creating virtual environment at $VENV_DIR"
    mkdir -p "$(dirname "$VENV_DIR")"

    if ! python3 -m venv "$VENV_DIR"; then
        log_error "Failed to create virtual environment"
        return 1
    fi
    log_success "Virtual environment created"

    # Activate venv and upgrade pip
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"

    log_progress "Upgrading pip in virtual environment"
    if ! pip install --upgrade pip setuptools wheel -q; then
        log_error "Failed to upgrade pip"
        return 1
    fi
    log_success "pip upgraded"

    # Install Python packages
    local packages=(
        "openai>=1.0.0"
        "anthropic>=0.25.0"
        "google-generativeai>=0.3.0"
        "rank-bm25>=0.2.2"
        "pyyaml>=6.0"
        "python-dotenv>=1.0.0"
        "requests>=2.31.0"
        "numpy>=1.24.0"
    )

    log_progress "Installing Python packages: ${packages[*]}"

    if ! pip install "${packages[@]}" -q; then
        log_error "Failed to install Python packages"
        return 1
    fi

    log_success "Python packages installed"

    # Install development tools
    log_progress "Installing development tools (virtualenv, pipx)"
    if ! pip install virtualenv pipx -q; then
        log_error "Failed to install development tools"
        return 1
    fi
    log_success "Development tools installed"

    # Add venv activation to .bashrc if not present
    local bashrc="$HOME/.bashrc"
    local venv_activate="source $VENV_DIR/bin/activate"

    if ! grep -q "$venv_activate" "$bashrc" 2>/dev/null; then
        log_progress "Adding virtual environment activation to .bashrc"
        {
            echo ""
            echo "# OpenClaw Python virtual environment"
            echo "$venv_activate"
        } >> "$bashrc"
        log_success "Added to .bashrc"
    fi

    deactivate 2>/dev/null || true

    return 0
}

# Validate installation
validate() {
    log_progress "Validating Python environment installation"

    local all_valid=true

    # Check Python version
    if validate_command "python3"; then
        local version
        version=$(python3 --version 2>&1 | awk '{print $2}')

        if validate_version "$version" "$MIN_PYTHON_VERSION"; then
            log_success "Python version: $version (>= $MIN_PYTHON_VERSION)"
        else
            log_error "Python version $version < $MIN_PYTHON_VERSION"
            all_valid=false
        fi
    else
        log_error "Python3 command not found"
        all_valid=false
    fi

    # Check virtual environment
    if [[ -d "$VENV_DIR" ]]; then
        log_success "Virtual environment exists: $VENV_DIR"
    else
        log_error "Virtual environment not found: $VENV_DIR"
        all_valid=false
    fi

    # Check packages in venv
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate" 2>/dev/null || {
        log_error "Failed to activate virtual environment"
        all_valid=false
        return 1
    }

    local packages=("openai" "anthropic" "google.generativeai" "rank_bm25" "yaml" "dotenv")

    for package in "${packages[@]}"; do
        local import_name="$package"
        # Handle special cases
        [[ "$package" == "yaml" ]] && import_name="yaml"
        [[ "$package" == "dotenv" ]] && import_name="dotenv"

        if python3 -c "import $import_name" 2>/dev/null; then
            local version
            version=$(python3 -c "import $import_name; print(getattr($import_name, '__version__', 'unknown'))" 2>/dev/null)
            log_success "Package installed: $package ($version)"
        else
            log_error "Package missing: $package"
            all_valid=false
        fi
    done

    deactivate 2>/dev/null || true

    if [[ "$all_valid" == "true" ]]; then
        log_success "Python environment validation passed"
        return 0
    else
        log_error "Python environment validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back Python environment installation"

    if [[ -d "$VENV_DIR" ]]; then
        log_progress "Removing virtual environment: $VENV_DIR"
        rm -rf "$VENV_DIR"
        log_success "Virtual environment removed"
    fi

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
