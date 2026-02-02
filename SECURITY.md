# Security Policy

OpenClaw takes security seriously. This document outlines our security practices, vulnerability disclosure process, and guidelines for maintaining a secure installation.

---

## 🛡️ Security Enhancements in v2.0

OpenClaw v2.0 addresses **20+ security vulnerabilities** identified in the security audit:

### Critical Fixes (CVSS 9.0-10.0)

✅ **Eliminated curl | bash vulnerabilities**
- All `curl ... | bash` patterns removed
- Downloads verified with SHA256 checksums
- Scripts executed from temporary files only

✅ **Download verification system**
- SHA256 checksum validation
- GPG signature support
- Retry logic with exponential backoff

### High Priority Fixes (CVSS 7.0-8.9)

✅ **Secret sanitization in logs**
- 15+ secret patterns automatically redacted
- API keys, tokens, passwords masked
- Prevents accidental exposure in logs

✅ **Input validation**
- Module names (alphanumeric + hyphens/underscores only)
- URLs (HTTPS only, format validation)
- File paths (directory traversal prevention)
- Environment variables (protected variables blocked)

✅ **Credential encryption**
- AES-256-CBC encryption for sensitive files
- PBKDF2 key derivation
- Restrictive file permissions (0600/0700)

✅ **Pre-commit secret detection**
- Blocks commits containing secrets
- 10+ secret patterns detected
- Prevents accidental credential exposure

### Moderate Priority Fixes (CVSS 4.0-6.9)

✅ **Secure temporary file handling**
- Uses `mktemp -d` for unpredictable paths
- Proper cleanup with trap handlers
- Prevents race conditions

✅ **Fixed unquoted variables**
- Proper escaping in sed/grep commands
- Prevents code injection via regex

✅ **Package signature verification**
- npm and pip verify package signatures
- Repository GPG keys validated

---

## 🔐 Security Best Practices

### For Users

#### 1. Credential Management

**DO:**
- ✅ Use app-specific passwords (not your main password)
- ✅ Store credentials in environment variables
- ✅ Use `.env` files with restrictive permissions (0600)
- ✅ Enable 2FA on all services
- ✅ Rotate tokens every 90 days
- ✅ Use credential encryption:
  ```bash
  source bootstrap/lib/crypto.sh
  crypto_init
  encrypt_workspace ~/.openclaw/workspace
  ```

**DON'T:**
- ❌ Hardcode credentials in scripts
- ❌ Commit `.env` files to git
- ❌ Share API keys via chat/email
- ❌ Use the same password across services
- ❌ Store plaintext credentials in public locations

#### 2. Installation Security

**DO:**
- ✅ Clone repository and review code before running
- ✅ Verify git repository authenticity:
  ```bash
  git remote -v
  # Should show: github.com/nyldn/openclaw-config
  ```
- ✅ Check file permissions after installation
- ✅ Review logs for suspicious activity
- ✅ Use latest stable version

**DON'T:**
- ❌ Use `curl | bash` (no longer supported)
- ❌ Run as root user
- ❌ Install from untrusted forks
- ❌ Skip security modules
- ❌ Disable pre-commit hooks

#### 3. Network Security

**DO:**
- ✅ Use HTTPS/TLS for all connections
- ✅ Configure firewall (UFW):
  ```bash
  sudo ufw enable
  sudo ufw allow ssh
  sudo ufw allow 443/tcp  # HTTPS only
  ```
- ✅ Use VPN for sensitive operations
- ✅ Keep systems patched and updated

**DON'T:**
- ❌ Expose unnecessary ports
- ❌ Use HTTP (insecure)
- ❌ Disable firewall
- ❌ Trust public Wi-Fi without VPN

#### 4. File Permissions

```bash
# Correct permissions for sensitive files
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/*.env
chmod 600 ~/.openclaw/*.json
chmod 600 ~/.openclaw/productivity/*.env
chmod 700 ~/.openclaw/workspace
chmod 700 ~/.openclaw/logs
```

#### 5. Log Management

**DO:**
- ✅ Review logs regularly
- ✅ Verify secret sanitization working:
  ```bash
  grep -i "api.*key\|token\|password" logs/*.log
  # Should show: ***REDACTED***
  ```
- ✅ Set log rotation
- ✅ Restrict log access (0600)

**DON'T:**
- ❌ Share log files publicly
- ❌ Disable secret sanitization
- ❌ Store logs in world-readable locations

### For Contributors

#### 1. Code Security

- Never commit secrets (pre-commit hook will block)
- Validate all user input
- Use parameterized queries for databases
- Escape shell variables: `"${var}"`
- Use `set -euo pipefail` in bash scripts
- Run ShellCheck on all shell scripts

#### 2. Dependency Security

- Pin dependency versions
- Use `npm audit` and `pip audit`
- Update dependencies regularly
- Review dependency changes in PRs

#### 3. Testing

- Include security test cases
- Test input validation
- Test error handling
- Verify secret sanitization

---

## 🚨 Vulnerability Disclosure

### Reporting a Vulnerability

**We take security vulnerabilities seriously.** If you discover a security issue:

#### DO NOT:
- ❌ Open a public GitHub issue
- ❌ Disclose publicly before fix is available
- ❌ Exploit the vulnerability

#### DO:
1. **Email** security findings to: [your-security-email@example.com]
2. **Include:**
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)
3. **Use** this template:

```
Subject: [SECURITY] Brief description

Vulnerability Type: [e.g., Command Injection, XSS, etc.]
Severity: [Low/Medium/High/Critical]
Affected Component: [e.g., bootstrap/modules/XX-*.sh]
Affected Versions: [e.g., v1.0.0 - v2.0.0]

Description:
[Detailed description of the vulnerability]

Steps to Reproduce:
1. [Step 1]
2. [Step 2]
3. [Step 3]

Expected Behavior:
[What should happen]

Actual Behavior:
[What actually happens]

Impact:
[Potential security impact]

Proof of Concept:
[Optional: PoC code or exploit demonstration]

Suggested Fix:
[Optional: Your recommended solution]

Additional Context:
[Any other relevant information]
```

### Response Timeline

- **24 hours**: Initial acknowledgment
- **7 days**: Vulnerability assessment and severity rating
- **30 days**: Fix development and testing
- **60 days**: Public disclosure (coordinated)

### Severity Ratings

We use CVSS v3.1 for severity ratings:

| Severity | CVSS Score | Response Time | Examples |
|----------|-----------|---------------|----------|
| **Critical** | 9.0-10.0 | 48 hours | RCE, Authentication bypass |
| **High** | 7.0-8.9 | 7 days | SQL injection, XSS, Secret exposure |
| **Medium** | 4.0-6.9 | 30 days | CSRF, Open redirect, Info disclosure |
| **Low** | 0.1-3.9 | 90 days | Minor config issues, Low-impact bugs |

### Recognition

We appreciate responsible disclosure. Contributors may be:
- Listed in SECURITY_ACKNOWLEDGMENTS.md
- Mentioned in release notes
- Credited in CVE (if assigned)

---

## 📋 Security Audit Results (v2.0)

### Audit Summary

**Audit Date:** 2026-02-01
**Auditor:** Internal Security Review
**Scope:** Full codebase (bootstrap system, modules, MCP servers)

### Findings

| Severity | Count | Status |
|----------|-------|--------|
| Critical | 2 | ✅ Fixed |
| High | 5 | ✅ Fixed |
| Medium | 8 | ✅ Fixed |
| Low | 6 | ✅ Fixed |
| **Total** | **21** | **✅ All Fixed** |

### Critical Vulnerabilities (Fixed)

1. **CWE-78: OS Command Injection via curl|bash**
   - **Impact:** Remote code execution
   - **Fix:** Removed all `curl | bash` patterns
   - **Files:** `install.sh`, `modules/03-nodejs.sh`, `modules/04-claude-cli.sh`

2. **CWE-319: Cleartext Transmission of Sensitive Information**
   - **Impact:** Credential exposure in logs
   - **Fix:** Implemented secret sanitization
   - **Files:** `lib/logger.sh`

### High Vulnerabilities (Fixed)

3. **CWE-20: Improper Input Validation**
   - **Impact:** Injection attacks
   - **Fix:** Comprehensive validation functions
   - **Files:** `lib/validation.sh`, `bootstrap.sh`

4. **CWE-377: Insecure Temporary File**
   - **Impact:** Race conditions, unauthorized access
   - **Fix:** Use `mktemp` everywhere
   - **Files:** `install.sh`, all modules

5. **CWE-78: OS Command Injection via Unquoted Variables**
   - **Impact:** Command injection in sed/grep
   - **Fix:** Proper variable quoting and escaping
   - **Files:** `modules/14-security.sh`

6. **CWE-327: Use of Weak Cryptography**
   - **Impact:** Credential exposure at rest
   - **Fix:** AES-256-CBC encryption
   - **Files:** `lib/crypto.sh`

7. **CWE-200: Exposure of Sensitive Information**
   - **Impact:** Secret leakage via git
   - **Fix:** Pre-commit hook
   - **Files:** `.git/hooks/pre-commit`

### Recommendations Implemented

✅ Download verification with checksums
✅ HTTPS-only URL validation
✅ Restrictive file permissions
✅ Security-focused logging
✅ Input sanitization
✅ Credential encryption
✅ Pre-commit secret detection
✅ Comprehensive security documentation

---

## 🔍 Security Features by Component

### Bootstrap System

| Component | Security Features |
|-----------|-------------------|
| `bootstrap.sh` | Input validation, secure module loading |
| `install.sh` | Secure temp files, checksum verification |
| `lib/logger.sh` | Secret sanitization (15+ patterns), restrictive permissions |
| `lib/validation.sh` | URL/module/path validation, injection prevention |
| `lib/secure-download.sh` | SHA256/GPG verification, retry logic |
| `lib/crypto.sh` | AES-256-CBC encryption, key management |

### Modules

| Module | Security Considerations |
|--------|------------------------|
| `03-nodejs.sh` | Fixed curl\|bash, uses temp files |
| `04-claude-cli.sh` | Fixed curl\|bash, uses temp files |
| `14-security.sh` | SSH hardening, firewall config, fail2ban |
| `15-productivity-tools.sh` | Restrictive permissions, credential templates |

### MCP Servers

| Server | Authentication | Transport Security |
|--------|---------------|-------------------|
| Google Calendar | OAuth 2.0 | HTTPS only |
| Email | App passwords | TLS (IMAP 993, SMTP 587) |
| Todoist | API token | HTTPS only |
| Slack | Bot token | HTTPS only, Socket Mode |

---

## 📚 Security Resources

### Internal Documentation

- [INSTALLATION.md](INSTALLATION.md) - Secure installation procedures
- [MIGRATION.md](MIGRATION.md) - Security migration guide
- [PRODUCTIVITY_INTEGRATIONS.md](deployment-tools/docs/PRODUCTIVITY_INTEGRATIONS.md) - Credential setup security

### External References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE/SANS Top 25](https://cwe.mitre.org/top25/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [Center for Internet Security Benchmarks](https://www.cisecurity.org/cis-benchmarks/)

### Tools

- [ShellCheck](https://www.shellcheck.net/) - Shell script linting
- [Git-secrets](https://github.com/awslabs/git-secrets) - Prevent committing secrets
- [Trivy](https://github.com/aquasecurity/trivy) - Vulnerability scanner
- [OpenSSL](https://www.openssl.org/) - Cryptography toolkit

---

## 🔄 Security Update Process

### For Users

```bash
# Check for security updates
cd ~/openclaw-config
git fetch origin
git log HEAD..origin/main --oneline | grep -i security

# Apply security updates
git pull origin main
cd bootstrap
./bootstrap.sh --update

# Verify security fixes applied
./bootstrap.sh --doctor
```

### For Maintainers

1. Security vulnerability reported
2. Assess severity (CVSS score)
3. Develop and test fix
4. Create security advisory
5. Release patch version
6. Notify users via:
   - GitHub Security Advisory
   - Release notes
   - Email (for critical issues)

---

## ✅ Security Checklist

Use this checklist to verify your installation security:

### Installation

- [ ] Cloned repository (not curl|bash)
- [ ] Verified repository authenticity
- [ ] Reviewed code before running
- [ ] Using latest stable version

### Credentials

- [ ] All credentials in environment variables
- [ ] No secrets hardcoded in scripts
- [ ] 2FA enabled on all services
- [ ] App-specific passwords used
- [ ] Credentials encrypted at rest
- [ ] Token rotation schedule established

### System

- [ ] Running as non-root user
- [ ] Firewall configured (UFW)
- [ ] SSH hardened (if applicable)
- [ ] System packages updated
- [ ] Antivirus installed (if applicable)

### Files

- [ ] Correct permissions on sensitive files (0600/0700)
- [ ] Pre-commit hook installed and working
- [ ] `.env` files in `.gitignore`
- [ ] Logs sanitized (secrets redacted)
- [ ] Backups encrypted

### Network

- [ ] HTTPS-only for API calls
- [ ] TLS for email (IMAP 993, SMTP 587)
- [ ] VPN for sensitive operations
- [ ] No unnecessary ports exposed

### Monitoring

- [ ] Regular log review
- [ ] Update notifications enabled
- [ ] Security mailing list subscribed
- [ ] Automated backups configured

---

## 📞 Contact

**Security Issues:** [your-security-email@example.com]
**General Support:** https://github.com/nyldn/openclaw-config/issues
**Documentation:** https://github.com/nyldn/openclaw-config/wiki

---

**Last Updated:** 2026-02-01
**Version:** 2.0.0

---

*Security is a shared responsibility. Thank you for helping keep OpenClaw secure.*
