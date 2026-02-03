#!/usr/bin/env bash

# OpenClaw Remote Installation Script
# Fetches and runs the bootstrap system from GitHub
#
# SECURITY NOTICE:
# This script is designed to be safe for curl-to-bash usage:
# - Uses mktemp for secure temporary directories
# - Clones full repository for inspection
# - Auto-detects TTY and uses non-interactive mode when piped
# - Only installs minimal modules (system-deps, python, nodejs) by default
#
# RECOMMENDED: Clone repository and review before running:
#   git clone https://github.com/nyldn/openclaw-config.git
#   cd openclaw-config/bootstrap
#   ./bootstrap.sh --interactive

set -euo pipefail

# Configuration
REPO_URL="https://github.com/nyldn/openclaw-config"
BRANCH="main"
TEMP_DIR=""  # Will be set using mktemp
INSTALL_DIR="$HOME/openclaw-config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites"

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi

    # Check for required commands
    local required_cmds=("git" "curl" "bash")

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Required command not found: $cmd"
            log_info "Please install $cmd and try again"
            exit 1
        fi
    done

    log_success "Prerequisites check passed"
}

# Clone repository
clone_repo() {
    log_info "Cloning OpenClaw repository"

    # Create secure temporary directory
    TEMP_DIR=$(mktemp -d) || {
        log_error "Failed to create temporary directory"
        exit 1
    }

    # Ensure cleanup on exit
    trap 'rm -rf "$TEMP_DIR"' EXIT INT TERM

    # Clone to temp directory
    if git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TEMP_DIR" &>/dev/null; then
        log_success "Repository cloned to $TEMP_DIR"
    else
        log_error "Failed to clone repository"
        exit 1
    fi
}

# Install bootstrap
install_bootstrap() {
    log_info "Installing bootstrap system"

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Copy entire repository (not just bootstrap)
    if [[ -d "$TEMP_DIR" ]]; then
        # Copy all files except .git
        rsync -a --exclude='.git' "$TEMP_DIR/" "$INSTALL_DIR/" || \
        cp -r "$TEMP_DIR/"* "$INSTALL_DIR/" 2>/dev/null || true

        log_success "Repository files copied to $INSTALL_DIR"
    else
        log_error "Repository not found"
        exit 1
    fi

    # Make scripts executable
    chmod +x "$INSTALL_DIR/bootstrap/bootstrap.sh" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/bootstrap/modules/"*.sh 2>/dev/null || true
    chmod +x "$INSTALL_DIR/bootstrap/scripts/"*.sh 2>/dev/null || true

    log_success "Bootstrap system installed"
}

# Run bootstrap
run_bootstrap() {
    log_info "Running bootstrap installation"

    cd "$INSTALL_DIR/bootstrap" || exit 1

    # Check if we have a TTY
    local bootstrap_args=("$@")

    if [[ ! -t 0 ]]; then
        log_warn "No TTY detected (running via curl-to-bash)"
        log_info "Using non-interactive mode with minimal installation"
        bootstrap_args=("--non-interactive" "--only" "system-deps,python,nodejs")
    fi

    # Pass arguments to bootstrap script
    if ./bootstrap.sh "${bootstrap_args[@]}"; then
        log_success "Bootstrap completed successfully"
    else
        log_error "Bootstrap failed"
        log_info "Check logs at: $INSTALL_DIR/bootstrap/logs/"
        exit 1
    fi

    cd - > /dev/null || exit 1
}

# Cleanup
cleanup() {
    log_info "Cleaning up temporary files"

    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log_success "Temporary files removed"
    fi
}

# Main installation
main() {
    echo "╔════════════════════════════════════════╗"
    echo "║   OpenClaw Remote Installation         ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Check prerequisites
    check_prerequisites

    # Clone repository
    clone_repo

    # Install bootstrap
    install_bootstrap

    # Run bootstrap with passed arguments
    run_bootstrap "$@"

    # Cleanup
    cleanup

    echo ""
    log_success "Installation complete!"
    echo ""
    log_info "Repository: $INSTALL_DIR"
    log_info "Bootstrap: $INSTALL_DIR/bootstrap"
    log_info "Workspace: $HOME/openclaw-workspace"
    echo ""

    if [[ -t 0 ]]; then
        log_info "To customize installation:"
        log_info "  cd $INSTALL_DIR/bootstrap && ./bootstrap.sh --interactive"
    else
        log_info "Minimal installation completed (system-deps, python, nodejs)"
        log_info "To install more modules:"
        log_info "  cd $INSTALL_DIR/bootstrap"
        log_info "  ./bootstrap.sh --interactive"
        log_info "  ./bootstrap.sh --list-modules  # See all available modules"
    fi
}

# Run main function
main "$@"
