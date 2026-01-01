# Ceres Services Test Suite (PowerShell)
# Verifies all 10 services are running and responding correctly
# Usage: .\test-services.ps1

param(
    [int]$Timeout = 30
)

$NAMESPACE = "ceres"
$passed = 0
$failed = 0

function Test-ServiceHealth {
    param(
        [string]$ServiceName,
        [int]$Port,
        [string]$HealthPath = "/"
    )
    
    Write-Host -NoNewline "Testing $ServiceName... "
    
    try {
        # Get pod
        $pod = kubectl get pod -n $NAMESPACE -l "app=$ServiceName" -o jsonpath='{.items[0].metadata.name}' 2>$null
        if (-not $pod) {
            Write-Host "FAIL (pod not running)" -ForegroundColor Red
            return $false
        }
        
        # Get pod IP
        $podIp = kubectl get pod -n $NAMESPACE -l "app=$ServiceName" -o jsonpath='{.items[0].status.podIP}' 2>$null
        if (-not $podIp) {
            Write-Host "FAIL (no pod IP)" -ForegroundColor Red
            return $false
        }
        
        # Test HTTP endpoint
        $response = Invoke-WebRequest -Uri "http://$podIp:$Port$HealthPath" -TimeoutSec $Timeout -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "PASS" -ForegroundColor Green
            return $true
        } else {
            Write-Host "FAIL (status code $($response.StatusCode))" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "FAIL (error: $_)" -ForegroundColor Red
        return $false
    }
}

function Test-PodRunning {
    param([string]$Label)
    
    Write-Host -NoNewline "Testing $Label... "
    
    try {
        $running = kubectl get pod -n $NAMESPACE -l $Label -o jsonpath='{.items[0].status.phase}' 2>$null
        
        if ($running -eq "Running") {
            Write-Host "PASS" -ForegroundColor Green
            return $true
        } else {
            Write-Host "FAIL (status: $running)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "FAIL" -ForegroundColor Red
        return $false
    }
}

# Header
Write-Host ""
Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Ceres Services Test Suite (PowerShell)   ║" -ForegroundColor Cyan
Write-Host "║   Testing all 10 services                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# SECTION 1: Cluster Status
Write-Host "SECTION 1: Cluster Status" -ForegroundColor Yellow
Write-Host ("─" * 44)

try {
    $nodesReady = (kubectl get nodes 2>$null | Select-String "Ready" | Measure-Object).Count
    Write-Host "Nodes ready: $nodesReady / 3"
}
catch {
    Write-Host "Could not check nodes"
}

try {
    $podsRunning = (kubectl get pods -n $NAMESPACE 2>$null | Select-String "Running" | Measure-Object).Count
    Write-Host "Pods running: $podsRunning / 10"
}
catch {
    Write-Host "Could not check pods"
}

Write-Host ""

# SECTION 2: Kubernetes Core
Write-Host "SECTION 2: Kubernetes Core Services" -ForegroundColor Yellow
Write-Host ("─" * 44)

Write-Host -NoNewline "Testing API server... "
try {
    $info = kubectl cluster-info 2>$null
    if ($info) {
        Write-Host "PASS" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "FAIL" -ForegroundColor Red
        $failed++
    }
}
catch {
    Write-Host "FAIL" -ForegroundColor Red
    $failed++
}

Write-Host ""

# SECTION 3: Database Services
Write-Host "SECTION 3: Database Services" -ForegroundColor Yellow
Write-Host ("─" * 44)

if (Test-PodRunning "app=postgresql") { $passed++ } else { $failed++ }
if (Test-PodRunning "app=redis") { $passed++ } else { $failed++ }

Write-Host ""

# SECTION 4: Authentication
Write-Host "SECTION 4: Authentication Service" -ForegroundColor Yellow
Write-Host ("─" * 44)

if (Test-PodRunning "app=keycloak") { $passed++ } else { $failed++ }

Write-Host ""

# SECTION 5: Document Management
Write-Host "SECTION 5: Document Management Service" -ForegroundColor Yellow
Write-Host ("─" * 44)

if (Test-PodRunning "app=nextcloud") { $passed++ } else { $failed++ }

Write-Host ""

# SECTION 6: Version Control
Write-Host "SECTION 6: Version Control Service" -ForegroundColor Yellow
Write-Host ("─" * 44)

if (Test-PodRunning "app=gitea") { $passed++ } else { $failed++ }

Write-Host ""

# SECTION 7: Messaging
Write-Host "SECTION 7: Messaging Service" -ForegroundColor Yellow
Write-Host ("─" * 44)

if (Test-PodRunning "app=mattermost") { $passed++ } else { $failed++ }

Write-Host ""

# SECTION 8: Monitoring
Write-Host "SECTION 8: Monitoring Services" -ForegroundColor Yellow
Write-Host ("─" * 44)

if (Test-PodRunning "app=prometheus") { $passed++ } else { $failed++ }
if (Test-PodRunning "app=grafana") { $passed++ } else { $failed++ }

Write-Host ""

# SECTION 9: Management
Write-Host "SECTION 9: Management Services" -ForegroundColor Yellow
Write-Host ("─" * 44)

if (Test-PodRunning "app=portainer") { $passed++ } else { $failed++ }

Write-Host ""

# SECTION 10: Ingress
Write-Host "SECTION 10: Ingress Controller" -ForegroundColor Yellow
Write-Host ("─" * 44)

Write-Host -NoNewline "Testing Nginx Ingress... "
try {
    $ingress = kubectl get pod -n ingress-nginx 2>$null | Select-String "Running"
    if ($ingress) {
        Write-Host "PASS" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "FAIL" -ForegroundColor Red
        $failed++
    }
}
catch {
    Write-Host "FAIL" -ForegroundColor Red
    $failed++
}

Write-Host ""

# SECTION 11: Advanced Tests
Write-Host "SECTION 11: Advanced Service Tests" -ForegroundColor Yellow
Write-Host ("─" * 44)

# PostgreSQL test
Write-Host -NoNewline "PostgreSQL connectivity... "
try {
    $pgResult = kubectl exec postgres-0 -n $NAMESPACE -- psql -U postgres -d ceres -c "SELECT 1" 2>$null
    if ($pgResult) {
        Write-Host "PASS" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "FAIL" -ForegroundColor Red
        $failed++
    }
}
catch {
    Write-Host "FAIL" -ForegroundColor Red
    $failed++
}

# Redis test
Write-Host -NoNewline "Redis connectivity... "
try {
    $redisResult = kubectl exec redis-0 -n $NAMESPACE -- redis-cli ping 2>$null
    if ($redisResult -match "PONG") {
        Write-Host "PASS" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "FAIL" -ForegroundColor Red
        $failed++
    }
}
catch {
    Write-Host "FAIL" -ForegroundColor Red
    $failed++
}

# Persistent volumes
Write-Host -NoNewline "Persistent volumes... "
try {
    $pvcCount = (kubectl get pvc -n $NAMESPACE 2>$null | Select-String "Bound" | Measure-Object).Count
    if ($pvcCount -ge 5) {
        Write-Host "PASS ($pvcCount bound)" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "FAIL (only $pvcCount bound)" -ForegroundColor Red
        $failed++
    }
}
catch {
    Write-Host "FAIL" -ForegroundColor Red
    $failed++
}

Write-Host ""

# Summary
Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Test Summary                             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$total = $passed + $failed
$successRate = if ($total -gt 0) { [int]($passed * 100 / $total) } else { 0 }

Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host "Total:  $total"
Write-Host "Success rate: $successRate%"
Write-Host ""

if ($failed -eq 0) {
    Write-Host "All tests PASSED! Cluster is healthy." -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some tests FAILED. See details above." -ForegroundColor Red
    Write-Host ""
    Write-Host "Debugging steps:"
    Write-Host "  kubectl logs pod-name -n $NAMESPACE"
    Write-Host "  kubectl describe pod pod-name -n $NAMESPACE"
    Write-Host "  kubectl get events -n $NAMESPACE"
    exit 1
}
