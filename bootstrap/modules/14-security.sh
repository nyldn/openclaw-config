#!/usr/bin/env bash

# Module: VM Security Hardening
# Implements SSH hardening, firewall, fail2ban, AIDE, and security monitoring

MODULE_NAME="security"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="VM security hardening (SSH, firewall, fail2ban, AIDE)"
MODULE_DEPS=("system-deps")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

SSH_CONFIG="/etc/ssh/sshd_config"
UFW_RULES="/etc/ufw/user.rules"
SECURITY_DIR="$HOME/.openclaw-security"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    local all_installed=true

    # Check for fail2ban
    if ! command -v fail2ban-client &>/dev/null; then
        log_debug "fail2ban not installed"
        all_installed=false
    fi

    # Check for ufw
    if ! command -v ufw &>/dev/null; then
        log_debug "ufw not installed"
        all_installed=false
    fi

    # Check for AIDE
    if ! command -v aide &>/dev/null; then
        log_debug "AIDE not installed"
        all_installed=false
    fi

    if [[ "$all_installed" == "true" ]]; then
        log_debug "Security tools are installed"
        return 0
    else
        log_debug "Some security tools are missing"
        return 1
    fi
}

# Install the module
install() {
    log_section "Installing VM Security Hardening"

    # Create security directory
    mkdir -p "$SECURITY_DIR"

    # Install security packages
    log_progress "Installing security packages..."

    local packages=(
        "fail2ban"      # Intrusion prevention
        "ufw"           # Uncomplicated Firewall
        "aide"          # File integrity monitoring
        "rkhunter"      # Rootkit detection
        "lynis"         # Security auditing
        "unattended-upgrades"  # Automatic security updates
    )

    for package in "${packages[@]}"; do
        log_info "Installing $package..."
        if sudo apt-get install -y "$package" -qq 2>&1 | tee -a /tmp/security-install.log; then
            log_success "$package installed"
        else
            log_warn "Failed to install $package"
        fi
    done

    # Configure SSH hardening
    log_progress "Configuring SSH hardening..."

    # Backup original SSH config
    if [[ -f "$SSH_CONFIG" ]]; then
        sudo cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%s)"
        log_info "SSH config backed up"
    fi

    # SSH hardening settings
    local ssh_settings=(
        "PermitRootLogin no"
        "PasswordAuthentication no"
        "PubkeyAuthentication yes"
        "PermitEmptyPasswords no"
        "ChallengeResponseAuthentication no"
        "UsePAM yes"
        "X11Forwarding no"
        "MaxAuthTries 3"
        "MaxSessions 2"
        "ClientAliveInterval 300"
        "ClientAliveCountMax 2"
        "AllowUsers $USER"
    )

    log_info "Applying SSH hardening..."
    for setting in "${ssh_settings[@]}"; do
        local key
        key=$(echo "$setting" | cut -d' ' -f1)

        # Escape special characters for safe use in sed
        local safe_key safe_setting
        # Escape regex special characters in key for grep/sed pattern
        safe_key=$(printf '%s\n' "$key" | sed 's/[.[\*^$/]/\\&/g')
        # Escape replacement special characters (& and /) in setting
        safe_setting=$(printf '%s\n' "$setting" | sed 's/[\/&]/\\&/g')

        # Check if setting exists and update, or append
        if sudo grep -q "^${key}" "$SSH_CONFIG"; then
            sudo sed -i "s/^${safe_key}.*/${safe_setting}/" "$SSH_CONFIG"
        else
            echo "$setting" | sudo tee -a "$SSH_CONFIG" >/dev/null
        fi
    done

    log_success "SSH hardening applied"

    # Configure UFW (firewall)
    log_progress "Configuring UFW firewall..."

    # Set default policies
    sudo ufw --force reset >/dev/null 2>&1
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow SSH (current port)
    local ssh_port
    ssh_port=$(grep "^Port" "$SSH_CONFIG" | awk '{print $2}' || echo "22")
    sudo ufw allow "$ssh_port"/tcp comment 'SSH'

    # Allow common development ports (localhost only where possible)
    sudo ufw allow 3000/tcp comment 'Development Server'
    sudo ufw allow 5432/tcp comment 'PostgreSQL'
    sudo ufw allow 8000/tcp comment 'Alternative Dev Server'

    # Enable UFW
    sudo ufw --force enable
    log_success "UFW firewall configured and enabled"

    # Configure fail2ban
    log_progress "Configuring fail2ban..."

    # Create local config
    sudo tee /etc/fail2ban/jail.local >/dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
destemail = root@localhost
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = $ssh_port
logpath = /var/log/auth.log
maxretry = 3
EOF

    # Start fail2ban
    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban
    log_success "fail2ban configured and started"

    # Initialize AIDE (File Integrity Monitoring)
    log_progress "Initializing AIDE database (this may take a few minutes)..."

    # Configure AIDE
    sudo tee -a /etc/aide/aide.conf >/dev/null <<EOF

# Custom rules for OpenClaw
/home/$USER/.openclaw R+b+sha256
/etc/ssh R+b+sha256
/etc/systemd R+b+sha256
EOF

    # Initialize AIDE database
    if sudo aideinit 2>&1 | tee -a /tmp/aide-init.log; then
        sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        log_success "AIDE database initialized"
    else
        log_warn "AIDE initialization had issues (check /tmp/aide-init.log)"
    fi

    # Configure automatic security updates
    log_progress "Configuring automatic security updates..."

    sudo tee /etc/apt/apt.conf.d/50unattended-upgrades >/dev/null <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

    sudo dpkg-reconfigure -plow unattended-upgrades
    log_success "Automatic security updates configured"

    # Create security monitoring script
    log_progress "Creating security monitoring script..."

    cat > "$SECURITY_DIR/security-check.sh" <<'EOF'
#!/bin/bash
# Daily security check script

echo "==================================="
echo "OpenClaw VM Security Report"
echo "Date: $(date)"
echo "==================================="
echo ""

# Check for failed login attempts
echo "Failed SSH Login Attempts (last 24h):"
sudo journalctl -u ssh --since "24 hours ago" | grep "Failed password" | wc -l

# fail2ban status
echo ""
echo "Fail2ban Status:"
sudo fail2ban-client status sshd

# Check for rootkits
echo ""
echo "Rootkit Check:"
sudo rkhunter --check --skip-keypress --report-warnings-only

# AIDE integrity check
echo ""
echo "File Integrity Check:"
if sudo aide --check; then
    echo "No changes detected"
else
    echo "WARNING: File system changes detected!"
fi

# UFW status
echo ""
echo "Firewall Status:"
sudo ufw status numbered

# Check for available updates
echo ""
echo "Available Security Updates:"
apt list --upgradable 2>/dev/null | grep -i security || echo "None"

echo ""
echo "==================================="
EOF

    chmod +x "$SECURITY_DIR/security-check.sh"
    log_success "Security monitoring script created"

    # Set up daily security check cron job
    (crontab -l 2>/dev/null; echo "0 2 * * * $SECURITY_DIR/security-check.sh > $SECURITY_DIR/security-report-\$(date +\%Y\%m\%d).txt 2>&1") | crontab -
    log_success "Daily security check scheduled"

    log_info ""
    log_info "========================================="
    log_info "VM Security Hardening Complete"
    log_info "========================================="
    log_info ""
    log_info "Installed security tools:"
    log_info "  ✓ fail2ban - Intrusion prevention (SSH brute-force protection)"
    log_info "  ✓ UFW - Firewall (default deny incoming, allow SSH + dev ports)"
    log_info "  ✓ AIDE - File integrity monitoring"
    log_info "  ✓ rkhunter - Rootkit detection"
    log_info "  ✓ lynis - Security auditing tool"
    log_info "  ✓ unattended-upgrades - Automatic security patches"
    log_info ""
    log_info "SSH Hardening Applied:"
    log_info "  ✓ Root login disabled"
    log_info "  ✓ Password authentication disabled (key-only)"
    log_info "  ✓ Max auth tries: 3"
    log_info "  ✓ Allowed users: $USER"
    log_info ""
    log_info "Firewall Rules (UFW):"
    log_info "  ✓ Default: Deny incoming, allow outgoing"
    log_info "  ✓ Allowed: SSH ($ssh_port), Dev ports (3000, 5432, 8000)"
    log_info ""
    log_info "Monitoring:"
    log_info "  ✓ Daily security reports: $SECURITY_DIR/security-report-YYYYMMDD.txt"
    log_info "  ✓ fail2ban logs: sudo journalctl -u fail2ban"
    log_info "  ✓ Manual check: $SECURITY_DIR/security-check.sh"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Review SSH config: $SSH_CONFIG"
    log_info "  2. Test SSH connection before closing current session"
    log_info "  3. Run security audit: sudo lynis audit system"
    log_info "  4. Check firewall: sudo ufw status verbose"
    log_info ""
    log_warn "IMPORTANT: Test SSH access in a NEW terminal before logging out!"
    log_info ""

    return 0
}

# Validate installation
validate() {
    log_progress "Validating VM Security Hardening"

    local all_valid=true

    # Check fail2ban
    if command -v fail2ban-client &>/dev/null; then
        if sudo systemctl is-active fail2ban &>/dev/null; then
            log_success "fail2ban is running"

            # Check banned IPs
            local banned_count
            banned_count=$(sudo fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $4}')
            log_info "Currently banned IPs: ${banned_count:-0}"
        else
            log_error "fail2ban is not running"
            all_valid=false
        fi
    else
        log_error "fail2ban not installed"
        all_valid=false
    fi

    # Check UFW
    if command -v ufw &>/dev/null; then
        if sudo ufw status | grep -q "Status: active"; then
            log_success "UFW firewall is active"
        else
            log_error "UFW firewall is not active"
            all_valid=false
        fi
    else
        log_error "UFW not installed"
        all_valid=false
    fi

    # Check AIDE
    if command -v aide &>/dev/null; then
        if [[ -f /var/lib/aide/aide.db ]]; then
            log_success "AIDE database exists"
        else
            log_warn "AIDE database not found (run aideinit)"
        fi
    else
        log_error "AIDE not installed"
        all_valid=false
    fi

    # Check SSH hardening
    if [[ -f "$SSH_CONFIG" ]]; then
        local permit_root
        permit_root=$(sudo grep "^PermitRootLogin" "$SSH_CONFIG" | awk '{print $2}')

        if [[ "$permit_root" == "no" ]]; then
            log_success "Root login disabled"
        else
            log_error "Root login is enabled (SECURITY RISK)"
            all_valid=false
        fi

        local password_auth
        password_auth=$(sudo grep "^PasswordAuthentication" "$SSH_CONFIG" | awk '{print $2}')

        if [[ "$password_auth" == "no" ]]; then
            log_success "Password authentication disabled"
        else
            log_warn "Password authentication is enabled"
        fi
    else
        log_error "SSH config not found"
        all_valid=false
    fi

    # Check security monitoring script
    if [[ -x "$SECURITY_DIR/security-check.sh" ]]; then
        log_success "Security monitoring script exists"
    else
        log_warn "Security monitoring script not found"
    fi

    # Check cron job
    if crontab -l 2>/dev/null | grep -q "security-check.sh"; then
        log_success "Daily security check is scheduled"
    else
        log_warn "Daily security check not scheduled"
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "VM Security Hardening validation passed"
        return 0
    else
        log_error "VM Security Hardening validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back VM Security Hardening"

    # Stop services
    sudo systemctl stop fail2ban 2>/dev/null || true
    sudo systemctl disable fail2ban 2>/dev/null || true

    # Disable UFW
    sudo ufw --force disable 2>/dev/null || true

    # Restore SSH config
    if [[ -f "$SSH_CONFIG.backup."* ]]; then
        local latest_backup
        latest_backup=$(ls -t "$SSH_CONFIG.backup."* | head -n1)
        sudo cp "$latest_backup" "$SSH_CONFIG"
        sudo systemctl restart sshd
        log_info "SSH config restored from backup"
    fi

    # Remove cron job
    crontab -l 2>/dev/null | grep -v "security-check.sh" | crontab -

    log_warn "Security packages (fail2ban, ufw, aide) are still installed"
    log_info "To remove manually: sudo apt-get remove fail2ban ufw aide rkhunter lynis"

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
