#!/usr/bin/env bash

# OpenClaw Remote Installation Script
# Fetches and runs the bootstrap system from GitHub

set -euo pipefail

# Configuration
REPO_URL="https://github.com/user/openclawd-config"
BRANCH="main"
TEMP_DIR="/tmp/openclaw-bootstrap-$$"
INSTALL_DIR="$HOME/openclaw-bootstrap"

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

    # Remove temp directory if it exists
    rm -rf "$TEMP_DIR"

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

    # Copy bootstrap directory
    if [[ -d "$TEMP_DIR/bootstrap" ]]; then
        cp -r "$TEMP_DIR/bootstrap/"* "$INSTALL_DIR/"
        log_success "Bootstrap files copied to $INSTALL_DIR"
    else
        log_error "Bootstrap directory not found in repository"
        exit 1
    fi

    # Make scripts executable
    chmod +x "$INSTALL_DIR/bootstrap.sh"
    chmod +x "$INSTALL_DIR/modules/"*.sh 2>/dev/null || true

    log_success "Bootstrap system installed"
}

# Run bootstrap
run_bootstrap() {
    log_info "Running bootstrap installation"

    cd "$INSTALL_DIR" || exit 1

    # Pass any arguments to bootstrap script
    if ./bootstrap.sh "$@"; then
        log_success "Bootstrap completed successfully"
    else
        log_error "Bootstrap failed"
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
    log_info "Bootstrap directory: $INSTALL_DIR"
    log_info "Workspace directory: $HOME/openclaw-workspace"
    echo ""
    log_info "To run bootstrap again: cd $INSTALL_DIR && ./bootstrap.sh"
}

# Run main function
main "$@"
