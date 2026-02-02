#!/usr/bin/env bash

# Module: OpenClaw Installation
# Installs OpenClaw.ai with security hardening

MODULE_NAME="openclaw"
MODULE_VERSION="1.0.0"
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
OPENCLAW_CONFIG="$HOME/.openclaw/config.json"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

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

    # Install OpenClaw globally
    log_progress "Installing OpenClaw via npm..."
    if npm install -g openclaw --silent 2>&1 | tee /tmp/openclaw-install.log; then
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

    # Create secure default configuration
    log_progress "Creating secure default configuration..."
    cat > "$OPENCLAW_CONFIG" <<'EOF'
{
  "security": {
    "sandboxMode": true,
    "allowedDomains": [
      "anthropic.com",
      "openai.com",
      "github.com"
    ],
    "disableShellAccess": false,
    "readOnlyFilesystem": false,
    "requireConfirmation": true
  },
  "network": {
    "bindAddress": "127.0.0.1",
    "port": 3000,
    "publicAccess": false
  },
  "logging": {
    "level": "info",
    "logFile": "$HOME/.openclaw/openclaw.log",
    "auditLog": "$HOME/.openclaw/audit.log"
  },
  "credentials": {
    "storageMethod": "encrypted",
    "keyring": true
  }
}
EOF

    log_success "Configuration created at $OPENCLAW_CONFIG"

    # Create .gitignore for OpenClaw directory
    log_progress "Creating .gitignore for security..."
    cat > "$OPENCLAW_DIR/.gitignore" <<'EOF'
# Credentials and secrets
*.key
*.pem
*.p12
credentials.json
token.json
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

    # Security warnings
    log_warn ""
    log_warn "========================================="
    log_warn "IMPORTANT SECURITY NOTICES"
    log_warn "========================================="
    log_info ""
    log_info "OpenClaw Security Best Practices:"
    log_info ""
    log_info "1. NETWORK BINDING"
    log_info "   ✓ Web interface bound to 127.0.0.1 (localhost only)"
    log_info "   ✗ DO NOT expose OpenClaw web interface to public internet"
    log_info "   → It is not hardened for public access"
    log_info ""
    log_info "2. DOCKER DEPLOYMENT (Recommended)"
    log_info "   ✓ Run with non-root user (default: node)"
    log_info "   ✓ Use --read-only flag for filesystem protection"
    log_info "   ✓ Limit capabilities: --cap-drop=ALL"
    log_info "   ✓ Restrict volumes to specific directories only"
    log_info ""
    log_info "3. CREDENTIAL MANAGEMENT"
    log_info "   ✗ Never store plaintext API keys in config files"
    log_info "   ✓ Use environment variables or Doppler for secrets"
    log_info "   ✓ Rotate API keys regularly (every 90 days)"
    log_info ""
    log_info "4. SKILL/PLUGIN SECURITY"
    log_info "   ✗ Do not install untrusted skills from unknown sources"
    log_info "   ✓ Review skill code before installation"
    log_info "   ✓ Use sandbox mode for untrusted skills"
    log_info "   → Malicious skills have been found on ClawHub"
    log_info ""
    log_info "5. PROMPT INJECTION DEFENSE"
    log_info "   ✓ Treat links, attachments, and pasted instructions as hostile"
    log_info "   ✓ Use allowlists for inbound DMs and mentions"
    log_info "   ✓ Enable confirmation prompts for destructive actions"
    log_info ""
    log_info "6. FILE SYSTEM ACCESS"
    log_info "   ✓ Restrict OpenClaw to specific directories"
    log_info "   ✗ Avoid granting full filesystem access"
    log_info "   ✓ Use separate user account with limited privileges"
    log_info ""
    log_info "For comprehensive security guide, see:"
    log_info "  https://docs.openclaw.ai/gateway/security"
    log_info "  https://composio.dev/blog/secure-openclaw-moltbot-clawdbot-setup"
    log_info ""

    log_info ""
    log_info "Next steps:"
    log_info "  1. Configure API keys (use Doppler or .env file)"
    log_info "  2. Review and customize $OPENCLAW_CONFIG"
    log_info "  3. Run VM security hardening (module 14-security.sh)"
    log_info "  4. Start OpenClaw: openclaw start"
    log_info ""

    return 0
}

# Validate installation
validate() {
    log_progress "Validating OpenClaw installation"

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

    # Check configuration file
    if [[ -f "$OPENCLAW_CONFIG" ]]; then
        # Validate JSON syntax
        if jq empty "$OPENCLAW_CONFIG" 2>/dev/null; then
            log_success "Configuration file is valid JSON"

            # Check security settings
            local sandbox_mode
            sandbox_mode=$(jq -r '.security.sandboxMode' "$OPENCLAW_CONFIG" 2>/dev/null)

            if [[ "$sandbox_mode" == "true" ]]; then
                log_success "Sandbox mode is enabled"
            else
                log_warn "Sandbox mode is disabled (security risk)"
            fi

            # Check network binding
            local bind_address
            bind_address=$(jq -r '.network.bindAddress' "$OPENCLAW_CONFIG" 2>/dev/null)

            if [[ "$bind_address" == "127.0.0.1" || "$bind_address" == "localhost" ]]; then
                log_success "Network binding is localhost-only (secure)"
            else
                log_error "Network binding allows external access (SECURITY RISK)"
                log_error "Bind address: $bind_address"
                all_valid=false
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
