#!/bin/bash
set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
PORT="${PORT:-8080}"
moon build src/lib/driver --target=js --release
bun src/docs/build.ts
echo "Documentation: http://localhost:${PORT}/book/"
echo "Playground: http://localhost:${PORT}/playground.html"
echo "Restart after edits to rebuild. Press Ctrl+C to stop."
python3 -m http.server "$PORT" --directory dist
