# Architecture

System architecture overview for openclaw-config.

## System Overview

```
┌─────────────────────────────────────────────────────────┐
│                    User Machine                          │
│                                                         │
│  ┌─────────────┐   ┌──────────────┐   ┌─────────────┐ │
│  │  Claude CLI  │   │  OpenAI CLI  │   │ Gemini CLI  │ │
│  └──────┬──────┘   └──────┬───────┘   └──────┬──────┘ │
│         │                  │                   │        │
│         └──────────┬───────┴───────────────────┘        │
│                    ▼                                     │
│  ┌─────────────────────────────────────────────────┐    │
│  │              OpenClaw Gateway                    │    │
│  │         (localhost:18789, loopback)              │    │
│  └────────┬──────────────┬──────────────┬──────────┘    │
│           │              │              │               │
│  ┌────────▼──┐  ┌───────▼────┐  ┌──────▼───────┐      │
│  │   Agents  │  │ MCP Servers │  │   Skills     │      │
│  │ (sandbox) │  │ (Calendar,  │  │ (ClawHub     │      │
│  │           │  │  Email,     │  │  registry)   │      │
│  │           │  │  Slack,     │  │              │      │
│  │           │  │  Todoist)   │  │              │      │
│  └───────────┘  └────────────┘  └──────────────┘      │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │              Workspace (~/.openclaw/)            │    │
│  │  workspace/  skills/  extensions/  openclaw.json │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐    │
│  │ Tailscale│  │ Security │  │   Auto-Updates    │    │
│  │  (VPN)   │  │(firewall,│  │ (systemd timer)   │    │
│  │          │  │ fail2ban)│  │                   │    │
│  └──────────┘  └──────────┘  └───────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Module Dependency Graph

```
system-deps (01)
├── python (02)
│   ├── codex-cli (05)
│   └── gemini-cli (06)
├── nodejs (03)
│   ├── claude-cli (04)
│   ├── openclaw (13)
│   │   ├── openclaw-skills (16)
│   │   └── openclaw-env (07)
│   ├── deployment-tools (10)
│   │   └── productivity-tools (15)
│   └── claude-octopus (09)
├── memory-init (08)
├── dev-tools (12)
├── auto-updates (11)
├── security (14)
├── tailscale (17)
└── ollama (18)
```

## Data Flow

```
┌──────────┐     ┌───────────┐     ┌──────────────┐
│  User    │────▶│  CLI /    │────▶│  AI Provider │
│  Input   │     │  Gateway  │     │  APIs        │
└──────────┘     └─────┬─────┘     └──────┬───────┘
                       │                   │
                       ▼                   ▼
              ┌────────────────┐  ┌────────────────┐
              │  MCP Servers   │  │  Response +    │
              │  (tools, data) │  │  Tool Calls    │
              └────────┬───────┘  └────────┬───────┘
                       │                   │
                       ▼                   ▼
              ┌────────────────────────────────────┐
              │         Workspace Storage          │
              │  memory.db │ logs │ context files  │
              └────────────────────────────────────┘
```

## Directory Structure

```
openclaw-config/
├── bootstrap/
│   ├── modules/          # 18 installation modules (01-18)
│   ├── scripts/          # Setup, update, validation scripts
│   ├── templates/        # .env, USER.md, BOOTSTRAP.md templates
│   ├── config/           # packages.yaml, skill-registry.yaml
│   ├── lib/              # Shared libraries (logger, crypto, etc.)
│   ├── systemd/          # Service and timer units
│   ├── tests/            # Test suite
│   ├── aliases/          # Shell alias definitions
│   ├── bootstrap.sh      # Main entry point
│   ├── install.sh        # Module installer
│   ├── verify.sh         # Post-install verification
│   └── manifest.yaml     # Module registry (v3.0.0)
├── deployment-tools/
│   ├── mcp/              # MCP server configs and implementations
│   └── scripts/          # Deployment helper scripts
├── infrastructure/
│   └── oci/              # OCI Terraform (ARM, Debian 12)
├── docs/                 # Guides, security, architecture
└── .github/
    └── workflows/        # CI (shellcheck, terraform lint)
```

## Security Model

```
┌─────────────────────────────────────────────┐
│              Security Layers                │
│                                             │
│  1. Network                                 │
│     ├── UFW firewall (deny incoming)        │
│     ├── SSH key-only auth (no passwords)    │
│     └── Tailscale VPN (optional)            │
│                                             │
│  2. Application                             │
│     ├── Gateway: loopback binding only      │
│     ├── Agents: sandbox mode (non-main)     │
│     ├── DM policy: pairing required         │
│     └── Skill registry: blocklist           │
│                                             │
│  3. Credentials                             │
│     ├── .env file (chmod 0600)              │
│     ├── .gitignore (secrets excluded)       │
│     ├── Pre-commit hook (secret scanning)   │
│     └── Optional encryption (crypto.sh)     │
│                                             │
│  4. Monitoring                              │
│     ├── fail2ban (SSH brute-force)          │
│     ├── AIDE (file integrity)               │
│     ├── Daily security reports              │
│     └── OCI alarms (CPU, memory)            │
└─────────────────────────────────────────────┘
```
