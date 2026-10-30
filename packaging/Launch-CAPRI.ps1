$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$hostExe = Join-Path $root 'host\Capri.exe'
$companionExe = Join-Path $root 'companion\Capri.exe'
if (-not (Test-Path -LiteralPath $hostExe)) { throw "CAPRI host is missing: $hostExe" }
if (-not (Test-Path -LiteralPath $companionExe)) { throw "CAPRI companion is missing: $companionExe" }
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$env:CAPRI_BRIDGE_TOKEN = [Convert]::ToHexString($bytes).ToLowerInvariant()
$env:CAPRI_CORE_PORT = '47824'
$env:CAPRI_CORE_MODE = '1'
try {
  Start-Process -FilePath $hostExe -WorkingDirectory (Split-Path -Parent $hostExe)
  Start-Sleep -Milliseconds 900
  Start-Process -FilePath $companionExe -WorkingDirectory (Split-Path -Parent $companionExe)
} finally {
  Remove-Item Env:CAPRI_BRIDGE_TOKEN -ErrorAction SilentlyContinue
  Remove-Item Env:CAPRI_CORE_PORT -ErrorAction SilentlyContinue
  Remove-Item Env:CAPRI_CORE_MODE -ErrorAction SilentlyContinue
}
