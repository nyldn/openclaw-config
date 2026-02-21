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
# shellcheck source=../lib/secure-download.sh
source "$LIB_DIR/secure-download.sh"

VENV_DIR="$HOME/.local/venv/openclaw"
CONFIG_DIR="$HOME/.config/claude"
CLAUDE_INSTALL_URL="https://claude.ai/install.sh"

ensure_claude_path() {
    local -a candidates=(
        "$HOME/.claude/bin/claude"
        "$HOME/.local/bin/claude"
        "/usr/local/bin/claude"
        "/opt/homebrew/bin/claude"
    )

    local candidate
    for candidate in "${candidates[@]}"; do
        if [[ -x "$candidate" ]]; then
            local claude_dir
            claude_dir=$(dirname "$candidate")

            if [[ ":$PATH:" != *":$claude_dir:"* ]]; then
                export PATH="$claude_dir:$PATH"
            fi

            local shell_rc="$HOME/.bashrc"
            if [[ -f "$HOME/.zshrc" ]]; then
                shell_rc="$HOME/.zshrc"
            fi

            if ! grep -q "openclaw-claude-path" "$shell_rc" 2>/dev/null; then
                {
                    echo ""
                    echo "# openclaw-claude-path"
                    echo "export PATH=\"$claude_dir:\$PATH\""
                } >> "$shell_rc"
            fi

            log_success "Found Claude CLI at: $candidate"
            return 0
        fi
    done

    return 1
}

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    # Check if Claude CLI is installed
    export PATH="$HOME/.local/bin:$HOME/.claude/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
    if ! validate_command "claude"; then
        if ! ensure_claude_path; then
            log_debug "Claude CLI not found"
            return 1
        fi
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
    log_progress "Installing Claude Code CLI"

    # Prefer official install methods
    if command -v claude &>/dev/null; then
        log_success "Claude CLI already available"
    else
        if [[ "$(uname)" == "Darwin" ]]; then
            if command -v brew &>/dev/null; then
                log_info "Installing Claude Code via Homebrew cask"
                if brew install --cask claude-code; then
                    log_success "Claude CLI installed via Homebrew"
                else
                    log_error "Homebrew install failed"
                    return 1
                fi
            else
                log_warn "Homebrew not found; using official install script"
                local claude_installer
                claude_installer=$(mktemp)
                trap 'rm -f "$claude_installer"' RETURN

                if download_with_verification "$CLAUDE_INSTALL_URL" "$claude_installer"; then
                    log_warn "Downloaded installer hash: $(sha256sum "$claude_installer" 2>/dev/null || shasum -a 256 "$claude_installer" | awk '{print $1}')"
                    if bash "$claude_installer"; then
                        log_success "Claude CLI installed via install script"
                    else
                        log_error "Claude CLI install script failed"
                        log_info "Please install manually from: https://claude.ai/download"
                        return 1
                    fi
                else
                    log_error "Failed to download Claude CLI installer"
                    log_info "Please install manually from: https://claude.ai/download"
                    return 1
                fi
            fi
        else
            log_info "Installing Claude Code via official install script"
            local claude_installer
            claude_installer=$(mktemp)
            trap 'rm -f "$claude_installer"' RETURN

            if download_with_verification "$CLAUDE_INSTALL_URL" "$claude_installer"; then
                log_warn "Downloaded installer hash: $(sha256sum "$claude_installer" 2>/dev/null || shasum -a 256 "$claude_installer" | awk '{print $1}')"
                if bash "$claude_installer"; then
                    log_success "Claude CLI installed via install script"
                else
                    log_error "Claude CLI install script failed"
                    log_info "Please install manually from: https://claude.ai/download"
                    return 1
                fi
            else
                log_error "Failed to download Claude CLI installer"
                log_info "Please install manually from: https://claude.ai/download"
                return 1
            fi
        fi
    fi

    # Ensure PATH contains common install locations for this session
    export PATH="$HOME/.local/bin:$HOME/.claude/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

    if ! validate_command "claude"; then
        if ! ensure_claude_path; then
            log_error "Claude CLI not found after installation"
            log_info "Try reloading your shell: source ~/.bashrc (or ~/.zshrc)"
            log_info "Manual install: curl -fsSL https://claude.ai/install.sh -o /tmp/claude-install.sh && bash /tmp/claude-install.sh"
            return 1
        fi
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

    export PATH="$HOME/.local/bin:$HOME/.claude/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

    local all_valid=true

    # Check Claude CLI
    if validate_command "claude" || ensure_claude_path; then
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

    # Uninstall Claude CLI if installed via Homebrew
    if command -v brew &>/dev/null; then
        brew uninstall --cask claude-code 2>/dev/null || true
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
