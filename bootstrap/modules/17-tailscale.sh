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
# shellcheck source=../lib/secure-download.sh
source "$LIB_DIR/secure-download.sh"

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

            if download_with_verification "https://tailscale.com/install.sh" "$ts_setup"; then
                log_warn "Downloaded Tailscale installer hash: $(sha256sum "$ts_setup" 2>/dev/null || shasum -a 256 "$ts_setup" | awk '{print $1}')"

                # Wait for any existing dpkg/apt locks to release
                local lock_wait=0
                while sudo fuser /var/lib/dpkg/lock-frontend &>/dev/null 2>&1 || sudo fuser /var/lib/apt/lists/lock &>/dev/null 2>&1; do
                    if [[ $lock_wait -eq 0 ]]; then
                        log_info "Waiting for other package managers to finish..."
                    fi
                    lock_wait=$((lock_wait + 1))
                    if [[ $lock_wait -gt 60 ]]; then
                        log_warn "Timed out waiting for dpkg lock after 60 seconds"
                        break
                    fi
                    sleep 1
                done

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

    # Actively configure Tailscale Serve for OpenClaw gateway
    log_progress "Configuring OpenClaw gateway for Tailscale..."

    if validate_command "tailscale"; then
        local ts_status
        ts_status=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // empty' 2>/dev/null || echo "")

        if [[ "$ts_status" == "Running" ]]; then
            log_info "Tailscale is running — setting up Tailscale Serve for gateway"
            if tailscale serve --bg 18789 2>&1 | tee -a /tmp/tailscale-serve.log; then
                local ts_hostname
                ts_hostname=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' 2>/dev/null | sed 's/\.$//')
                log_success "Tailscale Serve active on port 18789"
                if [[ -n "$ts_hostname" ]]; then
                    log_info "Access OpenClaw at: https://$ts_hostname/"
                fi
            else
                log_warn "Failed to start Tailscale Serve (check /tmp/tailscale-serve.log)"
                log_info "You can manually run: tailscale serve --bg 18789"
            fi
        elif [[ "$ts_status" == "NeedsLogin" ]]; then
            log_warn "Tailscale needs login before Serve can be configured"
            log_info "Run 'sudo tailscale up' to authenticate, then:"
            log_info "  tailscale serve --bg 18789"
        else
            log_info "Tailscale status: ${ts_status:-unknown}"
            log_info "To enable Tailscale Serve for remote gateway access:"
            log_info "  1. Authenticate: sudo tailscale up"
            log_info "  2. Enable Serve: tailscale serve --bg 18789"
        fi
    else
        log_warn "Tailscale CLI not available — cannot configure Serve"
    fi

    if [[ -f "$OPENCLAW_CONFIG" ]]; then
        local has_tailscale
        has_tailscale=$(sed 's|//.*||' "$OPENCLAW_CONFIG" | jq -r '.gateway.tailscale // empty' 2>/dev/null)

        if [[ -z "$has_tailscale" ]]; then
            log_info ""
            log_info "Tailscale modes:"
            log_info "  serve  — Expose gateway on your tailnet only"
            log_info "  funnel — Expose gateway to the public internet via Tailscale Funnel"
        fi
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
