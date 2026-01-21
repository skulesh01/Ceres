# K3s Diagnostic and Auto-Fix Script
# Automatically detects and fixes common K3s deployment issues

param(
    [switch]$AutoFix = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "K3s Cluster Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check 1: Network connectivity
Write-Host "[CHECK 1] DNS Resolution..." -ForegroundColor Yellow
try {
    $dnsTest = & ssh root@192.168.1.3 "nslookup registry-1.docker.io 8.8.8.8" 2>&1 | Out-String
    if ($dnsTest -match "can't resolve") {
        Write-Host "  [FAIL] DNS resolution failed" -ForegroundColor Red
        if ($AutoFix) {
            Write-Host "  [FIX] Restarting K3s service..." -ForegroundColor Yellow
            & ssh root@192.168.1.3 "systemctl restart k3s && sleep 15" 2>&1 | Out-Null
            Write-Host "  [OK] K3s restarted" -ForegroundColor Green
        } else {
            Write-Host "  [HINT] Run with -AutoFix to restart K3s" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [OK] DNS working" -ForegroundColor Green
    }
} catch {
    Write-Host "  [SKIP] Cannot check DNS (SSH issue)" -ForegroundColor Gray
}

# Check 2: K3s service status
Write-Host ""
Write-Host "[CHECK 2] K3s Service Status..." -ForegroundColor Yellow
try {
    $k3sStatus = & ssh root@192.168.1.3 "systemctl is-active k3s" 2>&1 | Out-String
    $k3sStatus = $k3sStatus.Trim()
    if ($k3sStatus -ne "active") {
        Write-Host "  [FAIL] K3s is not running ($k3sStatus)" -ForegroundColor Red
        if ($AutoFix) {
            Write-Host "  [FIX] Starting K3s..." -ForegroundColor Yellow
            & ssh root@192.168.1.3 "systemctl start k3s" 2>&1 | Out-Null
            Write-Host "  [OK] K3s started" -ForegroundColor Green
        }
    } else {
        Write-Host "  [OK] K3s running" -ForegroundColor Green
    }
} catch {
    Write-Host "  [SKIP] Cannot check K3s status (SSH issue)" -ForegroundColor Gray
}

# Check 3: Cluster connectivity
Write-Host ""
Write-Host "[CHECK 3] Cluster API..." -ForegroundColor Yellow
$clusterInfo = & kubectl cluster-info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [FAIL] Cannot connect to cluster" -ForegroundColor Red
    Write-Host "  [HINT] Run .\remote-deploy.ps1 to update kubeconfig" -ForegroundColor Gray
} else {
    Write-Host "  [OK] Cluster accessible" -ForegroundColor Green
}

# Check 4: Node status
Write-Host ""
Write-Host "[CHECK 4] Node Status..." -ForegroundColor Yellow
try {
    $nodeStatus = & kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type==\"Ready\")].status}' 2>&1
    if ($nodeStatus -eq "True") {
        Write-Host "  [OK] Node ready" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Node not ready" -ForegroundColor Red
    }
} catch {
    Write-Host "  [SKIP] Cannot check node status" -ForegroundColor Gray
}

# Check 5: Failed pods
Write-Host ""
Write-Host "[CHECK 5] Pod Status..." -ForegroundColor Yellow
$failedPods = & kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded -o json 2>$null | ConvertFrom-Json
if ($failedPods.items.Count -gt 0) {
    Write-Host "  [WARN] Found $($failedPods.items.Count) non-running pods:" -ForegroundColor Yellow
    foreach ($pod in $failedPods.items) {
        Write-Host "    - $($pod.metadata.namespace)/$($pod.metadata.name): $($pod.status.phase)" -ForegroundColor Gray
        
        # Auto-fix ImagePullBackOff
        if ($pod.status.containerStatuses -and $pod.status.containerStatuses[0].state.waiting.reason -eq "ImagePullBackOff") {
            Write-Host "      Reason: ImagePullBackOff (network issue)" -ForegroundColor Red
            if ($AutoFix -and !$script:k3sRestarted) {
                Write-Host "      [FIX] Restarting K3s to fix network..." -ForegroundColor Yellow
                ssh root@192.168.1.3 "systemctl restart k3s && sleep 15"
                $script:k3sRestarted = $true
                Write-Host "      [OK] K3s restarted, wait 30s for recovery" -ForegroundColor Green
            }
        }
    }
} else {
    Write-Host "  [OK] All pods running/succeeded" -ForegroundColor Green
}

# Check 6: PVC status
Write-Host ""
Write-Host "[CHECK 6] PVC Status..." -ForegroundColor Yellow
try {
    $allPVCs = & kubectl get pvc -A -o json 2>&1 | ConvertFrom-Json
    $pendingPVCs = $allPVCs.items | Where-Object { $_.status.phase -ne "Bound" }
    if ($pendingPVCs.Count -gt 0) {
        Write-Host "  [WARN] Found $($pendingPVCs.Count) unbound PVCs" -ForegroundColor Yellow
        foreach ($pvc in $pendingPVCs) {
            Write-Host "    - $($pvc.metadata.namespace)/$($pvc.metadata.name): $($pvc.status.phase)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [OK] All PVCs bound" -ForegroundColor Green
    }
} catch {
    Write-Host "  [SKIP] Cannot check PVC status" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Diagnostic Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Cluster Health:" -ForegroundColor Yellow
& kubectl get nodes
Write-Host ""
Write-Host "System Pods:" -ForegroundColor Yellow
& kubectl get pods -n kube-system
Write-Host ""

if ($AutoFix) {
    Write-Host "[INFO] Auto-fix completed. Re-run without -AutoFix to verify." -ForegroundColor Cyan
} else {
    Write-Host "[INFO] Run with -AutoFix to automatically fix detected issues." -ForegroundColor Cyan
}
Write-Host ""
