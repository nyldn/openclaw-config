#!/usr/bin/env bash

# Module: OpenClaw Skills Installation
# Installs popular skills from ClawHub (clawhub.com) via native openclaw CLI

MODULE_NAME="openclaw-skills"
MODULE_VERSION="2.0.0"
MODULE_DESCRIPTION="Popular OpenClaw skills from ClawHub registry"
MODULE_DEPS=("nodejs" "openclaw")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

# Skills from ClawHub (clawhub.com) — popular skills with 400+ downloads
# Uses native `openclaw skills install` command
SKILLS=(
    "ByteRover"
    "Self-Improving Agent"
    "Agent Browser"
    "Proactive Agent"
    "Deep Research Agent"
    "Memory Setup"
    "Agent Browser 2"
    "Second Brain"
    "Prompt Guard"
    "AgentMail"
    "Compound Engineering"
    "Agent Browser 3"
    "Exa"
    "Context7 MCP"
    "Ontology"
)

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    # Verify openclaw CLI is available
    if ! validate_command "openclaw"; then
        log_debug "openclaw not found"
        return 1
    fi

    # Check if at least some skills are installed
    if [[ -d "$HOME/.openclaw/skills" ]]; then
        log_debug "OpenClaw skills directory exists"
        return 0
    fi

    log_debug "Skills not yet installed"
    return 1
}

# Install a single skill via ClawHub
install_skill() {
    local skill="$1"
    log_progress "Installing skill: $skill"

    if openclaw skills install "$skill" 2>&1 | tee -a /tmp/openclaw-skill-install.log; then
        log_success "Skill installed: $skill"
        return 0
    else
        log_warn "Failed to install skill: $skill"
        return 1
    fi
}

# Install the module
install() {
    log_section "Installing OpenClaw Skills"

    # Verify openclaw CLI is available
    if ! validate_command "openclaw"; then
        log_error "openclaw CLI is required but not found"
        log_info "Please install OpenClaw first (module 13-openclaw.sh)"
        return 1
    fi

    # Create skills directory if it doesn't exist
    mkdir -p "$HOME/.openclaw/skills"

    log_info "Installing ${#SKILLS[@]} popular skills from ClawHub"
    log_info "Registry: https://clawhub.com"
    log_info ""

    local installed_count=0
    local failed_count=0
    local failed_skills=()

    # Clear previous log
    > /tmp/openclaw-skill-install.log

    for skill in "${SKILLS[@]}"; do
        if install_skill "$skill"; then
            installed_count=$((installed_count + 1))
        else
            failed_count=$((failed_count + 1))
            failed_skills+=("$skill")
        fi
    done

    log_info ""
    log_success "Installed $installed_count out of ${#SKILLS[@]} skills"

    if [[ $failed_count -gt 0 ]]; then
        log_warn "Failed to install $failed_count skills:"
        for skill in "${failed_skills[@]}"; do
            log_warn "  - $skill"
        done
        log_info "Check log: /tmp/openclaw-skill-install.log"
    fi

    log_info ""
    log_info "Installed skills include:"
    log_info "  • ByteRover: Project knowledge management"
    log_info "  • Self-Improving Agent: AI self-improvement capabilities"
    log_info "  • Agent Browser: Web browsing for agents"
    log_info "  • Proactive Agent: Proactive task automation"
    log_info "  • Deep Research Agent: Comprehensive research"
    log_info "  • Memory Setup: Memory management configuration"
    log_info "  • Second Brain: Personal knowledge management"
    log_info "  • Prompt Guard: Prompt injection protection"
    log_info "  • AgentMail: Email integration"
    log_info "  • And more..."
    log_info ""

    if [[ $failed_count -gt 0 ]]; then
        return 1
    fi

    return 0
}

# Validate installation
validate() {
    log_progress "Validating OpenClaw skills installation"

    local all_valid=true

    # Check openclaw CLI
    if validate_command "openclaw"; then
        log_success "openclaw CLI is available"
    else
        log_error "openclaw CLI not found"
        all_valid=false
    fi

    # Check skills directory
    if [[ -d "$HOME/.openclaw/skills" ]]; then
        log_success "Skills directory exists: $HOME/.openclaw/skills"

        # Count installed skills
        local skill_count
        skill_count=$(find "$HOME/.openclaw/skills" -maxdepth 1 -type d | wc -l)
        log_info "Found $skill_count skill directories"
    else
        log_warn "Skills directory not found"
        all_valid=false
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "OpenClaw skills validation passed"
        return 0
    else
        log_error "OpenClaw skills validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back OpenClaw skills installation"

    # Note: We don't automatically remove skills as they may contain user data
    log_info "Skills directory preserved at: $HOME/.openclaw/skills"
    log_info "To manually remove, run: rm -rf $HOME/.openclaw/skills"

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
