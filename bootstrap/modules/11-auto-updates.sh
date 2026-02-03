#!/usr/bin/env bash

# Module: Auto-Updates
# Configures daily automatic updates for all system components

MODULE_NAME="auto-updates"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="Daily automatic updates for system packages and tools"
MODULE_DEPS=("system-deps")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

BOOTSTRAP_DIR="$(dirname "$SCRIPT_DIR")"
UPDATE_SCRIPT="$BOOTSTRAP_DIR/scripts/auto-update.sh"
SYSTEMD_DIR="$BOOTSTRAP_DIR/systemd"
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"
LOG_DIR="/var/log/openclaw"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    # Check if update script exists
    if [[ ! -f "$UPDATE_SCRIPT" ]]; then
        log_debug "Update script not found: $UPDATE_SCRIPT"
        return 1
    fi

    # Check if systemd timer is enabled
    if systemctl --user is-enabled openclaw-auto-update.timer &>/dev/null; then
        log_debug "Auto-update timer is enabled"
        return 0
    else
        log_debug "Auto-update timer is not enabled"
        return 1
    fi
}

# Detect if running in a container (Docker, Podman, etc.)
is_container() {
    [[ -f /.dockerenv ]] || \
    [[ -f /run/.containerenv ]] || \
    grep -qE '(docker|lxc|containerd|kubepods)' /proc/1/cgroup 2>/dev/null || \
    [[ "$(cat /proc/1/sched 2>/dev/null | head -1)" =~ "bash|sh" ]]
}

# Install the module
install() {
    log_section "Installing Auto-Update System"

    if is_container; then
        log_warn "Container environment detected - systemd not available"
        log_info "Auto-updates require systemd and are skipped in containers"
        log_info "Run updates manually: ~/openclaw-config/bootstrap/scripts/auto-update.sh"
        return 0
    fi

    # Create log directory
    log_progress "Creating log directory: $LOG_DIR"
    if ! sudo mkdir -p "$LOG_DIR"; then
        log_error "Failed to create log directory"
        return 1
    fi

    if ! sudo chown "$USER:$USER" "$LOG_DIR"; then
        log_error "Failed to set log directory permissions"
        return 1
    fi

    log_success "Log directory created"

    # Verify update script exists
    if [[ ! -f "$UPDATE_SCRIPT" ]]; then
        log_error "Update script not found: $UPDATE_SCRIPT"
        return 1
    fi

    # Make update script executable
    log_progress "Making update script executable"
    if ! chmod +x "$UPDATE_SCRIPT"; then
        log_error "Failed to make update script executable"
        return 1
    fi
    log_success "Update script is executable"

    # Create user systemd directory
    log_progress "Creating systemd user directory"
    mkdir -p "$USER_SYSTEMD_DIR"
    log_success "Systemd user directory created"

    # Install systemd service
    log_progress "Installing systemd service"
    if [[ ! -f "$SYSTEMD_DIR/openclaw-auto-update.service" ]]; then
        log_error "Service file not found: $SYSTEMD_DIR/openclaw-auto-update.service"
        return 1
    fi

    # Expand %u and %h in service file
    sed "s|%u|$USER|g; s|%h|$HOME|g" \
        "$SYSTEMD_DIR/openclaw-auto-update.service" \
        > "$USER_SYSTEMD_DIR/openclaw-auto-update.service"

    log_success "Systemd service installed"

    # Install systemd timer
    log_progress "Installing systemd timer"
    if [[ ! -f "$SYSTEMD_DIR/openclaw-auto-update.timer" ]]; then
        log_error "Timer file not found: $SYSTEMD_DIR/openclaw-auto-update.timer"
        return 1
    fi

    cp "$SYSTEMD_DIR/openclaw-auto-update.timer" \
        "$USER_SYSTEMD_DIR/openclaw-auto-update.timer"

    log_success "Systemd timer installed"

    # Reload systemd
    log_progress "Reloading systemd daemon"
    if ! systemctl --user daemon-reload; then
        log_error "Failed to reload systemd daemon"
        return 1
    fi
    log_success "Systemd daemon reloaded"

    # Enable timer
    log_progress "Enabling auto-update timer"
    if ! systemctl --user enable openclaw-auto-update.timer; then
        log_error "Failed to enable auto-update timer"
        return 1
    fi
    log_success "Auto-update timer enabled"

    # Start timer
    log_progress "Starting auto-update timer"
    if ! systemctl --user start openclaw-auto-update.timer; then
        log_error "Failed to start auto-update timer"
        return 1
    fi
    log_success "Auto-update timer started"

    # Enable lingering (allows user services to run when not logged in)
    log_progress "Enabling user lingering"
    if ! sudo loginctl enable-linger "$USER" 2>/dev/null; then
        log_warn "Failed to enable lingering (may require systemd >= 230)"
        log_info "User services may not run when not logged in"
    else
        log_success "User lingering enabled"
    fi

    log_info ""
    log_info "Auto-update system configured successfully!"
    log_info ""
    log_info "Daily updates will run at 3:00 AM"
    log_info "Updates will also run 15 minutes after boot"
    log_info ""
    log_info "Useful commands:"
    log_info "  Check timer status:  systemctl --user status openclaw-auto-update.timer"
    log_info "  Check last run:      systemctl --user status openclaw-auto-update.service"
    log_info "  View logs:           journalctl --user -u openclaw-auto-update.service"
    log_info "  Run update now:      systemctl --user start openclaw-auto-update.service"
    log_info "  View update report:  cat $LOG_DIR/update-report-\$(date +%Y%m%d).txt"
    log_info ""

    return 0
}

# Validate installation
validate() {
    log_progress "Validating Auto-Update System installation"

    if is_container; then
        log_info "Container environment - systemd components skipped"
        if [[ -x "$UPDATE_SCRIPT" ]]; then
            log_success "Update script is available for manual use"
            return 0
        else
            log_error "Update script not found"
            return 1
        fi
    fi

    local all_valid=true

    # Check update script
    if [[ -x "$UPDATE_SCRIPT" ]]; then
        log_success "Update script is executable: $UPDATE_SCRIPT"
    else
        log_error "Update script not found or not executable"
        all_valid=false
    fi

    # Check log directory
    if [[ -d "$LOG_DIR" ]]; then
        if [[ -w "$LOG_DIR" ]]; then
            log_success "Log directory is writable: $LOG_DIR"
        else
            log_error "Log directory is not writable: $LOG_DIR"
            all_valid=false
        fi
    else
        log_error "Log directory not found: $LOG_DIR"
        all_valid=false
    fi

    # Check systemd service
    if [[ -f "$USER_SYSTEMD_DIR/openclaw-auto-update.service" ]]; then
        log_success "Systemd service installed"
    else
        log_error "Systemd service not found"
        all_valid=false
    fi

    # Check systemd timer
    if [[ -f "$USER_SYSTEMD_DIR/openclaw-auto-update.timer" ]]; then
        log_success "Systemd timer installed"
    else
        log_error "Systemd timer not found"
        all_valid=false
    fi

    # Check timer status
    if systemctl --user is-enabled openclaw-auto-update.timer &>/dev/null; then
        log_success "Auto-update timer is enabled"
    else
        log_error "Auto-update timer is not enabled"
        all_valid=false
    fi

    if systemctl --user is-active openclaw-auto-update.timer &>/dev/null; then
        log_success "Auto-update timer is active"

        # Show next run time
        local next_run
        next_run=$(systemctl --user list-timers openclaw-auto-update.timer 2>/dev/null | grep openclaw-auto-update | awk '{print $1, $2, $3}')
        if [[ -n "$next_run" ]]; then
            log_info "Next scheduled update: $next_run"
        fi
    else
        log_error "Auto-update timer is not active"
        all_valid=false
    fi

    # Check lingering
    if loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
        log_success "User lingering is enabled"
    else
        log_warn "User lingering is not enabled (updates may not run when logged out)"
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "Auto-Update System validation passed"
        return 0
    else
        log_error "Auto-Update System validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back Auto-Update System installation"

    # Stop and disable timer
    if systemctl --user is-active openclaw-auto-update.timer &>/dev/null; then
        log_progress "Stopping auto-update timer"
        systemctl --user stop openclaw-auto-update.timer 2>/dev/null || true
    fi

    if systemctl --user is-enabled openclaw-auto-update.timer &>/dev/null; then
        log_progress "Disabling auto-update timer"
        systemctl --user disable openclaw-auto-update.timer 2>/dev/null || true
    fi

    # Remove systemd files
    if [[ -f "$USER_SYSTEMD_DIR/openclaw-auto-update.service" ]]; then
        log_progress "Removing systemd service"
        rm -f "$USER_SYSTEMD_DIR/openclaw-auto-update.service"
    fi

    if [[ -f "$USER_SYSTEMD_DIR/openclaw-auto-update.timer" ]]; then
        log_progress "Removing systemd timer"
        rm -f "$USER_SYSTEMD_DIR/openclaw-auto-update.timer"
    fi

    # Reload systemd
    log_progress "Reloading systemd daemon"
    systemctl --user daemon-reload 2>/dev/null || true

    # Note: We don't remove the log directory or update script
    # as they may contain useful data and are part of the repository

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
