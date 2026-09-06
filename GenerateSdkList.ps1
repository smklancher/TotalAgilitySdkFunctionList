<#
.SYNOPSIS
    Generates a public API surface (one file per type) for TotalAgility.Sdk.dll
    and strips out unwanted lines (SecuritySafeCritical/SecurityCritical
    attributes and #nullable directives) from every generated file.

.PARAMETER InputFolder
    Folder containing TotalAgility.Sdk.dll. The generated .cs files are written
    here too.

.EXAMPLE
    .\Generate-PublicApi.ps1 -InputFolder "C:\Builds\TotalAgility"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFolder
)

$ErrorActionPreference = 'Stop'

# Normalize / validate the folder
$InputFolder = (Resolve-Path -Path $InputFolder).ProviderPath
$dllPath = Join-Path $InputFolder 'TotalAgility.Sdk.dll'

if (-not (Test-Path $dllPath)) {
    throw "Could not find TotalAgility.Sdk.dll in '$InputFolder'."
}

Write-Host "Installing/updating Meziantou.Framework.PublicApiGenerator.Tool..." -ForegroundColor Cyan
dotnet tool install --global Meziantou.Framework.PublicApiGenerator.Tool
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
    # dotnet tool install returns non-zero if already installed in some versions; treat only hard failures as fatal
    Write-Warning "dotnet tool install exited with code $LASTEXITCODE (may already be installed)."
}

Write-Host "Generating public API surface (one file per type)..." -ForegroundColor Cyan
Meziantou.Framework.PublicApiGenerator.Tool --input $dllPath --output $InputFolder --file-layout OneFilePerType
if ($LASTEXITCODE -ne 0) {
    throw "Meziantou.Framework.PublicApiGenerator.Tool failed with exit code $LASTEXITCODE."
}

# With OneFilePerType, output is a set of files like TotalAgility.Sdk.<Type>.g.cs
$generatedFiles = Get-ChildItem -Path $InputFolder -Filter 'TotalAgility.Sdk.*.g.cs' -File

if (-not $generatedFiles -or $generatedFiles.Count -eq 0) {
    throw "No generated files matching 'TotalAgility.Sdk.*.g.cs' were found in '$InputFolder'."
}

Write-Host "Found $($generatedFiles.Count) generated file(s) to clean." -ForegroundColor Cyan

$linesToRemove = @(
    '[System.Security.SecuritySafeCritical]',
    '[System.Security.SecurityCritical]',
    '#nullable restore',
    '#nullable disable',
    '#nullable enable'
)

foreach ($file in $generatedFiles) {
    Write-Host "Cleaning: $($file.FullName)" -ForegroundColor Cyan

    $content = Get-Content -Path $file.FullName

    $filtered = $content | Where-Object {
        $line = $_.Trim()
        -not ($linesToRemove -contains $line)
    }

    Set-Content -Path $file.FullName -Value $filtered -Encoding UTF8
}

Write-Host "Done. Cleaned $($generatedFiles.Count) file(s) in $InputFolder" -ForegroundColor Green