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

if (-not $SkipCore) {
    $coreCandidates = @(
        (Join-Path $root "out/windows/Capri.exe"),
        (Join-Path $root "out/cross/Capri.exe"),
        (Join-Path $root "out/cross/Capri")
    )
    $core = $coreCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($core) {
        Start-Process -FilePath $core -WorkingDirectory (Split-Path -Parent $core)
    }
    else {
        Write-Warning "The main CAPRI executable was not found. Build it with ./ci/build-windows.ps1 or dotnet build cross/Capri.Cross.csproj, then run this script again. Starting the coding-agent companion only."
    }
}

Start-Process -FilePath $electron -ArgumentList "." -WorkingDirectory $companion
Write-Host "CAPRI coding-agent companion launched. Claude Code, Codex and Antigravity events are handled by its local 127.0.0.1 bridge."
