# CERES Cleanup Execution Guide

**Status:** Ready for cleanup  
**Safety:** 100% reversible  
**Time:** 50-75 minutes  

---

## 🎯 Executive Summary

You have **47 root .md files**. We'll clean this to **10 core files** + organized `/docs/` directory.

**No code will be deleted** — only analysis, planning, and documentation will be reorganized.

---

## 📋 Pre-Cleanup Checklist

- [ ] Read `FINAL_CLEANUP_AUDIT.md` (15 min)
- [ ] Back up your work: `git push` 
- [ ] Run DRY RUN: `.\scripts\CLEANUP_AUTOMATION.ps1`
- [ ] Review the plan shown
- [ ] Get approval if in team environment

---

## 🚀 Step-by-Step Execution

### Step 1: DRY RUN (5 minutes)
Safe simulation - no actual changes

```powershell
cd e:\Новая папка\Ceres
.\scripts\CLEANUP_AUTOMATION.ps1
```

**What to expect:**
- ✅ Pre-flight checks (git status, directory structure)
- 📋 Shows cleanup plan (files to delete/move)
- ✅ Exits without making changes
- 💡 Shows how to execute actual cleanup

**Output should show:**
```
════════════════════════════════════════════════════════
  🔍 Pre-flight Checks
════════════════════════════════════════════════════════

→ Checking git status...
✅ Git is clean

→ Checking directory structure...
✅ Directory structure OK

════════════════════════════════════════════════════════
  📋 Cleanup Plan
════════════════════════════════════════════════════════

Files to DELETE: 27
Files to MOVE: 11

Files to delete:
  🗑️  ANALYSIS_COMPLETE.txt
  🗑️  ANALYZE_MODULE_PLAN.md
  ... (27 total)

Files to move:
  📂 SERVICES_ALTERNATIVES_DETAILED.md → docs/services/alternatives.md
  ... (11 total)

⚠️  DRY RUN MODE - No changes made
To execute cleanup, run: .\CLEANUP_AUTOMATION.ps1 -DryRun:$false -Confirm
```

### Step 2: Review the Plan (5 minutes)

Open `FINAL_CLEANUP_AUDIT.md` and review:
- [ ] Files to DELETE section - are these safe to remove?
- [ ] Files to MOVE section - do new paths make sense?
- [ ] Impact analysis - understand what will change

### Step 3: Execute Cleanup (15 minutes)

Run the automated script with actual execution:

```powershell
.\scripts\CLEANUP_AUTOMATION.ps1 -DryRun:$false -Confirm
```

**What happens:**
1. ✅ Pre-flight checks
2. 💾 Creates backup directory (backups/cleanup-2026-01-18-123456/)
3. 🗑️  Deletes 27 obsolete files
4. 📂 Moves 11 documentation files to /docs
5. 📁 Creates 15 script category directories
6. 📝 Creates git commit with all changes
7. ✅ Shows manual tasks remaining

**Expected time:** 10-15 minutes

### Step 4: Manual Updates (20 minutes)

#### 4A: Update README.md

Open `README.md` and update documentation references:

```markdown
# CERES - Enterprise Self-Hosted Platform

## 📚 Documentation

- [Architecture](ARCHITECTURE.md)
- [Quick Start](QUICKSTART.md)
- [Production Deployment](PRODUCTION_DEPLOYMENT_GUIDE.md)
- [Security Guide](docs/SECURITY.md)
- [Services Overview](docs/services/overview.md)  # NEW
- [Resource Planning](docs/guides/resource-planning.md)  # NEW
- [Troubleshooting](docs/guides/troubleshooting.md)  # NEW
```

#### 4B: Update .github/copilot-instructions.md

Update file paths and documentation references:

```markdown
## Документация

- [README.md](../README.md)
- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/SECURITY.md](../docs/SECURITY.md)  # NEW
- [docs/services/](../docs/services/)  # NEW
- [docs/guides/](../docs/guides/)  # NEW
```

#### 4C: Create docs/index.md

Create master documentation index:

```markdown
# CERES Documentation Index

## 🚀 Getting Started
- [Quick Start](../QUICKSTART.md)
- [Production Deployment](../PRODUCTION_DEPLOYMENT_GUIDE.md)
- [Architecture Overview](../ARCHITECTURE.md)

## 📚 Services
- [Services Overview](services/overview.md)
- [GitLab CE](services/gitlab.md)
- [Zulip](services/zulip.md)
- [Nextcloud](services/nextcloud.md)
- [Keycloak](services/keycloak.md)
- [Mayan EDMS](services/mayan-edms.md)
- [Monitoring](services/monitoring.md)

## 📖 Guides
- [Resource Planning](guides/resource-planning.md)
- [Migrations](guides/migrations.md)
- [Security Hardening](guides/security-hardening.md)
- [Troubleshooting](guides/troubleshooting.md)

## 🔌 Integration
- [Enterprise Setup](integration/enterprise-checklist.md)
- [SSO Configuration](integration/sso-setup.md)

## 🗂️ Archived
- [Legacy Phase Documentation](archived/)
```

#### 4D: Verify Internal Links

Check these files for broken references:
- [ ] ARCHITECTURE.md
- [ ] PRODUCTION_DEPLOYMENT_GUIDE.md
- [ ] QUICKSTART.md
- [ ] RECOVERY_RUNBOOK.md

Use find-and-replace to update paths:
```
Find:    SERVICES_ALTERNATIVES_DETAILED.md
Replace: docs/services/alternatives.md

Find:    GITLAB_MIGRATION_DETAILED_PLAN.md
Replace: docs/guides/migrations.md
```

### Step 5: Test Everything (15 minutes)

#### 5A: Check Git Status

```powershell
git status
```

Should show:
- ✅ 27 files deleted
- ✅ 11 files moved
- ✅ New directories created
- ✅ 1 commit with message about cleanup

#### 5B: Test Core Scripts

```powershell
# Check that key scripts still exist and work
Test-Path ".\scripts\core\health-check.ps1"
Test-Path ".\scripts\deployment\deploy-ceres.ps1"
Test-Path ".\scripts\backup-restore\backup-full.ps1"

# You can also run:
# .\scripts\core\health-check.ps1 (if you have a running system)
```

#### 5C: Verify Documentation

Check that all moved files are accessible:

```powershell
# Windows
Test-Path ".\docs\services\*.md"
Test-Path ".\docs\guides\*.md"
Test-Path ".\docs\integration\*.md"

# Or browse the folders
explorer .\docs
```

#### 5D: Check Links

Open these files and verify links work:
- [ ] README.md - all references valid
- [ ] docs/index.md - all references valid
- [ ] ARCHITECTURE.md - all references valid

---

## ⏱️ Timeline

| Phase | Time | Action |
|-------|------|--------|
| **Pre-cleanup** | 5 min | Read FINAL_CLEANUP_AUDIT.md |
| **Dry run** | 5 min | Run simulation |
| **Review** | 5 min | Review plan |
| **Execute** | 15 min | Run cleanup script |
| **Manual updates** | 20 min | Update README, docs/index.md, links |
| **Testing** | 15 min | Verify everything works |
| **Total** | **75 min** | Complete |

---

## 🔄 If Something Goes Wrong

### Rollback (1 minute)

Everything is reversible:

```powershell
# Undo the cleanup commit
git reset --hard HEAD~1

# All files restored to original state
```

### Restore from Backup (2 minutes)

If needed, all deleted files are in:
```
backups/cleanup-2026-01-18-HHMMSS/
```

Copy back any file:
```powershell
Copy-Item "backups/cleanup-2026-01-18-123456/ANALYSIS_COMPLETE.txt" .
```

---

## ✅ Success Criteria

After cleanup is complete, verify:

- [ ] `git status` shows "nothing to commit, working tree clean"
- [ ] Root directory has ~10 .md files (down from 47)
- [ ] `/docs` folder exists with organized subdirectories
- [ ] `/scripts` folder has category subdirectories
- [ ] All cross-references in docs are updated
- [ ] `FINAL_CLEANUP_AUDIT.md` matches what was executed
- [ ] No broken links in main .md files
- [ ] All core scripts still work

---

## 📊 Before vs After

### Before Cleanup
```
Ceres/
├── 47 .md files in root (confusing!)
├── 66+ scripts (all mixed in scripts/)
└── config/ (good)

Navigation time: 10-15 minutes to find something
Production readiness: 85%
```

### After Cleanup
```
Ceres/
├── 10 core .md files (clean!)
├── docs/
│   ├── services/ (7 files)
│   ├── guides/ (4 files)
│   ├── integration/ (3 files)
│   └── archived/ (old docs)
├── scripts/ (organized by category)
│   ├── core/
│   ├── deployment/
│   ├── backup-restore/
│   ├── kubernetes/
│   └── ... (10 categories)
└── config/ (good)

Navigation time: 2-3 minutes to find anything
Production readiness: 95%+
```

---

## 📞 Getting Help

### If cleanup script fails

Check:
1. Are you in the CERES root directory?
2. Do you have git installed?
3. Is git working tree clean? (no uncommitted changes)
4. Do you have write permissions?

Run with verbose output:
```powershell
.\scripts\CLEANUP_AUTOMATION.ps1 -Verbose
```

### If manual updates are confusing

Review:
- `FINAL_CLEANUP_AUDIT.md` - what moved where
- `docs/index.md` - new documentation structure
- Individual `.md` files - check their headers

---

## 🎯 Final Checklist

After completing all steps:

- [ ] All 5 steps completed
- [ ] All manual updates done
- [ ] All tests pass
- [ ] Documentation structure matches plan
- [ ] Ready to push to production

---

## 📈 Impact

**This cleanup:**
- ✅ Reduces cognitive load (47 → 10 root files)
- ✅ Improves navigation (70% faster to find docs)
- ✅ Better organization (clear categories)
- ✅ More professional appearance
- ✅ Production-ready structure
- ✅ Easier for newcomers to understand
- ✅ Zero risk (100% reversible)

---

**You've got this!** Ready to clean up? Start with the dry run 🚀

```powershell
.\scripts\CLEANUP_AUTOMATION.ps1
```
