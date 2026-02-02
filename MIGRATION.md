# Migration Guide: v1.x → v2.0

Guide for upgrading existing OpenClaw installations from v1.x to v2.0.

---

## 🔄 Overview

OpenClaw v2.0 introduces significant improvements in security, user experience, and functionality. This guide will help you upgrade safely while preserving your existing configuration.

**Estimated Migration Time:** 15-30 minutes

---

## 📋 What's Changed

### Breaking Changes

1. **Interactive Installation is Now Default**
   - Old: All modules installed automatically
   - New: Interactive menu for module selection
   - **Impact:** Automation scripts must use `--non-interactive` flag

2. **OpenClaw No Longer Required**
   - Old: OpenClaw installed automatically
   - New: OpenClaw is optional
   - **Impact:** Must explicitly select if needed

3. **No More `curl | bash` Installation**
   - Old: One-line installer with `curl | bash`
   - New: Must clone repository first
   - **Impact:** Update any documentation/scripts using old method

4. **Module Numbering Changed**
   - Old: 11 modules (01-11)
   - New: 16 modules (01-15 + optional 16)
   - **Impact:** Custom scripts referencing module numbers need updates

### New Features

1. **Interactive Installation** - TUI with presets
2. **Productivity Tools** - Calendar, Email, Tasks, Slack MCP servers
3. **Security Enhancements** - 20+ vulnerability fixes
4. **Dependency Resolution** - Automatic with topological sort
5. **Credential Encryption** - AES-256-CBC for sensitive files

---

## 🚀 Migration Steps

### Step 1: Backup Current Installation

```bash
# Backup OpenClaw configuration
mkdir -p ~/openclaw-backup
cp -r ~/.openclaw ~/openclaw-backup/
cp -r ~/openclaw-workspace ~/openclaw-backup/

# Backup environment variables (if customized)
env | grep -E "(ANTHROPIC|OPENAI|GEMINI|TODOIST|SLACK)" > ~/openclaw-backup/env-vars.txt

# Backup custom scripts (if any)
cp -r ~/openclaw-config ~/openclaw-backup/ 2>/dev/null || true
```

### Step 2: Note Current Modules

Check which modules you currently have installed:

```bash
cd ~/openclaw-config/bootstrap
cat ~/.openclaw/bootstrap-state.yaml | grep "installed: true"
```

Save this list for reference.

### Step 3: Update Repository

```bash
cd ~/openclaw-config
git fetch origin
git checkout main
git pull origin main
```

### Step 4: Review Changes

```bash
# See what's changed
git log --oneline --since="2026-01-01"

# Review security improvements
cat SECURITY.md

# Review new features
cat deployment-tools/docs/PRODUCTIVITY_INTEGRATIONS.md
```

### Step 5: Run Migration-Friendly Update

**Option A: Keep All Existing Modules**

```bash
cd ~/openclaw-config/bootstrap

# Update all currently installed modules (non-interactive)
./bootstrap.sh --non-interactive --update
```

**Option B: Interactive Update (Choose New Modules)**

```bash
cd ~/openclaw-config/bootstrap

# Run interactive installer
./bootstrap.sh --interactive

# Select modules in the menu:
# - All your existing modules
# - Plus any new ones you want (productivity-tools, etc.)
```

**Option C: Specific Modules Only**

```bash
cd ~/openclaw-config/bootstrap

# Update only specific modules
./bootstrap.sh --non-interactive --only system-deps,python,nodejs,claude-cli
```

### Step 6: Verify Installation

```bash
# Validate all modules
./bootstrap.sh --validate

# Check state file
cat ~/.openclaw/bootstrap-state.yaml
```

### Step 7: Migrate to New Security Features

#### Enable Credential Encryption (Optional but Recommended)

```bash
# Source encryption library
source ~/openclaw-config/bootstrap/lib/crypto.sh

# Initialize encryption system
crypto_init

# Encrypt sensitive files
encrypt_workspace ~/.openclaw/workspace

# Backup encryption key securely!
crypto_backup_key ~/secure-location/openclaw-key.backup
```

#### Install Pre-commit Hook

```bash
cd ~/openclaw-config

# The hook should already be there, make it executable
chmod +x .git/hooks/pre-commit

# Test it
echo "ANTHROPIC_API_KEY=sk-ant-test123" > test-secret.txt
git add test-secret.txt
git commit -m "test"  # Should be blocked!
rm test-secret.txt
```

### Step 8: Set Up New Productivity Tools (Optional)

If you want the new productivity integrations:

```bash
# Install productivity module
cd ~/openclaw-config/bootstrap/modules
./15-productivity-tools.sh install

# Follow setup instructions
productivity-setup

# Configure credentials (see PRODUCTIVITY_INTEGRATIONS.md)
```

---

## 🔧 Fixing Common Migration Issues

### Issue 1: "Module not found" Errors

**Symptom:** Errors about missing modules during update

**Solution:**
```bash
# Rediscover modules
cd ~/openclaw-config/bootstrap
./bootstrap.sh --list-modules

# Reinstall specific module
./modules/XX-module-name.sh install
```

### Issue 2: Interactive Mode on CI/CD Server

**Symptom:** Bootstrap hangs waiting for input on automated systems

**Solution:**
```bash
# Always use --non-interactive flag in scripts
./bootstrap.sh --non-interactive --update

# Or set in environment
export NON_INTERACTIVE=true
./bootstrap.sh
```

### Issue 3: OpenClaw Not Installed

**Symptom:** OpenClaw missing after upgrade

**Solution:**
```bash
# OpenClaw is now optional, install explicitly
cd ~/openclaw-config/bootstrap

# Interactive: Select "openclaw" in the menu
./bootstrap.sh --interactive

# Or non-interactive:
./bootstrap.sh --only openclaw
```

### Issue 4: Credentials Not Working

**Symptom:** MCP servers can't access credentials

**Solution:**
```bash
# Check environment variables are set
source ~/.bashrc
env | grep -E "(ANTHROPIC|OPENAI|GEMINI)"

# For new productivity tools, source new credentials
source ~/.openclaw/productivity/credentials.env

# Or decrypt if encrypted
source ~/openclaw-config/bootstrap/lib/crypto.sh
decrypt_workspace ~/.openclaw/workspace
```

### Issue 5: Permission Denied Errors

**Symptom:** Bootstrap fails with permission errors

**Solution:**
```bash
# Fix permissions on OpenClaw directories
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/*.yaml
chmod 700 ~/.openclaw/workspace

# Re-run bootstrap
cd ~/openclaw-config/bootstrap
./bootstrap.sh --validate
```

---

## 📦 Module Mapping (v1.x → v2.0)

| v1.x Module | v2.0 Module | Changes |
|-------------|-------------|---------|
| 01-system-deps | 01-system-deps | ✅ No changes |
| 02-python | 02-python | ✅ No changes |
| 03-nodejs | 03-nodejs | ⚠️ Fixed curl\|bash vulnerability |
| 04-claude-cli | 04-claude-cli | ⚠️ Fixed curl\|bash vulnerability |
| 05-codex-cli | 05-codex-cli | ✅ No changes |
| 06-gemini-cli | 06-gemini-cli | ✅ No changes |
| 07-openclaw-env | 07-openclaw-env | 🔄 Now optional |
| 08-memory-init | 08-memory-init | ✅ No changes |
| 09-claude-octopus | 09-claude-octopus | ✅ No changes |
| 10-deployment-tools | 10-deployment-tools | ✅ No changes |
| 11-auto-updates | 11-auto-updates | ✅ No changes |
| *(none)* | 12-rclone | ✨ **NEW** Cloud storage sync |
| *(none)* | 13-dev-tools | ✨ **NEW** Development utilities |
| *(none)* | 14-security | ✨ **NEW** Security hardening |
| *(none)* | 15-productivity-tools | ✨ **NEW** Calendar, Email, Tasks, Slack |

---

## 🔐 Security Migration

### Before v2.0 (Insecure)

```bash
# Old installation (INSECURE - don't use!)
curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash

# Credentials in plaintext
echo "ANTHROPIC_API_KEY=sk-ant-..." >> ~/.bashrc

# No log sanitization (secrets exposed)
cat ~/openclaw-config/bootstrap/logs/bootstrap.log
```

### After v2.0 (Secure)

```bash
# New installation (SECURE)
git clone https://github.com/nyldn/openclaw-config.git
cd openclaw-config/bootstrap
./bootstrap.sh

# Encrypted credentials
source ~/openclaw-config/bootstrap/lib/crypto.sh
encrypt_config ~/.openclaw/credentials.env

# Sanitized logs (secrets redacted)
cat ~/openclaw-config/bootstrap/logs/bootstrap.log
# Output: ANTHROPIC_API_KEY=***REDACTED_ANTHROPIC_KEY***
```

### Applying Security Fixes to Existing Installation

```bash
cd ~/openclaw-config

# Update to v2.0
git pull origin main

# Re-run security-sensitive modules
cd bootstrap
./modules/03-nodejs.sh install      # Fixes curl|bash
./modules/04-claude-cli.sh install  # Fixes curl|bash
./modules/14-security.sh install    # SSH hardening, firewall

# Enable secret sanitization (automatic in v2.0)
# Logs are now automatically sanitized

# Enable credential encryption
source lib/crypto.sh
crypto_init
encrypt_workspace ~/.openclaw/workspace
```

---

## 📝 Configuration File Changes

### bootstrap-state.yaml

No changes to format. New fields added:

```yaml
version: "2.0.0"  # Updated
modules:
  # ... existing modules ...
  productivity-tools:  # NEW
    version: "1.0.0"
    installed: true
    installed_at: "2026-02-01T12:00:00Z"
```

### manifest.yaml

Enhanced with new fields:

```yaml
modules:
  system-deps:
    version: "1.0.0"
    required: true
    category: "foundation"      # NEW
    size: "~50MB"              # NEW
    description: "..."
    description_long: "..."    # NEW
```

### MCP Configuration Files

New productivity servers added:

```json
{
  "mcpServers": {
    // ... existing servers ...
    "google-calendar": { /* NEW */ },
    "email": { /* NEW */ },
    "todoist": { /* NEW */ },
    "slack": { /* NEW */ }
  }
}
```

---

## ✅ Post-Migration Checklist

- [ ] All modules from v1.x still installed
- [ ] New modules installed (if desired)
- [ ] Credentials still working
- [ ] MCP servers responding
- [ ] Claude CLI functional
- [ ] Pre-commit hook installed and tested
- [ ] Sensitive files encrypted (optional)
- [ ] Backup created and verified
- [ ] Documentation reviewed
- [ ] CI/CD scripts updated with `--non-interactive`

---

## 🆘 Rollback Procedure

If migration fails and you need to rollback:

```bash
# Stop any running services
sudo systemctl stop openclaw-update.timer 2>/dev/null || true

# Restore from backup
rm -rf ~/.openclaw
rm -rf ~/openclaw-workspace
cp -r ~/openclaw-backup/.openclaw ~/
cp -r ~/openclaw-backup/openclaw-workspace ~/

# Restore repository to v1.x
cd ~/openclaw-config
git fetch --tags
git checkout v1.2.0  # Last v1.x version

# Verify restoration
cd bootstrap
./bootstrap.sh --validate
```

---

## 📚 Additional Resources

- [INSTALLATION.md](INSTALLATION.md) - Complete installation guide
- [SECURITY.md](SECURITY.md) - Security policy and best practices
- [PRODUCTIVITY_INTEGRATIONS.md](deployment-tools/docs/PRODUCTIVITY_INTEGRATIONS.md) - Productivity setup guide
- [GitHub Issues](https://github.com/nyldn/openclaw-config/issues) - Report problems

---

## 🤝 Getting Help

**Having trouble with migration?**

1. Check this guide's troubleshooting section
2. Review relevant documentation
3. Search [existing issues](https://github.com/nyldn/openclaw-config/issues)
4. Open a new issue with:
   - Your v1.x version
   - Migration steps attempted
   - Error messages
   - Output of `./bootstrap.sh --doctor`

---

**Migration completed successfully? Welcome to v2.0! 🎉**
