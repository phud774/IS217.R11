[CmdletBinding()]
param(
    [string] $SourceData,
    [string] $OutputDirectory
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'build_looker_share.py'
$arguments = @($script)
if ($SourceData) { $arguments += @('--source-data', $SourceData) }
if ($OutputDirectory) { $arguments += @('--output-directory', $OutputDirectory) }
python @arguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
