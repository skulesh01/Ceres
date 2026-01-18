# Resource Planning System - Quick Reference

## System Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                   USER RUNS CONFIGURE-CERES.PS1                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────┐
        │ [STEP 1] Analyze System          │
        │ ├─ Get CPU cores                 │
        │ ├─ Get RAM (GB)                  │
        │ └─ Get free disk (GB)            │
        └──────────────────┬───────────────┘
                           │
                           ▼
        ┌──────────────────────────────────┐
        │ [STEP 2] Load Profiles           │
        │ ├─ small.json                    │
        │ ├─ medium.json                   │
        │ └─ large.json                    │
        └──────────────────┬───────────────┘
                           │
                           ▼
        ┌──────────────────────────────────┐
        │ [STEP 3] Get Recommendations     │
        │ ├─ Call Get-ProfileRecommendation
        │ ├─ Compare resources vs profiles │
        │ └─ Identify feasible options     │
        └──────────────────┬───────────────┘
                           │
                           ▼
        ┌──────────────────────────────────┐
        │ [STEP 4] Profile Selection       │
        │ ├─ Show menu (or preset)         │
        │ ├─ User picks option             │
        │ └─ Validate selection            │
        └──────────────────┬───────────────┘
                           │
                           ▼
        ┌──────────────────────────────────┐
        │ [STEP 5] Validation              │
        │ ├─ Check profile structure       │
        │ ├─ Verify VMs defined            │
        │ └─ Test resource allocation      │
        └──────────────────┬───────────────┘
                           │
                           ▼
        ┌──────────────────────────────────┐
        │ [STEP 6] Show Deployment Plan    │
        │ ├─ ASCII visualization           │
        │ ├─ List all VMs                  │
        │ └─ Show services per VM          │
        └──────────────────┬───────────────┘
                           │
                           ▼
        ┌──────────────────────────────────┐
        │ [STEP 7] Export Plan             │
        │ ├─ Create DEPLOYMENT_PLAN.json   │
        │ ├─ Write to disk                 │
        │ └─ Confirm completion            │
        └──────────────────┬───────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │ DEPLOYMENT_PLAN.json   │
              │ Ready for Phase 2      │
              └────────────────────────┘
```

## Profile Selection Logic

```
Available Resources: 12 CPU, 15GB RAM, 122GB Disk
                           │
                           ▼
        ┌─────────────────────────────────────────┐
        │  Check Profile: SMALL                   │
        │  ├─ CPU: 4 <= 12 ✅                     │
        │  ├─ RAM: 8GB <= 15GB ✅                 │
        │  └─ Disk: 80GB <= 122GB ✅              │
        │  Result: FEASIBLE ✅                    │
        └─────────────────────────────────────────┘
                           │
        ┌─────────────────┴──────────────────┐
        ▼                                    ▼
   ┌──────────────────┐        ┌──────────────────────┐
   │  Check: MEDIUM   │        │  Check: LARGE        │
   │  ├─ CPU: 10 ≤ 12✅        │  ├─ CPU: 24 > 12 ❌  │
   │  ├─ RAM: 20 > 15❌        │  ├─ RAM: 56 > 15 ❌  │
   │  └─ INFEASIBLE❌          │  └─ INFEASIBLE ❌    │
   └──────────────────┘        └──────────────────────┘
        │                                    │
        └─────────────┬──────────────────────┘
                      │
                      ▼
        ┌──────────────────────────┐
        │ Feasible Profiles:       │
        │ • small [RECOMMENDED]    │
        │                          │
        │ Recommendation: small ⭐ │
        └──────────────────────────┘
```

## Library Function Call Graph

```
configure-ceres.ps1
├─ Source Resource-Profiles.ps1
│  └─ 7 functions loaded:
│     ├─ Get-ResourceProfiles()
│     ├─ Get-ResourceProfile()
│     ├─ Get-AvailableProfiles()
│     ├─ Test-ResourceProfile()
│     ├─ Get-ProfileTotals()
│     ├─ Compare-ProfileToResources()
│     └─ Get-ProfileRecommendation()
│
├─ Get-ResourceProfiles() [Step 2]
│  ├─ Load small.json
│  ├─ Load medium.json
│  └─ Load large.json
│
├─ Get-ProfileRecommendation() [Step 3]
│  ├─ For each profile:
│  │  └─ Compare-ProfileToResources()
│  │     └─ Get-ProfileTotals()
│  └─ Return feasible list
│
├─ Get-ResourceProfile() [Step 4]
│  └─ Load selected profile
│
└─ Test-ResourceProfile() [Step 5]
   └─ Validate structure
```

## Profile Comparison Matrix

```
┌────────┬─────────┬──────┬───────┬──────────┬────────────────┐
│Profile │  VMs    │ CPU  │ RAM   │  Disk    │ Recommended    │
├────────┼─────────┼──────┼───────┼──────────┼────────────────┤
│ SMALL  │ 1 (all) │  4   │  8GB  │  80GB    │ Dev/Testing    │
│        │ (DC)    │      │       │          │                │
├────────┼─────────┼──────┼───────┼──────────┼────────────────┤
│ MEDIUM │ 3 (K8s) │  10  │ 20GB  │ 170GB    │ ⭐ Standard    │
│        │ (k3s)   │      │       │          │    Team        │
├────────┼─────────┼──────┼───────┼──────────┼────────────────┤
│ LARGE  │ 5 (K8s) │  24  │ 56GB  │ 450GB    │ Enterprise/HA  │
│        │ (HA)    │      │       │          │                │
└────────┴─────────┴──────┴───────┴──────────┴────────────────┘

Test System: 12 CPU, 15GB RAM, 122GB Disk
Result: SMALL FEASIBLE ✅ | MEDIUM ❌ | LARGE ❌
```

## File Structure

```
config/profiles/
├── small.json              # 79 lines - Dev deployment
├── medium.json             # 90 lines - Standard deployment
└── large.json              # 100 lines - Enterprise HA

scripts/
├── analyze-resources.ps1   # 120 lines - Resource analyzer
├── configure-ceres.ps1     # 242 lines - Config wizard
├── verify-phase1.ps1       # 95 lines - Verification
├── test-profiles.ps1       # 15 lines - Profile tester
└── _lib/
    └── Resource-Profiles.ps1 # 369 lines - Library (7 functions)

docs/
└── (existing documentation)

Generated:
└── DEPLOYMENT_PLAN.json    # Generated after wizard
```

## Function Reference

### Get-ProfileRecommendation
```powershell
$rec = Get-ProfileRecommendation -AvailableCpu 12 -AvailableRam 15 -AvailableDisk 122

# Returns:
# {
#   FeasibleProfiles = @("small")
#   Recommended = "small"
#   FeasibleCount = 1
# }
```

### Get-ProfileTotals
```powershell
$profile = Get-ResourceProfile -ProfileName "medium"
$totals = Get-ProfileTotals -Profile $profile

# Returns:
# {
#   cpu = 10
#   ram_gb = 20
#   disk_gb = 170
#   vm_count = 3
# }
```

### Test-ResourceProfile
```powershell
$result = Test-ResourceProfile -Profile $profile

# Returns:
# {
#   Success = $true
#   Errors = @()
#   ErrorCount = 0
# }
```

## Usage Examples

### Example 1: Analyze System Only
```powershell
.\scripts\analyze-resources.ps1
# Output: Resource analysis and profile recommendations
```

### Example 2: Interactive Configuration
```powershell
.\scripts\configure-ceres.ps1
# User sees menu, selects profile, gets deployment plan
```

### Example 3: Preset Configuration
```powershell
.\scripts\configure-ceres.ps1 -PresetProfile medium
# Automatically uses medium profile, skips menu
```

### Example 4: Fully Automated
```powershell
.\scripts\configure-ceres.ps1 -NonInteractive
# Auto-selects recommended profile, generates plan
```

### Example 5: JSON Output
```powershell
.\scripts\analyze-resources.ps1 -Json | ConvertFrom-Json
# Machine-readable output for automation
```

## Validation Flow

```
Input: Profile from JSON
       │
       ▼
┌─────────────────────────────┐
│ Validate Profile Structure  │
├─────────────────────────────┤
│ ✓ Check 'name'              │
│ ✓ Check 'version'           │
│ ✓ Check 'virtual_machines'  │
│ ✓ Check each VM:            │
│   - Has 'name' ✓            │
│   - CPU >= 1 ✓              │
│   - RAM >= 1GB ✓            │
│   - Disk >= 10GB ✓          │
│ ✓ Check resource_allocation │
│   for each service          │
└────────────┬────────────────┘
             │
             ▼
        ┌─────────┐
        │ VALID ✅│
        └─────────┘
```

---

**Quick Links**:
- 📄 [PHASE_1_MVP_SUMMARY.md](PHASE_1_MVP_SUMMARY.md) - Full documentation
- 📄 [PHASE_1_COMPLETE.md](PHASE_1_COMPLETE.md) - Implementation checklist
- 🔧 [scripts/analyze-resources.ps1](scripts/analyze-resources.ps1) - Analysis tool
- 🔧 [scripts/configure-ceres.ps1](scripts/configure-ceres.ps1) - Configuration wizard
- 📚 [scripts/_lib/Resource-Profiles.ps1](scripts/_lib/Resource-Profiles.ps1) - Library functions
- 🎯 [config/profiles/](config/profiles/) - Profile definitions
