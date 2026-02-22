#!/usr/bin/env bash

# Module: OpenAI Codex CLI
# Installs OpenAI Codex CLI (@openai/codex)

MODULE_NAME="codex-cli"
MODULE_VERSION="2.0.0"
MODULE_DESCRIPTION="OpenAI Codex CLI"
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

    if validate_command "codex"; then
        log_debug "Codex CLI is installed"
        return 0
    fi

    log_debug "Codex CLI not found"
    return 1
}

# Install the module
install() {
    log_section "Installing OpenAI Codex CLI"

    # Ensure npm global bin is in PATH for this session
    export PATH="$HOME/.local/npm-global/bin:$HOME/.local/bin:$PATH"

    # Create config directory
    log_progress "Creating OpenAI config directory: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
    log_success "Config directory created"

    # Remove stale openai-cli package if present
    if npm ls -g openai-cli &>/dev/null; then
        log_progress "Removing stale openai-cli package..."
        npm uninstall -g openai-cli --silent 2>/dev/null || true
    fi

    # Install Codex CLI via npm
    log_progress "Installing @openai/codex via npm..."
    if npm install -g @openai/codex; then
        local version
        version=$(codex --version 2>/dev/null || echo "unknown")
        log_success "Codex CLI installed: $version"
    else
        log_error "Failed to install @openai/codex"
        return 1
    fi

    log_info "OpenAI API key configuration required"
    log_info "Set OPENAI_API_KEY environment variable"
    log_info "Run 'codex' to start an interactive session"

    return 0
}

# Validate installation
validate() {
    log_progress "Validating Codex CLI installation"
    export PATH="$HOME/.local/npm-global/bin:$HOME/.local/bin:$PATH"

    local all_valid=true

    # Check Codex CLI
    if validate_command "codex"; then
        local version
        version=$(codex --version 2>/dev/null || echo "unknown")
        log_success "Codex CLI installed: $version"
    else
        log_error "Codex CLI not found (expected 'codex' command)"
        all_valid=false
    fi

    # Check config directory
    if [[ -d "$CONFIG_DIR" ]]; then
        log_success "Config directory exists: $CONFIG_DIR"
    else
        log_warn "Config directory not found: $CONFIG_DIR"
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "Codex CLI validation passed"
        return 0
    else
        log_error "Codex CLI validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back Codex CLI installation"

    if command -v npm &>/dev/null; then
        npm uninstall -g @openai/codex 2>/dev/null || true
        npm uninstall -g openai-cli 2>/dev/null || true
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
