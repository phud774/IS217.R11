$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$checksumFile = Join-Path $root 'SHA256SUMS.txt'

if (-not (Test-Path -LiteralPath $checksumFile)) {
    throw 'Khong tim thay SHA256SUMS.txt.'
}

$failed = $false
foreach ($line in Get-Content -LiteralPath $checksumFile) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split '  ', 2
    if ($parts.Count -ne 2) { continue }
    $expected = $parts[0].Trim()
    $relativePath = $parts[1].Trim()
    $path = Join-Path $root $relativePath

    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "THIEU: $relativePath" -ForegroundColor Red
        $failed = $true
        continue
    }

    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($actual -ne $expected) {
        Write-Host "SAI CHECKSUM: $relativePath" -ForegroundColor Red
        $failed = $true
    } else {
        Write-Host "OK: $relativePath" -ForegroundColor Green
    }
}

if ($failed) {
    throw 'Goi bi thieu hoac hong file. Hay giai nen/tai lai.'
}

Write-Host 'Tat ca file deu hop le.' -ForegroundColor Green

