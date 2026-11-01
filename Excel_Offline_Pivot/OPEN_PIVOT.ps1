$ErrorActionPreference = 'Stop'

$cubePath = Join-Path $PSScriptRoot 'IowaLiquor_Offline.cub'
$templatePath = Join-Path $PSScriptRoot 'IowaLiquor_Offline.odc'

if (-not (Test-Path -LiteralPath $cubePath)) {
    throw "Khong tim thay file cube: $cubePath"
}

if (-not (Test-Path -LiteralPath $templatePath)) {
    throw "Khong tim thay file ket noi: $templatePath"
}

$template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
$escapedCubePath = [System.Security.SecurityElement]::Escape($cubePath)
$runtimeOdc = Join-Path $env:TEMP "IowaLiquor_Offline_$PID.odc"
$content = $template.Replace('__CUBE_PATH__', $escapedCubePath)

$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($runtimeOdc, $content, $utf8WithoutBom)

Write-Host 'Dang mo PivotTable trong Excel...' -ForegroundColor Cyan
Start-Process -FilePath $runtimeOdc -WorkingDirectory $PSScriptRoot
