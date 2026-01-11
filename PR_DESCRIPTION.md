# 🔐 Security: Remove All Hardcoded Secrets

## Summary
This PR removes all hardcoded passwords, credentials, and sensitive IP addresses from the codebase, replacing them with environment variables for secure configuration management.

## Changes

### 🔒 Security Improvements
- ✅ Removed all hardcoded passwords (`!r0oT3dc`, etc.)
- ✅ Removed all hardcoded IPs (`192.168.1.3`, `192.168.1.10`, etc.)
- ✅ Replaced with environment variables (`$env:DEPLOY_SERVER_PASSWORD`, etc.)
- ✅ Created `.env.example` template for secure configuration
- ✅ Added comprehensive security guide ([SECURITY_SETUP.md](../SECURITY_SETUP.md))
- ✅ Created `Load-Env.ps1` helper for environment loading
- ✅ Deleted temporary scripts with exposed credentials

### 📝 Files Modified
- `DEPLOY.ps1` - Environment variables instead of hardcoded values
- `auto-deploy.ps1` - Environment variables for SSH credentials
- `flux-status.ps1` - Environment variables for server access
- `check-status.ps1` - Environment variables for authentication
- `README.md` - Added security notice at the top

### 🗑️ Files Removed
- `setup-ssh.ps1` - Had hardcoded password
- `setup-ssh-key.sh` - Had hardcoded password
- `status.bat` - Had hardcoded password
- `deploy-flux.ps1` - Temporary file with secrets
- `deploy-flux-releases.ps1` - Temporary file with secrets
- `quick-deploy.ps1` - Temporary file with secrets
- And several other temporary test scripts

### 📁 New Files
- `.env.example` - Template for secure configuration
- `SECURITY_SETUP.md` - Complete security setup guide
- `scripts/_lib/Load-Env.ps1` - Helper to load environment variables

### 📦 Archived Files
- Moved legacy docs to `archive/docs/`
- Moved legacy K8s manifests to `archive/legacy-k8s/`
- Moved deprecated scripts to `archive/scripts/`

## Breaking Changes

⚠️ **Users must now create `.env` file before running scripts:**

```powershell
# 1. Copy template
Copy-Item .env.example .env

# 2. Edit with your values
notepad .env

# 3. Load environment
. .\scripts\_lib\Load-Env.ps1

# 4. Run deployment
.\DEPLOY.ps1
```

## Migration Guide

### For Existing Users

If you have existing deployments with hardcoded values:

1. **Create `.env` file:**
   ```powershell
   Copy-Item .env.example .env
   ```

2. **Fill in your actual values:**
   ```env
   DEPLOY_SERVER_IP=192.168.1.3
   DEPLOY_SERVER_USER=root
   DEPLOY_SERVER_PASSWORD=YourActualPassword
   K3S_CORE_IP=192.168.1.10
   # ... etc
   ```

3. **Update scripts to load environment:**
   ```powershell
   # At the start of your session
   . .\scripts\_lib\Load-Env.ps1
   
   # Then run your scripts normally
   .\DEPLOY.ps1
   ```

### For New Users

Follow the complete guide in [SECURITY_SETUP.md](../SECURITY_SETUP.md)

## Testing

✅ Tested locally:
- Environment variables load correctly via `Load-Env.ps1`
- Scripts fail gracefully if `.env` not found
- Deployment works with environment-sourced credentials
- No secrets exposed in git history (new branch)

## Security Benefits

- 🔒 **No credentials in git history** - Fresh branch without exposure
- 🔐 **Secrets in .env only** - Already in `.gitignore`
- 📖 **Clear documentation** - Security best practices guide
- ✅ **Easy rotation** - Change `.env` file, no code changes needed
- 🚫 **Fail-safe** - Scripts check for required variables

## Checklist

- [x] All hardcoded passwords removed
- [x] All hardcoded IPs removed
- [x] `.env.example` created with all variables
- [x] Security documentation written
- [x] Helper script for loading env vars
- [x] README updated with security notice
- [x] Temporary files cleaned up
- [x] Legacy files archived
- [x] `.gitignore` verified
- [x] Local testing completed

## Post-Merge TODO

After merging, users should:
1. Read [SECURITY_SETUP.md](../SECURITY_SETUP.md)
2. Create their `.env` file
3. Test deployment in safe environment
4. Update any CI/CD secrets

## Related Issues

This PR addresses security concerns about exposed credentials in the public repository.

---

**Review Priority:** HIGH - Security-critical changes

cc @skulesh01
