#!/usr/bin/env bash

# Module: Tailscale Integration
# Optional Tailscale install and gateway configuration for remote access

MODULE_NAME="tailscale"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="Tailscale VPN for secure remote gateway access"
MODULE_DEPS=("system-deps")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    if ! validate_command "tailscale"; then
        return 1
    fi

    log_debug "Tailscale is installed"
    return 0
}

# Install the module
install() {
    log_section "Installing Tailscale Integration"

    # Install Tailscale
    if validate_command "tailscale"; then
        local ts_version
        ts_version=$(tailscale version 2>/dev/null | head -n1 || echo "unknown")
        log_success "Tailscale already installed: $ts_version"
    else
        log_progress "Installing Tailscale..."

        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS — recommend Tailscale from App Store or brew
            if validate_command "brew"; then
                if brew install --cask tailscale 2>&1 | tee -a /tmp/tailscale-install.log; then
                    log_success "Tailscale installed via Homebrew"
                else
                    log_error "Failed to install Tailscale via Homebrew"
                    log_info "Install manually: https://tailscale.com/download/mac"
                    return 1
                fi
            else
                log_info "Install Tailscale from: https://tailscale.com/download/mac"
                log_info "Or via Homebrew: brew install --cask tailscale"
                return 1
            fi
        else
            # Linux — use official install script
            local ts_setup
            ts_setup=$(mktemp)
            trap 'rm -f "$ts_setup"' RETURN

            if curl -fsSL -o "$ts_setup" https://tailscale.com/install.sh; then
                if sudo bash "$ts_setup" 2>&1 | tee -a /tmp/tailscale-install.log; then
                    log_success "Tailscale installed"
                else
                    log_error "Failed to install Tailscale"
                    return 1
                fi
            else
                log_error "Failed to download Tailscale installer"
                return 1
            fi
        fi
    fi

    # Prompt for Tailscale login
    log_info ""
    log_info "Tailscale requires authentication to join your tailnet."
    log_info "Run 'sudo tailscale up' to authenticate (opens browser)."
    log_info ""

    # Configure OpenClaw gateway for Tailscale Serve/Funnel (optional)
    log_progress "Configuring OpenClaw gateway for Tailscale..."

    if [[ -f "$OPENCLAW_CONFIG" ]]; then
        # Check if tailscale config already exists
        local has_tailscale
        has_tailscale=$(sed 's|//.*||' "$OPENCLAW_CONFIG" | jq -r '.gateway.tailscale // empty' 2>/dev/null)

        if [[ -z "$has_tailscale" ]]; then
            log_info "To enable Tailscale Serve for remote gateway access, add to $OPENCLAW_CONFIG:"
            log_info '  "gateway": { "tailscale": { "mode": "serve" } }'
            log_info ""
            log_info "Tailscale modes:"
            log_info "  serve  — Expose gateway on your tailnet only"
            log_info "  funnel — Expose gateway to the public internet via Tailscale Funnel"
        else
            log_info "Tailscale gateway config already present"
        fi
    else
        log_warn "OpenClaw config not found — install OpenClaw first (module 13)"
    fi

    log_info ""
    log_info "Tailscale integration complete."
    log_info "Documentation: https://docs.openclaw.ai/gateway/tailscale"
    log_info ""

    return 0
}

# Validate installation
validate() {
    log_progress "Validating Tailscale integration"

    local all_valid=true

    if validate_command "tailscale"; then
        local ts_version
        ts_version=$(tailscale version 2>/dev/null | head -n1 || echo "unknown")
        log_success "Tailscale installed: $ts_version"

        # Check if Tailscale is connected
        local ts_status
        ts_status=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // empty' 2>/dev/null || echo "")

        if [[ "$ts_status" == "Running" ]]; then
            log_success "Tailscale is connected"
        elif [[ "$ts_status" == "NeedsLogin" ]]; then
            log_warn "Tailscale needs login (run: sudo tailscale up)"
        else
            log_warn "Tailscale status: ${ts_status:-unknown}"
        fi
    else
        log_error "Tailscale not installed"
        all_valid=false
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "Tailscale validation passed"
        return 0
    else
        log_error "Tailscale validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back Tailscale integration"

    log_info "Tailscale package preserved (used by other services)"
    log_info "To remove: sudo apt-get remove tailscale (Linux) or brew uninstall tailscale (macOS)"

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
