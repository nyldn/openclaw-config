# OpenClaw VM Bootstrap System

Automated installation system for Debian VMs that sets up Claude CLI, OpenAI Codex CLI, Gemini CLI, and the GOTCHA/ATLAS framework environment.

## Quick Start

### Remote Installation (Recommended)

From any Debian-based system:

```bash
curl -fsSL https://raw.githubusercontent.com/nyldn/openclaw-config/main/bootstrap/install.sh | bash
```

### Local Installation

```bash
# Clone repository
git clone https://github.com/nyldn/openclaw-config.git
cd openclaw-config/bootstrap

# Run bootstrap
./bootstrap.sh
```

## Features

- **Modular Architecture**: Individual modules for each component
- **Incremental Updates**: Only install what's changed
- **Hybrid Mode**: CLI tools for terminal + API SDKs for programmatic access
- **Extensible**: Easy to add new tools and packages
- **State Tracking**: Knows what's installed and when
- **Validation**: Post-installation checks for all components
- **Rollback Support**: Undo installations if needed

## What Gets Installed

### System Dependencies
- Base packages: curl, git, build-essential, sqlite3
- Development headers and libraries
- Locale and timezone configuration

### Python Environment (3.9+)
- Python runtime and pip
- Virtual environment at `~/.local/venv/openclaw`
- SDKs: Anthropic, OpenAI, Google Generative AI
- Utilities: rank-bm25, pyyaml, python-dotenv

### Node.js Environment (22+)
- Node.js 22 LTS runtime and npm (required by OpenClaw >=22.12.0)
- Global packages directory at `~/.local/npm-global`

### LLM CLI Tools
- **Claude Code CLI**: Terminal access to Claude
- **OpenAI CLI**: Terminal access to GPT models
- **Gemini CLI**: Terminal access to Gemini (SDK primary)

### Deployment Tools
- **Vercel CLI**: Serverless and edge deployments
- **Netlify CLI**: Static sites and serverless functions
- **Supabase CLI**: Database, auth, and storage deployments
- **Extended MCP Servers**: GitHub, Filesystem, PostgreSQL, Brave Search
- **Shell Aliases**: 28+ deployment and sync shortcuts

### Automated Maintenance
- **Daily Auto-Updates**: Systemd timer-based updates
- **System Packages**: APT/YUM/DNF updates
- **Python/Node Packages**: Keep dependencies current
- **CLI Tools**: Update Vercel, Netlify, Supabase
- **Repository Updates**: Auto-pull from GitHub
- **Cleanup**: Remove unused packages and caches

### OpenClaw Skills

Popular skills from [ClawHub](https://clawhub.com) (400+ downloads):

- **ByteRover** (14,376): Project knowledge management through context trees
- **Self-Improving Agent** (9,370): AI self-improvement capabilities
- **Agent Browser** (4,765): Web browsing for agents
- **Proactive Agent** (2,189): Proactive task automation
- **Deep Research Agent** (1,630): Comprehensive research capabilities
- **Memory Setup** (1,206): Memory management configuration
- **Agent Browser 2** (1,135): Enhanced web browsing
- **Second Brain** (783): Personal knowledge management
- **Prompt Guard** (757): Prompt injection protection
- **AgentMail** (708): Email integration
- **Compound Engineering** (666): Complex engineering workflows
- **Agent Browser 3** (561): Advanced web capabilities
- **Exa** (522): Enhanced search capabilities
- **Context7 MCP** (451): Context management protocol
- **Ontology** (416): Knowledge graph management

### OpenClaw Workspace

Creates `~/.openclaw/workspace/` with upstream template files and GOTCHA structure:

```
~/.openclaw/workspace/
├── AGENTS.md              # Agent configurations (upstream)
├── SOUL.md                # Agent personality guidelines (upstream)
├── TOOLS.md               # Available tools documentation (upstream)
├── goals/                 # Goal definitions
├── tools/                 # Available tools
│   ├── manifest.md
│   └── memory/            # Memory system tools
├── context/               # Context storage
├── hardprompts/           # Reusable prompts
├── args/                  # Arguments and configs
├── memory/                # Memory files
│   └── logs/              # Daily logs
├── data/                  # Databases and data
└── .tmp/                  # Temporary files
```

### Memory System
- SQLite database for persistent memory
- Daily log files
- Semantic search capabilities
- Hybrid search (keyword + semantic)

## Usage

### Installation Options

```bash
# Full installation
./bootstrap.sh

# Verbose mode
./bootstrap.sh --verbose

# Install specific modules only
./bootstrap.sh --only python,claude-cli

# Skip optional modules
./bootstrap.sh --skip gemini-cli

# Dry run (preview)
./bootstrap.sh --dry-run

# Non-interactive
./bootstrap.sh --non-interactive
```

### Update Management

```bash
# Check for updates
./bootstrap.sh --check-updates

# Install updates
./bootstrap.sh --update

# Use custom manifest
./bootstrap.sh --manifest-url https://example.com/manifest.yaml
```

### Validation

```bash
# Validate installation
./bootstrap.sh --validate

# Run diagnostics
./bootstrap.sh --doctor

# List available modules
./bootstrap.sh --list-modules
```

## Post-Installation

### 1. Configure API Keys

Edit `~/.openclaw/workspace/.env`:

```bash
nano ~/.openclaw/workspace/.env
```

Add your API keys:

```env
ANTHROPIC_API_KEY=sk-ant-your-key-here
OPENAI_API_KEY=sk-proj-your-key-here
GOOGLE_API_KEY=your-google-api-key-here
```

### 2. Authenticate CLI Tools

```bash
# Claude CLI
claude login

# OpenAI CLI (or set API key in .env)
openai auth login

# Gemini - uses GOOGLE_API_KEY from .env

# Deployment Tools
vercel login
netlify login
supabase login
```

### 3. Configure MCP Servers

Edit environment variables for MCP servers:

```bash
# GitHub MCP Server
export GITHUB_PAT="ghp_your_github_personal_access_token"

# PostgreSQL MCP Server (Supabase)
export SUPABASE_DB_URL="postgresql://user:pass@host:port/db"

# Brave Search MCP Server (optional)
export BRAVE_API_KEY="your_brave_api_key"
```

Add to `~/.zshrc` for persistence:

```bash
echo 'export GITHUB_PAT="ghp_xxx"' >> ~/.zshrc
echo 'export SUPABASE_DB_URL="postgresql://xxx"' >> ~/.zshrc
source ~/.zshrc
```

### 4. Test Installation

```bash
# Validate all components
cd ~/openclaw-bootstrap
./bootstrap.sh --validate

# Test memory system
cd ~/.openclaw/workspace
python tools/memory/memory_read.py --format markdown
python tools/memory/memory_write.py --content "Bootstrap completed" --type event
```

### 5. Start Development

```bash
cd ~/.openclaw/workspace

# Use Claude CLI
claude

# Use Python SDKs programmatically
source ~/.local/venv/openclaw/bin/activate
python
>>> import anthropic
>>> import openai
>>> import google.generativeai as genai
```

## Directory Structure

```
bootstrap/
├── bootstrap.sh           # Main orchestrator
├── install.sh             # Remote installer
├── README.md              # This file
├── manifest.yaml          # Version manifest
├── config/                # Configuration files
│   ├── packages.yaml
│   └── llm-tools.yaml
├── modules/               # Installation modules
│   ├── 01-system-deps.sh
│   ├── 02-python.sh
│   ├── 03-nodejs.sh
│   ├── 04-claude-cli.sh
│   ├── 05-codex-cli.sh
│   ├── 06-gemini-cli.sh
│   ├── 07-openclaw-env.sh
│   ├── 08-memory-init.sh
│   ├── 09-claude-octopus.sh
│   ├── 10-deployment-tools.sh
│   ├── 11-auto-updates.sh
│   ├── 12-dev-tools.sh
│   ├── 13-openclaw.sh
│   ├── 14-security.sh
│   ├── 15-productivity-tools.sh
│   ├── 16-openclaw-skills.sh
│   └── 17-tailscale.sh
├── lib/                   # Shared utilities
│   ├── logger.sh
│   ├── validation.sh
│   └── network.sh
├── templates/             # Template files
│   ├── MEMORY.md.template
│   ├── .env.template
│   └── daily-log.md.template
└── logs/                  # Installation logs
```

## Module System

### Module Structure

Each module is a self-contained bash script with standard functions:

```bash
#!/usr/bin/env bash

MODULE_NAME="module-name"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="Module description"
MODULE_DEPS=("dependency1" "dependency2")

check_installed() {
    # Check if module is already installed
}

install() {
    # Install the module
}

validate() {
    # Validate installation
}

rollback() {
    # Rollback installation
}
```

### Adding New Modules

1. Create `modules/09-new-module.sh`
2. Implement standard functions
3. Add to `manifest.yaml`
4. Test: `./bootstrap.sh --module new-module`

## Update Mechanism

### Local State File

`~/.openclaw/bootstrap-state.yaml` tracks installed versions:

```yaml
version: "1.0.0"
installed_at: "2026-02-01T12:00:00Z"
modules:
  python:
    version: "1.0.0"
    installed_at: "2026-02-01T12:05:00Z"
  claude-cli:
    version: "1.0.0"
    installed_at: "2026-02-01T12:10:00Z"
```

### Remote Manifest

`manifest.yaml` defines available versions and packages:

```yaml
version: "1.0.0"
modules:
  python:
    version: "1.0.0"
    required: true
packages:
  python:
    - openai>=1.0.0
    - anthropic>=0.25.0
```

### Update Workflow

1. Fetch remote manifest from GitHub
2. Compare with local state
3. Install modules with version mismatches
4. Update local state

## Troubleshooting

### Installation Fails

```bash
# Run diagnostics
./bootstrap.sh --doctor

# Check logs
tail -f logs/bootstrap-*.log

# Validate system
./bootstrap.sh --validate
```

### Module-Specific Issues

```bash
# Reinstall specific module
./bootstrap.sh --only module-name

# Validate module
cd modules
bash 02-python.sh validate
```

### API Keys Not Working

```bash
# Check .env file
cat ~/.openclaw/workspace/.env

# Test Python SDK
source ~/.local/venv/openclaw/bin/activate
python -c "import anthropic; print(anthropic.__version__)"
```

### Memory System Issues

```bash
# Check database
sqlite3 ~/.openclaw/workspace/data/memory.db ".tables"

# Test memory tools
cd ~/.openclaw/workspace
python tools/memory/memory_read.py --format markdown
```

## Requirements

- **OS**: Debian 10+ or Ubuntu 20.04+
- **User**: Non-root user with sudo privileges
- **Disk**: 2GB+ free space
- **Network**: Internet connection for downloads
- **Memory**: 1GB+ RAM recommended

## Configuration Files

### packages.yaml

Defines system packages and Python/Node dependencies.

### llm-tools.yaml

Defines CLI tools and SDK configuration for each LLM provider.

### manifest.yaml

Version manifest for update checking and module management.

## Remote Deployment

### SSH Installation

```bash
# Copy and run locally
scp -r bootstrap/ user@192.168.0.4:~/
ssh user@192.168.0.4 'cd ~/bootstrap && ./bootstrap.sh'

# Or use remote install script
ssh user@192.168.0.4 'bash <(curl -fsSL https://example.com/install.sh)'
```

### Automated Deployment

```bash
# Deploy to multiple VMs
for host in vm1 vm2 vm3; do
    ssh user@$host 'curl -fsSL https://example.com/install.sh | bash'
done
```

## Advanced Usage

### Custom Configurations

```bash
# Use custom config
./bootstrap.sh --config config/dev.yaml

# Custom manifest URL
./bootstrap.sh --manifest-url https://internal.company.com/openclaw-manifest.yaml
```

### Selective Installation

```bash
# Minimal installation
./bootstrap.sh --only system-deps,python

# Development setup
./bootstrap.sh --only system-deps,python,nodejs,claude-cli

# Skip optional components
./bootstrap.sh --skip gemini-cli
```

## Contributing

To add new modules or improve existing ones:

1. Create/modify module in `modules/`
2. Update `manifest.yaml` with new versions
3. Test with `./bootstrap.sh --module your-module`
4. Commit changes and update remote manifest

## License

(Add your license here)

## Support

- GitHub Issues: https://github.com/nyldn/openclaw-config/issues
- Documentation: https://github.com/nyldn/openclaw-config/wiki

## Changelog

### v2.0.0 (2026-02-08)

- **BREAKING**: Upgraded Node.js requirement from 20 to 22+ (required by upstream OpenClaw)
- **BREAKING**: Config schema changed from `config.json` to `openclaw.json` (upstream format)
- **BREAKING**: Workspace moved from `~/openclaw-workspace` to `~/.openclaw/workspace`
- Integrated `openclaw onboard --install-daemon` wizard into install flow
- Skills now installed via native `openclaw skills install` (ClawHub) instead of sundial-hub
- Added `openclaw doctor` to validation pipeline
- Added gateway daemon systemd service (`openclaw-gateway.service`)
- Added Tailscale integration module (17-tailscale.sh) for remote gateway access
- Added development channel support (stable/beta/dev) to auto-update
- Updated security guidance to match upstream model (DM pairing, sandbox modes, allowlists)
- Default model set to `anthropic/claude-opus-4-6`
- Upstream template files (AGENTS.md, SOUL.md, TOOLS.md) in workspace
- UFW rules now include OpenClaw gateway port (18789)

### v1.3.0 (2026-02-04)

- Added OpenClaw skills module (16-openclaw-skills.sh)
- Installs 15 popular skills from awesome-openclaw-skills (400+ downloads)
- Skills installed via `npx sundial-hub add <name>`
- Includes ByteRover, Self-Improving Agent, Agent Browser, and more
- Source: https://github.com/sundial-org/awesome-openclaw-skills

### v1.2.0 (2026-02-01)

- Added auto-update system (11-auto-updates.sh)
- Daily automated updates via systemd timer
- Updates for system, Python, Node.js, CLI tools
- Repository auto-sync from GitHub
- Comprehensive update logging and reports
- Package cleanup and maintenance automation

### v1.1.0 (2026-02-01)

- Added deployment tools module (10-deployment-tools.sh)
- Vercel, Netlify, and Supabase CLI installations
- Extended MCP server configuration (6 servers)
- 28+ shell aliases for deployment and file sharing
- GitHub, Filesystem, PostgreSQL, Brave Search MCP servers
- Comprehensive deployment documentation

### v1.0.0 (2026-02-01)

- Initial release
- Core modules: system-deps, python, nodejs
- LLM CLI tools: Claude, OpenAI, Gemini
- GOTCHA framework structure
- Memory system initialization
- Update mechanism
- Validation and diagnostics
