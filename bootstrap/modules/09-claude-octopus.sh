#!/usr/bin/env bash

# Module: Claude Octopus Plugin
# Installs the Claude Octopus plugin for enhanced capabilities

MODULE_NAME="claude-octopus"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="Claude Octopus plugin for advanced AI personas and workflows"
MODULE_DEPS=("claude-cli")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

PLUGIN_URL="https://github.com/nyldn/claude-octopus"
PLUGIN_NAMESPACE="nyldn-plugins"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    # Check if Claude CLI is available
    export PATH="$HOME/.local/bin:$HOME/.claude/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
    if ! validate_command "claude"; then
        log_debug "Claude CLI not found"
        return 1
    fi

    # Check if plugin is installed
    # Note: This check may need adjustment based on actual Claude CLI plugin commands
    if claude plugin list 2>/dev/null | grep -q "claude-octopus"; then
        log_debug "Claude Octopus plugin is installed"
        return 0
    fi

    log_debug "Claude Octopus plugin not found"
    return 1
}

# Install the module
install() {
    log_section "Installing Claude Octopus Plugin"

    export PATH="$HOME/.local/bin:$HOME/.claude/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

    # Verify Claude CLI is available
    if ! validate_command "claude"; then
        log_warn "Claude CLI is not installed. Skipping claude-octopus install."
        log_info "Install later with: ./bootstrap.sh --only claude-cli,claude-octopus"
        return 0
    fi

    log_info "Installing Claude Octopus from: $PLUGIN_URL"

    # Add plugin to marketplace
    log_progress "Adding Claude Octopus to plugin marketplace"

    local marketplace_log
    marketplace_log=$(mktemp /tmp/octopus-marketplace-XXXXXX.log)
    if claude plugin marketplace add "$PLUGIN_URL" 2>&1 | tee "$marketplace_log"; then
        log_success "Plugin added to marketplace"
    else
        log_error "Failed to add plugin to marketplace"
        log_info "Check log: $marketplace_log"

        # Check if it's already added
        if grep -qi "already" "$marketplace_log"; then
            log_info "Plugin already in marketplace, continuing..."
        else
            return 1
        fi
    fi

    # Install plugin
    log_progress "Installing claude-octopus plugin"

    local install_log
    install_log=$(mktemp /tmp/octopus-install-XXXXXX.log)
    if claude plugin install "claude-octopus@$PLUGIN_NAMESPACE" 2>&1 | tee "$install_log"; then
        log_success "Claude Octopus plugin installed"
    else
        log_error "Failed to install plugin"
        log_info "Check log: $install_log"

        # Check if it's already installed
        if grep -qi "already installed" "$install_log"; then
            log_info "Plugin already installed, continuing..."
        else
            return 1
        fi
    fi

    # Run plugin setup
    log_progress "Running Octopus setup"

    log_info "You may need to run '/octo:setup' manually in Claude CLI"
    log_info "Example: claude --execute '/octo:setup'"

    # Attempt to run setup (may require interactive session)
    if claude --execute '/octo:setup' 2>/dev/null; then
        log_success "Octopus setup completed"
    else
        log_warn "Automatic setup failed - you may need to run '/octo:setup' manually"
        log_info "Start Claude CLI and run: /octo:setup"
    fi

    log_success "Claude Octopus installation complete"

    return 0
}

# Validate installation
validate() {
    log_progress "Validating Claude Octopus installation"

    local all_valid=true

    # Check Claude CLI
    export PATH="$HOME/.local/bin:$HOME/.claude/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
    if validate_command "claude"; then
        log_success "Claude CLI is available"
    else
        log_warn "Claude CLI not found; skipping claude-octopus validation"
        return 0
    fi

    # Check if plugin is installed
    log_progress "Checking plugin installation status"

    if claude plugin list 2>&1 | grep -q "claude-octopus"; then
        log_success "Claude Octopus plugin is installed"
    else
        log_warn "Plugin not found in plugin list"
        log_info "Try running: claude plugin list"
        all_valid=false
    fi

    # Check plugin commands/agents availability
    log_info "Available Octopus personas and skills:"
    log_info "- strategy-analyst: Market analysis and business strategy"
    log_info "- backend-architect: API design and microservices"
    log_info "- code-reviewer: Code quality and security analysis"
    log_info "- research-synthesizer: Literature review and synthesis"
    log_info "- test-automator: Test automation frameworks"
    log_info "- performance-engineer: Performance optimization"
    log_info "- security-auditor: Security audits and DevSecOps"
    log_info "- cloud-architect: Cloud infrastructure design"
    log_info "- ai-engineer: LLM applications and RAG systems"
    log_info "And many more..."

    if [[ "$all_valid" == "true" ]]; then
        log_success "Claude Octopus validation passed"
        return 0
    else
        log_error "Claude Octopus validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back Claude Octopus installation"

    if validate_command "claude"; then
        log_progress "Uninstalling Claude Octopus plugin"

        if claude plugin uninstall "claude-octopus@$PLUGIN_NAMESPACE" 2>/dev/null; then
            log_success "Plugin uninstalled"
        else
            log_warn "Failed to uninstall plugin (may not be installed)"
        fi

        # Remove from marketplace
        log_progress "Removing from marketplace"
        claude plugin marketplace remove "$PLUGIN_URL" 2>/dev/null || true
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
