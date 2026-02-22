#!/usr/bin/env bash

# Module: Node.js Environment
# Sets up Node.js 22+ runtime and npm

MODULE_NAME="nodejs"
MODULE_VERSION="2.0.0"
MODULE_DESCRIPTION="Node.js 22+ runtime and npm"
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

MIN_NODE_VERSION="22"
NPM_GLOBAL_PREFIX="$HOME/.local/npm-global"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    if ! validate_command "node"; then
        return 1
    fi

    local node_version
    node_version=$(node --version 2>&1 | sed 's/^v//' | cut -d. -f1)

    if [[ "$node_version" -lt "$MIN_NODE_VERSION" ]]; then
        log_debug "Node.js version $node_version < $MIN_NODE_VERSION"
        return 1
    fi

    log_debug "Node.js environment is installed"
    return 0
}

# Install the module
install() {
    log_section "Installing Node.js Environment"

    # Check if Node.js is already installed with correct version
    if validate_command "node"; then
        local current_version
        current_version=$(node --version 2>&1 | sed 's/^v//' | cut -d. -f1)

        if [[ "$current_version" -ge "$MIN_NODE_VERSION" ]]; then
            log_success "Node.js version meets requirements: v$current_version"
        else
            log_warn "Node.js version $current_version < $MIN_NODE_VERSION, upgrading..."
        fi
    fi

    # Add NodeSource repository for Node.js 22 LTS
    log_progress "Adding NodeSource repository for Node.js 22 LTS"

    # Download NodeSource setup script to temporary file
    local nodejs_setup_script
    nodejs_setup_script=$(mktemp)

    # Ensure cleanup on exit
    trap 'rm -f "$nodejs_setup_script"' RETURN

    log_progress "Downloading NodeSource setup script"
    if ! download_with_verification "https://deb.nodesource.com/setup_22.x" "$nodejs_setup_script"; then
        log_error "Failed to download NodeSource setup script"
        rm -f "$nodejs_setup_script"
        return 1
    fi

    # Log hash for forensic audit trail
    log_warn "Downloaded script hash: $(sha256sum "$nodejs_setup_script" 2>/dev/null || shasum -a 256 "$nodejs_setup_script" | awk '{print $1}')"
    log_warn "Executing NodeSource setup script (checksum pinning not available for frequently-updated scripts)"

    # Execute with sudo
    if ! sudo -E bash "$nodejs_setup_script"; then
        log_error "Failed to add NodeSource repository"
        rm -f "$nodejs_setup_script"
        return 1
    fi

    rm -f "$nodejs_setup_script"
    log_success "NodeSource repository added"

    # Install Node.js
    log_progress "Installing Node.js and npm"

    if ! sudo apt-get install -y -qq nodejs; then
        log_error "Failed to install Node.js"
        return 1
    fi

    log_success "Node.js installed"

    # Configure npm global prefix
    log_progress "Configuring npm global prefix: $NPM_GLOBAL_PREFIX"

    mkdir -p "$NPM_GLOBAL_PREFIX"

    if ! npm config set prefix "$NPM_GLOBAL_PREFIX"; then
        log_error "Failed to configure npm global prefix"
        return 1
    fi

    log_success "npm global prefix configured"

    # Add npm global bin to PATH
    local bashrc="$HOME/.bashrc"
    local npm_path="export PATH=\"$NPM_GLOBAL_PREFIX/bin:\$PATH\""

    if ! grep -q "$NPM_GLOBAL_PREFIX/bin" "$bashrc" 2>/dev/null; then
        log_progress "Adding npm global bin to PATH in .bashrc"
        {
            echo ""
            echo "# OpenClaw npm global prefix"
            echo "$npm_path"
        } >> "$bashrc"
        log_success "Added to .bashrc"
    fi

    # Also add to .profile for login shells (SSH sessions)
    # .bashrc has an early-exit guard for non-interactive shells,
    # so PATH exports there don't apply during SSH login
    local profile="$HOME/.profile"
    if [[ -f "$profile" ]] && ! grep -q "$NPM_GLOBAL_PREFIX/bin" "$profile" 2>/dev/null; then
        log_progress "Adding npm global bin to PATH in .profile"
        {
            echo ""
            echo "# OpenClaw npm global prefix"
            echo "if [ -d \"$NPM_GLOBAL_PREFIX/bin\" ] ; then"
            echo "    PATH=\"$NPM_GLOBAL_PREFIX/bin:\$PATH\""
            echo "fi"
        } >> "$profile"
        log_success "Added to .profile"
    fi

    # Export for current session
    export PATH="$NPM_GLOBAL_PREFIX/bin:$PATH"

    # Update npm to latest
    log_progress "Updating npm to latest version"
    if ! npm install -g npm@latest; then
        log_warn "Failed to update npm (non-critical)"
    else
        log_success "npm updated"
    fi

    return 0
}

# Validate installation
validate() {
    log_progress "Validating Node.js environment installation"

    local all_valid=true

    # Check Node.js
    if validate_command "node"; then
        local version
        version=$(node --version)

        local major_version
        major_version=$(echo "$version" | sed 's/^v//' | cut -d. -f1)

        if [[ "$major_version" -ge "$MIN_NODE_VERSION" ]]; then
            log_success "Node.js version: $version (>= v$MIN_NODE_VERSION)"
        else
            log_error "Node.js version $version < v$MIN_NODE_VERSION"
            all_valid=false
        fi
    else
        log_error "Node.js command not found"
        all_valid=false
    fi

    # Check npm
    if validate_command "npm"; then
        local npm_version
        npm_version=$(npm --version)
        log_success "npm version: $npm_version"
    else
        log_error "npm command not found"
        all_valid=false
    fi

    # Check npm global prefix configuration
    local configured_prefix
    configured_prefix=$(npm config get prefix)

    if [[ "$configured_prefix" == "$NPM_GLOBAL_PREFIX" ]]; then
        log_success "npm global prefix configured: $configured_prefix"
    else
        log_warn "npm global prefix not configured correctly (expected: $NPM_GLOBAL_PREFIX, got: $configured_prefix)"
    fi

    # Check if npm global bin is in PATH
    if echo "$PATH" | grep -q "$NPM_GLOBAL_PREFIX/bin"; then
        log_success "npm global bin is in PATH"
    else
        log_warn "npm global bin not in PATH (will be available after shell restart)"
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "Node.js environment validation passed"
        return 0
    else
        log_error "Node.js environment validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back Node.js environment installation"

    log_progress "Removing Node.js and npm"
    sudo apt-get remove -y -qq nodejs npm 2>/dev/null || true

    log_progress "Removing NodeSource repository"
    sudo rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true

    log_progress "Removing npm global directory"
    rm -rf "$NPM_GLOBAL_PREFIX" 2>/dev/null || true

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
