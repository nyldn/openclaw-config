# OpenClaw VM Configuration v2.0

Automated configuration and deployment system for OpenClaw VMs with comprehensive tooling for AI development, cloud deployment, file sharing, and personal productivity.

**What's New in v2.0:**
- 🎯 Interactive installation with preset selection
- 🔒 Comprehensive security hardening (20+ vulnerabilities fixed)
- 📅 Personal productivity integrations (Calendar, Email, Tasks, Slack)
- 🔐 Credential encryption at rest
- 🛡️ Pre-commit secret detection
- ⚡ Smart dependency resolution

## 🚀 Quick Start

### Installation

**Recommended Method (Secure):**

```bash
# Clone the repository
git clone https://github.com/nyldn/openclaw-config.git
cd openclaw-config/bootstrap

# Run the interactive installer
./bootstrap.sh
```

The installer will:
- ✅ Verify prerequisites (git, curl, bash)
- ✅ Show an interactive module selection menu
- ✅ Install only the components you choose
- ✅ Complete in ~5-15 minutes depending on selections

**Non-Interactive Mode:**

For automated installations (CI/CD, scripts):

```bash
# Install all modules without prompts
./bootstrap.sh --non-interactive

# Install specific modules only
./bootstrap.sh --only system-deps,nodejs,python
```

See [docs/INSTALLATION.md](docs/INSTALLATION.md) for detailed installation options and customization.

**Security Note:** We no longer support `curl | bash` installation methods as they pose security risks. Always clone the repository first to review the code before execution.

## 📦 What's Included

### Core AI Tools
- **Claude Code CLI** - Anthropic's Claude assistant
- **OpenAI CLI** - GPT-4 and GPT-3.5 access
- **Gemini CLI** - Run via `npx @google/gemini-cli` (see https://github.com/google-gemini/gemini-cli)
- **Claude Octopus** - Multi-AI orchestration system

### Deployment Platforms
- **Vercel CLI** - Serverless and edge deployments
- **Netlify CLI** - Static sites and functions
- **Supabase CLI** - Backend-as-a-Service

### File Sharing & Storage
- **Google Drive MCP** - Drive integration via MCP
- **Dropbox MCP** - Dropbox API access
- **rclone** - 50+ cloud storage backends
- **GitHub MCP** - Repository operations

### Development Environment
- **Python 3.9+** with virtual environment
- **Node.js 20+** with npm
- **System utilities** - git, curl, jq, etc.
- **Memory system** - SQLite-based persistence
- **Auto-updates** - Daily automated updates for all components

### MCP Servers (10+ Total)
**Core Servers:**
- Google Drive - File operations and sharing
- Dropbox - Cloud storage access
- GitHub - Repository management
- Filesystem - Local file operations
- PostgreSQL - Database access (Supabase)
- Brave Search - Web search capabilities

**Productivity Servers (NEW in v2.0):**
- Google Calendar - Event management and scheduling
- Email - IMAP/SMTP for reading and sending emails
- Todoist - Task and project management
- Slack - Team messaging and collaboration

### Security Features (NEW in v2.0)
- **Download Verification** - SHA256 checksums for all external downloads
- **Secret Sanitization** - Automatic redaction of API keys, tokens, passwords in logs
- **Credential Encryption** - AES-256-CBC encryption for sensitive config files
- **Pre-commit Hook** - Prevents accidental commits of secrets
- **Input Validation** - Strict validation of module names, URLs, file paths
- **Secure Temp Files** - Uses `mktemp` instead of predictable paths
- **Restrictive Permissions** - 0600/0700 for sensitive directories and files

### Shell Aliases (42+ Total)
- Deployment shortcuts (deploy-vercel, deploy-netlify, etc.)
- File sharing (share-dropbox, share-gdrive)
- Cloud sync (sync-dropbox, sync-gdrive, sync-s3)
- MCP management (mcp-list, mcp-reload, mcp-logs)
- Productivity helpers (productivity-setup, calendar-auth)

## 📁 Repository Structure

```
openclaw-config/
├── README.md                    # This file
├── docs/INSTALLATION.md        # Detailed installation guide
├── docs/guides/MIGRATION.md    # Migration guide for v1.x → v2.0
├── docs/guides/SECURITY.md     # Security policy and practices
├── bootstrap/                   # Bootstrap system
│   ├── bootstrap.sh            # Main installer (with interactive mode)
│   ├── install.sh              # Secure installation script
│   ├── manifest.yaml           # Module metadata (v2.0)
│   ├── checksums.yaml          # Download verification checksums
│   ├── modules/                # Installation modules (16 total)
│   │   ├── 01-system-deps.sh
│   │   ├── 02-python.sh
│   │   ├── 03-nodejs.sh
│   │   ├── 04-claude-cli.sh
│   │   ├── ...
│   │   ├── 14-security.sh
│   │   └── 15-productivity-tools.sh  # NEW in v2.0
│   └── lib/                    # Shared utilities
│       ├── logger.sh           # With secret sanitization
│       ├── validation.sh       # Enhanced input validation
│       ├── network.sh
│       ├── interactive.sh      # NEW: Interactive menus
│       ├── dependency-resolver.sh  # NEW: Dependency resolution
│       ├── secure-download.sh  # NEW: Download verification
│       └── crypto.sh           # NEW: Credential encryption
├── deployment-tools/           # Deployment configuration
│   ├── mcp/
│   │   ├── mcp-servers-extended.json
│   │   ├── mcp-servers-full-stack.json
│   │   └── implementations/    # NEW: Custom MCP servers
│   │       ├── google-calendar-mcp.js
│   │       ├── email-mcp.js
│   │       ├── todoist-mcp.js
│   │       └── slack-mcp.js
│   ├── config/
│   │   └── productivity-credentials.template.env
│   └── docs/
│       └── PRODUCTIVITY_INTEGRATIONS.md  # NEW: 40-page guide
│       ├── QUICK-START.md
│       ├── openclaw-setup-plan.md
│       └── EMBRACE-WORKFLOW-RESULTS.md
└── reports/                    # Project documentation
    └── FEASIBILITY_REPORT.md
```

## 🎯 Features

### Modular Architecture
- Individual modules for each component
- Incremental updates (only install what's changed)
- Dependency management between modules
- Rollback support for failed installations

### Automated Maintenance
- **Daily auto-updates** for all components
- System packages, Python packages, Node.js packages
- CLI tools (Vercel, Netlify, Supabase)
- MCP servers and repository updates
- Automatic cleanup of unused packages
- Daily update reports and logs

### Comprehensive Validation
- Post-installation health checks
- Module-specific validation
- System diagnostics (--doctor flag)
- Automated testing

### Enterprise-Ready
- State tracking and version management
- Remote manifest for updates
- Non-interactive installation mode
- Logging and error reporting

### Security First
- No credentials in repository
- Docker secrets support
- Token-based authentication
- Minimal privilege requirements

## 🔧 Usage

### Installation Options

```bash
# Full installation (all modules)
./bootstrap.sh

# Verbose output
./bootstrap.sh --verbose

# Install specific modules
./bootstrap.sh --only deployment-tools

# Skip optional modules
./bootstrap.sh --skip gemini-cli

# Preview changes (dry run)
./bootstrap.sh --dry-run

# Non-interactive mode
./bootstrap.sh --non-interactive
```

### Post-Installation

1. **Configure API Keys**
   ```bash
   nano ~/openclaw-workspace/.env
   ```

   Add your keys:
   ```env
   ANTHROPIC_API_KEY=sk-ant-xxx
   OPENAI_API_KEY=sk-proj-xxx
   GOOGLE_API_KEY=xxx
   GITHUB_PAT=ghp_xxx
   SUPABASE_DB_URL=postgresql://xxx
   ```

2. **Authenticate Services**
   ```bash
   claude login
   vercel login
   netlify login
   supabase login
   ```

3. **Reload Shell**
   ```bash
   source ~/.zshrc
   ```

4. **Test Installation**
   ```bash
   ./bootstrap.sh --validate
   ```

5. **Auto-Updates** (Configured Automatically)

   Daily updates are configured to run at 3:00 AM:
   ```bash
   # Check update timer status
   systemctl --user status openclaw-auto-update.timer

   # View last update
   journalctl --user -u openclaw-auto-update.service

   # View today's update report
   cat /var/log/openclaw/update-report-$(date +%Y%m%d).txt

   # Run update manually now
   systemctl --user start openclaw-auto-update.service
   ```

   See [AUTO_UPDATE_GUIDE.md](bootstrap/AUTO_UPDATE_GUIDE.md) for full documentation.

## 📚 Documentation

- **Bootstrap System**: [bootstrap/README.md](bootstrap/README.md)
- **Auto-Update Guide**: [bootstrap/AUTO_UPDATE_GUIDE.md](bootstrap/AUTO_UPDATE_GUIDE.md)
- **Quick Start Guide**: [deployment-tools/docs/QUICK-START.md](deployment-tools/docs/QUICK-START.md)
- **Setup Plan**: [deployment-tools/docs/openclaw-setup-plan.md](deployment-tools/docs/openclaw-setup-plan.md)
- **Workflow Results**: [deployment-tools/docs/EMBRACE-WORKFLOW-RESULTS.md](deployment-tools/docs/EMBRACE-WORKFLOW-RESULTS.md)

## 🚢 Deployment

### Single VM
```bash
ssh user@vm-host 'curl -fsSL https://raw.githubusercontent.com/nyldn/openclaw-config/main/bootstrap/install.sh | bash'
```

### Multiple VMs
```bash
for host in vm1 vm2 vm3; do
    ssh user@$host 'curl -fsSL https://raw.githubusercontent.com/nyldn/openclaw-config/main/bootstrap/install.sh | bash'
done
```

### Custom Configuration
```bash
./bootstrap.sh --config config/custom.yaml
./bootstrap.sh --manifest-url https://internal.company.com/manifest.yaml
```

## 🛠️ Available Commands

After installation, you'll have access to 42+ shell aliases:

### Deployment
```bash
deploy-vercel              # Deploy to Vercel
deploy-netlify             # Deploy to Netlify
deploy-supabase            # Deploy to Supabase
deploy                     # Auto-detect platform
```

### File Sharing
```bash
share                      # Create shareable link
share-dropbox              # Upload to Dropbox
share-gdrive               # Upload to Google Drive
```

### Cloud Sync
```bash
sync-dropbox               # Sync to Dropbox
sync-gdrive                # Sync to Google Drive
sync-s3                    # Sync to S3
```

### MCP Management
```bash
mcp-list                   # List MCP servers
mcp-reload                 # Reload configuration
mcp-logs                   # View MCP logs
mcp-test                   # Test connections
```

### Project Workflows
```bash
project-init               # Initialize new project
project-deploy             # Deploy current project
project-share              # Share project files
```

## 🔍 Requirements

- **OS**: Debian 10+ or Ubuntu 20.04+
- **User**: Non-root with sudo privileges
- **Disk**: 2GB+ free space
- **Network**: Internet connection
- **Memory**: 1GB+ RAM recommended

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add/modify modules in `bootstrap/modules/`
4. Test with `./bootstrap.sh --module your-module`
5. Submit a pull request

## 🎉 Success Metrics

- **Setup Time**: ~5 minutes
- **Components**: 10 modules
- **MCP Servers**: 6 configured
- **Shell Aliases**: 42 available
- **Validation**: 100% coverage

## 🔒 Security

**Enhanced in v2.0:**
- ✅ No `curl | bash` installation (security vulnerability eliminated)
- ✅ SHA256 checksum verification for all downloads
- ✅ Automatic secret sanitization in logs (15+ patterns)
- ✅ AES-256-CBC credential encryption at rest
- ✅ Pre-commit hook prevents accidental secret commits
- ✅ Comprehensive input validation (injection prevention)
- ✅ Restrictive file permissions (0600/0700 for sensitive files)
- ✅ Secure temporary file handling with `mktemp`

**Best Practices:**
- API tokens via environment variables
- App-specific passwords for email
- 90-day token rotation recommended
- Minimum privilege scopes enforced
- See [docs/guides/SECURITY.md](docs/guides/SECURITY.md) for full security policy

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: https://github.com/nyldn/openclaw-config/issues
- **Documentation**: https://github.com/nyldn/openclaw-config/wiki
- **Bootstrap Docs**: [bootstrap/README.md](bootstrap/README.md)

## 📅 Changelog

### v2.0.0 (2026-02-01)

**🎯 Major Features:**
- **Interactive Installation** - Beautiful TUI with preset selection (Minimal, Developer, Full, Custom)
- **Productivity Integrations** - 4 new MCP servers: Google Calendar, Email, Todoist, Slack (30 tools total)
- **Smart Dependencies** - Automatic dependency resolution with topological sort
- **OpenClaw Optional** - No longer required; choose only what you need

**🔒 Security Enhancements (20+ Fixes):**
- Fixed all `curl | bash` vulnerabilities
- SHA256 checksum verification for downloads
- Secret sanitization in logs (API keys, tokens, passwords)
- AES-256-CBC credential encryption
- Pre-commit hook for secret detection
- Comprehensive input validation
- Secure temp directory handling

**📦 New Components:**
- `15-productivity-tools.sh` module
- `lib/interactive.sh` - Interactive menu system
- `lib/dependency-resolver.sh` - Graph-based dependency resolution
- `lib/secure-download.sh` - Download verification
- `lib/crypto.sh` - Credential encryption
- 4 MCP server implementations
- Comprehensive 40-page productivity guide

**📝 Documentation:**
- Updated installation instructions (no more `curl | bash`)
- PRODUCTIVITY_INTEGRATIONS.md - Complete setup guide
- Enhanced manifest.yaml with categories and sizes
- docs/guides/MIGRATION.md for v1.x users
- docs/guides/SECURITY.md policy document

**⚠️ Breaking Changes:**
- Default installation is now interactive (use `--non-interactive` for scripts)
- OpenClaw no longer installed by default
- Removed insecure `curl | bash` installation method
- See [docs/guides/MIGRATION.md](docs/guides/MIGRATION.md) for upgrade instructions

### v1.2.0 (2026-02-01)
- Added auto-update system (module 11)
- Daily automated updates for all components
- Systemd timer for scheduled updates
- Update reports and comprehensive logging
- Repository auto-update from GitHub
- Package cleanup and maintenance

### v1.1.0 (2026-02-01)
- Added deployment tools module
- Extended MCP server configuration (6 servers)
- 28+ new shell aliases
- Comprehensive deployment documentation
- GitHub, Filesystem, PostgreSQL, Brave Search MCP servers

### v1.0.0 (2026-02-01)
- Initial release
- Core modules: system-deps, python, nodejs
- LLM CLI tools: Claude, OpenAI, Gemini
- GOTCHA framework structure
- Memory system initialization
- Update mechanism
- Validation and diagnostics

---

**Built with ❤️ for the OpenClaw ecosystem**

**Powered by Claude Octopus 🐙 - Full Double Diamond Workflow**
