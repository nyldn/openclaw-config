#!/usr/bin/env bash

# Generate TOOLS.md for OpenClaw Workspace
# Documents all installed tools, packages, and capabilities
# This file is read by OpenClaw to understand available tools

set -euo pipefail

WORKSPACE_DIR="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
TOOLS_FILE="$WORKSPACE_DIR/TOOLS.md"
STATE_FILE="$HOME/.openclaw/bootstrap-state.yaml"

# Ensure workspace exists
mkdir -p "$WORKSPACE_DIR"

# Generate timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S UTC' -u)

cat > "$TOOLS_FILE" <<'EOF'
# Available Tools & Capabilities

**Last Updated:** TIMESTAMP_PLACEHOLDER

This document describes all tools, packages, and capabilities available on this OpenClaw VM.
It is automatically generated from the bootstrap installation state.

---

## 🤖 AI & LLM Tools

### Claude Code CLI
- **Command:** `claude`
- **Purpose:** Anthropic's official Claude assistant for terminal
- **Usage:**
  ```bash
  claude chat              # Start interactive chat
  claude --version         # Check version
  ```
- **API Key:** Set `ANTHROPIC_API_KEY` in `~/openclaw-workspace/.env`
- **Documentation:** https://docs.anthropic.com/claude/docs/claude-cli

### OpenAI CLI (Codex)
- **Command:** `codex`, `openai`
- **Purpose:** Access GPT-4 and GPT-3.5 models from terminal
- **Usage:**
  ```bash
  openai api chat.completions.create -m gpt-4 -g user "Hello"
  ```
- **API Key:** Set `OPENAI_API_KEY` in `~/openclaw-workspace/.env`
- **Documentation:** https://platform.openai.com/docs/api-reference

### Gemini CLI
- **Command:** `gemini`
- **Purpose:** Google's Gemini models from terminal
- **Usage:**
  ```bash
  gemini chat              # Interactive chat
  gemini generate "prompt" # One-shot generation
  ```
- **API Key:** Set `GOOGLE_API_KEY` in `~/openclaw-workspace/.env`
- **Documentation:** https://ai.google.dev/docs

### OpenClaw.ai
- **Command:** `openclaw`
- **Purpose:** AI-powered automation and agent system
- **Configuration:** `~/.openclaw/openclaw.json`
- **Workspace:** `~/.openclaw/workspace/`
- **Usage:**
  ```bash
  openclaw start           # Start OpenClaw server
  openclaw session list    # List sessions
  ```
- **Documentation:** https://docs.openclaw.ai/

### Claude Octopus
- **Command:** Multi-AI orchestration system
- **Purpose:** Coordinate multiple AI providers for complex tasks
- **Location:** `~/openclaw-workspace/tools/claude-octopus/`
- **Documentation:** See workspace documentation

---

## 📦 Deployment & Infrastructure

### Vercel CLI
- **Command:** `vercel`
- **Purpose:** Deploy to Vercel serverless platform
- **Usage:**
  ```bash
  vercel                   # Deploy current directory
  vercel login             # Authenticate
  vercel logs              # View deployment logs
  vercel env ls            # List environment variables
  ```
- **Documentation:** https://vercel.com/docs/cli
- **Aliases:** `deploy-vercel`

### Netlify CLI
- **Command:** `netlify`
- **Purpose:** Deploy to Netlify platform
- **Usage:**
  ```bash
  netlify deploy           # Deploy site
  netlify login            # Authenticate
  netlify dev              # Local development server
  ```
- **Documentation:** https://docs.netlify.com/cli/get-started/
- **Aliases:** `deploy-netlify`

### Supabase CLI
- **Command:** `supabase`
- **Purpose:** Backend-as-a-Service - Postgres, Auth, Storage
- **Usage:**
  ```bash
  supabase start           # Start local Supabase
  supabase db push         # Push migrations
  supabase functions deploy # Deploy Edge Functions
  ```
- **Database URL:** Set `SUPABASE_DB_URL` in `~/openclaw-workspace/.env`
- **Documentation:** https://supabase.com/docs/guides/cli
- **Aliases:** `deploy-supabase`

---

## 🔧 Development Tools

### Node.js & npm
- **Command:** `node`, `npm`, `npx`
- **Version:** NODE_VERSION_PLACEHOLDER
- **Global packages location:** `~/.local/npm-global/`
- **Usage:**
  ```bash
  node --version
  npm install <package>
  npx <package>
  ```

### pnpm (Fast Package Manager)
- **Command:** `pnpm`
- **Purpose:** Fast, disk space efficient package manager
- **Benefits:** 70% less disk space than npm, faster installs
- **Usage:**
  ```bash
  pnpm install             # Install dependencies
  pnpm add <package>       # Add package
  pnpm run <script>        # Run script
  ```
- **Documentation:** https://pnpm.io/

### Python 3
- **Command:** `python3`, `pip3`
- **Version:** PYTHON_VERSION_PLACEHOLDER
- **Virtual environment:** `~/.local/venv/openclaw`
- **Activation:**
  ```bash
  source ~/.local/venv/openclaw/bin/activate
  ```
- **Installed packages:**
  - `anthropic` - Anthropic SDK
  - `openai` - OpenAI SDK
  - `google-generativeai` - Google Gemini SDK
  - And more (see `pip list`)

### Biome (Linter & Formatter)
- **Command:** `biome`
- **Purpose:** Unified toolchain for linting and formatting (replaces ESLint + Prettier)
- **Speed:** 10-25x faster than ESLint
- **Usage:**
  ```bash
  biome check .            # Check code
  biome format .           # Format code
  biome lint .             # Lint code
  ```
- **Documentation:** https://biomejs.dev/

### Doppler CLI (Secrets Management)
- **Command:** `doppler`
- **Purpose:** Secure secrets and configuration management
- **Usage:**
  ```bash
  doppler login            # Authenticate
  doppler secrets          # View secrets
  doppler run -- npm start # Run command with secrets
  ```
- **Documentation:** https://docs.doppler.com/docs/cli

### Bruno CLI (API Testing)
- **Command:** `bru`
- **Purpose:** API testing and documentation
- **Usage:**
  ```bash
  bru run collection.bru   # Run API tests
  ```
- **Documentation:** https://docs.usebruno.com/

### Turborepo (Monorepo Management)
- **Command:** `turbo`
- **Purpose:** High-performance build system for monorepos
- **Usage:**
  ```bash
  turbo run build          # Run build across workspace
  turbo run test --filter=pkg
  ```
- **Documentation:** https://turbo.build/repo/docs

---

## 🔐 Security Tools

### UFW (Uncomplicated Firewall)
- **Command:** `sudo ufw`
- **Status:** Check with `sudo ufw status`
- **Configuration:** Default deny incoming, allow SSH (22), HTTP (80), HTTPS (443)
- **Usage:**
  ```bash
  sudo ufw status          # Check status
  sudo ufw allow 8080      # Allow port
  ```

### fail2ban (Intrusion Prevention)
- **Service:** `fail2ban`
- **Purpose:** Automatically ban IPs with failed login attempts
- **Configuration:** `/etc/fail2ban/jail.local`
- **Usage:**
  ```bash
  sudo fail2ban-client status        # Check status
  sudo fail2ban-client status sshd   # SSH jail status
  ```

### AIDE (File Integrity Monitoring)
- **Command:** `sudo aide`
- **Purpose:** Detect unauthorized file modifications
- **Database:** `/var/lib/aide/aide.db`
- **Usage:**
  ```bash
  sudo aide --check        # Check for changes
  sudo aide --update       # Update database
  ```

### SSH Hardening
- **Configuration:** `/etc/ssh/sshd_config`
- **Security settings:**
  - No root login
  - No password authentication (key-only)
  - Max 3 authentication attempts
  - fail2ban monitors failed attempts

---

## 🔌 MCP Servers (Model Context Protocol)

Configuration: `~/.config/claude/mcp.json`

### Available MCP Servers

1. **Google Drive MCP**
   - Access and manage Google Drive files
   - Requires: `GOOGLE_DRIVE_CREDENTIALS`

2. **Dropbox MCP**
   - Access Dropbox files and folders
   - Requires: `DROPBOX_ACCESS_TOKEN`

3. **GitHub MCP**
   - Repository operations and management
   - Requires: `GITHUB_PAT`

4. **Filesystem MCP**
   - Local file operations
   - No credentials required

5. **PostgreSQL MCP (Supabase)**
   - Database operations
   - Requires: `SUPABASE_DB_URL`

6. **Brave Search MCP**
   - Web search capabilities
   - Requires: `BRAVE_API_KEY`

7. **Figma MCP**
   - Design file access
   - Requires: `FIGMA_PAT`, `FIGMA_FILE_KEY`

8. **Stripe MCP**
   - Payment processing operations
   - Requires: `STRIPE_SECRET_KEY`

9. **Sentry MCP**
   - Error tracking and monitoring
   - Requires: `SENTRY_AUTH_TOKEN`

10. **Sequential Thinking MCP**
    - Enhanced reasoning capabilities
    - No credentials required

### MCP Management Commands

```bash
mcp-list                 # List all MCP servers
mcp-reload               # Reload MCP configuration
mcp-logs                 # View MCP logs
mcp-test                 # Test MCP connections
```

---

## 🗂️ File Sharing & Cloud Storage

### rclone
- **Command:** `rclone`
- **Purpose:** Universal cloud storage tool (50+ providers)
- **Supported:** S3, Google Drive, Dropbox, OneDrive, etc.
- **Usage:**
  ```bash
  rclone config            # Configure remote
  rclone copy source: dest: # Copy files
  rclone sync source: dest: # Sync directories
  ```
- **Documentation:** https://rclone.org/docs/

### Cloud Sync Aliases

```bash
sync-dropbox <dir>       # Sync directory to Dropbox
sync-gdrive <dir>        # Sync directory to Google Drive
sync-s3 <dir>            # Sync directory to S3
share-dropbox <file>     # Upload and get shareable link
share-gdrive <file>      # Upload to Drive and share
```

---

## 🛠️ System Utilities

### Git
- **Command:** `git`
- **Configuration:** Global config in `~/.gitconfig`
- **SSH keys:** `~/.ssh/`

### jq (JSON Processor)
- **Command:** `jq`
- **Purpose:** Parse and manipulate JSON
- **Usage:**
  ```bash
  echo '{"name":"value"}' | jq '.name'
  ```

### curl & wget
- **Commands:** `curl`, `wget`
- **Purpose:** Download files and make HTTP requests

### build-essential
- **Includes:** gcc, g++, make
- **Purpose:** Compile software from source

---

## 📊 Memory & State Management

### Memory Database
- **Location:** `~/openclaw-workspace/data/memory.db`
- **Type:** SQLite database
- **Purpose:** Persistent memory for AI agents
- **Schema:** Defined in `~/openclaw-workspace/tools/memory/`

### Bootstrap State
- **Location:** `~/.openclaw/bootstrap-state.yaml`
- **Purpose:** Track installed modules and versions
- **Usage:** View with `cat ~/.openclaw/bootstrap-state.yaml`

---

## 🔄 Auto-Update System

### Update Schedule
- **Frequency:** Daily at 3:00 AM
- **Service:** `openclaw-auto-update.service`
- **Timer:** `openclaw-auto-update.timer`

### Update Components
- System packages (APT)
- Python packages (pip)
- Node.js global packages (npm)
- CLI tools (Vercel, Netlify, Supabase)
- MCP servers
- OpenClaw config repository

### Manual Update
```bash
systemctl --user start openclaw-auto-update.service
```

### Update Logs
- **Location:** `/var/log/openclaw/auto-update-YYYYMMDD.log`
- **Reports:** `/var/log/openclaw/update-report-YYYYMMDD.txt`

---

## 🌐 Environment Variables

**Location:** `~/openclaw-workspace/.env`

Required API keys:
```env
ANTHROPIC_API_KEY=sk-ant-xxx
OPENAI_API_KEY=sk-proj-xxx
GOOGLE_API_KEY=xxx
GITHUB_PAT=ghp_xxx
SUPABASE_DB_URL=postgresql://xxx
STRIPE_SECRET_KEY=sk_test_xxx
FIGMA_PAT=xxx
BRAVE_API_KEY=xxx
SENTRY_AUTH_TOKEN=xxx
DROPBOX_ACCESS_TOKEN=xxx
```

---

## 📖 Quick Reference: Common Tasks

### Deploy a Project
```bash
# Vercel
vercel

# Netlify
netlify deploy

# Supabase
supabase db push
```

### Share a File
```bash
share-dropbox myfile.pdf
share-gdrive document.docx
```

### Run AI Assistants
```bash
claude chat
gemini chat
openclaw start
```

### Check System Status
```bash
systemctl --user status openclaw-auto-update.timer
sudo ufw status
sudo fail2ban-client status
```

### View Logs
```bash
cat /var/log/openclaw/auto-update-$(date +%Y%m%d).log
journalctl --user -u openclaw-auto-update.service
```

---

## 🔗 Important Paths

| Purpose | Path |
|---------|------|
| OpenClaw Workspace | `~/.openclaw/workspace/` |
| OpenClaw Config | `~/.openclaw/openclaw.json` |
| Bootstrap Config | `~/openclaw-config/` |
| Environment Variables | `~/openclaw-workspace/.env` |
| Python Virtual Env | `~/.local/venv/openclaw/` |
| NPM Global Packages | `~/.local/npm-global/` |
| MCP Configuration | `~/.config/claude/mcp.json` |
| Auto-Update Logs | `/var/log/openclaw/` |
| Security Reports | `~/.openclaw-security/` |

---

## 📝 Bootstrap Modules Installed

MODULES_LIST_PLACEHOLDER

---

## 💡 Tips

1. **Always activate Python venv** before using Python tools:
   ```bash
   source ~/.local/venv/openclaw/bin/activate
   ```

2. **Reload shell after updates** to get new aliases:
   ```bash
   source ~/.zshrc  # or source ~/.bashrc
   ```

3. **Use auto-complete** for commands - press TAB

4. **Check logs** when things don't work - most services log to `/var/log/`

5. **MCP servers** require authentication - set API keys in `.env` first

6. **Deployment tools** require login before first use:
   ```bash
   vercel login
   netlify login
   supabase login
   ```

---

**Generated by:** OpenClaw Bootstrap System
**Repository:** https://github.com/nyldn/openclaw-config
**Documentation:** See bootstrap/README.md
EOF

# Replace placeholders
sed -i.bak "s/TIMESTAMP_PLACEHOLDER/$TIMESTAMP/g" "$TOOLS_FILE"

# Get Node.js version
if command -v node &>/dev/null; then
    NODE_VERSION=$(node --version)
    sed -i.bak "s/NODE_VERSION_PLACEHOLDER/$NODE_VERSION/g" "$TOOLS_FILE"
fi

# Get Python version
if command -v python3 &>/dev/null; then
    PYTHON_VERSION=$(python3 --version)
    sed -i.bak "s/PYTHON_VERSION_PLACEHOLDER/$PYTHON_VERSION/g" "$TOOLS_FILE"
fi

# Generate modules list from state file
if [[ -f "$STATE_FILE" ]]; then
    MODULES_LIST=$(awk '/modules:/ {flag=1; next} /^[^ ]/ {flag=0} flag && /  [a-z]/ {print "- " $1}' "$STATE_FILE" | sort)

    # Escape for sed
    MODULES_LIST_ESCAPED=$(echo "$MODULES_LIST" | sed ':a;N;$!ba;s/\n/\\n/g')

    sed -i.bak "s|MODULES_LIST_PLACEHOLDER|$MODULES_LIST_ESCAPED|g" "$TOOLS_FILE"
else
    sed -i.bak "s/MODULES_LIST_PLACEHOLDER/State file not found - run bootstrap to install modules/g" "$TOOLS_FILE"
fi

# Remove backup files
rm -f "$TOOLS_FILE.bak"

echo "✓ Generated TOOLS.md for OpenClaw workspace"
echo "  Location: $TOOLS_FILE"
echo "  OpenClaw will read this file to understand available tools"
