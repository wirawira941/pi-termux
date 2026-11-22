# pi-termux

Run the **Pi coding agent** natively on **Termux** (Android aarch64).

Pi ([earendil-works/pi](https://github.com/earendil-works/pi)) is a
token-efficient coding agent (sub-1,000-token system prompt) with 4 core tools
(Read/Write/Edit/Bash) and built-in MCP support. It has **no native
dependencies** and already bundles to a single file, making it the easiest
agent to port to Termux.

## Quick install

```sh
# Download the latest pi-termux zip from Releases
mkdir ~/pi-termux && cd ~/pi-termux
unzip ~/pi-termux-android-aarch64.zip
bash install.sh

# Run
pi-termux --version
```

Use `pi-termux` (not `pi`) to avoid clashing with any existing install.

## Custom model endpoint

Pi supports OpenAI-compatible endpoints via `~/.pi/models.json`:

```json
{
  "providers": {
    "my-endpoint": {
      "baseUrl": "http://localhost:11434/v1",
      "api": "openai-completions",
      "apiKey": "ollama",
      "models": [{ "id": "qwen2.5-coder:7b" }]
    }
  }
}
```

Then pick the model with `/model` inside Pi.

## How it works

- `termux/pi` — launcher script. Exports `PI_PACKAGE_DIR` so Pi finds its
  `package.json` (version), `docs/`, and `theme/` assets. This works around
  a Bun-on-Android bug where `process.execPath` points to
  `/apex/com.android.runtime/bin/linker64` instead of the actual binary.
- `termux/install.sh` — installs `pi.bin`, the launcher, `package.json`,
  `docs/`, `theme/`, and `assets/` into `$PREFIX/libexec/pi-termux`.

## Building from source

Requirements: Node.js 22.19+, Bun 1.4.2.

```sh
bash scripts/build-pi-android.sh
```

Build steps (Pi v1.6.0):

1. Clone `earendil-works/pi`, `npm install --ignore-scripts`
2. Build workspace packages in dependency order:
   `telemetry`, `schema`, `chord`, `tui`, `codemode`, `mcp`, `ai`,
   `durable`, `env`, `agent`
   - build each package with `npm run build`
   - for `ai`, generate its model data first:
     `(cd packages/ai && bun catalog/generate.ts --strict)`
     then run `npm run build:offline` (it validates the generated data,
     compiles with tsc, and copies `src/providers/data` into `dist/`)
   (coding-agent fails with TS2307 unless these are built first)
3. `npm run build:unbundled` in `packages/coding-agent` → `dist/bun/cli.js`
   (not `npm run build` — the bundle validation step is unnecessary here
   because we compile from `dist/bun/cli.js`)
4. Compile with Bun:
   ```
   bun build ./dist/bun/cli.js ./src/utils/image-resize-worker.ts \
     ./src/extensions/codemode/worker.ts \
     --compile --target=bun-android-arm64 \
     --no-compile-autoload-bunfig --no-compile-autoload-dotenv \
     --outfile pi.bin
   ```
   **Important:** compile the official entrypoint `dist/bun/cli.js`, not
   `dist/bundle/cli.js` (the latter loads sibling files at runtime and fails
   with "Cannot find module './cli-runtime.js'").
5. Package `pi.bin` + wrapper + `package.json` + `docs/` + `theme/` +
   `assets/` into a zip.

## License

Wrapper scripts: MIT. Pi itself is MIT by Earendil.
