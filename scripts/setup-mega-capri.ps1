param(
    [switch]$InstallHooks
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$companion = Join-Path $root "integrations/capri-desktop1"
$patch = Join-Path $root "integrations/companion-adapter/patches/main-core-mode.patch"
$adapter = Join-Path $root "integrations/companion-adapter/core-bridge.js"

function Require-Command([string]$Name, [string]$InstallHint) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required. $InstallHint"
    }
}

Require-Command "git" "Install Git for Windows and reopen PowerShell."
Require-Command "node" "Install Node.js 20 or newer and reopen PowerShell."
Require-Command "npm" "Install Node.js 20 or newer and reopen PowerShell."

$nodeMajor = [int]((node --version).TrimStart("v").Split(".")[0])
if ($nodeMajor -lt 20) { throw "Node.js 20 or newer is required; found $nodeMajor." }

Push-Location $root
try {
    git submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) { throw "Could not initialize the CAPRI companion submodule." }

    Push-Location $companion
    try {
        git apply --check $patch 2>$null
        if ($LASTEXITCODE -eq 0) {
            git apply $patch
            if ($LASTEXITCODE -ne 0) { throw "Could not apply the Mega CAPRI companion adapter patch." }
        }
        elseif (-not (Select-String -Path "src/main/main.js" -Pattern "forwardCodingEvent" -Quiet)) {
            throw "The companion adapter patch does not match the pinned source revision."
        }
        Copy-Item -Force $adapter "src/main/core-bridge.js"
    }
    finally { Pop-Location }

    npm ci --prefix $companion
    if ($LASTEXITCODE -ne 0) { throw "Could not install the companion dependencies." }

    node --test (Join-Path $root "integrations/companion-adapter/tests/core-bridge.test.js")
    if ($LASTEXITCODE -ne 0) { throw "The Mega CAPRI bridge tests failed." }
    npm run test:hooks --prefix $companion
    if ($LASTEXITCODE -ne 0) { throw "The companion hook tests failed." }

    if ($InstallHooks) {
        npm run hooks:install --prefix $companion
        if ($LASTEXITCODE -ne 0) { throw "Claude Code hook installation failed." }
        npm run hooks:codex:install --prefix $companion
        if ($LASTEXITCODE -ne 0) { throw "Codex hook installation failed." }
        npm run hooks:agy:install --prefix $companion
        if ($LASTEXITCODE -ne 0) { throw "Antigravity hook installation failed." }
    }
}
finally {
    Pop-Location
}

Write-Host "CAPRI Mega integration is ready."
if (-not $InstallHooks) {
    Write-Host "Run this script with -InstallHooks to connect Claude Code, Codex and Antigravity."
}
