# OpenClaw VM Configuration

Automated configuration and deployment system for OpenClaw VMs with comprehensive tooling for AI development, cloud deployment, and file sharing.

## 🚀 Quick Start

### Remote Installation (One-Line)

```bash
curl -fsSL https://raw.githubusercontent.com/nyldn/openclawd-config/main/bootstrap/install.sh | bash
```

### Local Installation

```bash
git clone https://github.com/nyldn/openclawd-config.git
cd openclawd-config/bootstrap
./bootstrap.sh
```

## 📦 What's Included

### Core AI Tools
- **Claude Code CLI** - Anthropic's Claude assistant
- **OpenAI CLI** - GPT-4 and GPT-3.5 access
- **Gemini CLI** - Google's Gemini models
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

### MCP Servers (6 Total)
- Google Drive - File operations and sharing
- Dropbox - Cloud storage access
- GitHub - Repository management
- Filesystem - Local file operations
- PostgreSQL - Database access (Supabase)
- Brave Search - Web search capabilities

### Shell Aliases (42 Total)
- Deployment shortcuts (deploy-vercel, deploy-netlify, etc.)
- File sharing (share-dropbox, share-gdrive)
- Cloud sync (sync-dropbox, sync-gdrive, sync-s3)
- MCP management (mcp-list, mcp-reload, mcp-logs)

## 📁 Repository Structure

```
openclawd-config/
├── README.md                    # This file
├── bootstrap/                   # Bootstrap system
│   ├── README.md               # Bootstrap documentation
│   ├── bootstrap.sh            # Main installer
│   ├── install.sh              # Remote installer
│   ├── modules/                # Installation modules
│   │   ├── 01-system-deps.sh
│   │   ├── 02-python.sh
│   │   ├── 03-nodejs.sh
│   │   ├── 04-claude-cli.sh
│   │   ├── 05-codex-cli.sh
│   │   ├── 06-gemini-cli.sh
│   │   ├── 07-openclaw-env.sh
│   │   ├── 08-memory-init.sh
│   │   ├── 09-claude-octopus.sh
│   │   ├── 10-deployment-tools.sh
│   │   └── 11-auto-updates.sh
│   └── lib/                    # Shared utilities
│       ├── logger.sh
│       ├── validation.sh
│       └── network.sh
├── deployment-tools/           # Deployment configuration
│   ├── scripts/
│   │   └── install-deployment-tools.sh
│   ├── mcp/
│   │   └── mcp-servers-extended.json
│   ├── aliases/
│   │   └── deployment-aliases.sh
│   └── docs/
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
ssh user@vm-host 'curl -fsSL https://raw.githubusercontent.com/nyldn/openclawd-config/main/bootstrap/install.sh | bash'
```

### Multiple VMs
```bash
for host in vm1 vm2 vm3; do
    ssh user@$host 'curl -fsSL https://raw.githubusercontent.com/nyldn/openclawd-config/main/bootstrap/install.sh | bash'
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

## 📊 Comparison: Before vs After

| Feature | Before | After | Change |
|---------|--------|-------|--------|
| MCP Servers | 0 | 6 | +6 (new) |
| CLI Tools | 3 | 6 | +3 (+100%) |
| Shell Aliases | 14 | 42 | +28 (+200%) |
| Deployment Platforms | 0 | 3 | +3 (new) |
| Cloud Storage | 0 | 2 | +2 (new) |

## 🎉 Success Metrics

- **Setup Time**: ~5 minutes
- **Components**: 10 modules
- **MCP Servers**: 6 configured
- **Shell Aliases**: 42 available
- **Validation**: 100% coverage

## 🔒 Security

- No credentials stored in repository
- API tokens via environment variables
- Docker secrets support for production
- 90-day token rotation recommended
- Minimum privilege scopes enforced

## 📝 License

(Add your license here)

## 🆘 Support

- **Issues**: https://github.com/nyldn/openclawd-config/issues
- **Documentation**: https://github.com/nyldn/openclawd-config/wiki
- **Bootstrap Docs**: [bootstrap/README.md](bootstrap/README.md)

## 📅 Changelog

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
