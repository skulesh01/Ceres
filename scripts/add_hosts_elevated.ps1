$hosts='C:\Windows\System32\drivers\etc\hosts'
$bak="C:\Windows\System32\drivers\etc\hosts.bak.$((Get-Date).ToString('yyyyMMdd_HHmmss'))"
Copy-Item -Path $hosts -Destination $bak -Force
$entries=@(
 '127.0.0.1 traefik.Ceres.local',
 '127.0.0.1 auth.Ceres.local',
 '127.0.0.1 taiga.Ceres.local',
 '127.0.0.1 edm.Ceres.local',
 '127.0.0.1 cloud.Ceres.local',
 '127.0.0.1 git.Ceres.local',
 '127.0.0.1 mail.Ceres.local',
 '127.0.0.1 erp.Ceres.local',
 '127.0.0.1 crm.Ceres.local',
 '127.0.0.1 prometheus.Ceres.local',
 '127.0.0.1 minio.Ceres.local',
 '127.0.0.1 netdata.Ceres.local'
)
$existing=Get-Content $hosts -ErrorAction SilentlyContinue
foreach($e in $entries){
  if(-not ($existing -contains $e)){
    Add-Content -Path $hosts -Value $e
    Write-Output "Added: $e"
  } else {
    Write-Output "Exists: $e"
  }
}
Write-Output "ALL_DONE"
