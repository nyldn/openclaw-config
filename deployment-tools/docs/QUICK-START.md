# 🚀 OpenClaw VM Setup - Quick Start Guide

## One-Line Installation

```bash
sh /path/to/install-deployment-tools.sh && source /path/to/deployment-aliases.sh
```

## 3-Step Setup

### Step 1: Install Tools (2 minutes)
```bash
# Copy installation script to your scripts directory
cp install-deployment-tools.sh /app/data/scripts/

# Run installation
sh /app/data/scripts/install-deployment-tools.sh
```

**Expected Output:**
```
✅ Installation complete! Versions:
   Vercel:   Vercel CLI 37.x.x
   Netlify:  netlify-cli/17.x.x
   Supabase: 1.x.x
```

### Step 2: Configure MCP Servers (1 minute)
```bash
# Backup existing config
cp /app/data/mcp/mcp.json /app/data/mcp/mcp.json.backup

# Install new config
cp mcp-servers-extended.json /app/data/mcp/mcp.json

# Reload Claude Code
pkill -HUP ttyd
```

### Step 3: Add Aliases (30 seconds)
```bash
# Add to shell config
cat deployment-aliases.sh >> ~/.zshrc

# Reload shell
source ~/.zshrc

# Verify
type deploy-vercel
```

## Authentication

### Vercel
```bash
vercel login
# Opens browser for authentication
```

### Netlify
```bash
netlify login
# Opens browser for authentication
```

### Supabase
```bash
supabase login
# Opens browser for authentication
```

### GitHub (for MCP)
```bash
# Create PAT at: https://github.com/settings/tokens
# Add to environment:
export GITHUB_PAT="ghp_xxxxxxxxxxxxxxxxxxxx"

# Make persistent:
echo 'export GITHUB_PAT="ghp_xxx"' >> ~/.zshrc
```

## Quick Test

```bash
# Test CLI tools
vercel --version
netlify --version
supabase --version

# Test aliases
mcp-list
deploy-vercel --help

# Test MCP servers (via Claude Code)
cc -p "list all MCP servers and test their connections"
```

## Common Commands

### Deployment
```bash
deploy-vercel              # Deploy to Vercel
deploy-netlify             # Deploy to Netlify
deploy-supabase            # Deploy database + functions
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
mcp-list                   # List configured servers
mcp-reload                 # Reload MCP configuration
mcp-logs                   # View MCP server logs
mcp-test                   # Test all connections
```

## Troubleshooting

### "command not found: vercel"
```bash
# Re-run installation
sh /app/data/scripts/install-deployment-tools.sh

# Verify npm path
which npm
```

### MCP servers not loading
```bash
# Check config syntax
cat /app/data/mcp/mcp.json | jq .

# View logs
mcp-logs

# Reload
mcp-reload
```

### Authentication issues
```bash
# Re-authenticate
vercel login --force
netlify login --force
supabase login
```

## What You Get

**Before:**
- 2 MCP servers
- 40 CLI tools
- 14 shell aliases
- 0 deployment platforms

**After:**
- 6 MCP servers (+4)
- 43 CLI tools (+3)
- 42 shell aliases (+28)
- 3 deployment platforms (+3)

## Support

- Full documentation: `openclaw-setup-plan.md`
- Workflow results: `EMBRACE-WORKFLOW-RESULTS.md`
- ClaudePantheon reference: `/Users/chris/git/ClaudePantheon`

**Setup Time:** ~5 minutes total
**Difficulty:** Easy
**Status:** ✅ Production Ready
