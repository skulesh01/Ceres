param(
  [Parameter(Mandatory = $true)][ValidateSet('cmd','git-pull','upload','download','kubectl-apply')][string]$Action,
  [Parameter(Mandatory = $true)][string]$Argument,
  [string]$Argument2,
  [string]$Host,
  [string]$User,
  [int]$Port = 22,
  [string]$KeyPath,
  [string]$KubeconfigPath
)

$ErrorActionPreference = 'Stop'

$Host = if ($Host) { $Host } elseif ($env:REMOTE_HOST) { $env:REMOTE_HOST } else { '' }
$User = if ($User) { $User } elseif ($env:REMOTE_USER) { $env:REMOTE_USER } else { '' }
$Port = if ($env:REMOTE_PORT) { [int]$env:REMOTE_PORT } else { $Port }
$KeyPath = if ($KeyPath) { $KeyPath } elseif ($env:SSH_KEY_PATH) { $env:SSH_KEY_PATH } else { $KeyPath }
$KubeconfigPath = if ($KubeconfigPath) { $KubeconfigPath } elseif ($env:REMOTE_KUBECONFIG) { $env:REMOTE_KUBECONFIG } else { '~/.kube/config' }

if (-not $Host -or -not $User) {
  Write-Error "REMOTE_HOST and REMOTE_USER must be set (via params or env)."
}

$sshArgs = @('-p', $Port.ToString(), '-o', 'StrictHostKeyChecking=accept-new')
if ($KeyPath) { $sshArgs += @('-i', $KeyPath) }
$sshArgs += "$User@$Host"

switch ($Action) {
  'cmd' {
    if (-not $Argument) { Write-Error "cmd requires a command string" }
    & ssh @sshArgs $Argument
  }
  'git-pull' {
    if (-not $Argument) { Write-Error "git-pull requires a remote path" }
    & ssh @sshArgs "cd $Argument && git pull --ff-only"
  }
  'upload' {
    if (-not $Argument -or -not $Argument2) { Write-Error "upload requires <local> <remote>" }
    $scpArgs = @('-P', $Port.ToString(), '-o', 'StrictHostKeyChecking=accept-new')
    if ($KeyPath) { $scpArgs += @('-i', $KeyPath) }
    $scpArgs += $Argument, "$User@$Host:$Argument2"
    & scp @scpArgs
  }
  'download' {
    if (-not $Argument -or -not $Argument2) { Write-Error "download requires <remote> <local>" }
    $scpArgs = @('-P', $Port.ToString(), '-o', 'StrictHostKeyChecking=accept-new')
    if ($KeyPath) { $scpArgs += @('-i', $KeyPath) }
    $scpArgs += "$User@$Host:$Argument", $Argument2
    & scp @scpArgs
  }
  'kubectl-apply' {
    if (-not $Argument) { Write-Error "kubectl-apply requires <manifests_path>" }
    & ssh @sshArgs "KUBECONFIG=$KubeconfigPath kubectl apply -f $Argument"
  }
  default {
    Write-Error "Unsupported action: $Action"
  }
}
