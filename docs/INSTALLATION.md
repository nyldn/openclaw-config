# OpenClaw VM Installation Guide

Complete guide for installing OpenClaw VM configuration system on Debian/Ubuntu systems.

---

## 🚀 Quick Install (Recommended)

### Secure Installation

**For security reasons, we recommend cloning the repository first:**

```bash
# One-line install (clone + run)
git clone https://github.com/nyldn/openclaw-config.git && cd openclaw-config/bootstrap && ./bootstrap.sh
```

**Alternative One-Line (Download + Run):**

```bash
curl -fsSL https://raw.githubusercontent.com/nyldn/openclaw-config/main/bootstrap/install.sh -o /tmp/openclaw-install.sh && bash /tmp/openclaw-install.sh
```

**What this does:**
1. Verifies prerequisites (git, curl, bash)
2. Shows an interactive menu to select modules
3. Installs only the components you choose
4. Uses the repo in-place (no copy/move)
5. Takes ~5-15 minutes depending on selections

**Time:** ~5-15 minutes (depending on selections and internet speed)

---

## 📋 Installation Options

### Option 1: Interactive Installation (Default)

The bootstrap system now uses an interactive menu by default:

```bash
cd openclaw-config/bootstrap
./bootstrap.sh
```

You'll be presented with:
- **Preset Selection**: Minimal, Developer, Full, or Custom
- **Module Selection**: Choose exactly which components to install
- **Dependency Resolution**: Required dependencies are auto-selected
- **Installation Summary**: Review before proceeding

### Option 2: Non-Interactive Installation

For automated installations (CI/CD, scripts):

```bash
cd openclaw-config/bootstrap

# Install all modules without prompts
./bootstrap.sh --non-interactive

# Install specific modules only
./bootstrap.sh --non-interactive --only python,nodejs,claude-cli

# Skip optional modules
./bootstrap.sh --non-interactive --skip gemini-cli

# Dry run (preview only)
./bootstrap.sh --dry-run

# Verbose output
./bootstrap.sh --verbose

# Skip the post-install setup wizard
./bootstrap.sh --skip-setup
```

---

### Option 3: Manual Module Installation

Install individual modules without full bootstrap:

```bash
# Clone repository
git clone https://github.com/nyldn/openclaw-config.git
cd openclaw-config/bootstrap

# Install specific module
bash modules/04-claude-cli.sh install

# Validate installation
bash modules/04-claude-cli.sh validate

# Available modules:
# 01-system-deps.sh      - System dependencies
# 02-python.sh           - Python environment
# 03-nodejs.sh           - Node.js runtime
# 04-claude-cli.sh       - Claude Code CLI
# 05-codex-cli.sh        - OpenAI CLI
# 06-gemini-cli.sh       - Gemini CLI (npx @google/gemini-cli)
# 07-openclaw-env.sh     - OpenClaw workspace
# 08-memory-init.sh      - Memory system
# 09-claude-octopus.sh   - Multi-AI orchestration
# 10-deployment-tools.sh - Vercel, Netlify, Supabase
# 11-auto-updates.sh     - Automatic updates
# 12-dev-tools.sh        - pnpm, Biome, Doppler
# 13-openclaw.sh         - OpenClaw.ai installation
# 14-security.sh         - VM security hardening
# 15-productivity-tools.sh - Calendar, Email, Tasks, Slack
```

---

## 🔍 Prerequisites

### Required

- **OS**: Debian 10+ or Ubuntu 20.04+
- **User**: Non-root user with sudo privileges
- **Disk**: 2GB+ free space
- **Network**: Internet connection for downloads
- **Memory**: 1GB+ RAM recommended

### Pre-installed Commands

The installer checks for these and will fail if missing:
- `git`
- `curl`
- `bash`
- `sudo`

Install missing prerequisites:
```bash
sudo apt-get update
sudo apt-get install -y git curl bash sudo
```

---

## 📦 What Gets Installed

### System Packages
- Base utilities: curl, git, build-essential, jq
- Development headers and libraries
- Security tools: fail2ban, ufw, aide, rkhunter

### Python Environment
- Python 3.9+ with pip
- Virtual environment at `~/.local/venv/openclaw`
- SDKs: anthropic, openai, google-generativeai

### Node.js Environment
- Node.js 20+ LTS
- npm and global packages directory
- CLI tools: Vercel, Netlify, Supabase

### Development Tools
- pnpm (package manager)
- Biome (linter/formatter)
- Doppler CLI (secrets management)
- Bruno CLI (API testing)
- Turborepo (monorepo management)

### AI Tools
- Claude Code CLI
- OpenAI CLI (Codex)
- Gemini CLI (via `npx @google/gemini-cli`)
- OpenClaw.ai
- Claude Octopus (multi-AI orchestration)

Gemini CLI reference: https://github.com/google-gemini/gemini-cli
Claude Octopus requires the Claude CLI; if it isn't installed yet, the module will skip and you can rerun later with:
`./bootstrap.sh --only claude-cli,claude-octopus`

### Security Features
- SSH hardening (key-only auth, no root)
- UFW firewall (default deny)
- fail2ban intrusion prevention
- AIDE file integrity monitoring
- Automatic security updates
- Daily security reports

Automatic security updates are enabled non-interactively (no prompts).
In Docker/container test runs, UFW and fail2ban may be unavailable; validation will warn instead of failing.

### MCP Servers (10 total)
- Google Drive
- Dropbox
- GitHub
- Filesystem
- PostgreSQL (Supabase)
- Brave Search
- Figma
- Stripe
- Sentry
- Sequential Thinking

### Shell Aliases (42 total)
- Deployment shortcuts
- File sharing utilities
- Cloud sync commands
- MCP management tools

---

## ⚙️ Installation Process

### What Happens During Install

1. **Prerequisites Check**
   - Verifies git, curl, bash are available
   - Ensures running as non-root user
   - Checks for sudo access

2. **Repository Clone**
   - Downloads from GitHub to `/tmp/openclaw-bootstrap-$$`
   - Uses shallow clone for speed

3. **Bootstrap Installation**
   - Copies files to `~/openclaw-config`
   - Makes scripts executable
   - Sets up directory structure

4. **Module Installation** (in order)
   - 01: System dependencies
   - 02: Python environment
   - 03: Node.js runtime
   - 04: Claude CLI
   - 05: Codex CLI
   - 06: Gemini CLI
   - 07: OpenClaw workspace
   - 08: Memory system
   - 09: Claude Octopus
   - 10: Deployment tools
   - 11: Auto-updates
   - 12: Dev tools
   - 13: OpenClaw.ai
   - 14: Security hardening

5. **Cleanup**
   - Displays installation summary

> Note: If you use `bootstrap/install.sh`, it clones to a temp directory and copies into `~/openclaw-config`.

The summary includes:
- Selected modules and preset
- Failed modules with per-module log paths
- A ready-to-run retry command for failed modules

### Installation Locations

```
~/openclaw-config/          # Bootstrap system
~/openclaw-workspace/       # Work directory
~/.local/venv/openclaw/     # Python environment
~/.local/npm-global/        # Node.js packages
~/.config/claude/           # Claude Code config
~/.openclaw/                # OpenClaw config
~/.openclaw-security/       # Security reports
/var/log/openclaw/          # System logs
```

---

## ✅ Post-Installation

The installer runs the post-install setup and auth wizards automatically (interactive installs).
If you skipped it (or want to re-run), use:

```bash
bash ~/openclaw-config/bootstrap/scripts/openclaw-setup.sh
bash ~/openclaw-config/bootstrap/scripts/openclaw-auth.sh --all
```

### 1. Verify Installation

```bash
# Run validation
cd ~/openclaw-config/bootstrap
./bootstrap.sh --validate

# Check installed versions
claude --version
node --version
python3 --version
vercel --version
netlify --version
pnpm --version
```

### 2. Configure API Keys

```bash
# Edit environment file
nano ~/openclaw-workspace/.env
```

Add your API keys:
```env
ANTHROPIC_API_KEY=sk-ant-xxx
OPENAI_API_KEY=sk-proj-xxx
GOOGLE_API_KEY=xxx
GITHUB_PAT=ghp_xxx
SUPABASE_DB_URL=postgresql://xxx
STRIPE_SECRET_KEY=sk_test_xxx
FIGMA_PAT=xxx
```

### 3. Authenticate Services

```bash
# Claude Code
claude login

# Deployment tools
vercel login
netlify login
supabase login

# Secrets management (optional)
doppler login
```

### Claude Code CLI Notes

- macOS: `brew install --cask claude-code`
- Linux: `curl -fsSL https://claude.ai/install.sh -o /tmp/claude-install.sh && bash /tmp/claude-install.sh`
- Node.js 18+ only required for deprecated npm install flows
- `ripgrep` is usually included; if `claude` search fails, see Claude search troubleshooting

### 4. Reload Shell

```bash
# Apply new aliases and PATH
source ~/.zshrc
# or
source ~/.bashrc
```

### 5. Test Installation

```bash
# Test MCP servers
mcp-list

# Test deployment tools
vercel --help
netlify --help

# Test auto-updates
systemctl --user status openclaw-auto-update.timer

# Run security check
~/.openclaw-security/security-check.sh
```

---

## 🔧 Customization

### Skip Modules

```bash
# Download installer
curl -fsSL https://raw.githubusercontent.com/nyldn/openclaw-config/main/bootstrap/install.sh -o /tmp/openclaw-install.sh

# Don't install Gemini or Codex
bash /tmp/openclaw-install.sh --skip gemini-cli,codex-cli
```

### Install Only Specific Modules

```bash
# Download installer
curl -fsSL https://raw.githubusercontent.com/nyldn/openclaw-config/main/bootstrap/install.sh -o /tmp/openclaw-install.sh

# Minimal installation
bash /tmp/openclaw-install.sh --only system-deps,python,nodejs,claude-cli
```

### Environment Variables

Set before installation:

```bash
# Custom installation directory (install.sh only)
export INSTALL_DIR="$HOME/my-custom-dir"

# Then run install
curl -fsSL https://raw.githubusercontent.com/nyldn/openclaw-config/main/bootstrap/install.sh -o /tmp/openclaw-install.sh
bash /tmp/openclaw-install.sh
```

---

## 🐛 Troubleshooting

### Installation Fails

**Check logs:**
```bash
tail -f ~/openclaw-config/bootstrap/logs/bootstrap-*.log
```

Per-module logs:
```bash
ls -1 ~/openclaw-config/bootstrap/logs/modules
tail -f ~/openclaw-config/bootstrap/logs/modules/<run_id>/<module>.log
```

**Common issues:**

1. **Missing sudo access**
   ```bash
   # Add user to sudo group
   su -
   usermod -aG sudo $USER
   exit
   # Log out and back in
   ```

2. **Doppler CLI install fails with dpkg permission error**
   ```bash
   # Run with sudo (Linux)
   curl -Ls https://cli.doppler.com/install.sh -o /tmp/doppler.sh
   sudo sh /tmp/doppler.sh
   ```

3. **Insufficient disk space**
   ```bash
   df -h
   # Free up space or install to different location
   ```

4. **Network connectivity**
   ```bash
   # Test GitHub access
   curl -I https://github.com

   # Check DNS
   ping -c 3 github.com
   ```

5. **Permission denied**
   ```bash
   # Ensure scripts are executable
   chmod +x ~/openclaw-config/bootstrap/bootstrap.sh
   chmod +x ~/openclaw-config/bootstrap/modules/*.sh
   ```

### Module-Specific Failures

```bash
# Reinstall specific module
cd ~/openclaw-config/bootstrap
bash modules/04-claude-cli.sh install

# Validate module
bash modules/04-claude-cli.sh validate

# Rollback module
bash modules/04-claude-cli.sh rollback
```

### Start Fresh

```bash
# Remove all installations
rm -rf ~/openclaw-config
rm -rf ~/openclaw-workspace
rm -rf ~/.local/venv/openclaw
rm -rf ~/.openclaw

# Reinstall
curl -fsSL https://raw.githubusercontent.com/nyldn/openclaw-config/main/bootstrap/install.sh -o /tmp/openclaw-install.sh
bash /tmp/openclaw-install.sh
```

---

## 🔒 Security Considerations

### Installation Source Verification

**Verify the install.sh script before running:**

```bash
# Download and inspect
curl -fsSL https://raw.githubusercontent.com/nyldn/openclaw-config/main/bootstrap/install.sh > /tmp/install.sh
less /tmp/install.sh

# Run after review
bash /tmp/install.sh
```

### Checksum Verification

```bash
# Download checksum (when available)
curl -fsSL https://raw.githubusercontent.com/nyldn/openclaw-config/main/bootstrap/install.sh.sha256 > /tmp/install.sh.sha256

# Download script
curl -fsSL https://raw.githubusercontent.com/nyldn/openclaw-config/main/bootstrap/install.sh > /tmp/install.sh

# Verify
cd /tmp && sha256sum -c install.sh.sha256
```

### HTTPS-Only Downloads

The installer uses HTTPS for all downloads:
- GitHub repository: `https://github.com/nyldn/openclaw-config`
- Raw files: `https://raw.githubusercontent.com/...`
- Package managers: npm, pip (HTTPS by default)

---

## 📊 Installation Metrics

**Expected Duration:**
- Minimal install (~5 modules): 2-3 minutes
- Standard install (~10 modules): 5-10 minutes
- Full install (all modules): 10-15 minutes

**Bandwidth Usage:**
- Minimal: ~200MB
- Standard: ~500MB
- Full: ~1GB

**Disk Space:**
- After installation: ~2GB
- With caches: ~2.5GB

---

## 🔄 Updates

### Automatic Updates

Auto-updates run daily at 3:00 AM for:
- System packages
- Python packages
- Node.js packages
- CLI tools
- Repository sync

### Manual Updates

```bash
# Update bootstrap system
cd ~/openclaw-config
git pull origin main
./bootstrap.sh --update

# Update specific module
bash modules/10-deployment-tools.sh install
```

---

## 📚 Additional Resources

- **Main README**: [../README.md](../README.md)
- **Security Guide**: [guides/SECURITY_GUIDE.md](guides/SECURITY_GUIDE.md)
- **Development Tools**: [guides/DEV_TOOLS_GUIDE.md](guides/DEV_TOOLS_GUIDE.md)
- **Auto-Updates**: [../bootstrap/AUTO_UPDATE_GUIDE.md](../bootstrap/AUTO_UPDATE_GUIDE.md)
- **Bootstrap System**: [../bootstrap/README.md](../bootstrap/README.md)

---

## 🆘 Support

**Issues:** https://github.com/nyldn/openclaw-config/issues

**Common Commands:**
```bash
# Help
./bootstrap.sh --help

# List modules
./bootstrap.sh --list-modules

# Run diagnostics
./bootstrap.sh --doctor

# Validate installation
./bootstrap.sh --validate
```

---

**Installation Command:**
```bash
curl -fsSL https://raw.githubusercontent.com/nyldn/openclaw-config/main/bootstrap/install.sh -o /tmp/openclaw-install.sh
bash /tmp/openclaw-install.sh
```

**Last Updated:** 2026-02-03
