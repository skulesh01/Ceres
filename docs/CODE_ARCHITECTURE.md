# 🏗️ CERES Code Architecture

## 📐 SOLID Principles Applied

CERES codebase follows SOLID design principles for maintainability and extensibility.

### Single Responsibility Principle (SRP)
Each function has one clear purpose:
- `Get-CeresConfigDir` - Only resolves config path
- `Read-DotEnvFile` - Only parses env files
- `Assert-DockerRunning` - Only validates Docker daemon
- `New-SecureSecret` - Only generates secrets
- `Initialize-CeresEnv` - Only initializes environment
- `Get-CeresComposeFiles` - Only builds compose arguments

### Open/Closed Principle (OCP)
Code is open for extension, closed for modification:
- **Module system**: New modules added via configuration, not code changes
- **Secret generation**: `New-UrlSafeSecret` extends `New-SecureSecret` without modifying it
- **Env file format**: Parser supports extensions without core changes

### Liskov Substitution Principle (LSP)
Functions maintain consistent contracts:
- All path functions return absolute paths
- All secret generators return strings
- All validation functions throw on error or return void
- Consistent error handling patterns

### Interface Segregation Principle (ISP)
Small, focused function interfaces:
- Functions accept only required parameters
- No bloated interfaces
- Optional parameters are clearly marked
- Each script imports only needed functions

### Dependency Inversion Principle (DIP)
Depends on abstractions, not implementations:
- Scripts depend on function contracts, not implementations
- Docker commands abstracted through functions
- File paths abstracted through path functions
- No hardcoded dependencies

---

## 📦 Module Structure

### Core Library (`_lib/Ceres.ps1`)

Shared functionality for all CERES scripts. Organized by responsibility:

```
Ceres.ps1
├── Path Management
│   └── Get-CeresConfigDir
├── Environment File Operations  
│   └── Read-DotEnvFile
├── Docker Management
│   └── Assert-DockerRunning
├── Secret Generation
│   ├── New-SecureSecret
│   └── New-UrlSafeSecret
├── Environment Initialization
│   └── Initialize-CeresEnv
└── Docker Compose Orchestration
    └── Get-CeresComposeFiles
```

### Script Responsibilities

| Script | Primary Responsibility | Dependencies |
|--------|----------------------|--------------|
| **start.ps1** | Orchestrates service startup | Ceres.ps1 |
| **status.ps1** | Reports service health | Ceres.ps1 |
| **backup.ps1** | Creates backups | None |
| **restore.ps1** | Restores from backup | None |
| **cleanup.ps1** | Removes containers/volumes | None |
| **LAUNCH.ps1** | Proxmox deployment orchestration | Ceres.ps1 |

---

## 🔄 Data Flow

### 1. Environment Initialization Flow

```
start.ps1
    ↓
Get-CeresConfigDir()
    ↓
Initialize-CeresEnv()
    ├→ Check .env exists
    ├→ Read .env.example
    ├→ Generate secrets for missing/CHANGE_ME values
    └→ Write updated .env
    ↓
Read-DotEnvFile()
    ↓
Return environment variables to caller
```

### 2. Service Startup Flow

```
start.ps1
    ↓
Assert-DockerRunning()
    ├→ Check daemon
    ├→ Start Docker Desktop if needed
    └→ Wait for availability
    ↓
Get-CeresComposeFiles()
    ├→ Modular mode: base.yml + module YMLs
    └→ Clean mode: docker-compose-CLEAN.yml
    ↓
docker compose up -d
```

### 3. Module Selection Flow

```
User Input: start.ps1 core apps monitoring
    ↓
Parse Parameters
    ↓
Get-CeresComposeFiles -SelectedModules @("core", "apps", "monitoring")
    ↓
Build file list:
    -f compose/base.yml
    -f compose/core.yml
    -f compose/apps.yml
    -f compose/monitoring.yml
    ↓
Return to docker compose command
```

---

## 🛡️ Error Handling Strategy

### Strict Mode
All scripts use PowerShell Strict Mode:
```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

### Validation Layers

1. **Input Validation**
   - Parameter types enforced
   - ValidateScript attributes for paths
   - ValidateRange for numeric inputs

2. **Precondition Checks**
   - Docker daemon availability
   - File existence
   - Disk space

3. **Graceful Degradation**
   - Warning messages for non-critical issues
   - Verbose output for debugging
   - Clear error messages

### Exception Flow

```
Function Call
    ↓
[Validate Parameters] → InvalidArgument Exception
    ↓
[Check Preconditions] → Precondition Exception
    ↓
[Execute Logic] → Runtime Exception
    ↓
[Cleanup if needed]
    ↓
Return or Throw
```

---

## 📝 Code Documentation Standards

### Function Documentation Format

Every function includes complete comment-based help:

```powershell
<#
.SYNOPSIS
    Brief one-line description
.DESCRIPTION
    Detailed explanation of functionality
    Multiple paragraphs if needed
.PARAMETER ParamName
    Description of parameter
.OUTPUTS
    Type and description of return value
.EXAMPLE
    Example 1: Basic usage
    Example 2: Advanced usage
.NOTES
    Additional context:
    - SOLID principles applied
    - Security considerations
    - Performance notes
#>
function Verb-Noun {
    [CmdletBinding()]
    [OutputType([Type])]
    param(...)
    
    # Implementation
}
```

### Inline Comments

- **Why, not what**: Explain reasoning, not obvious code
- **Complex logic**: Document non-trivial algorithms
- **Security**: Note security-sensitive operations
- **Performance**: Document optimization choices

### Region Organization

Code organized into logical regions:
```powershell
#region Path Management
# Related functions
#endregion

#region Docker Operations
# Related functions
#endregion
```

---

## 🔍 Testing Strategy

### Manual Testing

1. **Unit-level**: Test individual functions
   ```powershell
   . .\scripts\_lib\Ceres.ps1
   $secret = New-SecureSecret -Bytes 32
   $secret.Length -gt 0  # Should be True
   ```

2. **Integration**: Test script interactions
   ```powershell
   .\scripts\start.ps1 core apps
   .\scripts\status.ps1
   ```

3. **End-to-end**: Full deployment test
   ```powershell
   .\scripts\LAUNCH.ps1
   ```

### Validation Points

- ✅ Parameter validation catches invalid input
- ✅ Docker daemon check prevents runtime errors
- ✅ Path resolution works across platforms
- ✅ Secret generation produces unique values
- ✅ Env file parsing handles edge cases

---

## 🚀 Extension Points

### Adding New Modules

1. Create `compose/newmodule.yml`
2. Update `Get-CeresComposeFiles` module map
3. Document in README.md
4. No other code changes needed

### Adding New Functions

1. Follow SOLID principles
2. Add to appropriate region in Ceres.ps1
3. Include complete documentation
4. Add to Export-ModuleMember
5. Update this architecture doc

### Adding New Scripts

1. Import Ceres.ps1: `. (Join-Path $PSScriptRoot "_lib\\Ceres.ps1")`
2. Use existing functions
3. Follow error handling patterns
4. Document in scripts/README.md

---

## 📊 Complexity Metrics

### Cyclomatic Complexity
Target: < 10 per function

Current status:
- `Get-CeresConfigDir`: 1 (Simple)
- `Read-DotEnvFile`: 4 (Simple)
- `Assert-DockerRunning`: 5 (Moderate)
- `Initialize-CeresEnv`: 7 (Moderate)
- `Get-CeresComposeFiles`: 4 (Simple)

### Maintainability Index
Target: > 80

Code maintainability: **Excellent**
- Clear naming
- Single responsibilities
- Comprehensive documentation
- Consistent patterns

---

## 🔐 Security Considerations

### Secret Generation
- Uses cryptographically secure RNG
- Minimum 8 bytes (64 bits)
- Base64 encoding for text safety
- URL-safe variant available

### Environment Files
- `.env` excluded from Git
- Automatic generation of missing secrets
- No secrets in code
- Warnings when secrets generated

### Docker Operations
- No privileged containers by default
- Network isolation via Docker networks
- Volume permissions managed
- Regular image updates

---

## 📚 References

### SOLID Principles
- [SOLID on Wikipedia](https://en.wikipedia.org/wiki/SOLID)
- [Clean Code by Robert C. Martin](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)

### PowerShell Best Practices
- [PowerShell Practice and Style Guide](https://poshcode.gitbook.io/powershell-practice-and-style/)
- [PowerShell Script Analyzer Rules](https://github.com/PowerShell/PSScriptAnalyzer)

### Docker Best Practices
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Best Practices](https://docs.docker.com/compose/production/)

---

**Last Updated:** 2026-01-01  
**Maintained by:** CERES Project Team
