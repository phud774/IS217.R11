[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $SqlInstance
)

$ErrorActionPreference = 'Stop'
$DatabaseName = 'IowaLiquorDW'
$packageRoot = $PSScriptRoot
$dataRoot = Join-Path $packageRoot 'Portable_Data'
$sqlRoot = Join-Path $packageRoot 'SQL'

$sqlcmd = (Get-Command sqlcmd.exe -ErrorAction Stop).Source
$bcp = (Get-Command bcp.exe -ErrorAction Stop).Source

Write-Host "Tao database [$DatabaseName] tren [$SqlInstance]..." -ForegroundColor Cyan
& $sqlcmd -S $SqlInstance -E -C -b `
    -i (Join-Path $sqlRoot '01_create_portable_database.sql')
if ($LASTEXITCODE -ne 0) {
    throw 'Khong tao duoc database. Neu database da ton tai, hay doi ten/xoa bang SSMS roi chay lai.'
}

$tables = @(
    'DIM_DATE',
    'DIM_STORE',
    'DIM_PRODUCT',
    'DIM_VENDOR',
    'FACT_LIQUOR_SALES'
)

foreach ($table in $tables) {
    $dataFile = Join-Path $dataRoot "$table.dat"
    if (-not (Test-Path -LiteralPath $dataFile)) {
        throw "Thieu file du lieu: $dataFile"
    }

    Write-Host "Nap $table..." -ForegroundColor Cyan
    & $bcp "dbo.$table" in $dataFile `
        -S $SqlInstance -d $DatabaseName -T -u `
        -c -C 65001 -t '|~|' -r 0x0a -E -b 100000 -m 1
    if ($LASTEXITCODE -ne 0) {
        throw "Nap du lieu that bai tai bang $table. Database dang o trang thai chua hoan tat."
    }
}

Write-Host 'Kiem tra so dong...' -ForegroundColor Cyan
& $sqlcmd -S $SqlInstance -E -C -b `
    -i (Join-Path $sqlRoot '02_verify_database.sql')
if ($LASTEXITCODE -ne 0) {
    throw 'Nap xong nhung buoc kiem tra database that bai.'
}

Write-Host 'Hoan tat. Tiep theo mo README.md de cau hinh va deploy SSAS.' -ForegroundColor Green

