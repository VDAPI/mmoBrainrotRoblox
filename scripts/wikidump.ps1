# Wiki data export (S34): runs tools/wikidump.luau from the repository root with the given arguments.
#   .\scripts\wikidump.ps1                 -> wiki/src/data/*.json, types.ts, tokens.data.css, docs/PRZEDMIOTY.md
#   .\scripts\wikidump.ps1 --check         -> exit 1 when the committed data is out of date
Set-Location (Join-Path $PSScriptRoot "..")
lune run tools/wikidump.luau @args
exit $LASTEXITCODE
