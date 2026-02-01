#!/usr/bin/env bash

# Module: OpenAI Codex CLI
# Installs OpenAI CLI and Python SDK

MODULE_NAME="codex-cli"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="OpenAI CLI and Python SDK"
MODULE_DEPS=("system-deps" "python" "nodejs")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

VENV_DIR="$HOME/.local/venv/openclaw"
CONFIG_DIR="$HOME/.config/openai"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    # Check if OpenAI CLI is installed
    if ! validate_command "openai"; then
        log_debug "OpenAI CLI not found"
        return 1
    fi

    # Check if OpenAI SDK is installed in venv
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate" 2>/dev/null || return 1

    if ! python3 -c "import openai" 2>/dev/null; then
        log_debug "OpenAI SDK not found"
        deactivate 2>/dev/null || true
        return 1
    fi

    deactivate 2>/dev/null || true

    log_debug "OpenAI CLI and SDK are installed"
    return 0
}

# Install the module
install() {
    log_section "Installing OpenAI CLI and SDK"

    # Create config directory
    log_progress "Creating OpenAI config directory: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
    log_success "Config directory created"

    # Install OpenAI CLI via npm
    log_progress "Installing OpenAI CLI via npm"

    if ! npm install -g openai-cli; then
        log_warn "Failed to install openai-cli, trying alternative package"

        # Try alternative package name
        if ! npm install -g openai; then
            log_error "Failed to install OpenAI CLI"
            log_info "You may need to install manually or use the API key directly"
            # Don't return error - CLI is optional, SDK is main requirement
        else
            log_success "OpenAI npm package installed"
        fi
    else
        log_success "OpenAI CLI installed"
    fi

    # Verify OpenAI SDK is installed (should be from Python module)
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"

    log_progress "Verifying OpenAI Python SDK"

    if python3 -c "import openai" 2>/dev/null; then
        local version
        version=$(python3 -c "import openai; print(openai.__version__)" 2>/dev/null)
        log_success "OpenAI SDK already installed: $version"
    else
        log_progress "Installing OpenAI Python SDK"
        if ! pip install openai>=1.0.0 -q; then
            log_error "Failed to install OpenAI SDK"
            deactivate 2>/dev/null || true
            return 1
        fi
        log_success "OpenAI SDK installed"
    fi

    deactivate 2>/dev/null || true

    log_info "OpenAI API key configuration required"
    log_info "Set OPENAI_API_KEY environment variable or run 'openai auth login'"

    return 0
}

# Validate installation
validate() {
    log_progress "Validating OpenAI CLI installation"

    local all_valid=true

    # Check OpenAI CLI (optional)
    if validate_command "openai"; then
        if openai --version &>/dev/null 2>&1; then
            local version
            version=$(openai --version 2>&1 | head -n1)
            log_success "OpenAI CLI installed: $version"
        else
            log_warn "OpenAI CLI found but version check failed (non-critical)"
        fi
    else
        log_warn "OpenAI CLI not found (optional - SDK is primary requirement)"
    fi

    # Check OpenAI SDK (required)
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate" 2>/dev/null || {
        log_error "Failed to activate virtual environment"
        all_valid=false
        return 1
    }

    if python3 -c "import openai" 2>/dev/null; then
        local sdk_version
        sdk_version=$(python3 -c "import openai; print(openai.__version__)" 2>/dev/null)
        log_success "OpenAI SDK installed: $sdk_version"

        # Check version meets minimum requirement
        if python3 -c "import openai; from packaging import version; assert version.parse(openai.__version__) >= version.parse('1.0.0')" 2>/dev/null; then
            log_success "OpenAI SDK version >= 1.0.0"
        else
            log_warn "OpenAI SDK version may be outdated"
        fi
    else
        log_error "OpenAI SDK not installed"
        all_valid=false
    fi

    deactivate 2>/dev/null || true

    # Check config directory
    if [[ -d "$CONFIG_DIR" ]]; then
        log_success "Config directory exists: $CONFIG_DIR"
    else
        log_warn "Config directory not found: $CONFIG_DIR"
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "OpenAI installation validation passed"
        return 0
    else
        log_error "OpenAI installation validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back OpenAI CLI installation"

    # Uninstall OpenAI CLI
    if command -v npm &>/dev/null; then
        npm uninstall -g openai-cli 2>/dev/null || true
        npm uninstall -g openai 2>/dev/null || true
    fi

    # Remove config directory
    if [[ -d "$CONFIG_DIR" ]]; then
        log_progress "Removing config directory: $CONFIG_DIR"
        rm -rf "$CONFIG_DIR"
    fi

    log_success "Rollback complete"

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
