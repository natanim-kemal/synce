param(
  [string]$ReleaseDir = "client/build/windows/x64/runner/Release",
  [string]$OutputPath = "client/build/synce-windows-setup.exe",
  [string]$Version = "0.0.0",
  [string]$NsiScript = "client/windows/synce.nsi"
)

$ErrorActionPreference = 'Stop'

$makensis = @(
  "C:\Program Files (x86)\NSIS\makensis.exe",
  "C:\Program Files\NSIS\makensis.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $makensis) { throw "makensis not found, install NSIS first" }

$release = (Resolve-Path $ReleaseDir).Path
$output = [System.IO.Path]::GetFullPath($OutputPath)
$script = (Resolve-Path $NsiScript).Path

& $makensis "/DOUTFILE=$output" "/DBINDIR=$release" "/DVERSION=$Version" $script
if ($LASTEXITCODE -ne 0) { throw "makensis failed with exit code $LASTEXITCODE" }
if (-not (Test-Path $output)) { throw "installer was not produced at $output" }

Write-Host "packaged $output ($([math]::Round((Get-Item $output).Length / 1MB, 2)) MB)"
