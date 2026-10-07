#!/usr/bin/env bash
# Wiki data export (S34): runs tools/wikidump.luau from the repository root with the given arguments.
#   bash scripts/wikidump.sh            -> wiki/src/data/*.json, types.ts, tokens.data.css, docs/PRZEDMIOTY.md
#   bash scripts/wikidump.sh --check    -> exit 1 when the committed data is out of date
set -euo pipefail
cd "$(dirname "$0")/.."
lune run tools/wikidump.luau "$@"
