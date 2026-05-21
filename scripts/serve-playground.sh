#!/bin/bash

# Exit on error
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PORT="${PORT:-8080}"

echo "Building MoonBit driver (JS target)..."
moon build src/lib/driver --target=js --release

echo "Bundling playground JS..."
bun build src/main/yodl.ts --outdir src/main/bundle --minify

echo ""
echo "Playground ready. Open http://localhost:${PORT}/src/main/playground.html"
echo "Press Ctrl+C to stop."
echo ""

python3 -m http.server "$PORT"
