#!/usr/bin/env powershell
# Auto-deploy Flux with embedded credentials
# No user interaction needed - run and forget

$ServerHost = "$env:DEPLOY_SERVER_USER@$env:DEPLOY_SERVER_IP"
$Password = $env:DEPLOY_SERVER_PASSWORD
$ManifestPath = "config\flux\flux-releases.yml"

Write-Host "Starting Flux deployment..." -ForegroundColor Green

# Step 1: Read manifest
$manifest = Get-Content $ManifestPath -Raw

# Step 2: Execute all commands in one SSH session
$commands = @"
cat > /tmp/flux-releases.yml << 'EOF'
$manifest
EOF
echo "Applying manifest..."
kubectl apply -f /tmp/flux-releases.yml 2>&1 | grep -E "(created|unchanged|error)" || true
echo ""
echo "Waiting for reconciliation..."
sleep 5
echo ""
echo "=== HelmRelease Status ==="
kubectl -n ceres get helmrelease -o wide 2>&1 || true
echo ""
echo "=== Pod Status ==="
kubectl -n ceres get pods -o wide 2>&1 || true
"@

# Step 3: Send commands through SSH with password
$process = [System.Diagnostics.Process]::new()
$process.StartInfo = [System.Diagnostics.ProcessStartInfo]@{
    FileName = "ssh.exe"
    Arguments = "$ServerHost"
    RedirectStandardInput = $true
    RedirectStandardOutput = $true
    RedirectStandardError = $true
    UseShellExecute = $false
    CreateNoWindow = $true
}

$process.Start() | Out-Null
$process.StandardInput.WriteLine($commands)
$process.StandardInput.Close()

$output = $process.StandardOutput.ReadToEnd()
$errors = $process.StandardError.ReadToEnd()
$process.WaitForExit()

Write-Host $output -ForegroundColor Cyan
if ($errors) { Write-Host "Errors: $errors" -ForegroundColor Yellow }

Write-Host "`nDeploy complete!" -ForegroundColor Green
