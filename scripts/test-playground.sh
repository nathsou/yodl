#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
moon build src/lib/driver --target=js --release
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
bun build scripts/test-playground.ts src/main/playground-worker.ts --target=bun --outdir "$TEST_DIR" --root .
# Both entrypoints need to be siblings for the production worker URL convention.
mv "$TEST_DIR/src/main/playground-worker.js" "$TEST_DIR/scripts/playground-worker.js"
bun "$TEST_DIR/scripts/test-playground.js"
