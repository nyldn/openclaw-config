# Auto-Update System Guide

The OpenClaw VM includes an automatic update system that keeps all software components up-to-date daily.

## What Gets Updated

### System Packages
- **Debian/Ubuntu**: `apt-get update && apt-get upgrade`
- **RHEL/CentOS**: `yum update`
- **Fedora**: `dnf upgrade`

### Python Packages
- Updates pip to latest version
- Updates all packages in the OpenClaw virtual environment
- Located at: `~/.local/venv/openclaw`

### Node.js Packages
- Updates npm itself
- Updates all global npm packages
- Includes deployment tools

### CLI Tools
- **Vercel CLI** - Latest version
- **Netlify CLI** - Latest version
- **Supabase CLI** - Latest version
- **Claude Code** - Auto-updates itself
- **OpenAI CLI** - Via npm global update
- **Gemini CLI** - Via npm global update

### MCP Servers
- Updates local MCP server dependencies
- NPX-based servers auto-update on use

### Repository Updates
- Fetches latest changes from GitHub
- Auto-pulls if no local modifications
- Located at: `~/openclawd-config`

### Cleanup
- Removes unused packages (`apt autoremove`)
- Cleans package cache (`apt autoclean`)
- Cleans npm cache

## Schedule

Updates run automatically:
- **Daily at 3:00 AM** (with random 0-30 minute delay)
- **15 minutes after boot** (if system was powered off during scheduled run)
- **Persistent** - Catches up on missed runs

## Manual Control

### Check Timer Status
```bash
systemctl --user status openclaw-auto-update.timer
```

### Check Last Run
```bash
systemctl --user status openclaw-auto-update.service
```

### View Logs
```bash
# Systemd journal
journalctl --user -u openclaw-auto-update.service

# Daily logs
cat /var/log/openclaw/auto-update-$(date +%Y%m%d).log

# Update reports
cat /var/log/openclaw/update-report-$(date +%Y%m%d).txt
```

### Run Update Now
```bash
systemctl --user start openclaw-auto-update.service
```

### View Next Scheduled Run
```bash
systemctl --user list-timers openclaw-auto-update.timer
```

### Disable Auto-Updates
```bash
systemctl --user stop openclaw-auto-update.timer
systemctl --user disable openclaw-auto-update.timer
```

### Re-enable Auto-Updates
```bash
systemctl --user enable openclaw-auto-update.timer
systemctl --user start openclaw-auto-update.timer
```

## Logs

### Log Locations
- **Daily logs**: `/var/log/openclaw/auto-update-YYYYMMDD.log`
- **Update reports**: `/var/log/openclaw/update-report-YYYYMMDD.txt`
- **Systemd journal**: `journalctl --user -u openclaw-auto-update.service`

### Log Retention
- Logs are created daily with date stamps
- Manual cleanup recommended after 30 days:
  ```bash
  find /var/log/openclaw -type f -mtime +30 -delete
  ```

### Log Rotation (Optional)
Create `/etc/logrotate.d/openclaw`:
```
/var/log/openclaw/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
}
```

## Update Reports

Daily reports include:
- System information (OS, kernel, uptime)
- Package versions (Python, Node.js, npm)
- CLI tool versions
- Disk usage
- Memory usage
- Recent package changes

View today's report:
```bash
cat /var/log/openclaw/update-report-$(date +%Y%m%d).txt
```

## Lock File

To prevent concurrent updates:
- Lock file: `/var/run/openclaw-auto-update.lock`
- Contains PID of running update process
- Automatically removed when update completes
- Stale locks are detected and removed

## Customization

### Change Update Time

Edit the timer file:
```bash
nano ~/.config/systemd/user/openclaw-auto-update.timer
```

Change the `OnCalendar` line:
```ini
# Run at 3:00 AM (default)
OnCalendar=*-*-* 03:00:00

# Run at 2:00 AM instead
OnCalendar=*-*-* 02:00:00

# Run twice daily (2 AM and 2 PM)
OnCalendar=*-*-* 02,14:00:00
```

Reload systemd:
```bash
systemctl --user daemon-reload
systemctl --user restart openclaw-auto-update.timer
```

### Skip Specific Updates

Edit the update script:
```bash
nano ~/openclawd-config/bootstrap/scripts/auto-update.sh
```

Comment out functions you don't want to run:
```bash
# update_python_packages || log_warn "Python package update had issues"
```

### Add Custom Updates

Add your own update functions to `auto-update.sh`:

```bash
update_custom_software() {
    log_info "Updating custom software..."

    # Your update commands here
    if custom-update-command; then
        log_success "Custom software updated"
    else
        log_warn "Failed to update custom software"
    fi

    return 0
}
```

Then call it in the `main()` function:
```bash
update_custom_software || log_warn "Custom update had issues"
```

## Notifications (Optional)

### Email Notifications

Install mail utilities:
```bash
sudo apt-get install mailutils
```

Add to update script:
```bash
# At end of main()
echo "Update completed. See attached report." | \
    mail -s "OpenClaw Update Report" -a "$report_file" your@email.com
```

### Slack/Discord Notifications

Add webhook notification:
```bash
send_notification() {
    local webhook_url="YOUR_WEBHOOK_URL"
    local message="$1"

    curl -X POST "$webhook_url" \
        -H 'Content-Type: application/json' \
        -d "{\"text\":\"$message\"}"
}

# In main()
send_notification "OpenClaw VM updates completed successfully"
```

## Troubleshooting

### Updates Not Running

Check timer status:
```bash
systemctl --user status openclaw-auto-update.timer
```

Check if enabled:
```bash
systemctl --user is-enabled openclaw-auto-update.timer
```

Check for errors:
```bash
journalctl --user -u openclaw-auto-update.service -n 50
```

### Permission Errors

Check log directory permissions:
```bash
ls -ld /var/log/openclaw
```

Should be owned by your user:
```bash
sudo chown -R $USER:$USER /var/log/openclaw
```

### Lock File Issues

Remove stale lock:
```bash
sudo rm -f /var/run/openclaw-auto-update.lock
```

### Service Won't Start

Check service file syntax:
```bash
systemd-analyze verify ~/.config/systemd/user/openclaw-auto-update.service
```

Reload daemon:
```bash
systemctl --user daemon-reload
```

### Updates Hanging

The service has a 10-minute timeout. If it hangs:
```bash
# Kill the service
systemctl --user stop openclaw-auto-update.service

# Check what's running
ps aux | grep auto-update
```

## Security Considerations

### Sudo Access

The update script requires sudo for:
- System package updates
- Log directory creation
- Package cleanup

Ensure your user has passwordless sudo for these operations, or updates will fail when unattended.

### Unattended Upgrades

For critical security updates, enable unattended-upgrades without prompts:
```bash
sudo apt-get install unattended-upgrades

# Enable periodic updates (no interactive prompts)
sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF

sudo tee /etc/apt/apt.conf.d/50unattended-upgrades >/dev/null <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# Enable timers if systemd is available
sudo systemctl enable --now apt-daily.timer apt-daily-upgrade.timer
```

This provides security patches between daily runs.

### Network Security

Updates require internet access. Ensure:
- Firewall allows outbound HTTP/HTTPS
- Proxy settings configured if needed
- DNS resolution working

## Performance Impact

### Resource Usage

During updates:
- **CPU**: Moderate (package compilation)
- **Memory**: Low to moderate
- **Disk I/O**: Moderate to high
- **Network**: High during downloads

### Timing Considerations

Default 3:00 AM time chosen to:
- Minimize impact on users
- Avoid peak internet hours
- Allow overnight downloads

### Random Delay

30-minute random delay prevents:
- Thundering herd problem
- Synchronized network load
- Server overload

## Best Practices

1. **Monitor logs weekly** - Check for failed updates
2. **Review reports monthly** - Ensure updates are applying
3. **Test after updates** - Validate critical applications
4. **Keep backups** - Before major system updates
5. **Document customizations** - Track changes to update script
6. **Set up notifications** - Be alerted to failures
7. **Review update schedule** - Adjust timing as needed

## Comparison: Manual vs Auto

| Aspect | Manual Updates | Auto-Updates |
|--------|----------------|--------------|
| Frequency | When you remember | Daily |
| Security patches | Delayed | Timely |
| Breaking changes | Can test first | Applied automatically |
| Maintenance | Your time | Automated |
| Consistency | Variable | Guaranteed |
| Rollback | Easier | Requires planning |

## Related Commands

```bash
# Check all installed versions
claude --version
vercel --version
netlify --version
supabase --version
python3 --version
node --version
npm --version

# Check what's outdated
pip list --outdated
npm outdated -g

# Manual system update
sudo apt-get update && sudo apt-get upgrade

# Check disk space
df -h

# Check last boot time
who -b

# View system update history
grep " install " /var/log/dpkg.log | tail -n 20
```

## Additional Resources

- **Systemd Timers**: https://www.freedesktop.org/software/systemd/man/systemd.timer.html
- **Systemd Services**: https://www.freedesktop.org/software/systemd/man/systemd.service.html
- **APT Documentation**: https://wiki.debian.org/Apt
- **npm Documentation**: https://docs.npmjs.com/cli/v9/commands/npm-update

---

**Note**: This auto-update system is designed for development VMs. For production systems, consider more robust solutions like Ansible, Chef, or Puppet.
