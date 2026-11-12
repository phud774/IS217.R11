[CmdletBinding()]
param(
    [string] $SourceData,
    [string] $OutputDirectory
)

$ErrorActionPreference = 'Stop'
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$separator = [char]0x1F
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

if ([string]::IsNullOrWhiteSpace($SourceData)) {
    $SourceData = Join-Path $PSScriptRoot '..\..\SSAS_IowaLiquor_Share\Portable_Data'
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $PSScriptRoot '..\Data'
}

function Split-PortableRow {
    param([Parameter(Mandatory = $true)][string] $Line)
    return $Line.Split([string[]]@('|~|'), [System.StringSplitOptions]::None)
}

function Csv-Field {
    param([AllowNull()][string] $Value)
    if ($null -eq $Value) { return '' }
    if ($Value.IndexOfAny([char[]]@(',', '"', "`r", "`n")) -ge 0) {
        return '"' + $Value.Replace('"', '""') + '"'
    }
    return $Value
}

function Read-Dimension {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][int] $ExpectedColumns,
        [Parameter(Mandatory = $true)][scriptblock] $Project
    )

    $result = @{}
    $reader = [System.IO.StreamReader]::new($Path, $utf8NoBom, $true, 1MB)
    try {
        while (($line = $reader.ReadLine()) -ne $null) {
            $parts = Split-PortableRow $line
            if ($parts.Count -ne $ExpectedColumns) {
                throw "Dong sai dinh dang trong $Path"
            }
            $result[$parts[0]] = & $Project $parts
        }
    }
    finally {
        $reader.Dispose()
    }
    return $result
}

$source = (Resolve-Path -LiteralPath $SourceData).Path
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$output = (Resolve-Path -LiteralPath $OutputDirectory).Path

Write-Host 'Dang doc cac bang chieu...' -ForegroundColor Cyan
$dates = Read-Dimension (Join-Path $source 'DIM_DATE.dat') 7 {
    param($p)
    return @($p[6], $p[3], $p[4], $p[5])
}
$stores = Read-Dimension (Join-Path $source 'DIM_STORE.dat') 5 {
    param($p)
    return @($p[1], $p[2], $p[3], $p[4])
}
$products = Read-Dimension (Join-Path $source 'DIM_PRODUCT.dat') 5 {
    param($p)
    $category = if ([string]::IsNullOrWhiteSpace($p[4])) { 'Unknown' } else { $p[4] }
    return $category
}
$vendors = Read-Dimension (Join-Path $source 'DIM_VENDOR.dat') 3 {
    param($p)
    $name = if ([string]::IsNullOrWhiteSpace($p[2])) { 'Unknown' } else { $p[2] }
    return $name
}

$countyCategory = [System.Collections.Generic.Dictionary[string, double[]]]::new([System.StringComparer]::Ordinal)
$monthlyVendor = [System.Collections.Generic.Dictionary[string, double[]]]::new([System.StringComparer]::Ordinal)
$monthlyStore = [System.Collections.Generic.Dictionary[string, double[]]]::new([System.StringComparer]::Ordinal)

$factPath = Join-Path $source 'FACT_LIQUOR_SALES.dat'
$reader = [System.IO.StreamReader]::new($factPath, $utf8NoBom, $true, 4MB)
$factRows = 0L
try {
    while (($line = $reader.ReadLine()) -ne $null) {
        $p = Split-PortableRow $line
        if ($p.Count -ne 9) { throw "Dong fact sai dinh dang tai dong $($factRows + 1)" }

        $date = $dates[$p[2]]
        $store = $stores[$p[3]]
        $category = $products[$p[4]]
        $vendor = $vendors[$p[5]]
        if ($null -eq $date -or $null -eq $store -or $null -eq $category -or $null -eq $vendor) {
            throw "Khoa chieu khong ton tai tai dong fact $($factRows + 1)"
        }

        $bottles = [int]::Parse($p[6], $culture)
        $dollars = [double]::Parse($p[7], $culture)
        $liters = [double]::Parse($p[8], $culture)
        $prefix = "$($date[0])$separator$($date[1])$separator$($date[2])$separator$($date[3])"

        $key = "$prefix$separator$($store[3])$separator$category"
        if (-not $countyCategory.ContainsKey($key)) { $countyCategory[$key] = [double[]]@(0, 0, 0, 0) }
        $a = $countyCategory[$key]
        $a[0] += 1; $a[1] += $bottles; $a[2] += $dollars; $a[3] += $liters

        $key = "$prefix$separator$vendor"
        if (-not $monthlyVendor.ContainsKey($key)) { $monthlyVendor[$key] = [double[]]@(0, 0, 0, 0) }
        $a = $monthlyVendor[$key]
        $a[0] += 1; $a[1] += $bottles; $a[2] += $dollars; $a[3] += $liters

        $key = "$prefix$separator$($p[3])"
        if (-not $monthlyStore.ContainsKey($key)) { $monthlyStore[$key] = [double[]]@(0, 0, 0, 0) }
        $a = $monthlyStore[$key]
        $a[0] += 1; $a[1] += $bottles; $a[2] += $dollars; $a[3] += $liters

        $factRows++
        if (($factRows % 500000) -eq 0) { Write-Host "Da xu ly $factRows dong..." -ForegroundColor DarkGray }
    }
}
finally {
    $reader.Dispose()
}

function Write-AggregateFile {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Header,
        [Parameter(Mandatory = $true)] $Dictionary,
        [Parameter(Mandatory = $true)][scriptblock] $DimensionFields
    )

    $writer = [System.IO.StreamWriter]::new($Path, $false, $utf8NoBom, 1MB)
    try {
        $writer.WriteLine($Header)
        foreach ($key in ($Dictionary.Keys | Sort-Object)) {
            $parts = $key.Split($separator)
            $dimensions = & $DimensionFields $parts
            $a = $Dictionary[$key]
            $metrics = @(
                ([long]$a[0]).ToString($culture),
                ([long]$a[1]).ToString($culture),
                $a[2].ToString('0.00', $culture),
                $a[3].ToString('0.000', $culture)
            )
            $writer.WriteLine((($dimensions + $metrics) -join ','))
        }
    }
    finally {
        $writer.Dispose()
    }
}

Write-Host 'Dang ghi cac CSV tong hop...' -ForegroundColor Cyan
Write-AggregateFile (Join-Path $output 'sales_monthly_county_category.csv') `
    'year,month_number,month_name,quarter_number,county_name,category_name,transaction_count,sales_bottles,sales_dollars,sales_liters' `
    $countyCategory {
        param($p)
        return @($p[0], $p[1], (Csv-Field $p[2]), $p[3], (Csv-Field $p[4]), (Csv-Field $p[5]))
    }

Write-AggregateFile (Join-Path $output 'sales_monthly_vendor.csv') `
    'year,month_number,month_name,quarter_number,vendor_name,transaction_count,sales_bottles,sales_dollars,sales_liters' `
    $monthlyVendor {
        param($p)
        return @($p[0], $p[1], (Csv-Field $p[2]), $p[3], (Csv-Field $p[4]))
    }

Write-AggregateFile (Join-Path $output 'sales_monthly_store.csv') `
    'year,month_number,month_name,quarter_number,store_no,store_name,store_city,county_name,transaction_count,sales_bottles,sales_dollars,sales_liters' `
    $monthlyStore {
        param($p)
        $store = $stores[$p[4]]
        return @($p[0], $p[1], (Csv-Field $p[2]), $p[3], (Csv-Field $store[0]), (Csv-Field $store[1]), (Csv-Field $store[2]), (Csv-Field $store[3]))
    }

$metadata = [ordered]@{
    source_fact_rows = $factRows
    county_category_rows = $countyCategory.Count
    vendor_rows = $monthlyVendor.Count
    store_rows = $monthlyStore.Count
    grain = 'Monthly aggregated data for Data Studio dashboards'
}
[System.IO.File]::WriteAllText(
    (Join-Path $output 'metadata.json'),
    ($metadata | ConvertTo-Json),
    $utf8NoBom
)

$checksumFiles = @(
    'metadata.json',
    'sales_monthly_county_category.csv',
    'sales_monthly_store.csv',
    'sales_monthly_vendor.csv'
)
$checksumLines = foreach ($name in $checksumFiles) {
    $hash = (Get-FileHash -LiteralPath (Join-Path $output $name) -Algorithm SHA256).Hash
    "$hash  $name"
}
[System.IO.File]::WriteAllLines(
    (Join-Path $output 'CHECKSUMS.sha256'),
    $checksumLines,
    $utf8NoBom
)

Write-Host "Hoan tat: $factRows dong fact -> $output" -ForegroundColor Green
