#!/usr/bin/env bash

# Module: Development Tools
# Installs essential tools for Next.js + Supabase + Payload CMS development

MODULE_NAME="dev-tools"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="Essential development tools (Biome, pnpm, Doppler CLI)"
MODULE_DEPS=("nodejs")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    local all_installed=true

    # Check pnpm
    if ! validate_command "pnpm"; then
        log_debug "pnpm not found"
        all_installed=false
    fi

    # Check Biome
    if ! validate_command "biome"; then
        log_debug "Biome not found"
        all_installed=false
    fi

    # Check Doppler CLI
    if ! validate_command "doppler"; then
        log_debug "Doppler CLI not found"
        all_installed=false
    fi

    if [[ "$all_installed" == "true" ]]; then
        log_debug "All development tools are installed"
        return 0
    else
        log_debug "Some development tools are missing"
        return 1
    fi
}

# Install the module
install() {
    log_section "Installing Development Tools"

    # Verify npm is available
    if ! validate_command "npm"; then
        log_error "npm is required but not found"
        log_info "Please install Node.js first (module 03-nodejs.sh)"
        return 1
    fi

    # Install pnpm
    log_progress "Installing pnpm (fast, disk-efficient package manager)"
    if npm install -g pnpm --silent 2>/dev/null; then
        local pnpm_version
        pnpm_version=$(pnpm --version 2>/dev/null)
        log_success "pnpm installed: v$pnpm_version"
    else
        log_error "Failed to install pnpm"
        return 1
    fi

    # Install Biome (unified linter/formatter)
    log_progress "Installing Biome (unified linter and formatter)"
    if npm install -g @biomejs/biome --silent 2>/dev/null; then
        local biome_version
        biome_version=$(biome --version 2>/dev/null | head -n1)
        log_success "Biome installed: $biome_version"
    else
        log_error "Failed to install Biome"
        return 1
    fi

    # Install Doppler CLI
    log_progress "Installing Doppler CLI (secrets management)"

    # Check OS and install accordingly
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux installation
        log_info "Installing Doppler CLI for Linux..."

        if curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh | sh 2>&1 | tee -a /tmp/doppler-install.log; then
            log_success "Doppler CLI installed"
        else
            log_warn "Failed to install Doppler CLI (optional tool)"
            log_info "You can install manually later with: curl -Ls https://cli.doppler.com/install.sh | sh"
        fi

    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS installation
        log_info "Installing Doppler CLI for macOS..."

        if command -v brew &>/dev/null; then
            if brew install dopplerhq/cli/doppler 2>&1 | tee -a /tmp/doppler-install.log; then
                log_success "Doppler CLI installed via Homebrew"
            else
                log_warn "Failed to install Doppler CLI via Homebrew"
            fi
        else
            log_warn "Homebrew not found, skipping Doppler CLI installation"
            log_info "Install Homebrew first or use: curl -Ls https://cli.doppler.com/install.sh | sh"
        fi
    else
        log_warn "Unsupported OS for automatic Doppler installation: $OSTYPE"
        log_info "Install manually from: https://docs.doppler.com/docs/install-cli"
    fi

    # Install additional global tools
    log_progress "Installing additional development tools..."

    # Bruno CLI (API testing)
    if npm install -g @usebruno/cli --silent 2>/dev/null; then
        log_success "Bruno CLI installed"
    else
        log_warn "Failed to install Bruno CLI (optional)"
    fi

    # Turborepo (monorepo management)
    if npm install -g turbo --silent 2>/dev/null; then
        log_success "Turborepo installed"
    else
        log_warn "Failed to install Turborepo (optional)"
    fi

    log_info ""
    log_info "Development tools installed successfully!"
    log_info ""
    log_info "Installed tools:"
    log_info "  ✓ pnpm - Fast, disk-efficient package manager"
    log_info "  ✓ Biome - Unified linter and formatter (replaces ESLint + Prettier)"
    log_info "  ✓ Doppler CLI - Secrets and environment variable management"
    log_info "  ✓ Bruno CLI - API testing and documentation"
    log_info "  ✓ Turborepo - High-performance monorepo build system"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Use 'pnpm' instead of 'npm' for faster installs"
    log_info "  2. Run 'biome init' in your project to configure linting"
    log_info "  3. Authenticate Doppler: doppler login"
    log_info ""
    log_info "Project setup helpers:"
    log_info "  - Initialize Biome: biome init"
    log_info "  - Create Turbo monorepo: npx create-turbo@latest"
    log_info "  - Setup Bruno collection: bru new <collection-name>"
    log_info ""

    return 0
}

# Validate installation
validate() {
    log_progress "Validating Development Tools installation"

    export PATH="$HOME/.local/npm-global/bin:$PATH"

    local all_valid=true

    # Check pnpm
    if validate_command "pnpm"; then
        local pnpm_version
        pnpm_version=$(pnpm --version 2>/dev/null)
        log_success "pnpm installed: v$pnpm_version"
    else
        log_error "pnpm not found"
        all_valid=false
    fi

    # Check Biome
    if validate_command "biome"; then
        local biome_version
        biome_version=$(biome --version 2>/dev/null | head -n1)
        log_success "Biome installed: $biome_version"
    else
        log_error "Biome not found"
        all_valid=false
    fi

    # Check Doppler CLI
    if validate_command "doppler"; then
        local doppler_version
        doppler_version=$(doppler --version 2>/dev/null | head -n1)
        log_success "Doppler CLI installed: $doppler_version"
    else
        log_warn "Doppler CLI not found (optional tool)"
    fi

    # Check Bruno CLI
    if validate_command "bru"; then
        log_success "Bruno CLI installed"
    else
        log_warn "Bruno CLI not found (optional tool)"
    fi

    # Check Turborepo
    if validate_command "turbo"; then
        local turbo_version
        turbo_version=$(turbo --version 2>/dev/null)
        log_success "Turborepo installed: v$turbo_version"
    else
        log_warn "Turborepo not found (optional tool)"
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "Development Tools validation passed"
        return 0
    else
        log_error "Development Tools validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back Development Tools installation"

    # Uninstall npm packages
    log_progress "Uninstalling pnpm"
    npm uninstall -g pnpm --silent 2>/dev/null || true

    log_progress "Uninstalling Biome"
    npm uninstall -g @biomejs/biome --silent 2>/dev/null || true

    log_progress "Uninstalling Bruno CLI"
    npm uninstall -g @usebruno/cli --silent 2>/dev/null || true

    log_progress "Uninstalling Turborepo"
    npm uninstall -g turbo --silent 2>/dev/null || true

    # Note: Doppler CLI requires manual uninstall
    # Linux: sudo rm $(which doppler)
    # macOS: brew uninstall doppler

    log_warn "Note: Doppler CLI requires manual uninstallation"
    log_info "  Linux: sudo rm \$(which doppler)"
    log_info "  macOS: brew uninstall doppler"

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
