param(
  [Parameter(Mandatory = $true)][ValidateSet('run','last','secret')][string]$Command,
  [Parameter()][string]$Workflow,
  [Parameter()][string]$SecretName,
  [Parameter()][string]$SecretValue,
  [Parameter()][string[]]$Inputs
)

$ErrorActionPreference = 'Stop'
$Repo = if ($env:GH_REPO) { $env:GH_REPO } else { '' }
if (-not $Repo) { Write-Error "GH_REPO must be set (owner/repo)." }

switch ($Command) {
  'run' {
    if (-not $Workflow) { Write-Error "run requires -Workflow <file>" }
    $argsList = @('workflow','run', $Workflow)
    if ($Inputs) { $argsList += $Inputs }
    $argsList += @('--repo', $Repo)
    & gh @argsList
  }
  'last' {
    if (-not $Workflow) { Write-Error "last requires -Workflow <file>" }
    & gh run list --workflow $Workflow --limit 1 --repo $Repo
  }
  'secret' {
    if (-not $SecretName -or -not $SecretValue) { Write-Error "secret requires -SecretName and -SecretValue" }
    & gh secret set $SecretName --body $SecretValue --repo $Repo
  }
  default { Write-Error "Unknown command: $Command" }
}
