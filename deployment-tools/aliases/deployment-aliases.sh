#!/bin/sh
# OpenClaw VM - Deployment Aliases
# Add to ~/.zshrc or ~/.bashrc for quick deployment commands

# Deployment shortcuts
alias deploy-vercel='vercel --prod'
alias deploy-netlify='netlify deploy --prod'
alias deploy-supabase='supabase db push && supabase functions deploy'

# Quick deploy (auto-detect platform)
alias deploy='cc -p "deploy this project to the appropriate platform"'
alias deploy-preview='cc -p "create a preview deployment"'

# File sharing shortcuts
alias share='cc -p "create a shareable link for this project"'
alias share-dropbox='cc -p "upload this project to Dropbox and create a share link"'
alias share-gdrive='cc -p "upload this project to Google Drive and create a share link"'

# Cloud sync shortcuts
alias sync-dropbox='rclone sync . dropbox:$(basename $(pwd)) -P'
alias sync-gdrive='rclone sync . gdrive:$(basename $(pwd)) -P'
alias sync-s3='rclone sync . s3:$(basename $(pwd)) -P'

# MCP management
alias mcp-list='cat /app/data/mcp/mcp.json | jq .mcpServers'
alias mcp-reload='pkill -HUP ttyd'
alias mcp-logs='tail -f ~/.claude/logs/*.log'
alias mcp-test='cc -p "test all MCP server connections"'

# Project management
alias project-init='cc -p "initialize a new project with best practices"'
alias project-deploy='cc -p "deploy this project (auto-detect platform)"'
alias project-share='cc -p "share this project via cloud storage"'

# Vercel-specific
alias vercel-login='vercel login'
alias vercel-ls='vercel ls'
alias vercel-logs='vercel logs'
alias vercel-env='vercel env ls'

# Netlify-specific
alias netlify-login='netlify login'
alias netlify-ls='netlify sites:list'
alias netlify-logs='netlify logs'
alias netlify-env='netlify env:list'

# Supabase-specific
alias supabase-login='supabase login'
alias supabase-ls='supabase projects list'
alias supabase-status='supabase status'
alias supabase-db='supabase db remote commit'

echo "✅ Deployment aliases loaded!"
echo "   Try: deploy-vercel, deploy-netlify, share, sync-dropbox"
