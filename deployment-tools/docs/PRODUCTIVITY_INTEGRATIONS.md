# OpenClaw Productivity Integrations

Complete guide for setting up and using personal productivity MCP servers with OpenClaw.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Google Calendar Setup](#google-calendar-setup)
- [Email Setup](#email-setup)
- [Todoist Setup](#todoist-setup)
- [Slack Setup](#slack-setup)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)
- [FAQ](#faq)

---

## Overview

OpenClaw provides four productivity MCP (Model Context Protocol) servers:

| Server | Purpose | Tools Available |
|--------|---------|----------------|
| **Google Calendar** | Manage calendar events | Create, list, update, delete events; search; check availability |
| **Email** | Read and send emails | List, read, send, reply, search emails; manage folders |
| **Todoist** | Task management | Create, list, update, complete tasks; manage projects |
| **Slack** | Team messaging | Send messages, read channels, search, upload files |

These integrations allow Claude to interact with your productivity tools directly, enabling powerful workflows like:
- Scheduling meetings based on email threads
- Creating tasks from meeting notes
- Sending Slack updates after completing tasks
- Finding free time slots across your calendar

---

## Prerequisites

- OpenClaw bootstrap system installed
- Node.js 20+ (`nodejs` module)
- Deployment tools module installed (`deployment-tools`)
- Internet connection for OAuth flows and API access

---

## Installation

### Via Bootstrap

If installing OpenClaw for the first time:

```bash
cd openclaw-config/bootstrap
./bootstrap.sh
```

Select the **"productivity-tools"** module in the interactive menu.

### Standalone Installation

If OpenClaw is already installed:

```bash
cd openclaw-config/bootstrap/modules
./15-productivity-tools.sh install
```

### Verify Installation

```bash
cd openclaw-config/bootstrap/modules
./15-productivity-tools.sh validate
```

---

## Google Calendar Setup

### Step 1: Enable Google Calendar API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to **APIs & Services** → **Library**
4. Search for "Google Calendar API"
5. Click **Enable**

### Step 2: Create OAuth Credentials

1. Go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth client ID**
3. If prompted, configure the OAuth consent screen:
   - User Type: **External** (for personal use)
   - App name: "OpenClaw Productivity"
   - User support email: Your email
   - Add your email to test users
4. Application type: **Desktop app**
5. Name: "OpenClaw Calendar Client"
6. Click **Create**

### Step 3: Download Credentials

1. Click the download icon (⬇) next to your OAuth client
2. Save the JSON file as:
   ```
   ~/.openclaw/google-calendar-credentials.json
   ```

### Step 4: Authenticate

Run the authentication flow:

```bash
node ~/.openclaw/workspace/mcp-servers/google-calendar-mcp.js
```

This will:
1. Print a URL - open it in your browser
2. Sign in with your Google account
3. Grant permissions to the app
4. Copy the authorization code
5. Paste it back in the terminal

The token will be saved to `~/.openclaw/google-calendar-token.json`

### Step 5: Test

The calendar MCP server is now ready. Test it with Claude Code CLI:

```bash
claude mcp list
# Should show "google-calendar" in the list
```

---

## Email Setup

### Option 1: Gmail with App Password (Recommended)

#### Enable 2-Factor Authentication

1. Go to [Google Account Security](https://myaccount.google.com/security)
2. Enable **2-Step Verification** if not already enabled

#### Generate App Password

1. Go to [App Passwords](https://myaccount.google.com/apppasswords)
2. Select **Mail** as the app
3. Select **Other** as the device
4. Name it: "OpenClaw Email"
5. Click **Generate**
6. Copy the 16-character password (spaces don't matter)

#### Configure Credentials

Create or edit `~/.openclaw/productivity/email-credentials.env`:

```bash
EMAIL_IMAP_HOST=imap.gmail.com
EMAIL_IMAP_PORT=993
EMAIL_SMTP_HOST=smtp.gmail.com
EMAIL_SMTP_PORT=587
EMAIL_USERNAME=your-email@gmail.com
EMAIL_PASSWORD=xxxx-xxxx-xxxx-xxxx  # 16-char app password
```

### Option 2: Outlook/Office 365

```bash
EMAIL_IMAP_HOST=outlook.office365.com
EMAIL_IMAP_PORT=993
EMAIL_SMTP_HOST=smtp.office365.com
EMAIL_SMTP_PORT=587
EMAIL_USERNAME=your-email@outlook.com
EMAIL_PASSWORD=your-app-password
```

For Outlook, generate an app password at [Microsoft Account Security](https://account.microsoft.com/security).

### Option 3: Other Email Providers

| Provider | IMAP Host | SMTP Host |
|----------|-----------|-----------|
| Yahoo | imap.mail.yahoo.com:993 | smtp.mail.yahoo.com:587 |
| iCloud | imap.mail.me.com:993 | smtp.mail.me.com:587 |
| Fastmail | imap.fastmail.com:993 | smtp.fastmail.com:587 |
| ProtonMail | 127.0.0.1:1143 (Bridge) | 127.0.0.1:1025 (Bridge) |

### Load Credentials

Add to `~/.bashrc` or `~/.zshrc`:

```bash
source ~/.openclaw/productivity/email-credentials.env
```

Then reload:

```bash
source ~/.bashrc
```

### Test Email Connection

```bash
# Test with Claude Code CLI
# Ask Claude: "List my recent emails"
```

---

## Todoist Setup

### Step 1: Get API Token

1. Go to [Todoist Integrations](https://todoist.com/prefs/integrations)
2. Scroll down to **API token**
3. Copy the token (long alphanumeric string)

### Step 2: Set Environment Variable

Add to `~/.bashrc` or `~/.zshrc`:

```bash
export TODOIST_API_TOKEN=your-token-here
```

Reload your shell:

```bash
source ~/.bashrc
```

### Step 3: Test

```bash
# Verify it's set
echo $TODOIST_API_TOKEN

# Test with Claude
# Ask: "List my Todoist tasks"
```

---

## Slack Setup

### Step 1: Create Slack App

1. Go to [Slack API Apps](https://api.slack.com/apps)
2. Click **Create New App**
3. Choose **From scratch**
4. App Name: "OpenClaw Productivity"
5. Pick your workspace
6. Click **Create App**

### Step 2: Configure Bot Token Scopes

1. Go to **OAuth & Permissions** in the left sidebar
2. Scroll to **Scopes** → **Bot Token Scopes**
3. Add these scopes:

   **Channel Permissions:**
   - `channels:history` - View messages in public channels
   - `channels:read` - View basic channel info
   - `channels:write` - Manage public channels

   **Messaging:**
   - `chat:write` - Send messages
   - `files:write` - Upload files

   **Group/Private Channels:**
   - `groups:history` - View messages in private channels
   - `groups:read` - View basic private channel info
   - `groups:write` - Manage private channels

   **Direct Messages:**
   - `im:history` - View direct messages
   - `im:read` - View basic DM info
   - `im:write` - Send direct messages

   **Multi-person DMs:**
   - `mpim:history` - View multi-person DM messages
   - `mpim:read` - View basic multi-person DM info
   - `mpim:write` - Send multi-person DMs

   **Other:**
   - `reactions:write` - Add emoji reactions
   - `search:read` - Search workspace
   - `users:read` - View user info

### Step 3: Install App to Workspace

1. Scroll to top of **OAuth & Permissions**
2. Click **Install to Workspace**
3. Click **Allow**
4. Copy the **Bot User OAuth Token** (starts with `xoxb-`)

### Step 4: Set Environment Variables

Add to `~/.bashrc` or `~/.zshrc`:

```bash
export SLACK_BOT_TOKEN=xoxb-your-bot-token-here
export SLACK_APP_TOKEN=xapp-your-app-token-here  # Optional
```

Reload:

```bash
source ~/.bashrc
```

### Step 5: Invite Bot to Channels

In Slack:
1. Go to any channel you want the bot to access
2. Type: `/invite @OpenClaw Productivity`
3. The bot can now read/write in that channel

### Step 6: Test

```bash
# Test with Claude
# Ask: "List my Slack channels"
```

---

## Usage Examples

### Google Calendar

**Create an event:**
```
Create a calendar event titled "Team Sync" tomorrow at 2pm for 1 hour
```

**List upcoming events:**
```
What's on my calendar for the next 3 days?
```

**Check availability:**
```
Am I free next Tuesday between 10am and 4pm?
```

**Search calendar:**
```
Find all calendar events with "dentist" in the title
```

### Email

**Read recent emails:**
```
Show me my 5 most recent emails
```

**Read specific email:**
```
Read email UID 1234 from my inbox
```

**Send email:**
```
Send an email to john@example.com with subject "Project Update"
and message "The project is on track for next week's deadline."
```

**Search emails:**
```
Search my emails for messages from sarah@company.com about the Q4 report
```

**Reply to email:**
```
Reply to email UID 5678 saying "Thanks for the update!"
```

### Todoist

**Create task:**
```
Create a Todoist task "Review pull request #42" due tomorrow with priority 3
```

**List tasks:**
```
Show me all my tasks due today
```

**Complete task:**
```
Mark Todoist task 123456789 as complete
```

**Create project:**
```
Create a new Todoist project called "Blog Posts"
```

### Slack

**Send message:**
```
Send a message to #general on Slack: "Deployment complete! ✅"
```

**Read messages:**
```
Show me the last 10 messages from #engineering
```

**Search workspace:**
```
Search Slack for messages about "database migration"
```

**Upload file:**
```
Upload file /path/to/report.pdf to #leadership channel with comment "Q4 Report"
```

---

## Troubleshooting

### Google Calendar Issues

**"No token found" error:**
- Run the authentication flow: `node ~/.openclaw/workspace/mcp-servers/google-calendar-mcp.js`
- Make sure you complete the OAuth flow in your browser

**"Invalid credentials" error:**
- Re-download credentials from Google Cloud Console
- Ensure file is at: `~/.openclaw/google-calendar-credentials.json`

**"Permission denied" errors:**
- Check that Calendar API is enabled in Google Cloud Console
- Verify OAuth consent screen configuration
- Add your email to test users if using External user type

### Email Issues

**"Login failed" error:**
- Verify you're using an app password (not your regular password)
- Check username is your full email address
- Ensure 2FA is enabled (required for app passwords)

**"Connection refused" error:**
- Verify IMAP/SMTP host and port settings
- Check firewall isn't blocking ports 993/587
- Some providers require "Less secure app access" enabled

**"Can't read emails" error:**
- Ensure IMAP is enabled in your email provider settings
- Gmail: Settings → Forwarding and POP/IMAP → Enable IMAP

### Todoist Issues

**"Authentication failed" error:**
- Verify `TODOIST_API_TOKEN` environment variable is set
- Get a fresh token from https://todoist.com/prefs/integrations
- Check for typos in the token

**"Task not found" error:**
- Task IDs are long numbers - ensure you're using the full ID
- Task may have been deleted or moved to a different project

### Slack Issues

**"Token invalid" error:**
- Regenerate bot token in Slack app settings
- Make sure you're using the Bot User OAuth Token (xoxb-), not User OAuth Token

**"Channel not found" error:**
- Invite bot to channel: `/invite @YourBotName`
- Use channel ID instead of name for private channels
- List channels first to get correct IDs

**"Missing scope" error:**
- Add required scope in OAuth & Permissions
- Reinstall app to workspace after adding scopes

---

## Security Best Practices

### Credential Storage

1. **Never commit credentials to git:**
   - All `.env` files are gitignored
   - Use templates for sharing configuration

2. **Use restrictive file permissions:**
   ```bash
   chmod 600 ~/.openclaw/productivity/*.env
   chmod 600 ~/.openclaw/google-calendar-*.json
   ```

3. **Use app-specific passwords:**
   - Never use your main email password
   - Generate unique passwords for each application

### Token Management

1. **Rotate tokens regularly:**
   - Email app passwords: Every 90 days
   - Slack bot tokens: Every 180 days
   - Todoist API token: Annually

2. **Revoke unused tokens:**
   - Google Calendar: Console → Credentials
   - Gmail: Security → Third-party apps
   - Slack: App Settings → OAuth & Permissions

3. **Monitor access:**
   - Check Google Account activity
   - Review Slack app permissions monthly

### Network Security

1. **Use HTTPS/TLS only:**
   - All MCP servers enforce encrypted connections
   - IMAP port 993 (TLS), SMTP port 587 (STARTTLS)

2. **Firewall configuration:**
   ```bash
   # Allow only necessary ports
   sudo ufw allow 993/tcp comment 'IMAP'
   sudo ufw allow 587/tcp comment 'SMTP'
   ```

### Data Privacy

1. **Limit scope of access:**
   - Only grant minimum required permissions
   - Review OAuth scopes before accepting

2. **Audit logs:**
   - Check MCP server logs: `~/.openclaw/logs/`
   - Monitor for unauthorized access attempts

3. **Encrypt sensitive data:**
   - Use OpenClaw credential encryption:
     ```bash
     source bootstrap/lib/crypto.sh
     encrypt_workspace ~/.openclaw/productivity
     ```

---

## FAQ

### Can I use multiple Google accounts?

Yes! Create separate credential files:
- `~/.openclaw/google-calendar-work-credentials.json`
- `~/.openclaw/google-calendar-personal-credentials.json`

Update `GOOGLE_APPLICATION_CREDENTIALS` environment variable to switch.

### Does this work with GSuite/Workspace accounts?

Yes! The setup process is the same. Your workspace admin may need to approve the OAuth app.

### Can I use this with self-hosted email servers?

Yes! Just update the IMAP/SMTP host settings to point to your server.

### How much do these integrations cost?

- Google Calendar API: Free (up to 1M requests/day)
- Gmail API: Free (included with Google account)
- Todoist: Requires Todoist account (free or premium)
- Slack: Requires Slack workspace (free or paid)

No additional API costs for normal usage.

### Can I disable specific integrations?

Yes! Comment out the server in your MCP configuration file:
```json
// "google-calendar": { ... }  // Disabled
```

### Are my credentials secure?

Yes, if you follow best practices:
- Credentials stored locally only
- Never transmitted except to official APIs
- File permissions restricted to your user
- Optional encryption at rest

### Can I contribute new integrations?

Absolutely! See [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines on adding new MCP servers.

---

## Additional Resources

- [Google Calendar API Documentation](https://developers.google.com/calendar/api)
- [Gmail API Documentation](https://developers.google.com/gmail/api)
- [Todoist API Documentation](https://developer.todoist.com/)
- [Slack API Documentation](https://api.slack.com/)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)

---

**Need help?** Open an issue at: https://github.com/nyldn/openclaw-config/issues
