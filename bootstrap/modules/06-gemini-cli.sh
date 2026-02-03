#!/usr/bin/env bash

# Module: Gemini CLI
# Installs Google Gemini CLI and SDK

MODULE_NAME="gemini-cli"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="Google Gemini CLI and SDK"
MODULE_DEPS=("system-deps" "python" "nodejs")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

VENV_DIR="$HOME/.local/venv/openclaw"
CONFIG_DIR="$HOME/.config/gemini"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    # Check if Gemini SDK is installed in venv (CLI is optional)
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate" 2>/dev/null || return 1

    if ! python3 -c "import google.generativeai" 2>/dev/null; then
        log_debug "Gemini SDK not found"
        deactivate 2>/dev/null || true
        return 1
    fi

    deactivate 2>/dev/null || true

    log_debug "Gemini SDK is installed"
    return 0
}

# Install the module
install() {
    log_section "Installing Gemini CLI and SDK"

    # Create config directory
    log_progress "Creating Gemini config directory: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
    log_success "Config directory created"

    # Gemini CLI is distributed via npx (no global install required)
    log_info "Gemini CLI is available via: npx @google/gemini-cli"
    log_info "Python SDK remains the primary programmatic interface"

    if ! command -v npx &>/dev/null; then
        log_warn "npx not found; Gemini CLI won't be available"
    fi

    # Install Gemini SDK
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"

    log_progress "Verifying Google Generative AI SDK"

    if python3 -c "import google.generativeai" 2>/dev/null; then
        local version
        version=$(python3 -c "import google.generativeai as genai; print(genai.__version__)" 2>/dev/null)
        log_success "Google Generative AI SDK already installed: $version"
    else
        log_progress "Installing Google Generative AI Python SDK"
        if ! pip install google-generativeai>=0.3.0 -q; then
            log_error "Failed to install Google Generative AI SDK"
            deactivate 2>/dev/null || true
            return 1
        fi
        log_success "Google Generative AI SDK installed"
    fi

    deactivate 2>/dev/null || true

    log_info "Gemini API key configuration required"
    log_info "Set GOOGLE_API_KEY environment variable in .env file"
    log_info "Get your API key from: https://makersuite.google.com/app/apikey"

    return 0
}

# Validate installation
validate() {
    log_progress "Validating Gemini installation"

    local all_valid=true

    # Check Gemini CLI (optional)
    if validate_command "gemini"; then
        log_success "Gemini CLI found"
    elif command -v npx &>/dev/null; then
        log_info "Gemini CLI available via npx @google/gemini-cli"
    else
        log_info "Gemini CLI not found (optional - SDK is primary requirement)"
    fi

    # Check Google Generative AI SDK (required)
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate" 2>/dev/null || {
        log_error "Failed to activate virtual environment"
        all_valid=false
        return 1
    }

    if python3 -c "import google.generativeai" 2>/dev/null; then
        local sdk_version
        sdk_version=$(python3 -c "import google.generativeai as genai; print(genai.__version__)" 2>/dev/null)
        log_success "Google Generative AI SDK installed: $sdk_version"

        # Test basic import
        if python3 -c "import google.generativeai as genai; genai.configure" 2>/dev/null; then
            log_success "SDK can be configured successfully"
        else
            log_warn "SDK import successful but configuration may need API key"
        fi
    else
        log_error "Google Generative AI SDK not installed"
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
        log_success "Gemini installation validation passed"
        return 0
    else
        log_error "Gemini installation validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back Gemini installation"

    # Uninstall CLI if installed globally
    if command -v npm &>/dev/null; then
        npm uninstall -g @google/gemini-cli 2>/dev/null || true
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
