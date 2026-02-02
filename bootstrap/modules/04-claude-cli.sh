#!/usr/bin/env bash

# Module: Claude CLI
# Installs Claude Code CLI and Anthropic SDK

MODULE_NAME="claude-cli"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="Claude Code CLI and Anthropic SDK"
MODULE_DEPS=("system-deps" "python" "nodejs")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

VENV_DIR="$HOME/.local/venv/openclaw"
CONFIG_DIR="$HOME/.config/claude"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    # Check if Claude CLI is installed
    if ! validate_command "claude"; then
        log_debug "Claude CLI not found"
        return 1
    fi

    # Check if Anthropic SDK is installed in venv
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate" 2>/dev/null || return 1

    if ! python3 -c "import anthropic" 2>/dev/null; then
        log_debug "Anthropic SDK not found"
        deactivate 2>/dev/null || true
        return 1
    fi

    deactivate 2>/dev/null || true

    log_debug "Claude CLI and SDK are installed"
    return 0
}

# Install the module
install() {
    log_section "Installing Claude CLI and SDK"

    # Create config directory
    log_progress "Creating Claude config directory: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
    log_success "Config directory created"

    # Install Claude Code CLI
    # Note: Installation method may vary - check official docs
    log_progress "Installing Claude Code CLI"

    # Try npm installation (adjust based on actual installation method)
    if command -v npm &>/dev/null; then
        log_info "Attempting npm installation of Claude CLI"

        # Check if there's an official npm package
        # This is a placeholder - update with actual package name when known
        if npm install -g @anthropic-ai/claude-code 2>/dev/null; then
            log_success "Claude CLI installed via npm"
        else
            log_warn "npm package not available, trying alternative installation method"

            # Alternative: Download from GitHub releases or official site
            log_progress "Downloading Claude CLI from official source"

            # Download installer to temporary file
            local install_url="https://install.claude.ai/cli"
            local claude_installer
            claude_installer=$(mktemp)

            # Ensure cleanup
            trap 'rm -f "$claude_installer"' RETURN

            log_progress "Downloading Claude CLI installer"
            if ! curl -fsSL -o "$claude_installer" "$install_url"; then
                log_error "Failed to download Claude CLI installer"
                log_info "Please install manually from: https://claude.ai/download"
                rm -f "$claude_installer"
                return 1
            fi

            # Note: Cannot verify checksum as Claude CLI installer may update frequently
            log_warn "Executing Claude CLI installer (checksum verification not available)"

            # Execute installer
            if bash "$claude_installer"; then
                log_success "Claude CLI installed"
            else
                log_error "Failed to install Claude CLI"
                log_info "Please install manually from: https://claude.ai/download"
                rm -f "$claude_installer"
                return 1
            fi

            rm -f "$claude_installer"
        fi
    else
        log_error "npm not available for Claude CLI installation"
        return 1
    fi

    # Verify Anthropic SDK is installed (should be from Python module)
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"

    log_progress "Verifying Anthropic Python SDK"

    if python3 -c "import anthropic" 2>/dev/null; then
        local version
        version=$(python3 -c "import anthropic; print(anthropic.__version__)" 2>/dev/null)
        log_success "Anthropic SDK already installed: $version"
    else
        log_progress "Installing Anthropic Python SDK"
        if ! pip install anthropic>=0.25.0 -q; then
            log_error "Failed to install Anthropic SDK"
            deactivate 2>/dev/null || true
            return 1
        fi
        log_success "Anthropic SDK installed"
    fi

    deactivate 2>/dev/null || true

    log_info "Claude CLI authentication required"
    log_info "Run 'claude login' to authenticate after bootstrap completes"

    return 0
}

# Validate installation
validate() {
    log_progress "Validating Claude CLI installation"

    local all_valid=true

    # Check Claude CLI
    if validate_command "claude"; then
        if claude --version &>/dev/null; then
            local version
            version=$(claude --version 2>&1 | head -n1)
            log_success "Claude CLI installed: $version"
        else
            log_warn "Claude CLI found but version check failed"
        fi
    else
        log_error "Claude CLI not found"
        log_info "You may need to install manually: https://claude.ai/download"
        all_valid=false
    fi

    # Check Anthropic SDK
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate" 2>/dev/null || {
        log_error "Failed to activate virtual environment"
        all_valid=false
        return 1
    }

    if python3 -c "import anthropic" 2>/dev/null; then
        local sdk_version
        sdk_version=$(python3 -c "import anthropic; print(anthropic.__version__)" 2>/dev/null)
        log_success "Anthropic SDK installed: $sdk_version"
    else
        log_error "Anthropic SDK not installed"
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
        log_success "Claude CLI validation passed"
        return 0
    else
        log_error "Claude CLI validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back Claude CLI installation"

    # Uninstall Claude CLI if installed via npm
    if command -v npm &>/dev/null; then
        npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
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
