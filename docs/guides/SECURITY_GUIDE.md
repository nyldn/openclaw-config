# OpenClaw VM Security Guide

This guide covers security hardening for the OpenClaw VM deployment, including OpenClaw-specific security practices and general VM hardening.

---

## 🔒 Table of Contents

1. [OpenClaw Security](#openclaw-security)
2. [VM Hardening](#vm-hardening)
3. [Network Security](#network-security)
4. [Access Control](#access-control)
5. [Monitoring & Auditing](#monitoring--auditing)
6. [Security Checklist](#security-checklist)

---

## OpenClaw Security

### Critical Security Warnings

⚠️ **NEVER** expose OpenClaw web interface to public internet
⚠️ **NEVER** store plaintext API keys in configuration files
⚠️ **NEVER** install untrusted skills from unknown sources
⚠️ **ALWAYS** run OpenClaw in Docker with security hardening
⚠️ **ALWAYS** treat links, attachments, and pasted instructions as hostile

**Container note:** When running OpenClaw inside a container for testing, host-level tools like `ufw` and `fail2ban` may not be available. In that case, the `security` module will warn (not fail) and you should apply firewall and intrusion prevention on the host or VM.

### Known Security Issues

**Documented Vulnerabilities:**
- Plaintext API key leakage ([Source](https://garymarcus.substack.com/p/openclaw-aka-moltbot-is-everywhere))
- Malicious skills on ClawHub targeting crypto users ([Source](https://www.tomshardware.com/tech-industry/cyber-security/malicious-moltbot-skill-targets-crypto-users-on-clawhub))
- Prompt injection vulnerabilities ([Source](https://blogs.cisco.com/ai/personal-ai-agents-like-openclaw-are-a-security-nightmare))
- Permission model bypass (CVE-2026-21636 in Node.js <22.12.0)
- Async hooks DoS (CVE-2025-59466 in Node.js <22.12.0)

**Attack Vectors:**
1. **Prompt Injection** - Malicious instructions embedded in documents, web pages, emails
2. **Skill Poisoning** - Malicious code in community skills
3. **Credential Theft** - API keys exposed through logs or insecure storage
4. **Lateral Movement** - Compromised OpenClaw accessing other services

### OpenClaw-Specific Hardening

#### 1. Network Binding

**Secure Configuration:**
```json
{
  "network": {
    "bindAddress": "127.0.0.1",
    "port": 3000,
    "publicAccess": false
  }
}
```

**Why:** OpenClaw's web interface is not hardened for public exposure ([Source](https://docs.openclaw.ai/gateway/security))

**Access Methods:**
- Local only: `http://localhost:3000`
- Remote access: Use SSH tunnel (`ssh -L 3000:localhost:3000 user@vm-ip`)
- Never bind to `0.0.0.0` or public IP

---

#### 2. Docker Deployment (Recommended)

**Secure Docker Run:**
```bash
docker run -d \
  --name openclaw \
  --user node \
  --read-only \
  --cap-drop=ALL \
  --tmpfs /tmp \
  --tmpfs /app/.openclaw \
  -v /limited/path:/data:ro \
  -e ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY} \
  openclaw/openclaw:latest
```

**Security Flags Explained:**
- `--user node` - Run as non-root user
- `--read-only` - Prevent filesystem writes (except tmpfs)
- `--cap-drop=ALL` - Remove all Linux capabilities
- `--tmpfs` - Temporary filesystems for runtime data
- `-v /limited/path:/data:ro` - Read-only volume mounts only

**Source:** [Composio Security Guide](https://composio.dev/blog/secure-openclaw-moltbot-clawdbot-setup)

---

#### 3. Credential Management

**❌ NEVER do this:**
```json
{
  "apiKeys": {
    "anthropic": "sk-ant-api03-..."  // Plaintext in config
  }
}
```

**✅ DO this instead:**
```bash
# Use environment variables
export ANTHROPIC_API_KEY="sk-ant-api03-..."

# Or use Doppler for centralized secrets
doppler run -- openclaw start

# Or use encrypted keyring
openclaw config set --keyring anthropic_key
```

**Key Rotation Policy:**
- Rotate API keys every 90 days
- Immediately rotate if exposed
- Use separate keys for dev/staging/production
- Monitor API key usage for anomalies

---

#### 4. Skill Security

**Vetting Process:**
```bash
# Before installing ANY skill:
1. Review source code on GitHub
2. Check author reputation and history
3. Look for suspicious:
   - Network requests to unknown domains
   - File system access beyond stated purpose
   - Credential access or storage
   - Code obfuscation

# Install in sandbox mode first
openclaw skill install --sandbox <skill-name>

# Test thoroughly before production use
```

**Known Malicious Patterns:**
- Cryptocurrency wallet access
- Credential exfiltration
- Backdoor installation
- Data mining

**ClawHub Safety:** 14 malicious skills found in Oct 2025 ([Source](https://www.tomshardware.com/tech-industry/cyber-security/malicious-moltbot-skill-targets-crypto-users-on-clawhub))

---

#### 5. Prompt Injection Defense

**Security Measures:**
```json
{
  "security": {
    "requireConfirmation": true,
    "sandboxMode": true,
    "allowedDomains": [
      "anthropic.com",
      "openai.com",
      "github.com"
    ],
    "disallowedActions": [
      "delete_all",
      "sudo",
      "rm -rf"
    ]
  }
}
```

**Best Practices:**
- Enable confirmation prompts for destructive actions
- Use allowlists for inbound DMs and mentions
- Treat all external content (links, attachments, pasted text) as potentially malicious
- Review actions before execution
- Disable auto-execution of discovered commands

---

#### 6. File System Access Control

**Principle of Least Privilege:**
```bash
# Create dedicated user for OpenClaw
sudo useradd -r -s /bin/bash -d /opt/openclaw openclaw-user

# Limit access to specific directories
/opt/openclaw/workspace  # Read/write allowed
/opt/openclaw/skills     # Read-only
/etc                     # No access
/root                    # No access
/home/*                  # No access (except openclaw-user)
```

**AppArmor Profile (optional):**
```
# /etc/apparmor.d/openclaw
profile openclaw /usr/bin/openclaw {
  /opt/openclaw/** rw,
  /tmp/** rw,
  deny /etc/** w,
  deny /root/** rw,
  deny /home/*/** rw,
}
```

---

## VM Hardening

Installed via `bootstrap/modules/14-security.sh`

### 1. SSH Hardening

**Configuration Applied:**
```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
MaxSessions 2
AllowUsers <your-user>
```

**Testing:**
```bash
# Verify SSH config
sudo sshd -t

# Test in new terminal BEFORE logging out
ssh -p <port> user@vm-ip

# Check active sessions
who
```

**SSH Key Management:**
```bash
# Generate strong key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@vm-ip

# Verify key-based login works
ssh -i ~/.ssh/id_ed25519 user@vm-ip
```

---

### 2. Firewall (UFW)

**Default Rules:**
```bash
# Check status
sudo ufw status verbose

# Default policies
Default: deny (incoming), allow (outgoing), disabled (routed)

# Allowed ports
22/tcp (SSH)
3000/tcp (Development server)
5432/tcp (PostgreSQL)
8000/tcp (Alternative dev server)
```

**Adding Rules:**
```bash
# Allow specific IP only
sudo ufw allow from 192.168.1.100 to any port 22

# Delete rule
sudo ufw delete allow 8000/tcp

# Rate limiting (SSH brute-force protection)
sudo ufw limit 22/tcp
```

---

### 3. Fail2ban (Intrusion Prevention)

**Configuration:**
- Ban time: 1 hour (3600 seconds)
- Find time: 10 minutes (600 seconds)
- Max retry: 3 attempts

**Monitoring:**
```bash
# Check status
sudo fail2ban-client status sshd

# Currently banned IPs
sudo fail2ban-client status sshd | grep "Currently banned"

# Unban IP
sudo fail2ban-client set sshd unbanip 192.168.1.100

# Check logs
sudo journalctl -u fail2ban -f
```

---

### 4. File Integrity Monitoring (AIDE)

**Daily Checks:**
```bash
# Manual check
sudo aide --check

# Update database after legitimate changes
sudo aide --update
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

**Monitored Paths:**
- `/home/$USER/.openclaw` - OpenClaw configuration
- `/etc/ssh` - SSH configuration
- `/etc/systemd` - System services

**Alerts:**
- Changes logged to daily security report
- Manual review required for unexpected modifications

---

### 5. Rootkit Detection (rkhunter)

**Scheduled Scans:**
```bash
# Manual scan
sudo rkhunter --check --skip-keypress

# Update definitions
sudo rkhunter --update

# Warnings only
sudo rkhunter --check --report-warnings-only
```

**Common False Positives:**
- Hidden files in user directories (normal)
- Development tools (Node.js, Python)
- Docker containers

---

### 6. Automatic Security Updates

**Configuration:** `/etc/apt/apt.conf.d/20auto-upgrades` and `/etc/apt/apt.conf.d/50unattended-upgrades`

**What Gets Updated:**
- Security patches only
- Kernel updates
- System libraries

**What Doesn't:**
- Major version upgrades
- Application packages
- Manual installs (npm, pip, etc.)

**Manual Updates:**
```bash
# Check for updates
sudo apt update
sudo apt list --upgradable

# Install security updates only
sudo unattended-upgrade -d

# Full upgrade (manual)
sudo apt upgrade
```

---

## Network Security

### Port Management

**Open Ports Inventory:**
```bash
# List listening ports
sudo ss -tulpn

# Common ports
22    - SSH (change default!)
3000  - OpenClaw/Development
5432  - PostgreSQL
8000  - Alternative dev server
```

**Recommendations:**
1. **Change SSH port** from 22 to random high port (e.g., 2222-65535)
2. **Close unused ports** immediately
3. **Use localhost binding** for services not needing external access
4. **Implement port knocking** for SSH (advanced)

---

### Outbound Traffic Control

**Restrict OpenClaw Network Access:**
```bash
# Allow only specific domains (iptables)
sudo iptables -A OUTPUT -p tcp -d anthropic.com -j ACCEPT
sudo iptables -A OUTPUT -p tcp -d openai.com -j ACCEPT
sudo iptables -A OUTPUT -p tcp -d github.com -j ACCEPT
sudo iptables -A OUTPUT -p tcp -j DROP

# Or use OpenClaw's allowedDomains config
```

---

## Access Control

### User Privilege Management

**Sudoers Configuration:**
```bash
# Allow specific commands only
openclaw-user ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart openclaw

# Never allow
openclaw-user ALL=(ALL) ALL  # Too permissive!
```

**Principle of Least Privilege:**
1. Create dedicated user for OpenClaw
2. No sudo access for automated processes
3. Use service accounts for background tasks
4. Rotate passwords/keys regularly

---

### SSH Key Security

**Key Types (in order of preference):**
1. Ed25519 (fastest, most secure)
2. ECDSA (P-256, P-384, P-521)
3. RSA (4096-bit minimum)
4. ❌ DSA (deprecated, insecure)

**Key Protection:**
```bash
# Set proper permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# Use passphrase for private keys
ssh-keygen -t ed25519 -C "email@example.com"
# Enter strong passphrase when prompted

# Use ssh-agent to avoid repeated passphrase entry
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

---

## Monitoring & Auditing

### Daily Security Report

**Location:** `~/.openclaw-security/security-report-YYYYMMDD.txt`

**Contains:**
- Failed SSH login attempts
- Fail2ban status and banned IPs
- Rootkit scan results
- File integrity check (AIDE)
- Firewall status
- Available security updates

**Reviewing:**
```bash
# Today's report
cat ~/.openclaw-security/security-report-$(date +%Y%m%d).txt

# Last 7 days
find ~/.openclaw-security -name "security-report-*" -mtime -7 -exec cat {} \;
```

---

### Log Monitoring

**Critical Logs:**
```bash
# SSH authentication
sudo journalctl -u ssh --since "24 hours ago"

# fail2ban
sudo journalctl -u fail2ban -f

# System logs
sudo journalctl -p err..emerg --since "1 hour ago"

# OpenClaw logs
tail -f ~/.openclaw/openclaw.log
tail -f ~/.openclaw/audit.log
```

**Log Rotation:**
```bash
# /etc/logrotate.d/openclaw
/home/*/.openclaw/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
}
```

---

### Security Auditing

**Manual Audit:**
```bash
# Run Lynis security audit
sudo lynis audit system

# Output
/var/log/lynis.log
/var/log/lynis-report.dat
```

**Key Metrics:**
- Hardening index (target: >80)
- Warnings (address all)
- Suggestions (implement high-priority)

**Automated Audits:**
```bash
# Add to cron
0 3 * * 0 sudo lynis audit system --quick
```

---

## Security Checklist

### Initial Setup

- [ ] Change default SSH port
- [ ] Disable root login
- [ ] Disable password authentication
- [ ] Install security tools (fail2ban, ufw, aide)
- [ ] Configure firewall rules
- [ ] Enable automatic security updates
- [ ] Set up monitoring scripts
- [ ] Create security baseline (AIDE)

### OpenClaw Setup

- [ ] Install OpenClaw via secure method
- [ ] Configure localhost-only binding
- [ ] Set up credential management (Doppler/env vars)
- [ ] Enable sandbox mode
- [ ] Configure allowed domains list
- [ ] Enable confirmation prompts
- [ ] Restrict file system access
- [ ] Review and vet all skills before installation

### Ongoing Maintenance

**Daily:**
- [ ] Review security reports
- [ ] Check fail2ban status
- [ ] Monitor failed login attempts

**Weekly:**
- [ ] Run AIDE integrity check
- [ ] Review system logs
- [ ] Check for security updates
- [ ] Verify firewall rules

**Monthly:**
- [ ] Run full security audit (Lynis)
- [ ] Review and update firewall rules
- [ ] Rotate API keys
- [ ] Update skill allowlist
- [ ] Review user access levels

**Quarterly:**
- [ ] Penetration testing (optional)
- [ ] Review and update security policies
- [ ] Update incident response plan
- [ ] Security team training/review

---

## Incident Response

### Security Breach Procedure

**If you suspect a breach:**

1. **Isolate**
   ```bash
   # Disconnect from network
   sudo ufw deny out

   # Stop OpenClaw
   systemctl --user stop openclaw
   ```

2. **Preserve Evidence**
   ```bash
   # Copy logs
   sudo cp -r /var/log /backup/incident-$(date +%s)/
   cp -r ~/.openclaw /backup/incident-$(date +%s)/
   ```

3. **Investigate**
   ```bash
   # Check active connections
   sudo ss -tulpn

   # Check running processes
   ps aux | grep openclaw

   # Review recent file changes
   sudo find / -mtime -1 -type f
   ```

4. **Remediate**
   - Rotate all API keys immediately
   - Reset passwords
   - Rebuild from clean backup if necessary
   - Update security configurations

5. **Report**
   - Document timeline of events
   - Identify root cause
   - Implement preventive measures
   - Update security procedures

---

## Resources

### Official Documentation
- OpenClaw Security: https://docs.openclaw.ai/gateway/security
- Composio Hardening Guide: https://composio.dev/blog/secure-openclaw-moltbot-clawdbot-setup
- Ubuntu Security: https://ubuntu.com/security

### Security Tools
- fail2ban: https://www.fail2ban.org/
- UFW: https://help.ubuntu.com/community/UFW
- AIDE: https://aide.github.io/
- Lynis: https://cisofy.com/lynis/
- rkhunter: http://rkhunter.sourceforge.net/

### Vulnerability Tracking
- CVE Database: https://cve.mitre.org/
- Node.js Security: https://nodejs.org/en/security/
- OpenClaw GitHub Security: https://github.com/openclaw/openclaw/security

### References

**Security Research:**
- [OpenClaw Security Nightmare - Cisco](https://blogs.cisco.com/ai/personal-ai-agents-like-openclaw-are-a-security-nightmare)
- [Malicious Skills on ClawHub - Tom's Hardware](https://www.tomshardware.com/tech-industry/cyber-security/malicious-moltbot-skill-targets-crypto-users-on-clawhub)
- [OpenClaw Security Risks - VentureBeat](https://venturebeat.com/security/openclaw-agentic-ai-security-risk-ciso-guide)
- [Linux Security Hardening - nixCraft](https://www.cyberciti.biz/tips/linux-security.html)
- [VM Hardening Best Practices](https://docs.anyone.io/security/vps-hardening-and-best-practices)

---

**Last Updated:** 2026-02-01
**Security Level:** Essential Hardening
**Threat Model:** Development VM with AI agent capabilities
