$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$output = Join-Path $root 'Aquarium_ATO_V1_0_LCEDA_FullProject_Import.zip'
$packageRoot = 'Aquarium_ATO_V1_0_LCEDA_Import'
$requiredFiles = @(
    'Aquarium_ATO_V1_0.PrjPcb',
    '01_Power_Pump.SchDoc',
    '02_Controller_IO.SchDoc',
    '03_Sensors.SchDoc',
    'Aquarium_ATO_PhysicalPin_V1_1.SchLib',
    'Aquarium_ATO_Footprints_V1_1.PcbLib',
    'Aquarium_ATO_V1_0.PcbLib',
    'Aquarium_ATO_V1_0_LCEDA.PcbDoc',
    'README.md',
    'PROJECT_AUDIT.md',
    'PCB_LAYOUT.md',
    'generate_lceda_pcb.cjs',
    '00_pcb_preflight.js',
    '01_build_aquarium_pcb.js',
    'package_lceda_import.ps1',
    'BOM.csv',
    'pin-net.csv',
    'validation.json',
    'Aquarium_ATO_V1_0_LCEDA_AUDIT.txt',
    'FOOTPRINT_AUDIT.md',
    'FOOTPRINT_PIN_POSITION_AUDIT.md',
    'PINOUT_AUDIT.md',
    'library_sources'
)

foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required Altium project file is missing: $path"
    }
}

$entryPaths = @()
foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $root $relativePath
    if ((Get-Item -LiteralPath $path).PSIsContainer) {
        $entryPaths += Get-ChildItem -LiteralPath $path -File -Recurse |
            ForEach-Object { $_.FullName }
    } else {
        $entryPaths += $path
    }
}

$automationScripts = Get-ChildItem -LiteralPath $root -File |
    Where-Object { $_.Extension -in '.pas', '.PrjScr' } |
    Sort-Object Name
$entryPaths += $automationScripts | ForEach-Object { $_.FullName }

$documentPaths = Select-String -LiteralPath (Join-Path $root 'Aquarium_ATO_V1_0.PrjPcb') `
    -Pattern '^DocumentPath=(.+)$' |
    ForEach-Object { $_.Matches[0].Groups[1].Value }
foreach ($documentPath in $documentPaths) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $documentPath))) {
        throw "Altium project reference is missing: $documentPath"
    }
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path -LiteralPath $output) {
    Remove-Item -LiteralPath $output -Force
}

$archive = [System.IO.Compression.ZipFile]::Open(
    $output,
    [System.IO.Compression.ZipArchiveMode]::Create
)
try {
    foreach ($path in $entryPaths) {
        $relativePath = $path.Substring($root.Length).TrimStart('\', '/')
        $entryName = "$packageRoot/$($relativePath.Replace('\', '/'))"
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $path,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
} finally {
    $archive.Dispose()
}

Write-Output "Created complete EDA import package: $output"
Write-Output "Included project references: $($documentPaths.Count)"
Write-Output "Included Altium scripts: $($automationScripts.Count)"
Write-Output "Included files: $($entryPaths.Count)"
