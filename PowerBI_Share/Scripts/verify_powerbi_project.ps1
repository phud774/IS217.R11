[CmdletBinding()]
param(
    [string] $ProjectRoot,
    [string] $SourceData
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
if ([string]::IsNullOrWhiteSpace($SourceData)) {
    $candidate = Join-Path $PSScriptRoot '..\..\SSAS_IowaLiquor_Share\Portable_Data'
    if (Test-Path -LiteralPath $candidate) {
        $SourceData = (Resolve-Path $candidate).Path
    }
}

$requiredJson = @(
    'IowaLiquor.pbip',
    'IowaLiquor.Report\definition.pbir',
    'IowaLiquor.Report\definition\version.json',
    'IowaLiquor.Report\definition\report.json',
    'IowaLiquor.Report\definition\pages\pages.json',
    'IowaLiquor.Report\definition\pages\ReportSectionIowaLiquorOverview\page.json',
    'IowaLiquor.SemanticModel\definition.pbism'
)

foreach ($relative in $requiredJson) {
    $path = Join-Path $ProjectRoot $relative
    if (-not (Test-Path -LiteralPath $path)) { throw "Thieu file: $relative" }
    Get-Content -LiteralPath $path -Raw | ConvertFrom-Json | Out-Null
}
Write-Host 'JSON: OK' -ForegroundColor Green

$checksumFile = Join-Path $ProjectRoot 'CHECKSUMS.sha256'
$failed = @()
foreach ($line in Get-Content -LiteralPath $checksumFile) {
    if ($line -notmatch '^([0-9A-F]{64})  (.+)$') { continue }
    $expected = $matches[1]
    $relative = $matches[2].Replace('/', '\')
    $path = Join-Path $ProjectRoot $relative
    if (-not (Test-Path -LiteralPath $path)) {
        $failed += "THIEU $relative"
    }
    elseif ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expected) {
        $failed += "SAI CHECKSUM $relative"
    }
}
if ($failed.Count -gt 0) { throw ($failed -join "`n") }
Write-Host 'Checksum project: OK' -ForegroundColor Green

$tableMap = [ordered]@{
    'DIM_DATE' = 'DIM_DATE.dat'
    'DIM_STORE' = 'DIM_STORE.dat'
    'DIM_PRODUCT' = 'DIM_PRODUCT.dat'
    'DIM_VENDOR' = 'DIM_VENDOR.dat'
    'FACT_LIQUOR_SALES' = 'FACT_LIQUOR_SALES.dat'
}

foreach ($table in $tableMap.Keys) {
    $tmdl = Join-Path $ProjectRoot "IowaLiquor.SemanticModel\definition\tables\$table.tmdl"
    $text = [System.IO.File]::ReadAllText($tmdl)
    if ($text -notmatch "(?m)^table $table\r?$") { throw "Sai khai bao table: $table" }
    if ($text -notmatch '(?m)^\s+partition .+ = m\r?$') { throw "Thieu partition M: $table" }

    if (-not [string]::IsNullOrWhiteSpace($SourceData)) {
        $matches = [regex]::Matches($text, '(?m)^[\t ]+"([A-Za-z0-9+/=]+)",?\r?$')
        if ($matches.Count -eq 0) { throw "Khong tim thay embedded data: $table" }

        $builder = [System.Text.StringBuilder]::new()
        foreach ($match in $matches) { [void]$builder.Append($match.Groups[1].Value) }
        $compressed = [Convert]::FromBase64String($builder.ToString())
        $memory = [System.IO.MemoryStream]::new($compressed, $false)
        $gzip = [System.IO.Compression.GZipStream]::new(
            $memory,
            [System.IO.Compression.CompressionMode]::Decompress
        )
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $actual = ([BitConverter]::ToString($sha.ComputeHash($gzip))).Replace('-', '')
        }
        finally {
            $sha.Dispose()
            $gzip.Dispose()
            $memory.Dispose()
        }

        $sourcePath = Join-Path $SourceData $tableMap[$table]
        $expected = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        if ($actual -ne $expected) { throw "Embedded data khong khop: $table" }
    }

    Write-Host "$table`: OK" -ForegroundColor Green
}

Write-Host 'Power BI project hop le theo cac kiem tra cau truc va du lieu.' -ForegroundColor Green
