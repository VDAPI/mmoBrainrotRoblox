# Full quality gate: formatting, lint, types, unit tests. Run from anywhere: .\scripts\check.ps1
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

function Invoke-Step([string]$Name, [scriptblock]$Body) {
	Write-Host "==> $Name" -ForegroundColor Cyan
	# Native tools log to stderr; judge them by exit code only (Windows PowerShell 5.1 would throw).
	$ErrorActionPreference = "Continue"
	& $Body
	if ($LASTEXITCODE -ne 0) {
		Write-Host "FAILED: $Name" -ForegroundColor Red
		exit $LASTEXITCODE
	}
}

$defsUrl = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
if (-not (Test-Path "globalTypes.d.luau")) {
	Write-Host "==> Downloading globalTypes.d.luau" -ForegroundColor Cyan
	Invoke-WebRequest -Uri $defsUrl -OutFile "globalTypes.d.luau" -UseBasicParsing
}

Invoke-Step "StyLua" { stylua --check src tests }
Invoke-Step "Selene" { selene src tests }
Invoke-Step "Sourcemap" { rojo sourcemap default.project.json -o sourcemap.json }
Invoke-Step "luau-lsp analyze" {
	luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions:@roblox=globalTypes.d.luau `
		--ignore="Packages/**" --ignore="ServerPackages/**" src
}
Invoke-Step "Lune tests" { lune run tests/run.luau }
Write-Host "All checks passed." -ForegroundColor Green
