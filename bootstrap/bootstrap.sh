#!/usr/bin/env bash

# OpenClaw Bootstrap System
# Main orchestrator for installing and managing OpenClaw VM environment

set -euo pipefail

# Script metadata
BOOTSTRAP_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
# shellcheck source=lib/logger.sh
source "$SCRIPT_DIR/lib/logger.sh"
# shellcheck source=lib/validation.sh
source "$SCRIPT_DIR/lib/validation.sh"
# shellcheck source=lib/network.sh
source "$SCRIPT_DIR/lib/network.sh"
# shellcheck source=lib/interactive.sh
source "$SCRIPT_DIR/lib/interactive.sh"
# shellcheck source=lib/dependency-resolver.sh
source "$SCRIPT_DIR/lib/dependency-resolver.sh"

# Configuration
STATE_DIR="$HOME/.openclaw"
STATE_FILE="$STATE_DIR/bootstrap-state.yaml"
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_DIR="$SCRIPT_DIR/config"
MANIFEST_FILE="$SCRIPT_DIR/manifest.yaml"
DEFAULT_MANIFEST_URL="https://raw.githubusercontent.com/nyldn/openclaw-config/main/bootstrap/manifest.yaml"

# Command-line options
VERBOSE=false
DRY_RUN=false
NON_INTERACTIVE=false
INTERACTIVE_MODE=false
UPDATE_MODE=false
CHECK_ONLY=false
VALIDATE_ONLY=false
MANIFEST_URL="$DEFAULT_MANIFEST_URL"
SELECTED_MODULES=()
SKIP_MODULES=()

# Usage information
usage() {
    cat <<EOF
OpenClaw Bootstrap System v${BOOTSTRAP_VERSION}

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -d, --dry-run           Preview actions without executing
    -i, --interactive       Force interactive mode (default if TTY available)
    -n, --non-interactive   Run without prompts (for automation/CI)
    -u, --update            Check for and install updates
    -c, --check-updates     Only check for updates, don't install
    -V, --validate          Validate existing installation
    --doctor                Diagnose installation issues

    --only MODULES          Install only specified modules (comma-separated)
    --skip MODULES          Skip specified modules (comma-separated)
    --module MODULE         Install a specific module

    --manifest-url URL      Use custom manifest URL
    --list-modules          List available modules

EXAMPLES:
    # Initial installation
    $0

    # Check for updates
    $0 --update

    # Install specific modules
    $0 --only python,claude-cli

    # Skip optional modules
    $0 --skip gemini-cli

    # Validate installation
    $0 --validate

    # Verbose dry run
    $0 --verbose --dry-run

EOF
}

# Parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                export VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -i|--interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            -n|--non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            -u|--update)
                UPDATE_MODE=true
                shift
                ;;
            -c|--check-updates)
                CHECK_ONLY=true
                UPDATE_MODE=true
                shift
                ;;
            -V|--validate)
                VALIDATE_ONLY=true
                shift
                ;;
            --doctor)
                run_doctor
                exit 0
                ;;
            --only)
                IFS=',' read -ra SELECTED_MODULES <<< "$2"
                # Validate module names
                for module in "${SELECTED_MODULES[@]}"; do
                    if ! validate_module_name "$module"; then
                        log_error "Invalid module name: $module"
                        exit 1
                    fi
                done
                shift 2
                ;;
            --skip)
                IFS=',' read -ra SKIP_MODULES <<< "$2"
                # Validate module names
                for module in "${SKIP_MODULES[@]}"; do
                    if ! validate_module_name "$module"; then
                        log_error "Invalid module name: $module"
                        exit 1
                    fi
                done
                shift 2
                ;;
            --module)
                SELECTED_MODULES=("$2")
                # Validate module name
                if ! validate_module_name "$2"; then
                    log_error "Invalid module name: $2"
                    exit 1
                fi
                shift 2
                ;;
            --manifest-url)
                # Validate URL
                if ! validate_url "$2"; then
                    log_error "Invalid manifest URL: $2"
                    exit 1
                fi
                MANIFEST_URL="$2"
                shift 2
                ;;
            --list-modules)
                list_modules
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Initialize state directory
init_state() {
    mkdir -p "$STATE_DIR"

    if [[ ! -f "$STATE_FILE" ]]; then
        log_info "Creating initial state file"
        cat > "$STATE_FILE" <<EOF
version: "0.0.0"
installed_at: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
modules: {}
EOF
    fi
}

# List available modules
list_modules() {
    log_section "Available Modules"

    if [[ ! -d "$MODULES_DIR" ]]; then
        log_error "Modules directory not found: $MODULES_DIR"
        return 1
    fi

    local modules
    modules=($(find "$MODULES_DIR" -name "*.sh" -type f | sort))

    for module_file in "${modules[@]}"; do
        local module_name
        module_name=$(basename "$module_file" .sh | sed 's/^[0-9]*-//')

        # Source module to get description
        # shellcheck source=/dev/null
        source "$module_file"

        local desc="${MODULE_DESCRIPTION:-No description}"
        local version="${MODULE_VERSION:-unknown}"

        echo "  $module_name (v$version)"
        echo "    $desc"
        echo ""
    done
}

# Get installed module version
get_installed_version() {
    local module="$1"

    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi

    # Simple YAML parsing
    local version
    version=$(grep -A 1 "^  $module:" "$STATE_FILE" | grep "version:" | awk '{print $2}' | tr -d '"' | tr -d "'")

    if [[ -n "$version" ]]; then
        echo "$version"
        return 0
    else
        return 1
    fi
}

# Update state file with module installation
update_state() {
    local module="$1"
    local version="$2"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Check if modules section exists
    if ! grep -q "^modules:" "$STATE_FILE"; then
        echo "modules:" >> "$STATE_FILE"
    fi

    # Update or add module entry
    if grep -q "^  $module:" "$STATE_FILE"; then
        # Update existing entry
        sed -i.bak "/^  $module:/,/^  [a-z]/ s/version: .*/version: \"$version\"/" "$STATE_FILE"
        sed -i.bak "/^  $module:/,/^  [a-z]/ s/installed_at: .*/installed_at: \"$timestamp\"/" "$STATE_FILE"
    else
        # Add new entry
        cat >> "$STATE_FILE" <<EOF
  $module:
    version: "$version"
    installed_at: "$timestamp"
EOF
    fi

    rm -f "$STATE_FILE.bak"
}

# Discover and order modules
discover_modules() {
    local modules=()

    if [[ ! -d "$MODULES_DIR" ]]; then
        log_error "Modules directory not found: $MODULES_DIR"
        return 1
    fi

    # Find all module scripts (numbered files)
    while IFS= read -r module_file; do
        local module_name
        module_name=$(basename "$module_file" .sh | sed 's/^[0-9]*-//')
        modules+=("$module_name")
    done < <(find "$MODULES_DIR" -name "[0-9]*-*.sh" -type f | sort)

    echo "${modules[@]}"
}

# Check if module should be installed
should_install_module() {
    local module="$1"

    # Check if module is in skip list
    for skip in "${SKIP_MODULES[@]}"; do
        if [[ "$module" == "$skip" ]]; then
            log_debug "Skipping module: $module (in skip list)"
            return 1
        fi
    done

    # If selected modules specified, only install those
    if [[ ${#SELECTED_MODULES[@]} -gt 0 ]]; then
        for selected in "${SELECTED_MODULES[@]}"; do
            if [[ "$module" == "$selected" ]]; then
                return 0
            fi
        done
        return 1
    fi

    return 0
}

# Install a module
install_module() {
    local module="$1"
    local module_file="$MODULES_DIR/${module}.sh"

    # Find module file (may have number prefix)
    if [[ ! -f "$module_file" ]]; then
        module_file=$(find "$MODULES_DIR" -name "*-${module}.sh" | head -n1)
    fi

    if [[ ! -f "$module_file" ]]; then
        log_error "Module not found: $module"
        return 1
    fi

    log_section "Installing Module: $module"

    # Debug: Print working directory before module installation
    log_debug "Working directory before $module: $(pwd)"

    # Make module executable
    chmod +x "$module_file"

    # Source module
    # shellcheck source=/dev/null
    source "$module_file"

    local version="${MODULE_VERSION:-1.0.0}"

    # Check if already installed
    if bash "$module_file" check &>/dev/null; then
        local installed_version
        if installed_version=$(get_installed_version "$module"); then
            log_info "Module already installed: $module v$installed_version"

            if [[ "$installed_version" == "$version" ]]; then
                log_success "Module is up to date"
                return 0
            else
                log_info "Upgrading from v$installed_version to v$version"
            fi
        fi
    fi

    # Run installation
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install module: $module v$version"
        return 0
    fi

    if bash "$module_file" install; then
        log_success "Module installed: $module v$version"

        # Debug: Print working directory after module installation
        log_debug "Working directory after $module: $(pwd)"

        # Update state
        update_state "$module" "$version"

        # Run validation
        if bash "$module_file" validate; then
            log_success "Module validation passed: $module"
        else
            log_warn "Module validation failed: $module"
            return 1
        fi

        # Debug: Print working directory after validation
        log_debug "Working directory after validation: $(pwd)"

        return 0
    else
        log_error "Module installation failed: $module"
        log_debug "Working directory after failure: $(pwd)"
        return 1
    fi
}

# Validate all installed modules
validate_installation() {
    log_section "Validating Installation"

    local all_valid=true
    local modules
    modules=($(discover_modules))

    for module in "${modules[@]}"; do
        local module_file
        module_file=$(find "$MODULES_DIR" -name "*-${module}.sh" | head -n1)

        if [[ -f "$module_file" ]]; then
            chmod +x "$module_file"

            log_progress "Validating module: $module"

            if bash "$module_file" validate; then
                log_success "Module valid: $module"
            else
                log_error "Module validation failed: $module"
                all_valid=false
            fi
        fi
    done

    if [[ "$all_valid" == "true" ]]; then
        log_success "All modules validated successfully"
        return 0
    else
        log_error "Some modules failed validation"
        return 1
    fi
}

# Check for updates
check_for_updates() {
    log_section "Checking for Updates"

    local result
    check_updates "$STATE_FILE" "$MANIFEST_URL"
    result=$?

    case $result in
        0)
            log_success "System is up to date"
            return 0
            ;;
        2)
            log_info "Initial installation required"
            return 2
            ;;
        3)
            log_warn "Updates available"
            return 3
            ;;
        *)
            log_error "Failed to check for updates"
            return 1
            ;;
    esac
}

# Run system diagnostics
run_doctor() {
    log_section "OpenClaw System Diagnostics"

    # System validation
    validate_system

    # Check all modules
    validate_installation

    # Check state file
    if [[ -f "$STATE_FILE" ]]; then
        log_success "State file exists: $STATE_FILE"
        local version
        version=$(grep "^version:" "$STATE_FILE" | awk '{print $2}' | tr -d '"')
        log_info "Installed version: $version"
    else
        log_warn "State file not found"
    fi

    # Check workspace
    local workspace="$HOME/openclaw-workspace"
    if [[ -d "$workspace" ]]; then
        log_success "Workspace exists: $workspace"

        # Count directories
        local dir_count
        dir_count=$(find "$workspace" -maxdepth 1 -type d | wc -l)
        log_info "Workspace subdirectories: $dir_count"
    else
        log_warn "Workspace not found: $workspace"
    fi

    log_success "Diagnostics complete"
}

# Run interactive module selection
run_interactive_mode() {
    log_section "Interactive Module Selection"

    # Initialize interactive system
    if ! interactive_init; then
        log_warn "Interactive mode not available (no TTY detected)"
        log_info "Falling back to non-interactive mode"
        return 1
    fi

    # Show welcome screen
    show_welcome_screen

    # Get all available modules
    local -a all_modules
    all_modules=($(discover_modules))

    # Show preset menu
    log_info "Showing preset selection..."
    local preset
    preset=$(show_preset_menu)

    if [[ $? -ne 0 ]]; then
        log_error "Preset selection cancelled"
        return 1
    fi

    log_info "Selected preset: $preset"

    # Get modules based on preset
    local selected_modules_str=""

    if [[ "$preset" == "custom" ]]; then
        # Show module selection menu
        log_info "Showing module selection menu..."
        selected_modules_str=$(show_module_menu "${all_modules[@]}")

        if [[ $? -ne 0 ]]; then
            log_error "Module selection cancelled"
            return 1
        fi
    else
        # Get preset modules
        selected_modules_str=$(get_preset_modules "$preset")
    fi

    # Convert to array
    read -ra SELECTED_MODULES <<< "$selected_modules_str"

    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then
        log_error "No modules selected"
        return 1
    fi

    log_info "User selected modules: ${SELECTED_MODULES[*]}"

    # Auto-include dependencies
    log_info "Resolving dependencies..."
    local all_modules_str
    all_modules_str=$(auto_include_dependencies "$MODULES_DIR" "${SELECTED_MODULES[@]}")

    # Update selected modules with dependencies
    read -ra SELECTED_MODULES <<< "$all_modules_str"

    log_success "Modules with dependencies: ${SELECTED_MODULES[*]}"

    # Resolve installation order
    log_info "Determining installation order..."
    local ordered_modules_str
    ordered_modules_str=$(resolve_dependencies "$MODULES_DIR" "${SELECTED_MODULES[@]}")

    if [[ $? -ne 0 ]]; then
        log_error "Failed to resolve dependencies (circular dependency detected)"
        return 1
    fi

    # Update selected modules with correct order
    read -ra SELECTED_MODULES <<< "$ordered_modules_str"

    log_success "Installation order: ${SELECTED_MODULES[*]}"

    # Show confirmation
    if ! confirm_installation "${SELECTED_MODULES[@]}"; then
        log_warn "Installation cancelled by user"
        return 1
    fi

    log_success "Interactive module selection complete"
    return 0
}

# Main installation flow
main() {
    # Parse arguments
    parse_args "$@"

    # Initialize logging
    logger_init "$SCRIPT_DIR/logs"

    log_section "OpenClaw Bootstrap v$BOOTSTRAP_VERSION"

    # Debug: Print working directory
    log_debug "Initial working directory: $(pwd)"
    log_debug "SCRIPT_DIR: $SCRIPT_DIR"
    log_debug "MODULES_DIR: $MODULES_DIR"

    # Initialize state
    init_state

    # Handle validation-only mode
    if [[ "$VALIDATE_ONLY" == "true" ]]; then
        validate_installation
        exit $?
    fi

    # Handle update check mode
    if [[ "$UPDATE_MODE" == "true" ]]; then
        check_for_updates
        local result=$?

        if [[ "$CHECK_ONLY" == "true" ]] || [[ $result -eq 0 ]]; then
            exit $result
        fi

        # Continue with installation if updates available
        if [[ $result -ne 3 ]]; then
            exit $result
        fi
    fi

    # Pre-flight checks
    if ! validate_system; then
        log_error "System validation failed. Please fix issues before continuing."
        exit 1
    fi

    # Determine if we should enter interactive mode
    # Interactive mode is enabled if:
    # 1. --interactive flag is set, OR
    # 2. No --only/--skip/--module flags AND not --non-interactive AND TTY available
    local should_run_interactive=false

    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        should_run_interactive=true
    elif [[ "$NON_INTERACTIVE" == "false" ]] && \
         [[ ${#SELECTED_MODULES[@]} -eq 0 ]] && \
         [[ ${#SKIP_MODULES[@]} -eq 0 ]] && \
         [[ -t 0 && -t 1 ]]; then
        should_run_interactive=true
    fi

    # Run interactive mode if enabled
    if [[ "$should_run_interactive" == "true" ]]; then
        if run_interactive_mode; then
            log_success "Interactive mode completed"
            # SELECTED_MODULES is now populated by run_interactive_mode
        else
            log_warn "Interactive mode not available or cancelled"
            log_info "Continuing with default module installation"
            # Fall back to discovering all modules
            SELECTED_MODULES=()
        fi
    fi

    # Discover modules (if not already selected via interactive mode)
    local modules
    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then
        log_info "Discovering installation modules"
        modules=($(discover_modules))
        log_info "Found ${#modules[@]} modules: ${modules[*]}"
    else
        log_info "Using selected modules: ${SELECTED_MODULES[*]}"
        # Use SELECTED_MODULES as the modules array
        modules=("${SELECTED_MODULES[@]}")
    fi

    # Install modules
    local failed_modules=()
    local installed_count=0
    local total_count=${#modules[@]}

    for module in "${modules[@]}"; do
        if should_install_module "$module"; then
            installed_count=$((installed_count + 1))

            log_progress_bar "$installed_count" "$total_count"

            if ! install_module "$module"; then
                failed_modules+=("$module")

                if [[ "$NON_INTERACTIVE" == "false" ]]; then
                    read -r -p "Continue despite failure? [y/N] " response
                    if [[ ! "$response" =~ ^[Yy]$ ]]; then
                        log_error "Installation aborted"
                        exit 1
                    fi
                fi
            fi
        fi
    done

    # Summary
    log_section "Installation Summary"

    if [[ ${#failed_modules[@]} -eq 0 ]]; then
        log_success "All modules installed successfully"
    else
        log_warn "Some modules failed to install:"
        for module in "${failed_modules[@]}"; do
            echo "  - $module"
        done
    fi

    # Update global version
    sed -i.bak "s/^version: .*/version: \"$BOOTSTRAP_VERSION\"/" "$STATE_FILE"
    rm -f "$STATE_FILE.bak"

    log_success "Bootstrap installation complete!"
    echo ""
    log_info "Next steps:"
    echo "  1. Configure API keys in ~/openclaw-workspace/.env"
    echo "  2. Authenticate CLI tools (claude login, etc.)"
    echo "  3. Test memory system: cd ~/openclaw-workspace && python tools/memory/memory_read.py"
    echo ""
    log_info "For help: $0 --help"
}

# Run main function
main "$@"
