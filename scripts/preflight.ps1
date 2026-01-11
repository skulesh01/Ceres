param(
    [string]$ServerIP = "192.168.1.3",
    [string]$ServerUser = "root",
    [string]$ServerPassword = $env:DEPLOY_SERVER_PASSWORD,
    [string]$Gateway = "192.168.1.1"
)

$plink = "$HOME\plink.exe"

Write-Host "`n=== CERES Preflight ===" -ForegroundColor Cyan
if (!(Test-Path $plink)) {
    Write-Host "Скачиваю plink.exe..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe" -OutFile $plink -UseBasicParsing
}

Write-Host "Проверка подключения..." -ForegroundColor Yellow
$testConn = & $plink -pw $ServerPassword -batch "$ServerUser@$ServerIP" "echo OK" 2>&1
if ($testConn -notmatch "OK") { Write-Host "[ERROR] SSH подключение не удалось" -ForegroundColor Red; exit 1 }

$cmd = @'
echo Gateway: $(ip route | awk '/default/ {print $3}')
ping -c 1 __GW__ >/dev/null 2>&1 && echo GW:OK || echo GW:FAIL
getent hosts github.com >/dev/null 2>&1 && echo DNS:OK || echo DNS:FAIL
echo BusyPorts:; ss -ltnup | egrep ':80|:443|:51820' || echo none
echo CPU:; nproc
echo RAM(MB):; free -m | awk '/Mem:/ {print $2}'
echo Disk:; df -h / | awk 'NR==2{print $1, $2, $3, $4}'
'@
$cmd = $cmd -replace '__GW__', $Gateway
$out = & $plink -pw $ServerPassword -batch "$ServerUser@$ServerIP" $cmd 2>&1
Write-Host $out
Write-Host "=== Preflight Done ===" -ForegroundColor Green
