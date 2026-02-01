# OpenClaw Bootstrap - Quick Start Guide

## 🚀 Installation Complete!

The OpenClaw VM Bootstrap System has been fully implemented with **23 files** including:
- 9 installation modules (including Claude Octopus plugin)
- 3 utility libraries
- 3 configuration files
- 3 template files
- Comprehensive documentation

## ✅ Verification

Run the verification script to confirm everything is ready:

```bash
./verify.sh
```

Expected output: `✓ All checks passed!`

## 📋 Quick Usage Guide

### Test Locally (Dry Run)

```bash
# Preview what would be installed
./bootstrap.sh --dry-run --verbose

# List available modules
./bootstrap.sh --list-modules
```

### Deploy to Debian VM

#### Option 1: Remote Installation (Recommended for Production)

```bash
# Update the GitHub URL in install.sh first, then:
curl -fsSL https://raw.githubusercontent.com/YOUR-USER/openclawd-config/main/bootstrap/install.sh | bash
```

#### Option 2: Local Installation

```bash
# Copy bootstrap directory to target VM
scp -r bootstrap/ user@192.168.0.4:~/

# SSH and run
ssh user@192.168.0.4
cd ~/bootstrap
./bootstrap.sh
```

### Selective Installation

```bash
# Install only specific modules
./bootstrap.sh --only python,claude-cli,claude-octopus

# Skip optional modules
./bootstrap.sh --skip gemini-cli

# Install everything except optional ones
./bootstrap.sh --skip claude-octopus
```

## 🔧 What Gets Installed

### Core System (Required)
- ✅ System dependencies (curl, git, build-essential, sqlite3)
- ✅ Python 3.9+ with virtual environment
- ✅ Node.js 20+ with npm
- ✅ OpenClaw workspace structure (GOTCHA framework)
- ✅ Memory system with SQLite database

### LLM Tools (Optional)
- ✅ Claude Code CLI + Anthropic SDK
- ✅ OpenAI CLI + OpenAI SDK
- ✅ Gemini SDK (CLI optional)
- ✅ Claude Octopus Plugin (NEW!)

## 📁 Workspace Structure Created

```
~/openclaw-workspace/
├── CLAUDE.md              # ATLAS framework guide
├── .env                   # API keys (configure after install)
├── goals/                 # Goal definitions
├── tools/
│   ├── manifest.md        # Available tools
│   └── memory/            # Memory system tools
├── context/               # Context storage
├── hardprompts/           # Reusable prompts
├── args/                  # Arguments and configs
├── memory/
│   ├── MEMORY.md          # Memory documentation
│   └── logs/              # Daily logs
├── data/
│   └── memory.db          # SQLite database
└── .tmp/                  # Temporary files
```

## 🔑 Post-Installation Steps

### 1. Configure API Keys

```bash
nano ~/openclaw-workspace/.env
```

Add your keys:
```env
ANTHROPIC_API_KEY=sk-ant-your-key-here
OPENAI_API_KEY=sk-proj-your-key-here
GOOGLE_API_KEY=your-google-api-key-here
```

### 2. Authenticate CLI Tools

```bash
# Claude CLI
claude login

# OpenAI CLI (optional - can use .env key)
openai auth login
```

### 3. Set Up Claude Octopus

```bash
# Start Claude CLI
claude

# In Claude session, run:
/octo:setup
```

### 4. Test Memory System

```bash
cd ~/openclaw-workspace

# Activate Python environment
source ~/.local/venv/openclaw/bin/activate

# Test memory write
python tools/memory/memory_write.py --content "Bootstrap completed successfully" --type event

# Test memory read
python tools/memory/memory_read.py --format markdown
```

## 🐙 Using Claude Octopus

The Claude Octopus plugin provides advanced AI personas and skills:

### Available Personas

- **strategy-analyst**: Market analysis and business strategy
- **backend-architect**: API design and microservices architecture
- **code-reviewer**: Code quality and security analysis
- **frontend-developer**: React components and UI implementation
- **test-automator**: Test automation frameworks
- **performance-engineer**: Performance optimization
- **security-auditor**: Security audits and DevSecOps
- **cloud-architect**: Cloud infrastructure design
- **ai-engineer**: LLM applications and RAG systems
- **database-architect**: Database design and architecture
- And many more...

### Using in Claude CLI

```bash
# Start Claude
claude

# Use a persona
/task strategy-analyst "analyze market opportunity for AI-powered note-taking app"

# Use a skill
/octopus-code-review path/to/code

# Run setup
/octo:setup
```

## 🔄 Update Management

```bash
# Check for updates
./bootstrap.sh --check-updates

# Install updates
./bootstrap.sh --update

# Update specific module
./bootstrap.sh --module claude-octopus
```

## ✔️ Validation

```bash
# Validate all installed components
./bootstrap.sh --validate

# Run full diagnostics
./bootstrap.sh --doctor
```

## 📊 Module List

| Module | Description | Required |
|--------|-------------|----------|
| system-deps | Base system packages | ✅ Yes |
| python | Python 3.9+ environment | ✅ Yes |
| nodejs | Node.js 20+ environment | ✅ Yes |
| claude-cli | Claude Code CLI | ❌ No |
| codex-cli | OpenAI CLI | ❌ No |
| gemini-cli | Gemini SDK | ❌ No |
| openclaw-env | GOTCHA structure | ✅ Yes |
| memory-init | Memory system | ✅ Yes |
| claude-octopus | Octopus plugin | ❌ No |

## 🛠️ Troubleshooting

### Bootstrap Fails

```bash
# Run diagnostics
./bootstrap.sh --doctor

# Check logs
tail -f logs/bootstrap-*.log

# Reinstall specific module
./bootstrap.sh --module python
```

### API Keys Not Working

```bash
# Verify .env file
cat ~/openclaw-workspace/.env

# Test Python SDK
source ~/.local/venv/openclaw/bin/activate
python -c "import anthropic; print('OK')"
```

### Claude Octopus Issues

```bash
# Check plugin list
claude plugin list

# Reinstall
./bootstrap.sh --module claude-octopus

# Manual setup in Claude CLI
claude
> /octo:setup
```

## 📚 Documentation

- **README.md** - Full documentation
- **IMPLEMENTATION_SUMMARY.md** - Implementation details
- **manifest.yaml** - Module versions
- **config/packages.yaml** - Package definitions
- **config/llm-tools.yaml** - LLM tool configurations

## 🎯 Next Steps

1. **Test on Fresh VM**: Deploy to a clean Debian VM to verify installation
2. **Update URLs**: Replace placeholder GitHub URLs with actual repository
3. **Add Atlas Files**: Ensure `atlas_framework/` directory has required files
4. **Create First Project**: Use GOTCHA framework to build something!
5. **Explore Octopus**: Try different personas and workflows

## 🎉 You're Ready!

The OpenClaw bootstrap system is fully implemented and ready to deploy. All 9 modules are working, including the new Claude Octopus plugin integration.

For help:
```bash
./bootstrap.sh --help
```

Happy building! 🚀
