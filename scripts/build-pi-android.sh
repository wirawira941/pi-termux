#!/usr/bin/env bash
# Build the Pi coding agent for Android aarch64 via Bun.
# Requirements: Node.js 22.19+, Bun 1.4.2
# Usage: bash scripts/build-pi-android.sh [pi-version]
set -euo pipefail

PI_VERSION="${1:-v1.6.0}"
WORKDIR="$(pwd)/pi-build"
OUTDIR="$(pwd)/pkg"

echo "=== Cloning pi $PI_VERSION ==="
rm -rf "$WORKDIR"
git clone --depth 1 --branch "$PI_VERSION" https://github.com/earendil-works/pi "$WORKDIR/pi-src"
cd "$WORKDIR/pi-src"

echo "=== Installing dependencies ==="
npm install --ignore-scripts

echo "=== Building workspace packages ==="
# coding-agent build fails with TS2307 unless these are built first.
# Order matters: schema before chord; telemetry/schema before ai;
# chord/ai/codemode/schema/telemetry before durable; chord/durable
# before env; ai/schema before agent.
for pkg in telemetry schema chord tui codemode mcp ai durable env agent; do
  echo "--- building packages/$pkg"
  if [ "$pkg" = "ai" ]; then
    # Model data generation is TypeScript; bun handles it without relying
    # on Node's type-stripping support. build:offline also copies
    # src/providers/data into dist for the compiled binary.
    (cd "packages/ai" && bun catalog/generate.ts --strict && npm run build:offline)
  else
    (cd "packages/$pkg" && npm run build)
  fi
done

echo "=== Building coding-agent ==="
# NB: build:unbundled, not build — we compile from dist/bun/cli.js anyway,
# so the extra bundle validation step is unnecessary.
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
