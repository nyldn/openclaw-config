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

# Skill registry configuration
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"
REGISTRY_FILE="$CONFIG_DIR/skill-registry.yaml"
HASH_FILE="$HOME/.openclaw/skill-hashes.sha256"

# Portable SHA256 wrapper (Linux: sha256sum, macOS: shasum -a 256)
compute_hash() {
    local file="$1"
    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        log_warn "No SHA256 tool found, skipping hash verification"
        echo ""
    fi
}

# Load registry settings (parsed with grep/awk, no yq dependency)
REGISTRY_MODE="blocklist"
REGISTRY_WARN_UNVERIFIED="true"
REGISTRY_REQUIRE_CONFIRM="true"
declare -a BLOCKED_SKILLS=()
declare -a ALLOWED_SKILLS=()

load_registry() {
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        log_warn "Skill registry not found: $REGISTRY_FILE"
        return 0
    fi

    REGISTRY_MODE=$(grep '^\s*mode:' "$REGISTRY_FILE" | awk '{print $2}' | head -1)
    REGISTRY_WARN_UNVERIFIED=$(grep '^\s*warn_unverified:' "$REGISTRY_FILE" | awk '{print $2}' | head -1)
    REGISTRY_REQUIRE_CONFIRM=$(grep '^\s*require_interactive_confirm:' "$REGISTRY_FILE" | awk '{print $2}' | head -1)

    local in_blocked=false in_allowed=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^blocked: ]]; then
            in_blocked=true; in_allowed=false; continue
        elif [[ "$line" =~ ^allowed: ]]; then
            in_allowed=true; in_blocked=false; continue
        elif [[ "$line" =~ ^[a-z] ]]; then
            in_blocked=false; in_allowed=false; continue
        fi

        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.*) ]]; then
            local name="${BASH_REMATCH[1]}"
            if [[ "$in_blocked" == "true" ]]; then
                BLOCKED_SKILLS+=("$name")
            elif [[ "$in_allowed" == "true" ]]; then
                ALLOWED_SKILLS+=("$name")
            fi
        fi
    done < "$REGISTRY_FILE"

    log_debug "Registry loaded: mode=$REGISTRY_MODE, ${#ALLOWED_SKILLS[@]} allowed, ${#BLOCKED_SKILLS[@]} blocked"
}

is_skill_blocked() {
    local skill="$1"
    for blocked in "${BLOCKED_SKILLS[@]}"; do
        if [[ "$skill" == "$blocked" ]]; then
            return 0
        fi
    done
    return 1
}

is_skill_allowed() {
    local skill="$1"
    if [[ "$REGISTRY_MODE" != "allowlist" ]]; then
        return 0  # In blocklist mode, anything not blocked is allowed
    fi
    for allowed in "${ALLOWED_SKILLS[@]}"; do
        if [[ "$skill" == "$allowed" ]]; then
            return 0
        fi
    done
    return 1
}

verify_skill_hash() {
    local skill="$1"
    local skill_dir="$HOME/.openclaw/skills/$skill"
    if [[ ! -d "$skill_dir" ]]; then
        return 0
    fi
    # Store hash of skill directory listing for change detection
    local current_hash
    current_hash=$(find "$skill_dir" -type f -exec cat {} + 2>/dev/null | compute_hash /dev/stdin)
    if [[ -z "$current_hash" ]]; then
        return 0
    fi
    mkdir -p "$(dirname "$HASH_FILE")"
    echo "$current_hash  $skill" >> "$HASH_FILE"
}

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

    # Ensure npm global bin is in PATH for this session
    export PATH="$HOME/.local/npm-global/bin:$HOME/.local/bin:$PATH"

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

# Install a single skill via ClawHub (with registry checks)
install_skill() {
    local skill="$1"

    # Blocklist check
    if is_skill_blocked "$skill"; then
        log_error "BLOCKED: Skill '$skill' is on the blocklist — skipping"
        return 1
    fi

    # Allowlist mode check
    if ! is_skill_allowed "$skill"; then
        log_warn "Skill '$skill' is not on the allowlist — skipping"
        return 1
    fi

    # Interactive confirmation (respects NON_INTERACTIVE)
    if [[ "$REGISTRY_REQUIRE_CONFIRM" == "true" ]]; then
        if [[ -z "${NON_INTERACTIVE:-}" ]] && [[ -t 0 ]]; then
            read -r -p "Install skill '$skill'? [Y/n] " response
            if [[ "$response" =~ ^[Nn]$ ]]; then
                log_info "Skipped skill: $skill"
                return 0
            fi
        fi
    fi

    log_progress "Installing skill: $skill"

    if openclaw skills install "$skill" 2>&1 | tee -a /tmp/openclaw-skill-install.log; then
        log_success "Skill installed: $skill"
        verify_skill_hash "$skill"
        return 0
    else
        log_warn "Failed to install skill: $skill"
        return 1
    fi
}

# Install the module
install() {
    log_section "Installing OpenClaw Skills"

    # Ensure npm global bin is in PATH for this session
    export PATH="$HOME/.local/npm-global/bin:$HOME/.local/bin:$PATH"

    # Load skill registry (allowlist/blocklist)
    load_registry

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

    # Ensure npm global bin is in PATH for this session
    export PATH="$HOME/.local/npm-global/bin:$HOME/.local/bin:$PATH"

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
