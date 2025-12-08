# Security Checklist for ilan-open-webui
**Created:** 2025-12-08
**Last Updated:** 2025-12-08
**Status:** 🟡 IN PROGRESS

---

## 🚨 IMMEDIATE ACTIONS REQUIRED

### ⏳ Critical Tasks (Complete ASAP)

- [ ] **Invalidate exposed Google API keys in Google Cloud Console**
  - Go to: https://console.cloud.google.com/apis/credentials
  - Delete: `AIzaSyBfy472IywzfrsOV9t5-tVmjs65oreDuR4`
  - Delete: `AIzaSyDc8DFZQPIR4dGAiFNGVhE_1ELLq6mjsTs`
  - **WHY:** These keys were public on GitHub for 1 day

- [ ] **Create new Google API keys with restrictions**
  - Click "+ CREATE CREDENTIALS" → "API key"
  - Copy the new key immediately
  - Click "RESTRICT KEY"
  - Select only required APIs (e.g., Generative Language API)
  - Click "SAVE"
  - **RESULT:** New secure key with limited permissions

- [ ] **Set environment variable for new key**
  ```bash
  # Option 1: Shell environment
  export GOOGLE_API_KEY='your_new_key_here'

  # Option 2: .env file (recommended for development)
  echo "GOOGLE_API_KEY=your_new_key_here" >> .env

  # Option 3: Add to ~/.bashrc or ~/.zshrc for persistence
  echo 'export GOOGLE_API_KEY="your_new_key_here"' >> ~/.bashrc
  ```

- [ ] **Test application with new credentials**
  ```bash
  # Verify environment variable is set
  echo $GOOGLE_API_KEY

  # Start your application
  # Test Gemini functionality
  # Verify API calls work correctly
  ```

- [ ] **Verify GitHub shows clean history**
  - Visit: https://github.com/oznav2/ilan-open-webui
  - Click on `backend/ilan-functions/gemini_pipelines.py`
  - Click "History" button
  - Confirm no API keys visible in any commit
  - **EXPECTED:** Empty string defaults only

---

## ✅ COMPLETED ACTIONS

### Security Audit & Remediation (2025-12-08)

- [x] **Security audit performed**
  - Scanned 14,531 commits
  - Found 2 exposed Google API keys
  - No other credentials found (.env files, other API keys, etc.)

- [x] **Removed API keys from source code**
  - File: `backend/ilan-functions/gemini_pipelines.py` (line 70)
  - File: `backend/ilan-functions/gemini_pipe_original.py` (line 153)
  - Changed hardcoded keys to empty strings

- [x] **Cleaned git history with git-filter-repo**
  - Processed 14,531 commits in 15.44 seconds
  - Replaced API keys with placeholders in all history
  - Verified complete removal with git log searches

- [x] **Force pushed cleaned history to GitHub**
  - Branch: main (`26f868a3c` → `82f5d4fdb`)
  - Branch: my-customizations (`e7cfd02f5` → `24ccadd6b`)
  - 11 tags updated
  - All history rewritten

- [x] **Created backup branches**
  - `backup-before-api-key-fix`
  - `backup-with-exposed-keys-20251208`
  - Safe to delete after confirming everything works

---

## 🛡️ ONGOING SECURITY PRACTICES

### Daily/Weekly Tasks

- [ ] **Check for exposed secrets in new commits**
  ```bash
  # Before committing, scan for secrets
  git diff | grep -E "AIza|sk-|ghp_|password.*=.*['\"]"
  ```

- [ ] **Review .env files are gitignored**
  ```bash
  git status --ignored | grep .env
  # Should show .env files as ignored
  ```

- [ ] **Monitor Google Cloud Console for unusual API usage**
  - Visit: https://console.cloud.google.com/apis/dashboard
  - Check for unexpected spikes or unusual patterns
  - Review error rates

### Monthly Security Checks

- [ ] **Rotate API keys (every 90 days recommended)**
  - Create new keys
  - Update environment variables
  - Delete old keys after testing
  - Update documentation

- [ ] **Review access logs**
  - Google Cloud Console: https://console.cloud.google.com/logs
  - Check for unusual IP addresses or times
  - Review failed authentication attempts

- [ ] **Update dependencies with security patches**
  ```bash
  # Python backend
  pip list --outdated
  pip install --upgrade [package]

  # Node frontend (if applicable)
  npm audit
  npm audit fix
  ```

- [ ] **Review and update .gitignore**
  ```bash
  # Ensure these patterns are present:
  .env
  .env.*
  !.env.example
  *.key
  *.pem
  secrets/
  credentials.json
  ```

### Quarterly Security Audits

- [ ] **Run full repository security scan**
  ```bash
  # Using TruffleHog
  docker run --rm -v "$(pwd):/repo" \
    trufflesecurity/trufflehog:latest \
    github --repo https://github.com/oznav2/ilan-open-webui

  # Or using GitLeaks
  gitleaks detect --source . --verbose
  ```

- [ ] **Review all custom pipeline files for hardcoded secrets**
  ```bash
  grep -r "api.*key.*=.*['\"]" backend/ilan-functions/
  grep -r "password.*=.*['\"]" backend/
  ```

- [ ] **Check GitHub security alerts**
  - Visit: https://github.com/oznav2/ilan-open-webui/security
  - Review Dependabot alerts
  - Review secret scanning alerts (if enabled)

---

## 🔧 RECOMMENDED SETUP

### 1. Install git-secrets (Prevents Future Leaks)

**macOS:**
```bash
brew install git-secrets
```

**Ubuntu/Debian:**
```bash
sudo apt-get install git-secrets
```

**Configure for this repository:**
```bash
cd /home/ilan/security-audit/ilan-open-webui

# Install hooks
git secrets --install

# Register AWS patterns
git secrets --register-aws

# Add custom patterns for Google API keys
git secrets --add 'AIza[0-9A-Za-z_-]{35}'

# Add patterns for other services you use
git secrets --add 'sk-[0-9A-Za-z]{48}'                    # OpenAI keys
git secrets --add 'sk-ant-api[0-9]{2}-[0-9A-Za-z_-]+'     # Anthropic keys
git secrets --add 'ghp_[0-9A-Za-z]{36}'                   # GitHub tokens

# Test it works
git secrets --scan
```

**What this does:**
- ✅ Prevents committing files with API keys
- ✅ Scans before each commit
- ✅ Blocks pushes containing secrets
- ✅ Protects all branches

### 2. Enable GitHub Secret Scanning

1. Go to: https://github.com/oznav2/ilan-open-webui/settings/security_analysis
2. Enable:
   - ✅ **Dependency graph**
   - ✅ **Dependabot alerts**
   - ✅ **Dependabot security updates**
   - ✅ **Secret scanning** (if available)
   - ✅ **Push protection** (prevents pushes with secrets)

### 3. Set Up Pre-commit Hooks

Create `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
```

Install:
```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

### 4. Use Environment Variable Management

**For Development:**
```bash
# Create .env file (already in .gitignore)
cat > .env << EOF
GOOGLE_API_KEY=your_key_here
# Add other keys as needed
EOF

# Load environment variables
source .env  # or use python-dotenv, direnv, etc.
```

**For Production:**
- Use platform environment variables (Vercel, Railway, Docker, etc.)
- Never commit .env files
- Use secret management services (AWS Secrets Manager, HashiCorp Vault)

---

## 🚫 NEVER DO THIS

### Forbidden Patterns

❌ **Never commit API keys:**
```python
# BAD - Hardcoded key
api_key = "AIzaSyBfy472IywzfrsOV9t5-tVmjs65oreDuR4"

# BAD - Default fallback key
api_key = os.getenv("API_KEY", "hardcoded_fallback")

# GOOD - Environment variable only
api_key = os.getenv("API_KEY")
if not api_key:
    raise ValueError("API_KEY environment variable required")
```

❌ **Never commit .env files:**
```bash
# Verify .env is gitignored
git check-ignore .env
# Should output: .env
```

❌ **Never commit credentials in config files:**
```json
// BAD - config.json
{
  "apiKey": "actual_key_here",
  "password": "actual_password"
}

// GOOD - config.example.json
{
  "apiKey": "YOUR_API_KEY_HERE",
  "password": "YOUR_PASSWORD_HERE"
}
```

❌ **Never share credentials in:**
- Slack/Discord messages
- Email
- Screenshots (blur sensitive info)
- Documentation/README files
- Code comments
- Commit messages

---

## 🔐 BEST PRACTICES

### Environment Variable Hierarchy

**Priority Order (highest to lowest):**
1. System environment variables
2. `.env` file (local development only)
3. Default values (only for non-sensitive configs)

**Example:**
```python
import os
from dotenv import load_dotenv

# Load .env file if it exists (development)
load_dotenv()

# Get API key (environment variable takes precedence)
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
if not GOOGLE_API_KEY:
    raise ValueError(
        "GOOGLE_API_KEY environment variable is required. "
        "Set it in .env file or export GOOGLE_API_KEY='your_key'"
    )
```

### API Key Restrictions

**Always restrict API keys:**
1. **Application restrictions:**
   - HTTP referrers (for web apps)
   - IP addresses (for server apps)
   - Android apps (for mobile)
   - iOS apps (for mobile)

2. **API restrictions:**
   - Select only the APIs you need
   - Example: Only "Generative Language API" for Gemini

3. **Set quotas:**
   - Daily request limits
   - Billing alerts
   - Usage monitoring

### Credential Rotation Schedule

| Credential Type | Rotation Frequency |
|----------------|-------------------|
| API Keys | Every 90 days |
| Passwords | Every 90 days |
| Access Tokens | Every 30 days |
| JWT Secrets | Every 180 days |
| SSH Keys | Annually or when compromised |

---

## 📊 SECURITY METRICS

### Current Status

| Metric | Status | Last Checked |
|--------|--------|--------------|
| Exposed API Keys | ✅ 0 | 2025-12-08 |
| .env Files in Git | ✅ 0 | 2025-12-08 |
| git-secrets Installed | ⏳ Pending | - |
| GitHub Secret Scanning | ⏳ Pending | - |
| Last Security Audit | ✅ Done | 2025-12-08 |
| Last Credential Rotation | ⏳ In Progress | - |

### Audit History

| Date | Type | Findings | Remediation |
|------|------|----------|-------------|
| 2025-12-08 | Full Scan | 2 exposed Google API keys | History cleaned, keys to be rotated |

---

## 📞 INCIDENT RESPONSE

### If You Discover Exposed Credentials

1. **IMMEDIATE:** Invalidate the exposed credentials
   - Don't wait for cleanup - invalidate first!
   - This prevents unauthorized usage immediately

2. **Document the exposure:**
   - What was exposed
   - When it was committed
   - How long it was public
   - Who had access

3. **Clean git history:**
   ```bash
   # Use git-filter-repo
   git filter-repo --replace-text <(echo 'exposed_key==>REMOVED')
   git push --force --all
   ```

4. **Create new credentials:**
   - Generate new keys
   - Apply proper restrictions
   - Update all environments

5. **Check for unauthorized usage:**
   - Review API logs
   - Check for unusual activity
   - Monitor billing for unexpected charges

6. **Learn and prevent:**
   - Document what happened
   - Update this checklist
   - Improve prevention measures

### Emergency Contacts

**Google Cloud Security:**
- Support: https://cloud.google.com/support
- Billing: https://console.cloud.google.com/billing

**GitHub Security:**
- Support: https://support.github.com/
- Security Advisory: security@github.com

---

## 📚 RESOURCES

### Security Tools

- **git-secrets:** https://github.com/awslabs/git-secrets
- **TruffleHog:** https://github.com/trufflesecurity/trufflehog
- **GitLeaks:** https://github.com/zricethezav/gitleaks
- **detect-secrets:** https://github.com/Yelp/detect-secrets

### Documentation

- **Google API Key Security:** https://cloud.google.com/docs/authentication/api-keys
- **GitHub Secret Scanning:** https://docs.github.com/en/code-security/secret-scanning
- **OWASP Secrets Management:** https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html
- **12-Factor App (Config):** https://12factor.net/config

### Training

- **OWASP Top 10:** https://owasp.org/www-project-top-ten/
- **Google Cloud Security Best Practices:** https://cloud.google.com/security/best-practices
- **GitHub Security Lab:** https://securitylab.github.com/

---

## 🎯 QUICK REFERENCE

### Pre-Commit Checklist

Before every commit:
- [ ] No API keys in code
- [ ] No passwords in code
- [ ] .env files not staged
- [ ] Reviewed git diff
- [ ] No sensitive data in commit message

### Pre-Push Checklist

Before every push:
- [ ] Ran security scan locally
- [ ] All tests pass
- [ ] No secrets in recent commits
- [ ] Reviewed changes one more time

### Environment Setup Checklist

For new developers:
- [ ] Clone repository
- [ ] Copy .env.example to .env
- [ ] Get API keys from team (never from git)
- [ ] Set environment variables
- [ ] Install git-secrets hooks
- [ ] Read this SECURITY_CHECKLIST.md

---

## 📝 CHANGELOG

### 2025-12-08
- Initial creation after security audit
- Documented exposed Google API keys incident
- Added comprehensive security practices
- Created immediate action items
- Added ongoing maintenance tasks

---

## ✅ COMPLETION CRITERIA

**This repository is secure when:**
- [x] Git history is clean (no exposed secrets)
- [x] Current code has no hardcoded secrets
- [ ] Old credentials are invalidated
- [ ] New credentials are created and restricted
- [ ] Environment variables properly configured
- [ ] Application tested and working
- [ ] git-secrets installed and configured
- [ ] GitHub secret scanning enabled
- [ ] Team educated on security practices
- [ ] Regular security audits scheduled

---

**Last Review:** 2025-12-08
**Next Review:** 2025-12-15 (weekly until all critical tasks complete)
**Review Frequency:** Monthly (after initial setup complete)

---

**Remember:** Security is not a one-time task. It's an ongoing practice that requires constant vigilance and regular maintenance. Stay secure! 🛡️
