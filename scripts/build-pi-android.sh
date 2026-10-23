#!/usr/bin/env bash
# Build the Pi coding agent for Android aarch64 via Bun.
# Requirements: Node.js 20+, Bun 1.4.2
# Usage: bash scripts/build-pi-android.sh [pi-version]
set -euo pipefail

PI_VERSION="${1:-v1.3.0}"
WORKDIR="$(pwd)/pi-build"
OUTDIR="$(pwd)/pkg"

echo "=== Cloning pi $PI_VERSION ==="
rm -rf "$WORKDIR"
git clone --depth 1 --branch "$PI_VERSION" https://github.com/earendil-works/pi "$WORKDIR/pi-src"
cd "$WORKDIR/pi-src"

echo "=== Installing dependencies ==="
npm install --ignore-scripts

echo "=== Building workspace packages (tsc) ==="
# coding-agent build fails with TS2307 unless these are built first.
# telemetry must come before ai (ai imports @earendil-works/pi-telemetry).
for pkg in telemetry tui ai agent codemode mcp; do
  echo "--- building packages/$pkg"
  # ai needs its model data generated first; the generate-models script is
  # TypeScript so it must run under bun (plain node can't run .ts files).
  if [ "$pkg" = "ai" ]; then
    (cd "packages/ai" && bun scripts/generate-models.ts --strict)
  fi
  (cd "packages/$pkg" && npx tsc -p tsconfig.build.json)
done

echo "=== Building coding-agent ==="
# NB: build:unbundled, not build — the bundle validation script fails on
# Node 20 (isBuiltin('node:sqlite') is false; node:sqlite was added in 22.5).
# We compile from dist/bun/cli.js anyway, so the bundle step is unnecessary.
(cd packages/coding-agent && npm run build:unbundled)

echo "=== Compiling for Android aarch64 ==="
cd packages/coding-agent
bun build ./dist/bun/cli.js ./src/utils/image-resize-worker.ts \
  ./src/extensions/codemode/worker.ts \
  --compile --target=bun-android-arm64 \
  --minify \
  --no-compile-autoload-bunfig --no-compile-autoload-dotenv \
  --outfile "$WORKDIR/pi.bin"

file "$WORKDIR/pi.bin"

echo "=== Packaging ==="
rm -rf "$OUTDIR"
mkdir -p "$OUTDIR/theme" "$OUTDIR/assets"
cp "$WORKDIR/pi.bin" "$OUTDIR/pi.bin"
cp ../../pi-termux/termux/pi "$OUTDIR/pi"
cp ../../pi-termux/termux/install.sh "$OUTDIR/install.sh"
cp package.json "$OUTDIR/package.json"
cp -r docs "$OUTDIR/docs"
cp src/modes/interactive/theme/dark.json src/modes/interactive/theme/light.json "$OUTDIR/theme/"
cp src/modes/interactive/assets/*.png "$OUTDIR/assets/" 2>/dev/null || true
chmod 755 "$OUTDIR/pi" "$OUTDIR/install.sh" "$OUTDIR/pi.bin"

echo "=== Done: $OUTDIR ==="
ls -la "$OUTDIR"
