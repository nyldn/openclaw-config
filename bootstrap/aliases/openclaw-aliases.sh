#!/bin/sh
# OpenClaw VM - Core Aliases
# Add to ~/.zshrc or ~/.bashrc: source ~/openclaw-config/bootstrap/aliases/openclaw-aliases.sh

# ─────────────────────────────────────────────────────────────────────────────
# Core OpenClaw Commands
# ─────────────────────────────────────────────────────────────────────────────

# Setup and configuration
alias openclaw-setup='bash ~/openclaw-config/bootstrap/scripts/openclaw-setup.sh'
alias openclaw-auth='bash ~/openclaw-config/bootstrap/scripts/openclaw-auth.sh'
alias openclaw-validate='bash ~/openclaw-config/bootstrap/scripts/openclaw-validate.sh'

# Quick shortcuts
alias oc-setup='openclaw-setup'
alias oc-auth='openclaw-auth'
alias oc-validate='openclaw-validate'

# Configuration management
alias openclaw-config='cd ~/.openclaw && ls -la'
alias openclaw-env='${EDITOR:-nano} ~/openclaw-workspace/.env'
alias openclaw-workspace='cd ~/openclaw-workspace'

# ─────────────────────────────────────────────────────────────────────────────
# Bootstrap Management
# ─────────────────────────────────────────────────────────────────────────────

alias openclaw-update='cd ~/openclaw-config/bootstrap && ./bootstrap.sh --update'
alias openclaw-doctor='cd ~/openclaw-config/bootstrap && ./bootstrap.sh --doctor'
alias openclaw-modules='cd ~/openclaw-config/bootstrap && ./bootstrap.sh --list-modules'

# ─────────────────────────────────────────────────────────────────────────────
# Productivity Tools
# ─────────────────────────────────────────────────────────────────────────────

alias productivity-setup='cat ~/.openclaw/productivity/*.md 2>/dev/null || echo "Run openclaw-setup first"'
alias productivity-config='cd ~/.openclaw/productivity && ls -la'

# ─────────────────────────────────────────────────────────────────────────────
# LLM CLI Quick Access
# ─────────────────────────────────────────────────────────────────────────────

# Claude
alias claude-login='claude login'
alias claude-status='claude whoami 2>/dev/null && echo "Authenticated" || echo "Not authenticated"'

# Load environment for SDK access
alias openclaw-activate='source ~/.local/venv/openclaw/bin/activate'

# ─────────────────────────────────────────────────────────────────────────────
# MCP Server Management
# ─────────────────────────────────────────────────────────────────────────────

alias mcp-servers='ls -la ~/openclaw-workspace/mcp-servers/ 2>/dev/null || ls -la ~/openclaw-config/deployment-tools/mcp/implementations/'

# ─────────────────────────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────────────────────────

alias openclaw-help='cat << "HELP"
OpenClaw Quick Reference
========================

Setup & Configuration:
  openclaw-setup      Interactive credential wizard
  openclaw-auth       Authenticate CLI tools & OAuth
  openclaw-validate   Check all services are working

Shortcuts:
  openclaw-env        Edit .env file
  openclaw-config     Browse config directory
  openclaw-workspace  Go to workspace directory

Management:
  openclaw-update     Check for and install updates
  openclaw-doctor     Run diagnostics
  openclaw-modules    List available modules

LLM Access:
  claude-login        Authenticate Claude CLI
  claude-status       Check Claude auth status
  openclaw-activate   Activate Python venv

Help:
  openclaw-help       Show this help
HELP
'
