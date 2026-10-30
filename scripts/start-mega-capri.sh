#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPANION="$ROOT/integrations/capri-desktop1"
CORE="$ROOT/out/cross/Capri"
ELECTRON="$COMPANION/node_modules/.bin/electron"

[[ -x "$ELECTRON" ]] || { echo "Run scripts/setup-mega-capri.sh first." >&2; exit 1; }
[[ -x "$CORE" ]] || { echo "Build the .NET 10 host with scripts/setup-mega-capri.sh first." >&2; exit 1; }

export CAPRI_BRIDGE_TOKEN="$(node -e 'process.stdout.write(require("node:crypto").randomBytes(32).toString("hex"))')"
export CAPRI_CORE_PORT=47824
export CAPRI_CORE_MODE=1

nohup "$CORE" >/dev/null 2>&1 &
CORE_PID=$!
sleep 1
nohup "$ELECTRON" "$COMPANION" >/dev/null 2>&1 &
ELECTRON_PID=$!

unset CAPRI_BRIDGE_TOKEN CAPRI_CORE_PORT CAPRI_CORE_MODE
echo "Mega CAPRI started (host PID $CORE_PID, coding-agent observer PID $ELECTRON_PID)."
