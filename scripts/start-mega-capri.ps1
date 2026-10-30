param(
    [switch]$SkipCore
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$companion = Join-Path $root "integrations/capri-desktop1"
$electron = Join-Path $companion "node_modules/.bin/electron.cmd"

if (-not (Test-Path $electron)) {
    throw "Companion dependencies are missing. Run ./scripts/setup-mega-capri.ps1 first."
}

$core = $null
if (-not $SkipCore) {
    $coreCandidates = @(
        (Join-Path $root "out/windows/Capri.exe"),
        (Join-Path $root "out/cross/Capri.exe"),
        (Join-Path $root "out/cross/Capri")
    )
    $core = $coreCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if ($core) {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $env:CAPRI_BRIDGE_TOKEN = [Convert]::ToHexString($bytes).ToLowerInvariant()
    $env:CAPRI_CORE_PORT = "47824"
    $env:CAPRI_CORE_MODE = "1"
    Start-Process -FilePath $core -WorkingDirectory (Split-Path -Parent $core)
    Start-Sleep -Milliseconds 800
    Start-Process -FilePath $electron -ArgumentList "." -WorkingDirectory $companion
    Remove-Item Env:CAPRI_BRIDGE_TOKEN
    Remove-Item Env:CAPRI_CORE_PORT
    Remove-Item Env:CAPRI_CORE_MODE
}
else {
    if (-not $SkipCore) {
        Write-Warning "The main CAPRI executable was not found. Build it with ./ci/build-windows.ps1 or dotnet build cross/Capri.Cross.csproj. Starting the companion's full UI instead."
    }
    Start-Process -FilePath $electron -ArgumentList "." -WorkingDirectory $companion
}
Write-Host "Mega CAPRI launched. The .NET assistant is the visible host; the Electron coding-agent observer runs in the background."
