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
# coding-agent build fails with TS2307 unless these are built first
for pkg in tui ai agent codemode mcp telemetry; do
  echo "--- building packages/$pkg"
  (cd "packages/$pkg" && npx tsc -b 2>/dev/null || npx tsc -p tsconfig.json)
done

echo "=== Building coding-agent ==="
(cd packages/coding-agent && npm run build)

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
chmod 755 "$OUTDIR/pi" "$OUTDIR/install.sh"

echo "=== Done: $OUTDIR ==="
ls -la "$OUTDIR"
