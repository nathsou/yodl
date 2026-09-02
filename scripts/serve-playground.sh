#!/bin/bash
set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
PORT="${PORT:-8080}"

if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port $PORT is already in use."
  echo "If it is an existing Yodl playground server, open http://localhost:${PORT}/playground.html."
  echo "Otherwise, choose another port, for example: PORT=8081 bash scripts/serve-playground.sh"
  exit 1
fi

moon build src/lib/driver --target=js --release
bun src/docs/build.ts
echo "Documentation: http://localhost:${PORT}/book/"
echo "Playground: http://localhost:${PORT}/playground.html"
echo "Restart after edits to rebuild. Press Ctrl+C to stop."
python3 -m http.server "$PORT" --directory dist
