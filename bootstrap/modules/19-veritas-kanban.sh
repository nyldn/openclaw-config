#!/usr/bin/env bash

# Module: Veritas Kanban
# Installs Veritas Kanban board with AI agent orchestration and MCP server

MODULE_NAME="veritas-kanban"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="Veritas Kanban board with AI agent orchestration and MCP server"
MODULE_DEPS=("nodejs" "dev-tools")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

INSTALL_DIR="$HOME/.local/share/veritas-kanban"
REPO_URL="https://github.com/BradGroux/veritas-kanban.git"
MCP_CONFIG="$HOME/.config/claude/mcp.json"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    if validate_command "vk" && [[ -d "$INSTALL_DIR" ]]; then
        log_debug "Veritas Kanban is installed"
        return 0
    fi

    log_debug "Veritas Kanban not found"
    return 1
}

# Install the module
install() {
    log_section "Installing Veritas Kanban"

    # Verify pnpm is available (from dev-tools module)
    if ! validate_command "pnpm"; then
        log_error "pnpm is required but not found"
        log_info "Please install dev-tools first (module 12-dev-tools.sh)"
        return 1
    fi

    # Clone repository
    if [[ -d "$INSTALL_DIR" ]]; then
        log_info "Veritas Kanban directory already exists, pulling latest..."
        if git -C "$INSTALL_DIR" pull 2>&1 | tee -a /tmp/veritas-kanban-install.log; then
            log_success "Repository updated"
        else
            log_error "Failed to update repository"
            return 1
        fi
    else
        log_progress "Cloning Veritas Kanban repository..."
        if git clone "$REPO_URL" "$INSTALL_DIR" 2>&1 | tee -a /tmp/veritas-kanban-install.log; then
            log_success "Repository cloned to $INSTALL_DIR"
        else
            log_error "Failed to clone repository"
            return 1
        fi
    fi

    # Install dependencies
    log_progress "Installing dependencies with pnpm..."
    if (cd "$INSTALL_DIR" && pnpm install --frozen-lockfile) 2>&1 | tee -a /tmp/veritas-kanban-install.log; then
        log_success "Dependencies installed"
    else
        log_error "Failed to install dependencies"
        return 1
    fi

    # Build all packages
    log_progress "Building all packages (server, web, cli, mcp, shared)..."
    if (cd "$INSTALL_DIR" && pnpm build) 2>&1 | tee -a /tmp/veritas-kanban-install.log; then
        log_success "Build completed"
    else
        log_error "Failed to build packages"
        return 1
    fi

    # Install CLI globally via npm link
    log_progress "Linking vk CLI globally..."
    if (cd "$INSTALL_DIR/cli" && npm link) 2>&1 | tee -a /tmp/veritas-kanban-install.log; then
        log_success "vk CLI linked globally"
    else
        log_error "Failed to link vk CLI"
        return 1
    fi

    # Create default .env from template
    if [[ -f "$INSTALL_DIR/server/.env.example" ]]; then
        if [[ ! -f "$INSTALL_DIR/server/.env" ]]; then
            log_progress "Creating server .env from template..."
            cp "$INSTALL_DIR/server/.env.example" "$INSTALL_DIR/server/.env"

            # Generate random admin key
            local admin_key
            admin_key=$(openssl rand -base64 32 | tr -d '/+=' | head -c 48)

            # Write admin key into .env
            if grep -q "VERITAS_ADMIN_KEY" "$INSTALL_DIR/server/.env"; then
                sed -i.bak "s|^VERITAS_ADMIN_KEY=.*|VERITAS_ADMIN_KEY=$admin_key|" "$INSTALL_DIR/server/.env"
                rm -f "$INSTALL_DIR/server/.env.bak"
            else
                echo "VERITAS_ADMIN_KEY=$admin_key" >> "$INSTALL_DIR/server/.env"
            fi

            log_success "Server .env configured with generated admin key"
        else
            log_info "Server .env already exists, skipping"
        fi
    else
        log_warn "No .env.example found, skipping .env setup"
    fi

    # Configure MCP server in Claude config
    if validate_command "jq" && [[ -f "$MCP_CONFIG" ]]; then
        log_progress "Configuring MCP server in Claude config..."
        local admin_key_val=""
        if [[ -f "$INSTALL_DIR/server/.env" ]]; then
            admin_key_val=$(grep "^VERITAS_ADMIN_KEY=" "$INSTALL_DIR/server/.env" 2>/dev/null | cut -d'=' -f2-)
        fi

        local tmp_config
        tmp_config=$(mktemp)
        if jq --arg install_dir "$INSTALL_DIR" --arg admin_key "$admin_key_val" \
            '.mcpServers["veritas-kanban"] = {
                "command": "node",
                "args": [($install_dir + "/mcp/dist/index.js")],
                "env": {
                    "VK_API_URL": "http://localhost:3001",
                    "VK_API_KEY": $admin_key
                }
            }' "$MCP_CONFIG" > "$tmp_config"; then
            mv "$tmp_config" "$MCP_CONFIG"
            log_success "MCP server configured in $MCP_CONFIG"
        else
            rm -f "$tmp_config"
            log_warn "Failed to update MCP config (non-critical)"
        fi
    else
        log_info "Skipping MCP config (jq not found or $MCP_CONFIG does not exist)"
    fi

    log_info ""
    log_info "Veritas Kanban installation complete!"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Start the server:     cd $INSTALL_DIR && pnpm dev"
    log_info "  2. Access the board:     http://localhost:3001"
    log_info "  3. CLI usage:            vk --help"
    log_info "  4. MCP server:           Configured for Claude integration"
    log_info ""
    log_info "Useful commands:"
    log_info "  vk board list            List all boards"
    log_info "  vk task create           Create a new task"
    log_info "  vk task list             List tasks"
    log_info ""

    return 0
}

# Validate installation
validate() {
    log_progress "Validating Veritas Kanban installation"

    local all_valid=true

    # Check vk CLI
    if validate_command "vk"; then
        log_success "vk CLI is available"
    else
        log_error "vk CLI not found"
        all_valid=false
    fi

    # Check install directory
    if [[ -d "$INSTALL_DIR" ]]; then
        log_success "Install directory exists: $INSTALL_DIR"
    else
        log_error "Install directory not found: $INSTALL_DIR"
        all_valid=false
    fi

    # Check subdirectories
    if [[ -d "$INSTALL_DIR/server" ]] && [[ -d "$INSTALL_DIR/mcp" ]]; then
        log_success "Server and MCP directories present"
    else
        log_error "Missing server/ or mcp/ subdirectories"
        all_valid=false
    fi

    # Check .env
    if [[ -f "$INSTALL_DIR/server/.env" ]]; then
        log_success "Server .env exists"
    else
        log_warn "Server .env not found"
    fi

    # Check build artifacts
    if [[ -f "$INSTALL_DIR/server/dist/index.js" ]] && [[ -f "$INSTALL_DIR/mcp/dist/index.js" ]]; then
        log_success "Build artifacts present (server/dist/index.js, mcp/dist/index.js)"
    else
        log_error "Build artifacts missing"
        all_valid=false
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "Veritas Kanban validation passed"
        return 0
    else
        log_error "Veritas Kanban validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back Veritas Kanban installation"

    # Unlink CLI
    if [[ -d "$INSTALL_DIR/cli" ]]; then
        log_progress "Unlinking vk CLI..."
        (cd "$INSTALL_DIR/cli" && npm unlink) 2>/dev/null || true
    fi

    # Remove install directory
    if [[ -d "$INSTALL_DIR" ]]; then
        log_progress "Removing install directory..."
        rm -rf "$INSTALL_DIR"
        log_success "Install directory removed"
    fi

    # Remove MCP entry from Claude config
    if validate_command "jq" && [[ -f "$MCP_CONFIG" ]]; then
        log_progress "Removing MCP entry from Claude config..."
        local tmp_config
        tmp_config=$(mktemp)
        if jq 'del(.mcpServers["veritas-kanban"])' "$MCP_CONFIG" > "$tmp_config"; then
            mv "$tmp_config" "$MCP_CONFIG"
            log_success "MCP entry removed"
        else
            rm -f "$tmp_config"
            log_warn "Failed to remove MCP entry (non-critical)"
        fi
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
