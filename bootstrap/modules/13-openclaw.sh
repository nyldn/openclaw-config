#!/usr/bin/env bash

# Module: OpenClaw Installation
# Installs OpenClaw.ai with security hardening

MODULE_NAME="openclaw"
MODULE_VERSION="2.0.0"
MODULE_DESCRIPTION="OpenClaw.ai installation with security configuration"
MODULE_DEPS=("nodejs")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

OPENCLAW_DIR="$HOME/.openclaw"
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    # Ensure npm global bin is in PATH for this session
    export PATH="$HOME/.local/npm-global/bin:$HOME/.local/bin:$PATH"

    if ! validate_command "openclaw"; then
        log_debug "OpenClaw not found"
        return 1
    fi

    if [[ -d "$OPENCLAW_DIR" ]]; then
        log_debug "OpenClaw directory exists"
        return 0
    else
        log_debug "OpenClaw directory missing"
        return 1
    fi
}

# Install the module
install() {
    log_section "Installing OpenClaw"

    # Verify npm is available
    if ! validate_command "npm"; then
        log_error "npm is required but not found"
        log_info "Please install Node.js first (module 03-nodejs.sh)"
        return 1
    fi

    # Check Node.js version (requires 22.12.0+)
    log_progress "Checking Node.js version..."
    local node_version
    node_version=$(node --version | sed 's/v//')
    local required_version="22.12.0"

    if ! printf '%s\n%s\n' "$required_version" "$node_version" | sort -V -C; then
        log_warn "Node.js $required_version or later required (current: v$node_version)"
        log_info "OpenClaw requires Node.js 22.12.0+ for security patches"
        log_info "CVE-2025-59466 (async_hooks DoS) and CVE-2026-21636 (Permission bypass)"
    else
        log_success "Node.js version OK: v$node_version"
    fi

    # Ensure npm global bin is in PATH for this session
    export PATH="$HOME/.local/npm-global/bin:$HOME/.local/bin:$PATH"

    # Install OpenClaw globally
    # Set SHARP_IGNORE_GLOBAL_LIBVIPS to prevent sharp dependency failures on some systems
    log_progress "Installing OpenClaw via npm..."
    if SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw --silent 2>&1 | tee /tmp/openclaw-install.log; then
        local openclaw_version
        openclaw_version=$(openclaw --version 2>/dev/null || echo "unknown")
        log_success "OpenClaw installed: $openclaw_version"
    else
        log_error "Failed to install OpenClaw"
        log_info "Check /tmp/openclaw-install.log for details"
        return 1
    fi

    # Create OpenClaw directory
    log_progress "Creating OpenClaw directory: $OPENCLAW_DIR"
    mkdir -p "$OPENCLAW_DIR"
    log_success "Directory created"

    # Run openclaw onboard wizard (upstream recommended flow)
    log_progress "Running OpenClaw onboard wizard..."
    if [[ -t 0 ]]; then
        # Interactive terminal — run the full onboard wizard with daemon install
        log_info "Starting interactive onboard wizard..."
        log_info "This will configure the gateway, daemon, and channel pairing."
        if openclaw onboard --install-daemon 2>&1 | tee -a /tmp/openclaw-onboard.log; then
            log_success "OpenClaw onboard completed"
        else
            log_warn "Onboard wizard exited with errors (check /tmp/openclaw-onboard.log)"
            log_info "Falling back to manual configuration..."
        fi
    else
        # Non-interactive — skip onboard, write config manually
        log_info "Non-interactive environment detected, skipping onboard wizard"
        log_info "Run 'openclaw onboard --install-daemon' after install to complete setup"
    fi

    # Create secure default configuration (upstream openclaw.json schema)
    # Only write if onboard didn't create one already
    if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
        log_progress "Creating secure default configuration..."
        cat > "$OPENCLAW_CONFIG" <<'EOF'
{
  // OpenClaw configuration — upstream schema
  // See https://docs.openclaw.ai/gateway/configuration

  "agent": {
    "model": "anthropic/claude-sonnet-4-6"
  },

  "models": {
    "routing": {
      "default": "anthropic/claude-sonnet-4-6",
      "fast": "anthropic/claude-haiku-4-5-20251001",
      "reasoning": "anthropic/claude-opus-4-6"
    },
    "fallback": ["anthropic/claude-opus-4-6", "openai/gpt-4o"]
  },

  "gateway": {
    "bind": "loopback",
    "port": 18789
  },

  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "non-main"
      }
    }
  },

  "channels": {
    "defaults": {
      "dmPolicy": "pairing"
    }
  },

  "plugins": {
    "directory": "~/.openclaw/extensions",
    "enabled": true,
    "autoload": true
  },

  "dashboard": {
    "enabled": true,
    "theme": "system"
  },

  "logging": {
    "level": "info"
  }
}
EOF
        log_success "Configuration created at $OPENCLAW_CONFIG"
    else
        log_info "Configuration already exists at $OPENCLAW_CONFIG (created by onboard)"
    fi

    # Create .gitignore for OpenClaw directory
    log_progress "Creating .gitignore for security..."
    cat > "$OPENCLAW_DIR/.gitignore" <<'EOF'
# Credentials and secrets
*.key
*.pem
*.p12
credentials.json
token.json
openclaw.json
config.json
.env
.env.*

# Logs
*.log
logs/

# Cache and temporary files
cache/
tmp/
.tmp/

# API keys
*api*key*
*secret*
EOF

    log_success ".gitignore created"

    # Generate TOOLS.md for OpenClaw workspace
    log_progress "Generating TOOLS.md for OpenClaw workspace..."
    local tools_script="$(dirname "$SCRIPT_DIR")/scripts/generate-openclaw-tools-doc.sh"

    if [[ -x "$tools_script" ]]; then
        if bash "$tools_script" 2>&1 | tee /tmp/openclaw-tools-gen.log; then
            log_success "TOOLS.md generated successfully"
            log_info "OpenClaw will read ~/.openclaw/workspace/TOOLS.md to understand available tools"
        else
            log_warn "Failed to generate TOOLS.md"
            log_info "You can manually run: $tools_script"
        fi
    else
        log_warn "TOOLS.md generation script not found or not executable"
        log_info "Expected: $tools_script"
    fi

    # Set up gateway daemon service (if not already handled by onboard --install-daemon)
    log_progress "Checking gateway daemon setup..."
    local systemd_src="$(dirname "$(dirname "$SCRIPT_DIR")")/bootstrap/systemd/openclaw-gateway.service"
    local systemd_user_dir="$HOME/.config/systemd/user"

    if [[ -f "$systemd_src" ]] && command -v systemctl &>/dev/null; then
        if [[ ! -f "$systemd_user_dir/openclaw-gateway.service" ]]; then
            mkdir -p "$systemd_user_dir"
            cp "$systemd_src" "$systemd_user_dir/openclaw-gateway.service"
            systemctl --user daemon-reload
            systemctl --user enable openclaw-gateway.service
            log_success "Gateway daemon service installed and enabled"
            log_info "Start with: systemctl --user start openclaw-gateway"
        else
            log_info "Gateway daemon service already installed"
        fi
    elif [[ "$(uname)" == "Darwin" ]]; then
        # macOS uses launchd — delegate to openclaw onboard --install-daemon
        log_info "macOS detected — gateway daemon managed via launchd"
        log_info "Run 'openclaw onboard --install-daemon' to configure launchd service"
    else
        log_info "systemd not available — gateway daemon setup skipped"
        log_info "Run 'openclaw onboard --install-daemon' to configure daemon manually"
    fi

    # Security warnings (aligned with upstream security model)
    log_warn ""
    log_warn "========================================="
    log_warn "IMPORTANT SECURITY NOTICES"
    log_warn "========================================="
    log_info ""
    log_info "OpenClaw Security Configuration (applied):"
    log_info ""
    log_info "1. GATEWAY BINDING"
    log_info "   ✓ Gateway bound to loopback (localhost only, port 18789)"
    log_info "   ✓ Use Tailscale Serve/Funnel for remote access (module 17)"
    log_info "   ✗ DO NOT set gateway.bind to 0.0.0.0 for public access"
    log_info ""
    log_info "2. SANDBOX MODE"
    log_info "   ✓ Sandbox mode: non-main (agents sandboxed outside main session)"
    log_info "   ✓ Configure per-channel allowlists for additional control"
    log_info "   → See: agents.defaults.sandbox.mode in openclaw.json"
    log_info ""
    log_info "3. DM PAIRING (Channel Security)"
    log_info "   ✓ DM policy: pairing (prevents unauthorized DM access)"
    log_info "   ✓ Configure channel-specific allowlists for inbound messages"
    log_info "   → See: channels.defaults.dmPolicy in openclaw.json"
    log_info ""
    log_info "4. CREDENTIAL MANAGEMENT"
    log_info "   ✗ Never store plaintext API keys in config files"
    log_info "   ✗ Do NOT use consumer Claude/ChatGPT subscriptions — use API keys"
    log_info "     Consumer subscriptions ban automated/bot usage; accounts get terminated"
    log_info "   ✓ Use environment variables or Doppler for secrets"
    log_info "   ✓ Rotate API keys regularly (every 90 days)"
    log_info ""
    log_info "5. SKILL/PLUGIN SECURITY"
    log_info "   ✗ Do not install untrusted skills from unknown sources"
    log_info "   ✓ Review skill code before installation"
    log_info "   ✓ Sandbox mode protects against malicious skills"
    log_info "   → Malicious skills have been found on ClawHub"
    log_info ""
    log_info "6. DIAGNOSTICS"
    log_info "   ✓ Run 'openclaw doctor' to check for risky configs"
    log_info "   ✓ Checks DM policies, version issues, and migration needs"
    log_info "   ✓ Run after any config changes"
    log_info ""
    log_info "For comprehensive security guide, see:"
    log_info "  https://docs.openclaw.ai/gateway/security"
    log_info ""

    log_info ""
    log_info "Next steps:"
    log_info "  1. Run onboard wizard if not already done: openclaw onboard --install-daemon"
    log_info "  2. Configure API keys (use Doppler or .env file)"
    log_info "  3. Review and customize $OPENCLAW_CONFIG"
    log_info "  4. Run VM security hardening (module 14-security.sh)"
    log_info "  5. Run diagnostics: openclaw doctor"
    log_info "  6. Start OpenClaw: openclaw start"
    log_info ""
    log_info "Cost Tracking:"
    log_info "  Monitor API usage and costs via provider billing dashboards:"
    log_info "  - Anthropic: https://console.anthropic.com/settings/billing"
    log_info "  - OpenAI:    https://platform.openai.com/usage"
    log_info "  - Google:    https://console.cloud.google.com/billing"
    log_info "  Set budget alerts in each provider to avoid unexpected charges."
    log_info ""
    log_info "Dashboard:"
    log_info "  The OpenClaw dashboard is enabled by default."
    log_info "  Access it at http://localhost:18789/dashboard after starting OpenClaw."
    log_info ""

    return 0
}

# Validate installation
validate() {
    log_progress "Validating OpenClaw installation"

    export PATH="$HOME/.local/npm-global/bin:$HOME/.local/bin:$PATH"

    local all_valid=true

    # Check OpenClaw command
    if validate_command "openclaw"; then
        local version
        version=$(openclaw --version 2>/dev/null || echo "unknown")
        log_success "OpenClaw installed: $version"
    else
        log_error "OpenClaw command not found"
        all_valid=false
    fi

    # Check OpenClaw directory
    if [[ -d "$OPENCLAW_DIR" ]]; then
        log_success "OpenClaw directory exists: $OPENCLAW_DIR"
    else
        log_error "OpenClaw directory not found"
        all_valid=false
    fi

    # Check configuration file (upstream openclaw.json schema)
    if [[ -f "$OPENCLAW_CONFIG" ]]; then
        # Validate JSON syntax (strip // comments for jq)
        if sed 's|//.*||' "$OPENCLAW_CONFIG" | jq empty 2>/dev/null; then
            log_success "Configuration file is valid JSON"

            # Check sandbox mode (upstream: agents.defaults.sandbox.mode)
            local sandbox_mode
            sandbox_mode=$(sed 's|//.*||' "$OPENCLAW_CONFIG" | jq -r '.agents.defaults.sandbox.mode // empty' 2>/dev/null)

            if [[ "$sandbox_mode" == "non-main" || "$sandbox_mode" == "always" ]]; then
                log_success "Sandbox mode: $sandbox_mode"
            elif [[ -z "$sandbox_mode" ]]; then
                log_warn "Sandbox mode not configured (recommend: non-main)"
            else
                log_warn "Sandbox mode: $sandbox_mode (consider: non-main)"
            fi

            # Check gateway binding (upstream: gateway.bind)
            local bind_mode
            bind_mode=$(sed 's|//.*||' "$OPENCLAW_CONFIG" | jq -r '.gateway.bind // empty' 2>/dev/null)

            if [[ "$bind_mode" == "loopback" || "$bind_mode" == "127.0.0.1" || "$bind_mode" == "localhost" ]]; then
                log_success "Gateway binding is loopback-only (secure)"
            elif [[ -z "$bind_mode" ]]; then
                log_warn "Gateway bind not configured (defaults may vary)"
            else
                log_error "Gateway binding allows external access: $bind_mode (SECURITY RISK)"
                all_valid=false
            fi

            # Check DM policy (upstream: channels.defaults.dmPolicy)
            local dm_policy
            dm_policy=$(sed 's|//.*||' "$OPENCLAW_CONFIG" | jq -r '.channels.defaults.dmPolicy // empty' 2>/dev/null)

            if [[ "$dm_policy" == "pairing" ]]; then
                log_success "DM policy: pairing (secure)"
            elif [[ -n "$dm_policy" ]]; then
                log_warn "DM policy: $dm_policy (recommend: pairing)"
            fi
        else
            log_error "Configuration file has invalid JSON"
            all_valid=false
        fi
    else
        log_warn "Configuration file not found (will use defaults)"
    fi

    # Check .gitignore
    if [[ -f "$OPENCLAW_DIR/.gitignore" ]]; then
        log_success ".gitignore file exists"
    else
        log_warn ".gitignore not found (credentials may be exposed to git)"
    fi

    # Check Node.js version
    local node_version
    node_version=$(node --version | sed 's/v//')
    local required_version="22.12.0"

    if ! printf '%s\n%s\n' "$required_version" "$node_version" | sort -V -C; then
        log_warn "Node.js version $node_version is older than recommended $required_version"
        log_info "Update for security patches: CVE-2025-59466, CVE-2026-21636"
    else
        log_success "Node.js version meets security requirements"
    fi

    # Run openclaw doctor for upstream diagnostics
    if validate_command "openclaw"; then
        log_progress "Running openclaw doctor..."
        if openclaw doctor 2>&1 | tee /tmp/openclaw-doctor.log; then
            log_success "openclaw doctor passed"
        else
            log_warn "openclaw doctor reported issues (see /tmp/openclaw-doctor.log)"
        fi
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "OpenClaw validation passed"
        return 0
    else
        log_error "OpenClaw validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back OpenClaw installation"

    # Uninstall OpenClaw
    if command -v npm &>/dev/null; then
        log_progress "Uninstalling OpenClaw from npm"
        npm uninstall -g openclaw 2>/dev/null || true
    fi

    # Note: We don't remove the OpenClaw directory as it may contain user data
    log_info "OpenClaw directory preserved at: $OPENCLAW_DIR"
    log_info "To completely remove, run: rm -rf $OPENCLAW_DIR"

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
