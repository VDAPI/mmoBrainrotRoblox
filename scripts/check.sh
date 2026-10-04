#!/usr/bin/env bash
# Full quality gate: formatting, lint, types, unit tests. Run from the repo root.
set -euo pipefail
cd "$(dirname "$0")/.."

DEFS_URL="https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
if [ ! -f globalTypes.d.luau ]; then
	echo "==> Downloading globalTypes.d.luau"
	curl -sfL -o globalTypes.d.luau "$DEFS_URL"
fi

echo "==> StyLua"
stylua --check src tests
echo "==> Selene"
selene src tests
echo "==> Sourcemap"
rojo sourcemap default.project.json -o sourcemap.json
echo "==> luau-lsp analyze"
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions:@roblox=globalTypes.d.luau \
	--ignore="Packages/**" --ignore="ServerPackages/**" src
echo "==> Lune tests"
lune run tests/run.luau
echo "All checks passed."
