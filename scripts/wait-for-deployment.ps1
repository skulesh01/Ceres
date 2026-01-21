# Wait for Kubernetes Deployment/StatefulSet to be Ready
# Usage: .\wait-for-deployment.ps1 -Name postgresql -Namespace ceres-core -Type StatefulSet -Timeout 300

param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    
    [Parameter(Mandatory=$true)]
    [string]$Namespace,
    
    [ValidateSet("Deployment", "StatefulSet")]
    [string]$Type = "Deployment",
    
    [int]$Timeout = 300
)

$ErrorActionPreference = "Stop"

Write-Host "Waiting for $Type/$Name in namespace $Namespace..." -ForegroundColor Cyan

$elapsed = 0
$checkInterval = 5

while ($elapsed -lt $Timeout) {
    # Get pod selector based on type
    if ($Type -eq "StatefulSet") {
        $pods = & kubectl get pods -n $Namespace -l app=$Name -o json 2>$null | ConvertFrom-Json
    } else {
        $selector = (& kubectl get deployment $Name -n $Namespace -o jsonpath='{.spec.selector.matchLabels}' 2>$null | ConvertFrom-Json)
        if ($selector) {
            $labelSelector = ($selector.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ","
            $pods = & kubectl get pods -n $Namespace -l $labelSelector -o json 2>$null | ConvertFrom-Json
        } else {
            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval
            continue
        }
    }
    
    if ($pods.items.Count -eq 0) {
        Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] Waiting for pods to be created..." -ForegroundColor Gray
        Start-Sleep -Seconds $checkInterval
        $elapsed += $checkInterval
        continue
    }
    
    # Check all pods
    $allReady = $true
    foreach ($pod in $pods.items) {
        $podName = $pod.metadata.name
        $phase = $pod.status.phase
        $conditions = $pod.status.conditions | Where-Object { $_.type -eq "Ready" }
        $ready = $conditions.status -eq "True"
        
        if ($phase -ne "Running" -or !$ready) {
            $allReady = $false
            
            # Check for errors
            if ($pod.status.containerStatuses) {
                $containerState = $pod.status.containerStatuses[0].state
                if ($containerState.waiting) {
                    $reason = $containerState.waiting.reason
                    if ($reason -in @("ErrImagePull", "ImagePullBackOff", "CrashLoopBackOff")) {
                        Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] ERROR: Pod $podName failed - $reason" -ForegroundColor Red
                        
                        # Show recent events
                        Write-Host "  Recent events:" -ForegroundColor Yellow
                        & kubectl describe pod $podName -n $Namespace | Select-String -Pattern "Warning|Error" | Select-Object -Last 3
                        
                        return $false
                    }
                }
            }
            
            Write-Host "  [$(Get-Date -Format 'HH:mm:ss')] Pod $podName : $phase (Ready: $ready)" -ForegroundColor Yellow
        }
    }
    
    if ($allReady) {
        Write-Host "  [OK] $Type/$Name is ready!" -ForegroundColor Green
        return $true
    }
    
    Start-Sleep -Seconds $checkInterval
    $elapsed += $checkInterval
}

Write-Host "  [TIMEOUT] $Type/$Name not ready after ${Timeout}s" -ForegroundColor Red
Write-Host "  Check status: kubectl get pods -n $Namespace" -ForegroundColor Yellow
return $false
