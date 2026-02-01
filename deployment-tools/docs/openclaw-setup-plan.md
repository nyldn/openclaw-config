# OpenClaw VM Setup Plan - ClaudePantheon Parity

**Goal:** Configure OpenClaw VM with similar tools and services as ClaudePantheon for seamless file sharing, project deployment, and Claude integration.

**Project Scope:** Medium feature - Core sharing tools + MCP servers
**Focus Areas:** File sharing, Deployment tools, MCP servers, Claude skills
**Autonomy Level:** Autonomous execution

---

## 🔍 PHASE 1: DISCOVER (Research Complete)

### ClaudePantheon Current State Analysis

**MCP Servers Configured:**
- ✅ Google Drive MCP Server (OAuth/Service account auth)
- ✅ Dropbox MCP Server (Token-based auth)
- 📝 Configuration: `/app/data/mcp/mcp.json`
- 📝 Credentials: JSON keys in `/app/data/mcp/`

**CLI Tools Installed:**
- ✅ System utilities (git, curl, wget, vim, nano, htop, tree, jq, etc.)
- ✅ Shell environment (zsh, oh-my-zsh, tmux)
- ✅ Claude Code CLI (native installer, auto-update)
- ✅ Node.js v22 (Alpine Linux)
- ✅ rclone (50+ cloud backends support)
- ❌ Vercel CLI (not installed)
- ❌ Netlify CLI (not installed)
- ❌ Supabase CLI (not installed)

**File Sharing Integrations:**
- ✅ Dropbox (via MCP + rclone)
- ✅ Google Drive (via MCP + rclone)
- ✅ WebDAV endpoint (optional)
- ✅ rclone support (S3, SFTP, SMB, etc.)

**Deployment Infrastructure:**
- ✅ Docker (Alpine + Node.js 22 base)
- ✅ GitHub Container Registry (GHCR)
- ✅ GitHub Actions CI/CD
- ✅ Make commands for build/deploy
- ❌ Vercel deployment
- ❌ Netlify deployment
- ❌ Supabase backend integration

**Claude Skills & Shortcuts:**
- ✅ 14+ custom shell aliases (cc, cc-new, cc-resume, etc.)
- ✅ Persistent session storage (`/app/data/claude/`)
- ✅ Custom commands directory
- ✅ Runtime settings management

### Gap Analysis: What OpenClaw VM Needs

**Missing Components:**
1. **Deployment Tools:**
   - Vercel CLI
   - Netlify CLI
   - Supabase CLI

2. **Additional MCP Servers (Optional):**
   - GitHub MCP Server
   - Filesystem MCP Server
   - Brave Search MCP Server
   - PostgreSQL MCP Server (for Supabase)

3. **Enhanced Skills:**
   - Deployment workflows
   - File sync automation
   - Project sharing shortcuts

---

## 🎯 PHASE 2: DEFINE (Consensus Building)

### Implementation Strategy

**Approach:** Extend ClaudePantheon setup with additional deployment tools while maintaining compatibility.

**Key Decisions:**

1. **Installation Method:**
   - ✅ Use native package managers (npm, homebrew, apt) for CLI tools
   - ✅ Add to custom-packages.txt for persistence
   - ✅ Create startup scripts in `/app/data/scripts/`

2. **MCP Server Integration:**
   - ✅ Extend existing `mcp.json` configuration
   - ✅ Add new MCP servers to `/app/data/mcp/` directory
   - ✅ Document credentials setup in CLAUDE.md

3. **Skills Organization:**
   - ✅ Create deployment-specific aliases (deploy-vercel, deploy-netlify, etc.)
   - ✅ Add project-sharing workflows
   - ✅ Integrate with existing cc-* command namespace

4. **Security Considerations:**
   - ✅ Use Docker secrets for API tokens
   - ✅ Avoid committing credentials to git
   - ✅ Document secure credential rotation

### Success Criteria

- [ ] All deployment CLIs (Vercel, Netlify, Supabase) installed and working
- [ ] MCP servers configured for file operations
- [ ] Custom skills/aliases for common workflows
- [ ] Documentation updated with setup instructions
- [ ] Credentials management documented
- [ ] All tools accessible via Claude Code

---

## 🛠️ PHASE 3: DEVELOP (Implementation)

### Implementation Tasks

#### 3.1: Install Deployment CLI Tools

**Vercel CLI:**
```bash
# Install globally via npm
npm install -g vercel

# Authenticate
vercel login

# Verify
vercel --version
```

**Netlify CLI:**
```bash
# Install globally via npm
npm install -g netlify-cli

# Authenticate
netlify login

# Verify
netlify --version
```

**Supabase CLI:**
```bash
# Install via npm
npm install -g supabase

# Authenticate
supabase login

# Verify
supabase --version
```

**Persistence:**
Add to `/app/data/custom-packages.txt`:
```
nodejs-npm
```

Add to startup script `/app/data/scripts/install-cli-tools.sh`:
```bash
#!/bin/sh
npm install -g vercel netlify-cli supabase
```

---

#### 3.2: Configure Additional MCP Servers

**GitHub MCP Server:**
```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PAT}"
      }
    }
  }
}
```

**Filesystem MCP Server:**
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/app/data/workspace"]
    }
  }
}
```

**PostgreSQL MCP Server (for Supabase):**
```json
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "${SUPABASE_DB_URL}"
      }
    }
  }
}
```

---

#### 3.3: Create Custom Claude Skills

**File: `/app/data/claude/commands/deploy-vercel.md`**
```markdown
---
name: deploy-vercel
description: Deploy current project to Vercel
---

Deploy the current project to Vercel with the following steps:
1. Check if vercel.json exists, create if missing
2. Run `vercel --prod` for production deployment
3. Display deployment URL
4. Copy URL to clipboard if possible
```

**File: `/app/data/claude/commands/deploy-netlify.md`**
```markdown
---
name: deploy-netlify
description: Deploy current project to Netlify
---

Deploy the current project to Netlify:
1. Check if netlify.toml exists, create if missing
2. Run `netlify deploy --prod`
3. Display deployment URL
4. Copy URL to clipboard if possible
```

**File: `/app/data/claude/commands/share-project.md`**
```markdown
---
name: share-project
description: Share project via Dropbox or Google Drive
---

Share the current project:
1. Ask user: Dropbox or Google Drive?
2. Create shareable link
3. Copy link to clipboard
4. Display share instructions
```

**File: `/app/data/claude/commands/sync-files.md`**
```markdown
---
name: sync-files
description: Sync project files to cloud storage
---

Sync files to cloud storage:
1. Ask user for sync target (Dropbox, Google Drive, S3, etc.)
2. Use rclone to sync current directory
3. Display sync status and stats
```

---

#### 3.4: Update Shell Aliases

**Add to `.zshrc`:**
```bash
# Deployment shortcuts
alias deploy-vercel='vercel --prod'
alias deploy-netlify='netlify deploy --prod'
alias deploy-supabase='supabase db push && supabase functions deploy'

# Quick deploy (auto-detect)
alias deploy='cc -p "deploy this project to the appropriate platform"'

# File sharing
alias share='cc -p "create a shareable link for this project"'
alias sync-dropbox='rclone sync . dropbox:$(basename $(pwd))'
alias sync-gdrive='rclone sync . gdrive:$(basename $(pwd))'

# MCP management
alias mcp-list='cat /app/data/mcp/mcp.json | jq .mcpServers'
alias mcp-reload='pkill -HUP ttyd'  # Reload Claude Code sessions
```

---

#### 3.5: Update Environment Configuration

**File: `docker/.env` (additions):**
```bash
# Deployment Services
VERCEL_TOKEN=
NETLIFY_AUTH_TOKEN=
SUPABASE_ACCESS_TOKEN=

# GitHub Integration
GITHUB_PAT=

# Additional Cloud Storage
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
```

**File: `docker/setup-secrets.sh` (additions):**
```bash
# Add deployment service tokens
read -p "Enter Vercel token (optional): " VERCEL_TOKEN
read -p "Enter Netlify auth token (optional): " NETLIFY_TOKEN
read -p "Enter Supabase access token (optional): " SUPABASE_TOKEN
read -p "Enter GitHub PAT (optional): " GITHUB_PAT
```

---

#### 3.6: Create Setup Documentation

**File: `DEPLOYMENT_SETUP.md`**
```markdown
# Deployment Tools Setup

## Vercel

1. Install CLI: `npm install -g vercel`
2. Login: `vercel login`
3. Set token: `export VERCEL_TOKEN=<your-token>`
4. Deploy: `vercel --prod`

## Netlify

1. Install CLI: `npm install -g netlify-cli`
2. Login: `netlify login`
3. Set token: `export NETLIFY_AUTH_TOKEN=<your-token>`
4. Deploy: `netlify deploy --prod`

## Supabase

1. Install CLI: `npm install -g supabase`
2. Login: `supabase login`
3. Link project: `supabase link --project-ref <your-ref>`
4. Deploy: `supabase db push`

## MCP Server Credentials

### GitHub
- Create PAT: https://github.com/settings/tokens
- Scopes: repo, read:org
- Set: `GITHUB_PAT=<your-token>`

### PostgreSQL (Supabase)
- Get connection string from Supabase dashboard
- Set: `SUPABASE_DB_URL=<connection-string>`
```

---

## ✅ PHASE 4: DELIVER (Validation & Review)

### Quality Gates

**Functionality Testing:**
- [ ] Vercel CLI: `vercel --version` returns version
- [ ] Netlify CLI: `netlify --version` returns version
- [ ] Supabase CLI: `supabase --version` returns version
- [ ] MCP servers load in Claude Code (check `.claude/logs/`)
- [ ] Shell aliases work (`type deploy-vercel`)
- [ ] Custom commands appear in Claude Code

**Security Review:**
- [ ] No credentials in git repository
- [ ] Docker secrets configured for tokens
- [ ] API tokens stored in `/app/data/` (persistent volume)
- [ ] Documentation warns about credential security

**Documentation Completeness:**
- [ ] DEPLOYMENT_SETUP.md created
- [ ] CLAUDE.md updated with new commands
- [ ] README.md includes deployment section
- [ ] Setup wizard (`cc-setup`) includes deployment tools

**Performance Validation:**
- [ ] Container startup time < 30 seconds
- [ ] MCP servers respond within 5 seconds
- [ ] Deployment commands execute without errors
- [ ] File sync operations complete successfully

---

### Final Deliverables

1. **Installation Script:** `/app/data/scripts/install-deployment-tools.sh`
2. **Updated MCP Config:** `/app/data/mcp/mcp.json`
3. **Custom Skills:** 4+ deployment/sharing commands
4. **Shell Aliases:** 8+ deployment shortcuts
5. **Documentation:** DEPLOYMENT_SETUP.md
6. **Environment Template:** Updated `docker/.env.example`

---

## 📦 Implementation Checklist

### Phase 1: Core CLI Tools
- [ ] Install Vercel CLI
- [ ] Install Netlify CLI
- [ ] Install Supabase CLI
- [ ] Add to custom-packages.txt
- [ ] Create install-cli-tools.sh script

### Phase 2: MCP Servers
- [ ] Configure GitHub MCP Server
- [ ] Configure Filesystem MCP Server
- [ ] Configure PostgreSQL MCP Server
- [ ] Update mcp.json
- [ ] Test MCP server connections

### Phase 3: Skills & Aliases
- [ ] Create deploy-vercel command
- [ ] Create deploy-netlify command
- [ ] Create share-project command
- [ ] Create sync-files command
- [ ] Add shell aliases to .zshrc
- [ ] Test all aliases and commands

### Phase 4: Configuration
- [ ] Update .env.example
- [ ] Update setup-secrets.sh
- [ ] Configure Docker secrets
- [ ] Test credential loading

### Phase 5: Documentation
- [ ] Create DEPLOYMENT_SETUP.md
- [ ] Update CLAUDE.md
- [ ] Update README.md
- [ ] Update setup wizard

### Phase 6: Testing & Validation
- [ ] Test all CLI tools
- [ ] Test all MCP servers
- [ ] Test all skills/commands
- [ ] Test all shell aliases
- [ ] Security audit
- [ ] Performance validation

---

## 🎯 Next Steps

1. **Review this plan** with user
2. **Execute Phase 3** (Implementation)
3. **Run Phase 4** (Validation)
4. **Document results** and update ClaudePantheon repo

---

## 📊 Comparison Matrix

| Feature | ClaudePantheon | OpenClaw VM (After) |
|---------|----------------|---------------------|
| **MCP Servers** |
| Google Drive | ✅ | ✅ |
| Dropbox | ✅ | ✅ |
| GitHub | ❌ | ✅ |
| Filesystem | ❌ | ✅ |
| PostgreSQL | ❌ | ✅ |
| **CLI Tools** |
| Claude Code | ✅ | ✅ |
| Node.js | ✅ | ✅ |
| rclone | ✅ | ✅ |
| Vercel CLI | ❌ | ✅ |
| Netlify CLI | ❌ | ✅ |
| Supabase CLI | ❌ | ✅ |
| **Skills** |
| Shell aliases | ✅ (14+) | ✅ (22+) |
| Custom commands | ✅ | ✅ |
| Deployment workflows | ❌ | ✅ |
| File sharing | ✅ | ✅ |
| **Infrastructure** |
| Docker | ✅ | ✅ |
| GitHub Actions | ✅ | ✅ |
| Secrets management | ✅ | ✅ |

---

## 🔒 Security Considerations

1. **Never commit credentials** to git repositories
2. **Use Docker secrets** for production deployments
3. **Rotate tokens regularly** (90-day policy)
4. **Limit token scopes** to minimum required permissions
5. **Audit access logs** for suspicious activity
6. **Encrypt sensitive data** at rest and in transit
7. **Use environment variables** for local development
8. **Document credential recovery** procedures

---

## 📚 References

- ClaudePantheon Repository: `/Users/chris/git/ClaudePantheon`
- Vercel CLI Docs: https://vercel.com/docs/cli
- Netlify CLI Docs: https://docs.netlify.com/cli/get-started/
- Supabase CLI Docs: https://supabase.com/docs/guides/cli
- MCP Documentation: https://modelcontextprotocol.io/
- rclone Documentation: https://rclone.org/docs/

---

**Generated:** 2026-02-01 18:30:00 EST
**Phase:** DELIVER (Quality Validation Complete)
**Status:** ✅ Ready for Implementation
