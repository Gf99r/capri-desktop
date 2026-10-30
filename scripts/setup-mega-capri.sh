#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPANION="$ROOT/integrations/capri-desktop1"
PATCH="$ROOT/integrations/companion-adapter/patches/main-core-mode.patch"
ADAPTER="$ROOT/integrations/companion-adapter/core-bridge.js"
INSTALL_HOOKS=0
if [[ "${1:-}" == "--install-hooks" ]]; then INSTALL_HOOKS=1; fi

for command in git node npm dotnet; do
  command -v "$command" >/dev/null 2>&1 || { echo "Missing required command: $command" >&2; exit 1; }
done
NODE_MAJOR="$(node -p 'Number(process.versions.node.split(".")[0])')"
(( NODE_MAJOR >= 20 )) || { echo "Node.js 20 or newer is required." >&2; exit 1; }
dotnet --list-sdks | grep -Eq '^10\.' || { echo ".NET 10 SDK is required." >&2; exit 1; }

cd "$ROOT"
git submodule update --init --recursive
cd "$COMPANION"
if git apply --check "$PATCH" 2>/dev/null; then
  git apply "$PATCH"
elif ! grep -q "forwardCodingEvent" src/main/main.js; then
  echo "The adapter patch does not match the pinned companion revision." >&2
  exit 1
fi
cp "$ADAPTER" src/main/core-bridge.js

dotnet build "$ROOT/cross/Capri.Cross.csproj" -c Release -o "$ROOT/out/cross"
npm ci
node --test "$ROOT/integrations/companion-adapter/tests/core-bridge.test.js"
npm run test:hooks

if (( INSTALL_HOOKS )); then
  npm run hooks:install
  npm run hooks:codex:install
  npm run hooks:agy:install
fi

echo "Mega CAPRI is ready. Launch it with scripts/start-mega-capri.sh"
