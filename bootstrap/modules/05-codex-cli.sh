#!/usr/bin/env bash

# Module: OpenAI Codex CLI
# Installs OpenAI CLI

MODULE_NAME="codex-cli"
MODULE_VERSION="1.1.0"
MODULE_DESCRIPTION="OpenAI CLI"
MODULE_DEPS=("system-deps" "nodejs")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

CONFIG_DIR="$HOME/.config/openai"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"
    export PATH="$HOME/.local/npm-global/bin:$HOME/.local/bin:$PATH"

    # Check if OpenAI CLI is installed
    if ! validate_command "ai"; then
        log_debug "OpenAI CLI not found"
        return 1
    fi

    log_debug "OpenAI CLI is installed"
    return 0
}

# Install the module
install() {
    log_section "Installing OpenAI CLI"

    # Ensure npm global bin is in PATH for this session
    export PATH="$HOME/.local/npm-global/bin:$HOME/.local/bin:$PATH"

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
            return 1
        else
            log_success "OpenAI npm package installed"
        fi
    else
        log_success "OpenAI CLI installed"
    fi

    log_info "OpenAI API key configuration required"
    log_info "Set OPENAI_API_KEY environment variable or run 'openai auth login'"

    return 0
}

# Validate installation
validate() {
    log_progress "Validating OpenAI CLI installation"
    export PATH="$HOME/.local/npm-global/bin:$HOME/.local/bin:$PATH"

    local all_valid=true

    # Check OpenAI CLI (openai-cli npm package installs as 'ai' command)
    if validate_command "ai"; then
        log_success "OpenAI CLI installed (ai command)"
    else
        log_error "OpenAI CLI not found (expected 'ai' command)"
        all_valid=false
    fi

    # Check config directory
    if [[ -d "$CONFIG_DIR" ]]; then
        log_success "Config directory exists: $CONFIG_DIR"
    else
        log_warn "Config directory not found: $CONFIG_DIR"
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "OpenAI CLI validation passed"
        return 0
    else
        log_error "OpenAI CLI validation failed"
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
