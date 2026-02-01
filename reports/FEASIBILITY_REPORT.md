# Technical Feasibility & Prerequisites: OpenClaw VM Enhancements

**Date:** 2026-02-01
**Target:** OpenClaw VM (`openclawd-config`)
**Reference:** ClaudePantheon (`/Users/chris/git/ClaudePantheon`)

## 1. Overview
This report analyzes the feasibility of integrating cloud storage, deployment CLIs, and MCP servers into the OpenClaw VM environment, mirroring and expanding upon the capabilities of the ClaudePantheon project.

**Conclusion:** The integration is **Highly Feasible**. The OpenClaw VM's current architecture (Debian/Ubuntu-based with Node.js and Python) supports all requested tools natively.

## 2. Reference Architecture (ClaudePantheon)
The reference project uses a Dockerized Alpine Linux environment with the following key components:
- **Base:** Node.js 22 on Alpine.
- **AI Tools:** Claude Code CLI, OpenAI Codex CLI, Google Gemini CLI.
- **Cloud Storage:** `rclone` (for file mounting) and custom MCP servers (for AI context) for Dropbox and Google Drive.
- **Web:** Nginx + PHP for a landing page and `ttyd` for web terminal access.

## 3. Requested Integrations & Prerequisites

### A. Cloud Storage & File Sharing
**Goal:** Easy file sharing and access (Dropbox, Google Drive).

| Tool | Approach | Prerequisites | Recommended Implementation |
|------|----------|---------------|----------------------------|
| **Dropbox** | `rclone` (Mounting) | Access Token | Install `rclone` via `apt`. Configure via `rclone config` (requires interactive auth or copying config). |
| | **MCP Server** | Node.js, Dropbox App Key | Port `dropbox-mcp.js` from ClaudePantheon. |
| **Google Drive** | `rclone` (Mounting) | OAuth Client ID/Secret | Same as Dropbox. |
| | **MCP Server** | Node.js, Google Cloud Project | Port `google-drive-mcp.js` from ClaudePantheon. |

**Strategy:** 
1. Install `rclone` for OS-level file access.
2. Setup an `mcp-servers/` directory for AI-level file access (porting scripts from ClaudePantheon).

### B. Deployment & Development Services
**Goal:** Manage deployments (Netlify, Vercel, Supabase).

| Service | CLI Tool | Prerequisites | Installation |
|---------|----------|---------------|--------------|
| **Netlify** | `netlify-cli` | Node.js 20+ | `npm install -g netlify-cli` |
| **Vercel** | `vercel` | Node.js 18+ | `npm install -g vercel` |
| **Supabase** | `supabase` | Node.js or Homebrew | `npm install -g supabase` (Universal) |

**Strategy:**
Add these packages to `bootstrap/config/packages.yaml` under the `node: global` section.

### C. Model Context Protocol (MCP) & Skills
**Goal:** Enhance AI capabilities.

- **MCP Servers:** Requires a dedicated directory (e.g., `/opt/openclaw/mcp`) and a configuration file (e.g., `mcp_config.json`) that the AI agent can read to spawn these servers.
- **Claude Skills:** These are typically Markdown files defining procedures. 
    - *Reference:* ClaudePantheon uses `CLAUDE.md`. 
    - *Action:* Create a `skills/` directory in the workspace root or user home.

## 4. Implementation Plan

### Step 1: Update Package Manifest
Modify `bootstrap/config/packages.yaml` to include:
```yaml
packages:
  system:
    apt:
      - rclone
      - fuse3  # Required for rclone mount
      # ... existing packages

  node:
    global:
      - netlify-cli
      - vercel
      - supabase
      # ... existing packages
```

### Step 2: Port MCP Servers
Copy the `docker/mcp-servers` directory from ClaudePantheon to `openclawd-config/modules/mcp-servers`.
- **Dependencies:** Ensure `package.json` in that folder is installed during provisioning.

### Step 3: Auth Configuration
These tools require authentication. The VM should provide a helper script (similar to `ClaudePantheon/docker/scripts/cli-installer.sh`) to:
1.  Authenticate `vercel login`, `netlify login`, `supabase login`.
2.  Configure `rclone config`.

## 5. Dependencies Summary
- **Node.js 20+:** Already present in OpenClaw config.
- **Python 3.9+:** Already present.
- **System Utils:** `fuse3` (for rclone mounts) needs to be added.
- **Auth Tokens:** User must provide these interactively or via environment variables/secrets.
