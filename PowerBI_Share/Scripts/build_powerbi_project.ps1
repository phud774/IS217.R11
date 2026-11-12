[CmdletBinding()]
param(
    [string] $SourceData,
    [string] $ProjectRoot
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
if ([string]::IsNullOrWhiteSpace($SourceData)) {
    $SourceData = (Resolve-Path (Join-Path $PSScriptRoot '..\..\SSAS_IowaLiquor_Share\Portable_Data')).Path
}

$modelRoot = Join-Path $ProjectRoot 'IowaLiquor.SemanticModel'
$definitionRoot = Join-Path $modelRoot 'definition'
$tablesRoot = Join-Path $definitionRoot 'tables'
$reportRoot = Join-Path $ProjectRoot 'IowaLiquor.Report'
$reportDefinitionRoot = Join-Path $reportRoot 'definition'
$pageName = 'ReportSectionIowaLiquorOverview'
$pageRoot = Join-Path $reportDefinitionRoot "pages\$pageName"

@($modelRoot, $definitionRoot, $tablesRoot, $reportRoot, $reportDefinitionRoot, $pageRoot) |
    ForEach-Object { [System.IO.Directory]::CreateDirectory($_) | Out-Null }

function Write-Utf8File {
    param([string] $Path, [string] $Content)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Write-JsonFile {
    param([string] $Path, $Object)
    Write-Utf8File $Path (($Object | ConvertTo-Json -Depth 20) + "`n")
}

function Write-EmbeddedTable {
    param(
        [string] $TableName,
        [string] $SourceFile,
        [array] $Columns,
        [array] $Measures = @(),
        [switch] $IsDateTable
    )

    $sourcePath = Join-Path $SourceData $SourceFile
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Thieu file nguon: $sourcePath"
    }

    $tempGzip = Join-Path ([System.IO.Path]::GetTempPath()) ("powerbi_" + [guid]::NewGuid().ToString('N') + '.gz')
    try {
        $input = [System.IO.File]::OpenRead($sourcePath)
        $output = [System.IO.File]::Create($tempGzip)
        $gzip = [System.IO.Compression.GZipStream]::new(
            $output,
            [System.IO.Compression.CompressionLevel]::Optimal,
            $false
        )
        try {
            $input.CopyTo($gzip)
        }
        finally {
            $gzip.Dispose()
            $input.Dispose()
            $output.Dispose()
        }

        $encoded = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($tempGzip))
        $target = Join-Path $tablesRoot "$TableName.tmdl"
        $writer = [System.IO.StreamWriter]::new($target, $false, $utf8NoBom, 1MB)
        try {
            $writer.WriteLine("table $TableName")
            if ($IsDateTable) { $writer.WriteLine("`tdataCategory: Time") }
            $writer.WriteLine()

            foreach ($measure in $Measures) {
                $writer.WriteLine("`tmeasure '$($measure.Name)' = $($measure.Expression)")
                $writer.WriteLine("`t`tformatString: $($measure.FormatString)")
                $writer.WriteLine()
            }

            foreach ($column in $Columns) {
                $writer.WriteLine("`tcolumn $($column.Name)")
                $writer.WriteLine("`t`tdataType: $($column.DataType)")
                if ($column.FormatString) { $writer.WriteLine("`t`tformatString: $($column.FormatString)") }
                if ($column.SortByColumn) { $writer.WriteLine("`t`tsortByColumn: $($column.SortByColumn)") }
                $writer.WriteLine("`t`tsummarizeBy: $($column.SummarizeBy)")
                $writer.WriteLine("`t`tsourceColumn: $($column.Name)")
                $writer.WriteLine()
            }

            $writer.WriteLine("`tpartition $TableName = m")
            $writer.WriteLine("`t`tmode: import")
            $writer.WriteLine("`t`tsource =")
            $writer.WriteLine("`t`t`tlet")
            $writer.WriteLine("`t`t`t`tEncoded = Text.Combine({")

            $chunkSize = 8192
            for ($offset = 0; $offset -lt $encoded.Length; $offset += $chunkSize) {
                $length = [Math]::Min($chunkSize, $encoded.Length - $offset)
                $chunk = $encoded.Substring($offset, $length)
                $comma = if (($offset + $length) -lt $encoded.Length) { ',' } else { '' }
                $writer.WriteLine("`t`t`t`t`t`"$chunk`"$comma")
            }

            $writer.WriteLine("`t`t`t`t}),")
            $writer.WriteLine("`t`t`t`tCompressed = Binary.FromText(Encoded, BinaryEncoding.Base64),")
            $writer.WriteLine("`t`t`t`tRaw = Binary.Decompress(Compressed, Compression.GZip),")
            $writer.WriteLine("`t`t`t`tLines = List.Select(Lines.FromBinary(Raw, null, null, 65001), each _ <> `"`"),")
            $writer.WriteLine("`t`t`t`tRows = List.Transform(Lines, each Text.Split(_, `"|~|`")),")

            $columnNames = ($Columns | ForEach-Object { '"' + $_.Name + '"' }) -join ', '
            $writer.WriteLine("`t`t`t`tSource = Table.FromRows(Rows, {$columnNames}),")

            $typePairs = ($Columns | ForEach-Object { '{"' + $_.Name + '", ' + $_.MType + '}' }) -join ', '
            $writer.WriteLine("`t`t`t`tTyped = Table.TransformColumnTypes(Source, {$typePairs}, `"en-US`")")
            $writer.WriteLine("`t`t`tin")
            $writer.WriteLine("`t`t`t`tTyped")
        }
        finally {
            $writer.Dispose()
        }

        Write-Host "$TableName`: $([math]::Round((Get-Item $target).Length / 1MB, 2)) MiB TMDL" -ForegroundColor DarkGray
    }
    finally {
        if (Test-Path -LiteralPath $tempGzip) {
            Remove-Item -LiteralPath $tempGzip -Force
        }
    }
}

$dateColumns = @(
    @{ Name='date_key'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' },
    @{ Name='ordered_on'; DataType='dateTime'; MType='type date'; SummarizeBy='none'; FormatString='yyyy-MM-dd' },
    @{ Name='day_number'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' },
    @{ Name='month_number'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' },
    @{ Name='month_name'; DataType='string'; MType='type text'; SummarizeBy='none'; SortByColumn='month_number' },
    @{ Name='quarter_number'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' },
    @{ Name='year_number'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' }
)

$storeColumns = @(
    @{ Name='store_key'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' },
    @{ Name='store_no'; DataType='string'; MType='type text'; SummarizeBy='none' },
    @{ Name='store_name'; DataType='string'; MType='type text'; SummarizeBy='none' },
    @{ Name='store_city'; DataType='string'; MType='type text'; SummarizeBy='none' },
    @{ Name='county_name'; DataType='string'; MType='type text'; SummarizeBy='none' }
)

$productColumns = @(
    @{ Name='product_key'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' },
    @{ Name='item_no'; DataType='string'; MType='type text'; SummarizeBy='none' },
    @{ Name='im_desc'; DataType='string'; MType='type text'; SummarizeBy='none' },
    @{ Name='bottle_volume_ml'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' },
    @{ Name='category_name'; DataType='string'; MType='type text'; SummarizeBy='none' }
)

$vendorColumns = @(
    @{ Name='vendor_key'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' },
    @{ Name='vendor_number'; DataType='string'; MType='type text'; SummarizeBy='none' },
    @{ Name='vendor_name'; DataType='string'; MType='type text'; SummarizeBy='none' }
)

$factColumns = @(
    @{ Name='sales_key'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' },
    @{ Name='invoice_id'; DataType='string'; MType='type text'; SummarizeBy='none' },
    @{ Name='date_key'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' },
    @{ Name='store_key'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' },
    @{ Name='product_key'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' },
    @{ Name='vendor_key'; DataType='int64'; MType='Int64.Type'; SummarizeBy='none'; FormatString='0' },
    @{ Name='sales_bottles'; DataType='int64'; MType='Int64.Type'; SummarizeBy='sum'; FormatString='#,0' },
    @{ Name='sales_dollars'; DataType='decimal'; MType='Currency.Type'; SummarizeBy='sum'; FormatString='\$#,0.00;(\$#,0.00);\$#,0.00' },
    @{ Name='sales_liters'; DataType='double'; MType='type number'; SummarizeBy='sum'; FormatString='#,0.000' }
)

$factMeasures = @(
    @{ Name='Total Sales'; Expression='SUM(FACT_LIQUOR_SALES[sales_dollars])'; FormatString='\$#,0.00;(\$#,0.00);\$#,0.00' },
    @{ Name='Total Bottles'; Expression='SUM(FACT_LIQUOR_SALES[sales_bottles])'; FormatString='#,0' },
    @{ Name='Total Liters'; Expression='SUM(FACT_LIQUOR_SALES[sales_liters])'; FormatString='#,0.000' },
    @{ Name='Transaction Count'; Expression='COUNTROWS(FACT_LIQUOR_SALES)'; FormatString='#,0' },
    @{ Name='Average Sale'; Expression='DIVIDE([Total Sales], [Transaction Count])'; FormatString='\$#,0.00;(\$#,0.00);\$#,0.00' }
)

Write-Host 'Dang nen va nhung du lieu vao semantic model...' -ForegroundColor Cyan
Write-EmbeddedTable 'DIM_DATE' 'DIM_DATE.dat' $dateColumns @() -IsDateTable
Write-EmbeddedTable 'DIM_STORE' 'DIM_STORE.dat' $storeColumns
Write-EmbeddedTable 'DIM_PRODUCT' 'DIM_PRODUCT.dat' $productColumns
Write-EmbeddedTable 'DIM_VENDOR' 'DIM_VENDOR.dat' $vendorColumns
Write-EmbeddedTable 'FACT_LIQUOR_SALES' 'FACT_LIQUOR_SALES.dat' $factColumns $factMeasures

Write-Utf8File (Join-Path $definitionRoot 'database.tmdl') @"
database IowaLiquor
	compatibilityLevel: 1702
	compatibilityMode: powerBI
"@

Write-Utf8File (Join-Path $definitionRoot 'model.tmdl') @"
model Model
	culture: en-US
	defaultPowerBIDataSourceVersion: powerBI_V3
	discourageImplicitMeasures
	sourceQueryCulture: en-US
	dataAccessOptions
		legacyRedirects
		returnErrorValuesAsNull

annotation __PBI_TimeIntelligenceEnabled = 0
annotation PBI_QueryOrder = ["DIM_DATE","DIM_STORE","DIM_PRODUCT","DIM_VENDOR","FACT_LIQUOR_SALES"]

ref table DIM_DATE
ref table DIM_STORE
ref table DIM_PRODUCT
ref table DIM_VENDOR
ref table FACT_LIQUOR_SALES
"@

Write-Utf8File (Join-Path $definitionRoot 'relationships.tmdl') @"
relationship 45dd70b6-a9eb-4ac1-afb6-2de0ca106956
	fromColumn: FACT_LIQUOR_SALES.date_key
	toColumn: DIM_DATE.date_key

relationship a935ebc4-2f23-4b88-bdbb-980055d54bf0
	fromColumn: FACT_LIQUOR_SALES.store_key
	toColumn: DIM_STORE.store_key

relationship 21f69e07-2b6d-4726-933e-a46609b2c8bb
	fromColumn: FACT_LIQUOR_SALES.product_key
	toColumn: DIM_PRODUCT.product_key

relationship e93e48f2-d21b-4b62-9309-b3db113795e0
	fromColumn: FACT_LIQUOR_SALES.vendor_key
	toColumn: DIM_VENDOR.vendor_key
"@

Write-JsonFile (Join-Path $modelRoot 'definition.pbism') ([ordered]@{
    '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/item/semanticModel/definitionProperties/1.0.0/schema.json'
    version = '4.2'
    settings = [ordered]@{ qnaEnabled = $true }
})

Write-JsonFile (Join-Path $ProjectRoot 'IowaLiquor.pbip') ([ordered]@{
    '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json'
    version = '1.0'
    artifacts = @([ordered]@{ report = [ordered]@{ path = 'IowaLiquor.Report' } })
    settings = [ordered]@{ enableAutoRecovery = $true }
})

Write-JsonFile (Join-Path $reportRoot 'definition.pbir') ([ordered]@{
    '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definitionProperties/2.0.0/schema.json'
    version = '4.0'
    datasetReference = [ordered]@{ byPath = [ordered]@{ path = '../IowaLiquor.SemanticModel' } }
})

Write-JsonFile (Join-Path $reportDefinitionRoot 'version.json') ([ordered]@{
    '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/versionMetadata/1.0.0/schema.json'
    version = '2.0.0'
})

Write-JsonFile (Join-Path $reportDefinitionRoot 'report.json') ([ordered]@{
    '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/report/3.1.0/schema.json'
    themeCollection = [ordered]@{}
    reportSource = 'Default'
    settings = [ordered]@{
        allowInlineExploration = $true
        defaultDrillFilterOtherVisuals = $true
        exportDataMode = 'AllowSummarizedAndUnderlying'
    }
})

$pagesRoot = Join-Path $reportDefinitionRoot 'pages'
[System.IO.Directory]::CreateDirectory($pagesRoot) | Out-Null
Write-JsonFile (Join-Path $pagesRoot 'pages.json') ([ordered]@{
    '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.1.0/schema.json'
    pageOrder = @($pageName)
    activePageName = $pageName
})

Write-JsonFile (Join-Path $pageRoot 'page.json') ([ordered]@{
    '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json'
    name = $pageName
    displayName = 'Iowa Liquor Overview'
    displayOption = 'FitToPage'
    height = 720
    width = 1280
})

$checksumTargets = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File |
    Where-Object { $_.Name -ne 'CHECKSUMS.sha256' -and $_.FullName -notmatch '\\.pbi\\' } |
    Sort-Object FullName
$checksumLines = foreach ($file in $checksumTargets) {
    $relative = $file.FullName.Substring($ProjectRoot.Length + 1).Replace('\', '/')
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    "$hash  $relative"
}
Write-Utf8File (Join-Path $ProjectRoot 'CHECKSUMS.sha256') (($checksumLines -join "`n") + "`n")

$projectBytes = (Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host "Hoan tat PowerBI_Share: $([math]::Round($projectBytes / 1MB, 2)) MiB" -ForegroundColor Green
